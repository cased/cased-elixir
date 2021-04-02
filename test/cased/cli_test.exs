defmodule Cased.CLITest do
  use Cased.TestCase
  import ExUnit.CaptureIO

  describe "start/1" do
    test "display error and exit" do
      Cased.CLI.Supervisor.start_link([])

      assert capture_io(:stderr, fn ->
               Cased.CLI.start()
             end) =~ "Application key not found or isn't valid."
    end
  end
end
