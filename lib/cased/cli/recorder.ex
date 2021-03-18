defmodule Cased.CLI.Recorder do
  use GenServer

  ## Client API

  def start() do
    case Process.whereis(__MODULE__) do
      nil -> start_link()
      pid -> {:ok, pid}
    end
  end

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  ## Server callback

  @impl true
  def init(_opts) do
    {:ok, %{}}
  end

  def handle_info({:io_request, _from, _reply, request} = msg, output) do
    send(Process.group_leader(), msg)
    {:noreply, output}
  end

  def handle_info(_msg, output) do
    {:noreply, output}
  end
end
