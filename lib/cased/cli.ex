defmodule Cased.CLI do
  @moduledoc false

  def start(api_key) do
    Cased.CLI.Shell.info("Running under Cased CLI.")
    Cased.CLI.Identity.start(api_key)
    {:ok, data} = Cased.CLI.Identity.identify()
    Cased.CLI.Shell.info("To login, please visit:")
    Cased.CLI.Shell.info(data.url)
    wait_identify()
  end

  def create_session do
    Cased.CLI.Session.start()
    Cased.CLI.Session.create(self())
    wait_session()
  end

  def wait_session do
    receive do
      {:session, %{state: "approved"} = _session, _} ->
        IO.write("\n")
        Cased.CLI.Shell.info("CLI session is now recording")
        {:ok, pid} = Cased.CLI.Recorder.start()
        Process.group_leader(self(), pid)

      {:session, %{state: "requested"}, counter} ->
        Cased.CLI.Shell.progress("Approval request sent#{String.duplicate(".", counter)}")
        wait_session()

      {:session, %{state: "denied"}, _} ->
        IO.write("\n")
        Cased.CLI.Shell.info("CLI session has been denied")

      {:session, %{state: "timed_out"}, _} ->
        IO.write("\n")
        Cased.CLI.Shell.info("CLI session has timed out")

      {:session, %{state: "canceled"}, _} ->
        IO.write("\n")
        Cased.CLI.Shell.info("CLI session has been canceled")

      {:error, "reason_required", _session} ->
        reason = Cased.CLI.Shell.prompt("Please enter a reason for access")
        Cased.CLI.Session.create(self(), %{reason: reason})
        wait_session()

      {:error, error, _session} ->
        IO.write("\n")
        Cased.CLI.Shell.info("CLI session has error: #{error}")
    after
      50_000 ->
        IO.write("\n")
        Cased.CLI.Shell.error("Session don't created")
    end
  end

  def wait_identify do
    receive do
      :identify_done ->
        IO.write("\n")
        Cased.CLI.Shell.info("Identify is complete")
        Cased.CLI.Shell.info("Start cli session. ")
        create_session()

      {:identify_retry, count} ->
        Cased.CLI.Shell.progress("#{String.duplicate(".", count)}")
        wait_identify()
    after
      50_000 ->
        IO.write("\n")
        Cased.CLI.Shell.info("Identify is't complete")
    end
  end
end
