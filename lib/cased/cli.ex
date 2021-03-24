defmodule Cased.CLI do
  @moduledoc false

  def start() do
    Cased.CLI.Shell.info("Running under Cased CLI.")
    Cased.CLI.Config.start()
    identify()
  end

  def identify() do
    Cased.CLI.Identity.start()
    Cased.CLI.Identity.identify(self())
    wait_identify()
  end

  def start_session do
    Cased.CLI.Session.start()
    Cased.CLI.Session.create(self())
    wait_session()
  end

  def shell_opts do
    [
      [
        prefix: " " <> IO.ANSI.green() <> "[cased] " <> IO.ANSI.reset(),
        dot_iex_path:
          [".iex.exs", "~/.iex.exs", "/etc/iex.exs"]
          |> Enum.map(&Path.expand/1)
          |> Enum.find("", &File.regular?/1)
      ]
    ]
  end

  def stop_record(iex_pid) do
    Cased.CLI.Recorder.stop_record()

    Cased.CLI.Recorder.get()
    |> Cased.CLI.Asciinema.File.build()
    |> Cased.CLI.Session.upload_record()

    _ = Process.unlink(iex_pid)
    :ok = GenServer.stop(iex_pid, :normal, 10_000)
    Cased.CLI.Shell.info("record stoped")
  end

  def start_record do
    {:ok, pid} = Cased.CLI.Recorder.start()
    Cased.CLI.Recorder.start_record()

    opts = [
      type: :elixir,
      shell_opts: shell_opts(),
      handler: pid,
      name: :ex_tty_handler_cased
    ]

    {:ok, iex_pid} = GenServer.start_link(ExTTY, opts)
    loop_io(iex_pid)
  end

  def loop_io(iex_pid) do
    send(self(), {:input, self(), IO.gets(:stdio, "")})
    wait_input(iex_pid)
  end

  def wait_input(iex_pid) do
    receive do
      {:input, _, "/stop" <> _} ->
        stop_record(iex_pid)

      {:input, _, data} ->
        ExTTY.send_text(iex_pid, data)
        loop_io(iex_pid)

      _msg ->
        loop_io(iex_pid)
    end
  end

  def wait_session do
    receive do
      {:session, %{state: "approved"} = _session, _} ->
        IO.write("\n")
        start_record()

      {:session, %{state: "requested"}, counter} ->
        Cased.CLI.Shell.progress("Approval request sent#{String.duplicate(".", counter)}")
        wait_session()

      {:error, %{state: "denied"}, _} ->
        IO.write("\n")
        Cased.CLI.Shell.info("CLI session has been denied")

      {:error, %{state: "timed_out"}, _} ->
        IO.write("\n")
        Cased.CLI.Shell.info("CLI session has timed out")

      {:error, %{state: "canceled"}, _} ->
        IO.write("\n")
        Cased.CLI.Shell.info("CLI session has been canceled")

      {:error, "reason_required", _session} ->
        reason = Cased.CLI.Shell.prompt("Please enter a reason for access")
        Cased.CLI.Session.create(self(), %{reason: reason})
        wait_session()

      {:error, "reauthenticate", _session} ->
        Cased.CLI.Shell.info(
          "You must re-authenticate with Cased due to recent changes to this application's settings."
        )

        Cased.CLI.Identity.reset()
        identify()

      {:error, error, _session} ->
        IO.write("\n")
        Cased.CLI.Shell.info("CLI session has error: #{inspect(error)}")
    after
      50_000 ->
        IO.write("\n")
        Cased.CLI.Shell.error("Session don't created")
    end
  end

  def wait_identify do
    receive do
      {:identify_init, url} ->
        Cased.CLI.Shell.info("To login, please visit:")
        Cased.CLI.Shell.info(url)
        wait_identify()

      :identify_done ->
        IO.write("\n")
        Cased.CLI.Shell.info("Identify is complete")
        Cased.CLI.Shell.info("Start cli session. ")
        start_session()

      {:identify_retry, count} ->
        Cased.CLI.Shell.progress("#{String.duplicate(".", count)}")
        wait_identify()

      {:error, error} ->
        Cased.CLI.Shell.info("Identify is fail. (#{inspect(error)}) ")
    after
      50_000 ->
        IO.write("\n")
        Cased.CLI.Shell.info("Identify is't complete")
    end
  end
end
