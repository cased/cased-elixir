defmodule Cased.CLI.Asciinema.File do
  @moduledoc false
  @version 2

  def build(%{events: events} = record) do
    json_events =
      events
      |> Enum.reduce(:first, fn
        event, :first -> [build_event(event)]
        event, acc -> [build_event(event) <> "\n" | acc]
      end)

    IO.iodata_to_binary([build_header(record) <> "\n" | json_events])
  end

  def build_event({_event_at, ts, event_data} = _event) do
    Jason.encode!([ts, "o", event_data])
  end

  def build_header(%{meta: meta, started_at: started_at} = record) do
    %{
      version: @version,
      env: %{
        SHELL: Map.get(meta, :shell),
        TERM: Map.get(meta, :term)
      },
      width: Map.get(meta, :columns, 80),
      height: Map.get(meta, :rows, 24),
      command: IO.iodata_to_binary(Map.get(meta, :command)),
      timestamp: DateTime.to_unix(started_at)
    }
    |> maybe_add_duration(record)
    |> Jason.encode!()
  end

  defp maybe_add_duration(headers, %{started: started, finished: finished})
       when not is_nil(finished) do
    duration = DateTime.diff(finished, started, :nanosecond) / 1_000_000_000
    Map.merge(headers, %{duration: duration})
  end

  defp maybe_add_duration(headers, _record), do: headers
end
