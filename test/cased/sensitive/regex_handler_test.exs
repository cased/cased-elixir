defmodule Cased.Sensitive.RegexHandlerTest do
  use Cased.TestCase

  describe "ranges/3" do
    test "handles regexp" do
      regex = ~r/@\w+/

      ranges =
        Cased.Sensitive.RegexHandler.new(:username, regex)
        |> Cased.Sensitive.RegexHandler.ranges(
          %{},
          {:action, "Hello @username and @username"}
        )

      expected_ranges = [
        %Cased.Sensitive.Range{label: :username, key: :action, begin_offset: 6, end_offset: 15},
        %Cased.Sensitive.Range{label: :username, key: :action, begin_offset: 20, end_offset: 29}
      ]

      assert expected_ranges == ranges
    end
  end
end
