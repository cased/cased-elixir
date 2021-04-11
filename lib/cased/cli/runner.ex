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

  def execute_in_shell(command) do
    send(Process.whereis(__MODULE__), {:execute_in_shell, command})
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
  def handle_info({:execute_in_shell, command}, state) do
    with sev_pid when is_pid(sev_pid) <- IEx.Broker.shell(),
         {_, dict} <- Process.info(sev_pid, :dictionary),
         eval_pid when is_pid(eval_pid) <- Keyword.get(dict, :evaluator) do
      send(eval_pid, {:eval, sev_pid, command, %IEx.State{}})
    else
      _ ->
        Process.send_after(self(), {:execute_in_shell, command}, 1000)
    end

    {:noreply, state}
  end

  def handle_info(_, state), do: {:noreply, state}

  def do_run(%{config: :started, identify: :started, autorun: true}) do
    run()
  end

  def do_run(_), do: :ok

  def run do
    if is_pid(IEx.Broker.shell()) do
      {:group_leader, gl} = Process.info(IEx.Broker.shell(), :group_leader)
      Cased.CLI.start(gl)
    end
  end

  defp autorun(%{config: :started} = state) do
    if Cased.CLI.Config.autorun() do
      Map.merge(state, %{autorun: true})
    else
      state
    end
  end

  defp autorun(state), do: state
end
