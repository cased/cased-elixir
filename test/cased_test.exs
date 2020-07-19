defmodule CasedTest do
  use ExUnit.Case

  describe "publish/2" do
    test "serializes data and sends to publisher via GenServer.cast/2" do
      publisher = self()

      data = %{action: "test"}

      data |> Cased.publish(publisher: publisher)

      encoded_data = Jason.encode!(data)
      assert_receive({:"$gen_cast", {:publish, ^encoded_data}}, 100)
    end

    test "serializes data and sends to publisher via GenServer.cast/2 with sensitive data" do
      publisher = self()

      data = %{greeting: "Hi @username"}

      data
      |> Cased.publish(
        publisher: publisher,
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

      assert_receive({:"$gen_cast", {:publish, value}}, 100)

      assert encoded_data == Jason.decode!(value)
    end
  end
end
