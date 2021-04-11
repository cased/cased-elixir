defmodule Cased.CLI.Session do
  @moduledoc false

  use GenServer

  @poll_timer 1_000

  alias Cased.CLI.Api

  defmodule State do
    @moduledoc false
    defstruct id: nil,
              url: nil,
              api_url: nil,
              api_record_url: nil,
              state: nil,
              metadata: nil,
              reason: nil,
              command: nil,
              guard_application: nil

    def from_session(state, session) do
      %{
        state
        | id: Map.get(session, "id"),
          url: Map.get(session, "url"),
          api_url: Map.get(session, "api_url"),
          api_record_url: Map.get(session, "api_record_url"),
          state: Map.get(session, "state"),
          metadata: Map.get(session, "metadata"),
          reason: Map.get(session, "reason"),
          command: Map.get(session, "command"),
          guard_application: Map.get(session, "guard_application")
      }
    end
  end

  ## Client API

  def start do
    case Process.whereis(__MODULE__) do
      nil -> start_link()
      pid -> {:ok, pid}
    end
  end

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def get do
    GenServer.call(__MODULE__, :get)
  end

  def create(io_pid, attrs \\ %{}) do
    GenServer.cast(__MODULE__, {:create, io_pid, Cased.CLI.Identity.get(), attrs})
    wait_session(io_pid)
  end

  def upload_record(data) do
    GenServer.call(__MODULE__, {:save_record, Cased.CLI.Identity.get(), data})
  end

  def wait_session(io_pid) do
    receive do
      {:session, %{state: "approved"} = _session, _} ->
        send(io_pid, :start_record)

      {:session, %{state: "requested"}, counter} ->
        Cased.CLI.Shell.progress("Approval request sent#{String.duplicate(".", counter)}")
        wait_session(io_pid)

      {:error, %{state: "denied"}, _} ->
        IO.write("\n")
        Cased.CLI.Shell.error("CLI session has been denied")
        :init.stop()

      {:error, %{state: "timed_out"}, _} ->
        IO.write("\n")
        Cased.CLI.Shell.error("CLI session has timed out")
        :init.stop()

      {:error, %{state: "canceled"}, _} ->
        IO.write("\n")
        Cased.CLI.Shell.error("CLI session has been canceled")
        :init.stop()

      {:error, "reason_required", _session} ->
        reason = Cased.CLI.Shell.prompt("Please enter a reason for access")
        send(io_pid, {:start_session, %{reason: reason}})

      {:error, "authenticate", _session} ->
        send(io_pid, :authenticate)

      {:error, "reauthenticate", _session} ->
        Cased.CLI.Shell.error(
          "You must re-authenticate with Cased due to recent changes to this application's settings."
        )

        send(io_pid, :reauthenticate)

      {:error, "unauthorized", _session} ->
        Cased.CLI.Shell.error("CLI session has error: unauthorized")

        if Cased.CLI.Config.use_credentials?() do
          Cased.CLI.Shell.error("Existing credentials are not valid.")
        end

        send(io_pid, :unauthorized)

      {:error, error, _session} ->
        IO.write("\n")
        Cased.CLI.Shell.error("CLI session has error: #{inspect(error)}")
    after
      50_000 ->
        IO.write("\n")
        Cased.CLI.Shell.error("Could not start CLI session.")
        :init.stop()
    end
  end

  ## Server callback
  @impl true
  def init(opts) do
    {:ok, State.__struct__(opts)}
  end

  @impl true
  def handle_call(:get, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_call({:save_record, identity, data}, _from, state) do
    Api.Session.put_record(state, identity, data)
    {:reply, state, state}
  end

  @impl true

  def handle_cast({:create, console_pid, %{user: nil}, _}, state) do
    send(console_pid, {:error, "authenticate", state})
    {:noreply, state}
  end

  @impl true
  def handle_cast({:create, console_pid, identity, attrs}, state) do
    case Api.Session.create(identity, attrs) do
      {:ok, session} ->
        new_state = State.from_session(state, session)

        with %{state: "requested"} <- new_state do
          Process.send_after(self(), {:wait_approval, console_pid, identity, 0}, @poll_timer)
        end

        send(console_pid, {:session, new_state, 0})
        {:noreply, new_state}

      {:invalid, %{"error" => error}} ->
        send(console_pid, {:error, error, state})
        {:noreply, state}

      {_, _reason} ->
        {:noreply, state}
    end
  end

  @impl true
  def handle_info({:wait_approval, console_pid, identify, counter}, %{id: id} = state) do
    case Api.Session.retrive(identify, id) do
      {:ok, session} ->
        new_state = State.from_session(state, session)

        with %{state: "requested"} <- new_state do
          Process.send_after(
            self(),
            {:wait_approval, console_pid, identify, counter + 1},
            @poll_timer
          )
        end

        send(console_pid, {:session, new_state, counter})
        {:noreply, new_state}

      {:error, %{"id" => _} = session} ->
        new_state = State.from_session(state, session)
        send(console_pid, {:error, new_state, 0})
        {:noreply, new_state}

      {:error, error} ->
        send(console_pid, {:error, error, state})
        {:noreply, state}

      _ ->
        {:noreply, state}
    end
  end

  def handle_info(_msg, state) do
    {:noreply, state}
  end
end
