defmodule Cased.CLI.Runner do
  @moduledoc false

  @new_file_line "\n#cased-new-file\nCased.CLI.start\n"
  @exist_file_line "\n#cased-exists-file\nCased.CLI.start\n"

  def autorun(%{run: true}) do
    file_path = Path.expand(".iex.exs")

    case File.exists?(file_path) do
      true ->
        if not String.contains?(File.read!(file_path), "Cased.CLI.start") do
          File.write(file_path, @exist_file_line, [:append])
        end

      _ ->
        File.write(file_path, @new_file_line)
    end
  end

  def autorun(_), do: :ok

  def post_run() do
    file_path = Path.expand(".iex.exs")

    case File.exists?(file_path) do
      true ->
        iex_code = File.read!(file_path)

        cond do
          String.contains?(iex_code, @new_file_line) ->
            File.rm(file_path)

          String.contains?(iex_code, @exist_file_line) ->
            code = String.replace(iex_code, @exist_file_line, "")
            File.write(file_path, code)
        end

      _ ->
        :ok
    end
  end
end
