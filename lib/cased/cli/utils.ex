defmodule Cased.CLI.Utils do
  @base_args "-detached -noinput -hidden -noshell"

  def start_hidden_node(port) do
    command_args = "-s Elixir.Cased.CLI.HiddenNode.Starter start #{port}"
    command = node_command() <> " " <> command_args
    Port.open({:spawn, command}, [:stream])
  end

  def node_command() do
    {:ok, command} = :init.get_argument(:progname)
    paths = Enum.join(:code.get_path(), " , ")
    "#{command} #{@base_args} -pa #{paths}"
  end
end
