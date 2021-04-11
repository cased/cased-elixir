defmodule Cased.CLI.Recorder do
  @moduledoc false

  use GenServer, shutdown: 30_000

  def stop_record() do
    GenServer.call(__MODULE__, :stop)
    do_upload()

    :init.stop()
  end

  def get do
    GenServer.call(__MODULE__, :get)
  end

  def start_record(config) do
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

    Cased.CLI.Runner.execute_in_shell(
      "import(Cased.CLI, only: [stop: 0]);IEx.dont_display_result()"
    )

    IEx.configure(
      default_prompt:
        IO.ANSI.green() <> "(cased)" <> IO.ANSI.reset() <> IEx.configuration()[:default_prompt]
    )

    IO.write("\n")
    Cased.CLI.Shell.info("Start record.")

    Cased.CLI.Shell.info("usage `stop` to close session .")
    IEx.dont_display_result()
    GenServer.call(__MODULE__, {:start, meta, config})
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
       buf: "",
       cursor_position: 0,
       config: %{}
     }}
  end

  def handle_call(:get, _from, state) do
    {:reply, state, state}
  end

  def handle_call(:stop, _from, state) do
    :erlang.trace(:all, false, [:all])
    {:reply, state, state}
  end

  def handle_call({:start, meta, config}, _from, state) do
    new_state = %{
      state
      | record: true,
        meta: meta,
        events: [],
        started_at: DateTime.now!("Etc/UTC"),
        config: config
    }

    do_autoupload(self(), config)

    :erlang.trace(
      Process.whereis(:user_drv),
      true,
      [:receive, :timestamp]
    )

    {:reply, new_state, new_state}
  end

  def handle_info(:upload, %{uploading: false, record: true, events: [_ | _]} = state) do
    uploader_pid = spawn(fn -> upload() end)
    do_autoupload(self(), state[:config])
    {:noreply, %{state | uploading: true, uploader_pid: uploader_pid}}
  end

  def handle_info(:upload, %{record: true} = state) do
    do_autoupload(self(), state[:config])
    {:noreply, state}
  end

  def handle_info(:upload, state), do: {:noreply, state}

  def handle_info(:uploaded, state) do
    {:noreply, %{state | uploading: false, uploader_pid: nil}}
  end

  def handle_info({:trace_ts, _, :receive, {_, {:requests, [_ | _] = events}}, ts} = _msg, state) do
    buf = state[:buf]

    {event_data, buf, cursor_position} =
      Enum.reduce(events, {[], buf, state[:cursor_position]}, fn
        {:move_rel, 0}, {acc, buf, pos} ->
          {[IO.ANSI.cursor_left(1) | acc], buf, pos - 1}

        {:move_rel, n}, {acc, buf, pos} when n < 0 ->
          {[IO.ANSI.cursor_left(abs(n)) | acc], buf, pos + n}

        {:move_rel, n}, {acc, buf, pos} when n > 0 ->
          {[IO.ANSI.cursor_right(n) | acc], buf, pos + n}

        {:delete_chars, 0}, {acc, buf, pos} ->
          {[IO.ANSI.cursor_left(1) <> "\e[2K" | acc], buf, pos - 1}

        {:delete_chars, n}, {acc, buf, pos} ->
          length_buf = String.length(buf)
          new_pos = pos - n
          tail_buf = String.slice(buf, new_pos, length_buf)
          new_buf = String.slice(buf, 0, new_pos - 1) <> " " <> tail_buf
          {[IO.ANSI.cursor_left(abs(n)) <> "\e[1P" | acc], new_buf, new_pos}

        {:insert_chars, :unicode, value}, {acc, buf, pos} ->
          new_pos = pos + 1
          length_buf = String.length(buf)
          tail_buf = String.slice(buf, pos, length_buf)
          new_buf = String.slice(buf, 0, pos) <> IO.chardata_to_string(value) <> tail_buf
          {["\u001b[1@#{IO.chardata_to_string(value)}" | acc], new_buf, new_pos}

        {:put_chars, :unicode, data}, {acc, buf, _pos} ->
          [new_buf | _] = String.split(buf <> IO.chardata_to_string(data), "\n") |> Enum.reverse()
          new_pos = String.length(new_buf) - 1
          {[data | acc], new_buf, new_pos}

        _event, acc ->
          acc
      end)

    event_data =
      event_data
      |> Enum.reverse()
      |> Enum.join()

    new_state =
      %{state | buf: buf, cursor_position: cursor_position}
      |> add_event(ts, event_data)

    {:noreply, new_state}
  end

  def handle_info({:trace_ts, _, _, {_, {:put_chars_sync, :unicode, data, _}}, ts} = _msg, state) do
    new_state =
      %{state | buf: "", cursor_position: 0}
      |> add_event(ts, data)

    {:noreply, new_state}
  end

  def handle_info(_msg, state) do
    {:noreply, state}
  end

  def terminate(_reason, state) do
    :erlang.trace(:all, false, [:all])
    Cased.CLI.Shell.info("Close `Cased` session.")
    do_upload(state)
    :normal
  end

  defp add_event(%{events: events} = state, ts, event) do
    event_data = String.replace(IO.chardata_to_string(event), "\n", "\r\n")

    start_ts =
      case events do
        [{start_ts, _, _} | _] -> start_ts
        _ -> ts
      end

    events = [{start_ts, :timer.now_diff(ts, start_ts) / 1_000_000, event_data} | events]

    %{state | events: events}
  end

  defp do_upload(record \\ nil) do
    record = record || __MODULE__.get()

    case record do
      %{events: [_ | _]} ->
        record
        |> Cased.CLI.Asciinema.File.build()
        |> Cased.CLI.Session.upload_record()

      _ ->
        :ok
    end
  end

  defp upload() do
    do_upload()
    send(Process.whereis(__MODULE__), :uploaded)
  end

  defp do_autoupload(pid, %{autoupload: true, autoupload_timer: timer}) do
    Process.send_after(pid, :upload, timer)
  end

  defp do_autoupload(_pid, _config), do: :ok
end
