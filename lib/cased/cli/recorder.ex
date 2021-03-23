defmodule Cased.CLI.Recorder do
  use GenServer

  ## Client API

  def start() do
    case Process.whereis(__MODULE__) do
      nil -> start_link()
      pid -> {:ok, pid}
    end
  end

  def put_event(event) do
    GenServer.call(__MODULE__, {:put_event, event})
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
  end

  def stop_record do
    GenServer.call(__MODULE__, :stop)
  end

  def get do
    GenServer.call(__MODULE__, :get)
  end

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  ## Server callback

  @impl true
  def init(_opts) do
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
  def handle_call({:put_event, event}, _from, state) do
    new_state = %{
      state
      | events: [{DateTime.now!("Etc/UTC"), event} | state[:events]]
    }

    {:reply, new_state, new_state}
  end

  @impl true
  def handle_info({:tty_data, event}, state) do
    clear_data = String.trim_trailing(event)

    new_state =
      case state[:events] do
        [{_, previous_event} | _] ->
          if String.trim_trailing(previous_event) == clear_data do
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

  def add_event(state, event) do
    %{
      state
      | events: [
          {DateTime.now!("Etc/UTC"), event} | state[:events]
        ]
    }
  end
end
