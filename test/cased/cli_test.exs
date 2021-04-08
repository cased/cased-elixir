defmodule Cased.CLITest do
  use Cased.TestCase
  import ExUnit.CaptureIO
  import Mock

  setup_with_mocks([
    {Cased.CLI, [:passthrough], [exit: fn -> :exit end]},
    {Cased.CLI.Session, [:passthrough], [create: fn io_pid -> send(io_pid, :start_record) end]},
    {Cased.CLI.Recorder, [:passthrough], [start_record: fn -> IO.puts("Start record") end]}
  ]) do
    :ok
  end

  describe "start/1" do
    test "display error and exit" do
      Cased.CLI.Supervisor.start_link([])

      assert capture_io(:stderr, fn ->
               Cased.CLI.start()
             end) =~ "Application key not found or isn't valid."
    end

    test "start identify" do
      Cased.CLI.Supervisor.start_link(app_key: "guard_application_xxx")

      assert capture_io(fn ->
               Cased.CLI.start()
             end) == "\e[33m[cased]\e[0m Running under Cased CLI.\nStart record\n"
    end
  end
end
