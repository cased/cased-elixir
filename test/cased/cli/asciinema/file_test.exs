defmodule Cased.CLI.Asciinema.FileTest do
  use Cased.TestCase

  alias Cased.CLI.Asciinema.File
  alias Cased.CLI.Recorder.State

  describe "build/1" do
    test "returns asciicast data" do
      started_at = DateTime.now!("Etc/UTC")

      assert File.build(%State{
               meta: %{started_at: started_at}
             }) ==
               ~s<{"command":"","env":{"SHELL":"","TERM":""},"height":24,"timestamp":#{
                 DateTime.to_unix(started_at)
               },"version":2,"width":80}\n>

      assert File.build(%State{
               meta: %{started_at: started_at, shell: "zsh", term: "xterm"},
               events: [
                 {{1618, 211_748, 585_244}, 2.895327, "iex(2)> "},
                 {{1618, 211_748, 585_244}, 2.895213, "\r\n"},
                 {{1618, 211_748, 585_244}, 2.890565, "\r\n"},
                 {{1618, 211_748, 585_244}, 2.570894, "2"},
                 {{1618, 211_748, 585_244}, 2.425942, " "},
                 {{1618, 211_748, 585_244}, 2.152942, "+"},
                 {{1618, 211_748, 585_244}, 1.781925, " "},
                 {{1618, 211_748, 585_244}, 1.493104, "2"},
                 {{1618, 211_748, 585_244}, 3.0e-6, "iex(1)>"},
                 {{1618, 211_748, 585_244}, 0.0, "\e[1D\e[2K"}
               ]
             }) ==
               ~s<{"command":"","env":{"SHELL":"zsh","TERM":"xterm"},"height":24,"timestamp":#{
                 DateTime.to_unix(started_at)
               },"version":2,"width":80}\n[0.0,"o","\\u001B[1D\\u001B[2K"]\n[3.0e-6,"o","iex(1)\>"]\n[1.493104,"o","2"]\n[1.781925,"o"," "]\n[2.152942,"o","+"]\n[2.425942,"o"," "]\n[2.570894,"o","2"]\n[2.890565,"o","\\r\\n"]\n[2.895213,"o","\\r\\n"]\n[2.895327,"o","iex(2)\> "]>
    end
  end
end
