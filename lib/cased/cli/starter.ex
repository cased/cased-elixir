defmodule Cased.CLI.Starter do
  use GenServer
  require Logger

  alias Cased.CLI.Utils
  alias Cased.CLI.HiddenNode
  alias Cased.CLI.Config
  alias Cased.CLI.Identity
  alias Cased.CLI.Session

  def run do
    {:ok, starter_port} = start(self())
    Logger.debug("Starter port: #{starter_port}")
    Utils.start_hidden_node(starter_port)

    receive do
      :ready ->
        %{user: %{"id" => user_token}} = Identity.get()
        %{api_record_url: record_url} = Session.get()

        config_msg =
          "command:configure:" <>
            Jason.encode!(%{
              user_token: user_token,
              record_url: record_url,
              app_key: Config.app_key()
            })

        HiddenNode.Client.send_message(config_msg)
        Cased.CLI.Recorder.start_record()
    after
      50_000 ->
        IO.inspect("cased cli (node) is not read")
    end
  end

  def start(console_pid) do
    GenServer.start(__MODULE__, console_pid, name: __MODULE__)
    server_port = get_port()
    accept()
    server_port
  end

  def get(), do: GenServer.call(__MODULE__, :get)
  def get_port(), do: :inet.port(get()[:listen])

  def accept, do: send(Process.whereis(__MODULE__), :accept)

  def init(console_pid) do
    Process.flag(:trap_exit, true)

    {:ok, listen} =
      :gen_tcp.listen(
        0,
        [:binary, packet: :line, active: false, reuseaddr: true]
      )

    {:ok, %{listen: listen, socket: nil, console: console_pid}}
  end

  def handle_call(:get, _from, state) do
    {:reply, state, state}
  end

  def handle_info(:serve, %{socket: nil} = state) do
    send(self(), :serve)
    {:noreply, state}
  end

  def handle_info(:serve, %{socket: socket} = state) do
    socket
    |> :gen_tcp.recv(0)
    |> handle_recived_data(state)

    {:noreply, state}
  end

  def handle_info(:accept, %{listen: listen} = state) do
    {:ok, socket} = :gen_tcp.accept(listen)
    Logger.debug("Client connected")
    send(self(), :serve)
    {:noreply, Map.merge(state, %{socket: socket})}
  end

  def handle_recived_data({:error, :closed}, %{socket: socket}) do
    Logger.debug("socket closed")
    :gen_tcp.close(socket)
    send(self(), :accept)
  end

  def handle_recived_data({:ok, "started:" <> port}, state) do
    Logger.debug("Hidden node server is started: #{port}")
    Cased.CLI.HiddenNode.Client.start(port)
    send(state[:console], :ready)
    send(self(), :serve)
  end

  def handle_recived_data({:ok, data}, _state) do
    Logger.debug("received data: #{data}")
    send(self(), :serve)
  end
end
