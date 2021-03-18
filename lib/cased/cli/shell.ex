defmodule Cased.CLI.Shell do
  @moduledoc false

  @prefix "#{IO.ANSI.yellow()} [cased]#{IO.ANSI.reset()} "

  def mix_shell?, do: :erlang.function_exported(Mix, :shell, 0)

  def prompt(prompt_prefix, defval \\ nil, defname \\ nil) do
    prompt_message = @prefix <> "#{prompt_prefix} [#{defname || defval}] "

    if mix_shell?() do
      Mix.shell().prompt(prompt_message)
    else
      :io.get_line(prompt_message)
    end
    |> case do
      "\n" ->
        case defval do
          nil ->
            prompt(prompt_prefix, defval, defname)

          defval ->
            defval
        end

      input ->
        String.trim(input)
    end
  end

  def info(message) do
    if mix_shell?() do
      Mix.shell().info(@prefix <> message)
    else
      IO.puts(@prefix <> message)
    end
  end

  def error(message) do
    if mix_shell?() do
      Mix.shell().error(@prefix <> message)
    else
      IO.puts(:stderr, @prefix <> message)
    end
  end

  def progress(message) do
    IO.write("\r" <> @prefix <> message)
  end
end
