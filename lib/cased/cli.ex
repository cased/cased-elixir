defmodule Cased.CLI do
  @moduledoc """
  The Cased.CLI

  The module responsibilities include:

  * checks credentials
  * identify user if need
  * run record
  """

  alias Cased.CLI.Runner
  alias Cased.CLI.Shell
  alias Cased.CLI.Session
  alias Cased.CLI.Config
  alias Cased.CLI.Identity
  alias Cased.CLI.Recorder

  @doc """
  Starts session.
  """
  def start(leader \\ nil) do
    if leader, do: Process.group_leader(self(), leader)
    IO.write(IO.ANSI.clear() <> IO.ANSI.home())

    case Config.valid_app_key() do
      true ->
        do_start()

      _ ->
        Shell.error("""
        Application key not found or isn't valid.
        """)
    end

    close_shell(Config.get(:close_shell, false))
  end

  defp do_start() do
    Runner.post_run(Config.get(:run_via_iex, false))
    Shell.info("Running under Cased CLI.")
    Session.create()
    loop()
  end

  defp close_shell(true), do: :init.stop()
  defp close_shell(_), do: :ok

  defp loop do
    receive do
      :reauthenticate ->
        Identity.reset()
        Identity.identify()

      :unauthorized ->
        Identity.reset()
        Identity.identify()
        loop()

      :authenticate ->
        Identity.identify()
        loop()

      :start_session ->
        Session.create()
        loop()

      {:start_session, attrs} ->
        Session.create(attrs)
        loop()

      :start_record ->
        Recorder.start_record()
        loop()

      :stopped_record ->
        Shell.info("record stoped")

      _msg ->
        loop()
    end
  end
end
