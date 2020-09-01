defmodule Cased.Sink do
  @moduledoc """
  A publisher that doesn't do much.
  """
  use GenServer

  @type init_opts :: any()

  @spec start_link(opts :: init_opts()) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  ##
  # Callbacks

  @doc """
  Build publisher configuration.
  """
  @spec init(opts :: init_opts()) :: {:ok, list()}
  @impl true
  def init(_opts) do
    {:ok, []}
  end

  @impl true
  def handle_call({:publish, event}, _from, events) do
    events = [event | events]
    {:reply, events, events}
  end

  ##
  # Test support

  @impl true
  def handle_call(:events, _from, events) do
    {:reply, events, events}
  end

  def get_events(sink) do
    GenServer.call(sink, :events)
  end
end
