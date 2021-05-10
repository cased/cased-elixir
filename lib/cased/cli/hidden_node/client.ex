defmodule Cased.CLI.HiddenNode.Client do
  @moduledoc false

  require Logger
  use GenServer

  @ip {127, 0, 0, 1}

  def start(port) when is_integer(port) do
    Logger.debug("connect to Hidden node: #{port}")
    {:ok, pid} = GenServer.start(__MODULE__, [], name: __MODULE__)
    connect(pid, port)
  end

  def start(port) when is_binary(port), do: start(String.to_integer(String.trim(port)))

  def send_message(message), do: send_message(Process.whereis(__MODULE__), message)
  def send_message(pid, message), do: GenServer.cast(pid, {:message, message})

  def connect(port), do: connect(Process.whereis(__MODULE__), port)
  def connect(pid, port), do: send(pid, {:connect, port})

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
    :ok = :gen_tcp.send(socket, message <> "\r\n")
    {:noreply, state}
  end

  def disconnect(state, reason) do
    Logger.debug("disconnected: #{reason}")
    {:stop, :normal, state}
  end
end
