defmodule Cased.CLI.Identity do
  @moduledoc """
  The modulus represents gen_server behaviour to identify user.
  """

  use GenServer

  alias Cased.CLI.Api
  alias Cased.CLI.Config

  @poll_timer 1_000

  defmodule State do
    @moduledoc false
    defstruct api_url: nil,
              code: nil,
              url: nil,
              id: nil,
              user: nil,
              ip_address: nil

    @type t :: __MODULE__
  end

  ## Client API

  def start do
    case Process.whereis(__MODULE__) do
      nil -> start_link([])
      pid -> {:ok, pid}
    end
  end

  @doc """
  Start user identify and wait result.
  """
  def identify do
    GenServer.cast(__MODULE__, {:identify, self()})
    wait_identify()
  end

  @doc "Get current identity"
  @spec get() :: Cased.CLI.Identity.State.t()
  def get do
    GenServer.call(__MODULE__, :get)
  end

  def reset do
    GenServer.call(__MODULE__, :reset)
  end

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def wait_identify do
    receive do
      {:identify_init, url} ->
        Cased.CLI.Shell.info("To login, please visit:")
        Cased.CLI.Shell.info(url)
        wait_identify()

      :identify_done ->
        IO.write("\r")
        Cased.CLI.Shell.info("Identify is complete")
        Cased.CLI.Shell.info("Start cli session. ")
        send(self(), :start_session)

      {:identify_retry, count} ->
        Cased.CLI.Shell.progress("#{String.duplicate(".", count)}")
        wait_identify()

      {:error, error} ->
        Cased.CLI.Shell.info("Identify is fail. (#{inspect(error)}) ")
    after
      50_000 ->
        IO.write("\n")
        Cased.CLI.Shell.info("Identify is't complete")
    end
  end

  ## Server callback
  @impl true
  def init(_opts) do
    opts =
      case Config.token() do
        nil -> %{}
        token -> %{user: %{"id" => token}}
      end

    Cased.CLI.Runner.started(:identify)
    {:ok, State.__struct__(opts)}
  end

  @impl true
  def handle_call(:get, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_call(:reset, _from, _state) do
    new_state = State.__struct__()
    {:reply, new_state, new_state}
  end

  @impl true
  def handle_cast({:identify, console_pid}, %{user: %{"id" => token}} = state)
      when is_binary(token) do
    send(console_pid, :identify_done)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:identify, console_pid}, state) do
    case Api.Identity.identify() do
      {:ok, %{"url" => url, "code" => code, "api_url" => api_url}} ->
        new_state = %{state | url: url, code: code, api_url: api_url}
        send(console_pid, {:identify_init, url})
        Process.send_after(self(), {:check, console_pid, 0}, @poll_timer)
        {:noreply, new_state}

      error ->
        send(console_pid, {:error, error})
        {:noreply, state}
    end
  end

  @impl true
  def handle_info({:check, console_pid, count}, state) do
    new_state =
      case Api.Identity.check(state) do
        {:ok, %{"id" => id, "user" => user, "ip_address" => ip_address}} ->
          send(console_pid, :identify_done)
          %{state | id: id, user: user, ip_address: ip_address}

        _error ->
          Process.send_after(self(), {:check, console_pid, count + 1}, @poll_timer)
          send(console_pid, {:identify_retry, count + 1})
          state
      end

    {:noreply, new_state}
  end

  def handle_info(_, state) do
    {:noreply, state}
  end
end
