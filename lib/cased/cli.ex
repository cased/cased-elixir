defmodule Cased.CLI do
  @moduledoc false

  def start() do
    Cased.CLI.Shell.info("Running under Cased CLI.")
    Cased.CLI.Session.create()
    loop()
  end

  def loop do
    receive do
      :reauthenticate ->
        Cased.CLI.Identity.reset()
        Cased.CLI.Identity.identify()
      :unauthorized ->
        Cased.CLI.Identity.reset()
        Cased.CLI.Identity.identify()
        loop()
      :authenticate ->
        Cased.CLI.Identity.identify()
        loop()
      :start_session ->
        Cased.CLI.Session.create()
        loop()
      {:start_session, attrs} ->
        Cased.CLI.Session.create(attrs)
        loop()
      :start_record ->
        Cased.CLI.Recorder.start_record()
        loop()
      :stopped_record ->
        Cased.CLI.Shell.info("record stoped")
      _msg ->
        loop()
    end
  end
end
