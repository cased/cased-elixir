defmodule CasedTest do
  use ExUnit.Case

  describe "publish/2" do
    test "serializes data and sends to publisher via GenServer.cast/2" do
      publisher = self()

      data = %{action: "test"}

      Cased.publish(self(), data)

      encoded_data = Jason.encode!(data)
      assert_receive({:"$gen_cast", {:publish, ^encoded_data}}, 100)
    end
  end
end
