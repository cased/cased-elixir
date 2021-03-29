defmodule Cased.CLI do
  @moduledoc """
  The Cased.CLI

  The module responsibilities include:

  * checks credentials
  * identify user if need
  * run record
  """

  @doc """
  Starts session.
  """
  def start() do
    Cased.CLI.Runner.post_run()
    IO.write(IO.ANSI.clear() <> IO.ANSI.home())
    Cased.CLI.Shell.info("Running under Cased CLI.")
    Cased.CLI.Session.create()
    loop()
  end

  defp loop do
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
