defmodule Cased.CLI.Asciinema.Uploader do
  @moduledoc false
  use GenServer

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def add_event do
    GenServer.cast(__MODULE__, :add_event)
  end

  ## Server callback
  @impl true
  def init(_opts) do
    {:ok, %{in_progress: false}}
  end

  @impl true
  def handle_cast(:add_event, %{} = state) do
    GenServer.cast(__MODULE__, :upload)
    {:noreply, state}
  end

  @impl true
  def handle_cast(:upload, state) do
    do_upload()
    {:noreply, %{state | in_progress: true}}
  end

  @impl true
  def handle_cast(:uploaded, state) do
    do_upload()
    {:noreply, %{state | in_progress: false}}
  end

  def do_upload do
    Cased.CLI.Recorder.get()
    |> Cased.CLI.Asciinema.File.build()
    |> Cased.CLI.Session.upload_record()
  end
end
