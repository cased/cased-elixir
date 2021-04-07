defmodule Cased.CLI.Runner do
  @moduledoc false
  use GenServer

  @keys [:autorun]

  def start_link(opts \\ %{}) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def started(component) do
    GenServer.cast(__MODULE__, {:started, component})
  end

  ## Server callback
  @impl true
  def init(opts) do
    {:ok, Map.take(Map.new(opts), @keys)}
  end

  @impl true
  def handle_cast({:started, component}, state) do
    new_state =
      state
      |> Map.merge(%{component => :started})
      |> autorun

    do_run(new_state)
    {:noreply, new_state}
  end

  @impl true
  def handle_info(_, state), do: {:noreply, state}

  def do_run(%{config: :started, identify: :started, autorun: true}) do
    run()
  end

  def do_run(_), do: :ok

  def run() do
    if is_pid(IEx.Broker.shell()) do
      {:group_leader, gl} = Process.info(IEx.Broker.shell(), :group_leader)
      Cased.CLI.start(gl)
    end
  end

  defp autorun(%{config: :started} = state) do
    if Cased.CLI.Config.get(:autorun, false) do
      Map.merge(state, %{autorun: true})
    else
      state
    end
  end

  defp autorun(state), do: state
end
