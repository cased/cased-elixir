defmodule Cased.CLI do
  @moduledoc """
  The Cased.CLI

  The module responsibilities include:

  * checks credentials
  * identify user if need
  * run record
  """
  require Logger

  alias Cased.CLI.Config
  alias Cased.CLI.Identity
  alias Cased.CLI.Session
  alias Cased.CLI.Shell

  @doc """
  Starts session.
  """
  @spec start(pid | nil) :: no_return
  def start(leader \\ nil) do
    Logger.configure(level: :info)
    if leader, do: Process.group_leader(self(), leader)
    Config.configure(%{iex_prompt: IEx.configuration()[:default_prompt]})

    if Config.autorun() do
      IEx.configure(default_prompt: "")
    end

    if Config.clear_screen(), do: IO.write(IO.ANSI.clear() <> IO.ANSI.home())

    case Config.valid_app_key() do
      true ->
        do_start()

      _ ->
        Shell.error("""
        Application key not found or isn't valid.
        """)

        Cased.CLI.exit()
    end
  end

  def exit, do: :init.stop()

  def stop do
    Cased.CLI.Recorder.stop_record()
  end

  defp do_start do
    Shell.info("Running under Cased CLI.")

    Session.create(self())
    loop()
  end

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
        Session.create(self())
        loop()

      {:start_session, attrs} ->
        Session.create(self(), attrs)
        loop()

      :start_record ->
        Cased.CLI.Starter.run()

      :stopped_record ->
        Shell.info("record stoped")

      _msg ->
        loop()
    end
  end
end
