defmodule CasedTest do
  use ExUnit.Case
  doctest Cased

  test "greets the world" do
    assert Cased.hello() == :world
  end
end
