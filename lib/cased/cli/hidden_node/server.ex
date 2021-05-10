defmodule Cased.CLI.HiddenNode.Server do
  @moduledoc false

  use GenServer, shutdown: 30_000
  require Logger

  alias __MODULE__.State

  defmodule State do
    @moduledoc false
    defstruct listen: nil,
              socket: nil,
              header: nil,
              events: [],
              user_token: nil,
              record_url: nil,
              app_key: nil

    @type t :: %__MODULE__{}
  end

  def start() do
    {:ok, _} = Application.ensure_all_started(:cased)
    {:ok, _pid} = GenServer.start(__MODULE__, [], name: __MODULE__)
    server_port = get_port()
    accept()
    server_port
  end

  def get(), do: GenServer.call(__MODULE__, :get)

  def get_port() do
    with %{listen: listen} <- get(), do: :inet.port(listen)
  end

  def accept, do: send(Process.whereis(__MODULE__), :accept)

  def init(_opts) do
    {:ok, listen} =
      :gen_tcp.listen(
        0,
        [:binary, packet: :line, active: false, reuseaddr: true]
      )

    {:ok, %State{listen: listen}}
  end

  def handle_call(:get, _from, state), do: {:reply, state, state}

  def handle_info(:accept, %{listen: listen} = state) do
    {:ok, socket} = :gen_tcp.accept(listen)
    Logger.debug("Client connected")
    send(self(), :serve)
    {:noreply, Map.merge(state, %{socket: socket})}
  end

  def handle_info(:serve, %{socket: nil} = state) do
    send(self(), :serve)
    {:noreply, state}
  end

  def handle_info(:serve, %{socket: socket} = state) do
    new_state =
      socket
      |> :gen_tcp.recv(0)
      |> handle_recived_data(state)
      |> case do
        {:ok, state} -> state
        _ -> state
      end

    {:noreply, new_state}
  end

  def handle_recived_data({:error, :closed}, state) do
    Logger.debug("socket closed")
    handle_exit(state)
  end

  def handle_recived_data({:ok, "event:" <> event}, %{events: events} = state) do
    Logger.debug("received event: #{event}")
    send(self(), :serve)
    {:ok, %{state | events: [String.trim_trailing(event) <> "\n" | events]}}
  end

  def handle_recived_data({:ok, "header:" <> header}, state) do
    Logger.debug("received header: #{header}")
    send(self(), :serve)
    {:ok, %{state | header: String.trim_trailing(header)}}
  end

  def handle_recived_data({:ok, "command:configure:" <> data}, state) do
    Logger.debug("received configure command: #{data}")

    config =
      data
      |> Jason.decode!()
      |> Enum.into(%{}, fn {k, v} -> {String.to_existing_atom(k), String.trim_trailing(v)} end)

    Logger.debug("received config: #{inspect(config)}")

    send(self(), :serve)
    {:ok, Map.merge(state, config)}
  end

  def handle_recived_data({:ok, "command:close"}, state) do
    Logger.debug("received close command")
    handle_exit(state)
  end

  def handle_recived_data({:ok, data}, state) do
    Logger.debug("received data: #{data}")
    send(self(), :serve)
    {:ok, state}
  end

  def handle_exit(state) do
    data = IO.iodata_to_binary([state.header <> "\n" | Enum.reverse(state.events)])

    Cased.CLI.Api.Session.put_record(
      %{app_key: state.app_key},
      state.record_url,
      state.user_token,
      data
    )

    :init.stop()
  end
end
