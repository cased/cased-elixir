defmodule Cased.CLI.HiddenNode.Starter do
  @moduledoc false

  require Logger
  use GenServer

  @ip {127, 0, 0, 1}

  def send_message(message), do: send_message(Process.whereis(__MODULE__), message)
  def send_message(pid, message), do: GenServer.cast(pid, {:message, message})

  def connect(port), do: connect(Process.whereis(__MODULE__), port)
  def connect(pid, port), do: send(pid, {:connect, port})

  def start(port) when is_integer(port) do
    Logger.debug("Hidden node connect to port: #{port}")

    with {:ok, pid} <- GenServer.start(__MODULE__, [], name: __MODULE__),
         _ <- connect(pid, port) do
      {:ok, server_port} = Cased.CLI.HiddenNode.Server.start()
      send_message(pid, "started:#{server_port}")
    end
  end

  def start(port) when is_binary(port), do: start(String.to_integer(port))

  def start([port]) do
    start(:erlang.list_to_integer(:erlang.atom_to_list(port)))
  end

  def init(_opts) do
    {:ok, %{socket: nil}}
  end

  def handle_info({:connect, port}, state) do
    Logger.debug("Connecting to #{:inet.ntoa(@ip)}:#{port}")
    opts = [:binary, packet: :line, active: false, reuseaddr: true, keepalive: true]

    case :gen_tcp.connect(@ip, port, opts) do
      {:ok, socket} ->
        {:noreply, %{state | socket: socket}}

      {:error, reason} ->
        disconnect(state, reason)
    end
  end

  def handle_cast({:message, message}, %{socket: socket} = state) do
    Logger.debug("send message: #{message}")
    :ok = :gen_tcp.send(socket, message <> "\r\n")
    {:noreply, state}
  end

  def disconnect(state, reason) do
    Logger.debug("disconnected: #{reason}")
    {:stop, :normal, state}
  end
end
