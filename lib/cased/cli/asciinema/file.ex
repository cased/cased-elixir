defmodule Cased.CLI.Asciinema.File do
  @version 2

  def build(%{events: events, started_at: started_at} = record) do
    json_events =
      events
      |> Enum.reduce(:first, fn
        event, :first -> [build_event(started_at, event)]
        event, acc -> [build_event(started_at, event) <> "\n" | acc]
      end)

    IO.iodata_to_binary([build_header(record) <> "\n" | json_events])
  end

  def build_event(started_at, {event_at, event_data} = _event) do
    time_position = DateTime.diff(event_at, started_at, :nanosecond) / 1_000_000_000
    Jason.encode!([time_position, "o", event_data])
  end

  def build_header(%{meta: meta, started_at: started_at} = record) do
    finished_at = Map.get(record, :finished_at, DateTime.now!("Etc/UTC"))
    duration = DateTime.diff(finished_at, started_at, :nanosecond) / 1_000_000_000

    %{
      version: @version,
      env: %{
        SHELL: Map.get(meta, :shell),
        TERM: Map.get(meta, :term)
      },
      width: Map.get(meta, :columns),
      height: Map.get(meta, :rows),
      command: IO.iodata_to_binary(Map.get(meta, :command)),
      timestamp: DateTime.to_unix(started_at),
      duration: duration,
      title: "Cased Elixir"
    }
    |> Jason.encode!()
  end
end
