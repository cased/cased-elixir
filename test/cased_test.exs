defmodule CasedTest do
  use ExUnit.Case

  setup do
    publisher = start_supervised!({Cased.Sink, []})

    {:ok, publisher: publisher}
  end

  describe "publish/2" do
    test "serializes data and sends to publisher via GenServer.call/2", %{publisher: publisher} do
      data = %{action: "test"}

      data |> Cased.publish(publishers: [publisher])

      encoded_data = Jason.encode!(data)
      assert [^encoded_data | _] = Cased.Sink.get_events(publisher)
    end

    test "serializes data, with set context, and sends to publisher via GenServer.call/2", %{
      publisher: publisher
    } do
      context_addition = %{location: "https://example.com"}
      Cased.Context.merge(context_addition)

      data = %{action: "test1"}
      data |> Cased.publish(publishers: [publisher])

      encoded_data = Jason.encode!(data |> Map.merge(context_addition))
      assert [^encoded_data | _] = Cased.Sink.get_events(publisher)

      data = %{action: "test2"}
      data |> Cased.publish(publishers: [publisher])

      encoded_data = Jason.encode!(data |> Map.merge(context_addition))
      assert [^encoded_data | _] = Cased.Sink.get_events(publisher)
    end

    test "serializes data, with scoped context, and sends to publisher via GenServer.call/2", %{
      publisher: publisher
    } do
      data = %{action: "test"}

      context_addition = %{location: "https://example.com"}

      Cased.Context.merge(context_addition, fn ->
        data |> Cased.publish(publishers: [publisher])
      end)

      encoded_data = Jason.encode!(data |> Map.merge(context_addition))
      assert [^encoded_data | _] = Cased.Sink.get_events(publisher)
    end

    test "serializes data and sends to publisher via GenServer.call/2 with sensitive data", %{
      publisher: publisher
    } do
      data = %{greeting: "Hi @username"}

      data
      |> Cased.publish(
        publishers: [publisher],
        handlers: [{Cased.Sensitive.RegexHandler, :username, ~r/@\w+/}]
      )

      pii_data = %{
        ".cased" => %{
          pii: %{
            greeting: [
              %{
                begin: 3,
                end: 12,
                label: :username
              }
            ]
          }
        }
      }

      encoded_data =
        pii_data
        |> Map.merge(data)
        |> Jason.encode!()
        |> Jason.decode!()

      assert [value | _] = Cased.Sink.get_events(publisher)
      assert encoded_data == Jason.decode!(value)
    end
  end
end
