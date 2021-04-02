defmodule Cased.CLI.Runner do
  @moduledoc false
  use GenServer

  @keys [:autorun]

  alias Cased.CLI.Shell

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
    new_state = Map.merge(state, %{component => :started})
    do_run(new_state)
    {:noreply, new_state}
  end

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

  @new_file_line "\n#cased-new-file\nCased.CLI.start\n"
  @exist_file_line "\n#cased-exists-file\nCased.CLI.start\n"

  def autorun(true) do
    file_path = Path.expand(".iex.exs")

    case File.exists?(file_path) do
      true ->
        if not String.contains?(File.read!(file_path), "Cased.CLI.start") do
          File.write(file_path, @exist_file_line, [:append])
        end

      _ ->
        File.write(file_path, @new_file_line)
    end
  end

  def autorun(_), do: :ok

  def post_run(true) do
    file_path = Path.expand(".iex.exs")

    case File.exists?(file_path) do
      true ->
        iex_code = File.read!(file_path)

        cond do
          String.contains?(iex_code, @new_file_line) ->
            File.rm(file_path)

          String.contains?(iex_code, @exist_file_line) ->
            code = String.replace(iex_code, @exist_file_line, "")
            File.write(file_path, code)
        end

      _ ->
        :ok
    end
  end

  def post_run(_), do: :ok
end
