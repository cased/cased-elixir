defmodule Cased.Sensitive.StringTest do
  use Cased.TestCase

  test "sensitive string can find all matches" do
    string = Cased.Sensitive.String.new("Hello @username and @username")

    expected_matches = [
      # first @username
      {6, 15},
      # second @username
      {20, 29}
    ]

    matches =
      string
      |> Cased.Sensitive.String.matches(~r/@\w+/)

    assert length(expected_matches) == length(matches)

    matches
    |> Enum.zip(expected_matches)
    |> Enum.each(fn {match, expected} ->
      assert expected == match
    end)
  end
end
