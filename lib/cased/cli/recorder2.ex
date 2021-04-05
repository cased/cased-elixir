defmodule Cased.CLI.Recorder2 do
  use GenServer

  @upload_timer 5_000

  def stop_record() do
    GenServer.call(__MODULE__, :stop)

    __MODULE__.get()
    |> Cased.CLI.Asciinema.File.build()
    |> Cased.CLI.Session.upload_record()

    :init.stop()
  end

  def get do
    GenServer.call(__MODULE__, :get)
  end

  def start_record do
    {_, rows} = :io.rows()
    {_, columns} = :io.columns()
    {_, [progname]} = :init.get_argument(:progname)

    meta = %{
      shell: System.get_env("SHELL"),
      term: System.get_env("TERM"),
      rows: rows,
      columns: columns,
      command: progname,
      arguments: :init.get_plain_arguments(),
      original_prompt: IEx.configuration()[:default_prompt]
    }

    GenServer.call(__MODULE__, {:start, meta})

    IEx.configure(
      default_prompt:
        IO.ANSI.green() <> "(cased)" <> IO.ANSI.reset() <> IEx.configuration()[:default_prompt]
    )

    IO.write("\n")
    Cased.CLI.Shell.info("Start record.")
    IEx.dont_display_result()
    GenServer.call(__MODULE__, {:start, meta})
    IEx.dont_display_result()
  end

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    Process.flag(:trap_exit, true)

    {:ok,
     %{
       uploading: false,
       uploader_pid: nil,
       record: false,
       started_at: nil,
       finished_at: nil,
       meta: %{},
       events: [],
       raw_events: [],
       buf: ""
     }}
  end

  def handle_call(:get, _from, state) do
    {:reply, state, state}
  end

  def handle_call(:stop, _from, state) do
    :erlang.trace(:all, false, [:all])
    {:reply, state, state}
  end

  def handle_call({:start, meta}, _from, state) do
    new_state = %{
      state
      | record: true,
        meta: meta,
        events: [],
        started_at: DateTime.now!("Etc/UTC")
    }

    Process.send_after(self(), :upload, @upload_timer)

    :erlang.trace(
      Process.whereis(:user_drv),
      true,
      [:receive, :timestamp]
    )

    {:reply, new_state, new_state}
  end

  def handle_info(:upload, %{uploading: false, record: true} = state) do
    uploader_pid = spawn(fn -> do_upload() end)
    Process.send_after(self(), :upload, @upload_timer)
    {:noreply, %{state | uploading: true, uploader_pid: uploader_pid}}
  end

  def handle_info(:upload, %{record: true} = state) do
    Process.send_after(self(), :upload, @upload_timer)
    {:noreply, state}
  end

  def handle_info(:upload, state), do: {:noreply, state}

  def handle_info(:uploaded, state) do
    {:noreply, %{state | uploading: false, uploader_pid: nil}}
  end

  def handle_info({:trace_ts, _, :receive, {_, {:requests, [_ | _] = events}}, ts} = _msg, state) do
    event_data =
      Enum.reduce(events, [], fn
        {:move_rel, 0}, acc ->
          [IO.ANSI.cursor_left(1) | acc]

        {:move_rel, n}, acc when n < 0 ->
          [IO.ANSI.cursor_left(abs(n)) | acc]

        {:move_rel, n}, acc when n > 0 ->
          [IO.ANSI.cursor_right(n) | acc]

        {:delete_chars, 0}, acc ->
          [IO.ANSI.cursor_left(1) <> "\e[2K" | acc]

        {:delete_chars, n}, acc ->
          [IO.ANSI.cursor_left(abs(n)) <> "\e[0K" | acc]

        {:insert_chars, :unicode, value}, ["\e[1D\e[2K" | acc] ->
          [value | acc]

        {:insert_chars, :unicode, value}, acc ->
          [value | acc]

        {:put_chars, :unicode, data}, acc ->
          [data | acc]

        _event, acc ->
          acc
      end)
      |> Enum.reverse()
      |> Enum.join()

    new_state = add_event(state, ts, event_data)
    {:noreply, new_state}
  end

  def handle_info({:trace_ts, _, _, {_, {:put_chars_sync, :unicode, data, _}}, ts} = _msg, state) do
    {:noreply, add_event(state, ts, data)}
  end

  def handle_info(_msg, state) do
    {:noreply, state}
  end

  defp get_datetime({megasec, sec, _}) do
    unix_timestamp = megasec * 1_000_000 + sec

    DateTime.from_unix!(unix_timestamp)
  end

  defp add_event(state, ts, event) do
    event_data = String.replace(IO.chardata_to_string(event), "\n", "\r\n")
    events = [{get_datetime(ts), event_data} | state[:events]]

    %{state | events: events}
  end

  defp do_upload() do
    __MODULE__.get()
    |> Cased.CLI.Asciinema.File.build()
    |> Cased.CLI.Session.upload_record()

    send(Process.whereis(__MODULE__), :uploaded)
  end
end
