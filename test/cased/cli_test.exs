defmodule Cased.CLITest do
  use Cased.TestCase
  import ExUnit.CaptureIO
  import Mock

  setup_with_mocks([{Cased.CLI, [:passthrough], [exit: fn -> :exit end]}]) do
    :ok
  end

  describe "start/1" do
    test "display error and exit" do
      Cased.CLI.Supervisor.start_link([])

      assert capture_io(:stderr, fn ->
               Cased.CLI.start()
             end) =~ "Application key not found or isn't valid."
    end

    test "start record" do
      with_mocks([
        {Cased.CLI.Session, [:passthrough],
         [create: fn io_pid -> send(io_pid, :start_record) end]},
        {Cased.CLI.Recorder, [:passthrough], [start_record: fn -> IO.puts("Start record") end]}
      ]) do
        Cased.CLI.Supervisor.start_link(app_key: "guard_application_xxx")

        assert capture_io(fn ->
                 Cased.CLI.start()
               end) == "\e[33m[cased]\e[0m Running under Cased CLI.\nStart record\n"
      end
    end

    test "ask reason of session" do
      with_mocks([
        {Mojito, [:passthrough],
         [
           post: fn "https://api.cased.com/cli/sessions?user_token=user_token_xxx", _headers ->
             {:ok, %{status_code: 200, body: Jason.encode!(%{"id" => "", "url" => ""})}}
           end
         ]}
      ]) do
        Cased.CLI.Supervisor.start_link(app_key: "guard_application_xxx", token: "user_token_xxx")

        assert capture_io(fn ->
                 Cased.CLI.start()
               end) == "\e[33m[cased]\e[0m Running under Cased CLI.\nStart record\n"
      end
    end
  end
end
