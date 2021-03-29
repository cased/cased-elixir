defmodule Cased.CLI.Recorder do
  use GenServer

  ## Client API

  def start() do
    case Process.whereis(__MODULE__) do
      nil -> start_link()
      pid -> {:ok, pid}
    end
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
      arguments: :init.get_plain_arguments()
    }

    GenServer.call(__MODULE__, {:start, meta})

    pid = Process.whereis(__MODULE__)

    opts = [
      type: :elixir,
      shell_opts: shell_opts(),
      handler: pid,
      name: :ex_tty_handler_cased
    ]

    IO.write(IO.ANSI.clear() <> IO.ANSI.home())
    {:ok, iex_pid} = GenServer.start_link(ExTTY, opts)
    loop_io(iex_pid)
  end

  def shell_opts do
    [
      [
        prefix: IO.ANSI.green() <> "[cased] " <> IO.ANSI.reset(),
        dot_iex_path:
          [".iex.exs", "~/.iex.exs", "/etc/iex.exs"]
          |> Enum.map(&Path.expand/1)
          |> Enum.find("", &File.regular?/1)
      ],
      {__MODULE__, :record_usage, []}
    ]
  end

  def record_usage do
    IO.puts("""
    Cased start record.
    /q   -  Stop record
    """)
  end

  def stop_record(iex_pid) do
    GenServer.call(__MODULE__, :stop)

    Cased.CLI.Recorder.get()
    |> Cased.CLI.Asciinema.File.build()
    |> Cased.CLI.Session.upload_record()

    _ = Process.unlink(iex_pid)
    :ok = GenServer.stop(iex_pid, :normal, 10_000)
    send(self(), :stopped_record)
  end

  def get do
    GenServer.call(__MODULE__, :get)
  end

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def loop_io(iex_pid) do
    send(self(), {:input, self(), IO.gets(:stdio, "")})
    wait_input(iex_pid)
  end

  def wait_input(iex_pid) do
    receive do
      {:input, :eof} ->
        stop_record(iex_pid)

      {:input, _, "/q" <> _} ->
        stop_record(iex_pid)

      {:input, _, data} ->
        ExTTY.send_text(iex_pid, data)
        loop_io(iex_pid)

      _msg ->
        loop_io(iex_pid)
    end
  end

  ## Server callback

  @impl true
  def init(_opts) do
    Process.flag(:trap_exit, true)

    {:ok,
     %{
       record: false,
       started_at: nil,
       finished_at: nil,
       meta: %{},
       events: []
     }}
  end

  @impl true
  def handle_call(:get, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_call({:start, meta}, _from, state) do
    new_state = %{
      state
      | record: true,
        meta: meta,
        events: [],
        started_at: DateTime.now!("Etc/UTC")
    }

    {:reply, new_state, new_state}
  end

  @impl true
  def handle_call(:stop, _from, state) do
    new_state = %{
      state
      | record: false,
        finished_at: DateTime.now!("Etc/UTC")
    }

    {:reply, new_state, new_state}
  end

  @impl true
  def handle_info({:tty_data, event}, state) do
    clear_data = String.trim_trailing(event, "\r\n")

    new_state =
      case state[:events] do
        [{_, previous_event} | _] ->
          if String.trim_trailing(previous_event, "\r\n") == clear_data do
            state
          else
            IO.write(event)
            add_event(state, event)
          end

        _ ->
          IO.write(event)
          add_event(state, event)
      end

    {:noreply, new_state, 300_000}
  end

  def handle_info(_msg, state) do
    {:noreply, [], state}
  end

  defp add_event(state, event) do
    %{
      state
      | events: [
          {DateTime.now!("Etc/UTC"), event} | state[:events]
        ]
    }
  end
end
