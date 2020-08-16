defmodule Cased.TestHelper do
  @moduledoc """
  Provides helper functions for testing Cased features.
  """

  import ExUnit.Assertions

  @doc """
  Asserts that a specific `count` of Cased events were published to `publisher` when evaluating `fun`.
  """
  @spec assert_publishes_cased_events(
          publisher :: atom() | pid(),
          count :: non_neg_integer(),
          fun :: function()
        ) :: any()
  def assert_publishes_cased_events(publisher, count, fun) do
    assert count == capture_cased_events(publisher, fun) |> length()
  end

  @doc """
  Asserts that one or more Cased events were published to `publisher` when evaluating `fun`.
  """
  @spec assert_publishes_cased_events(
          publisher :: atom() | pid(),
          fun :: function()
        ) :: any()
  def assert_publishes_cased_events(publisher, fun) do
    assert capture_cased_events(publisher, fun) |> length() > 0
  end

  @doc """
  Asserts that no Cased events were published to `publisher` when evaluating `fun`.
  """
  @spec assert_publishes_no_cased_events(
          publisher :: atom() | pid(),
          fun :: function()
        ) :: any()
  def assert_publishes_no_cased_events(publisher, fun) do
    assert_publishes_cased_events(publisher, 0, fun)
  end

  @doc """
  Captures Cased events published to `publisher` when evaluating `fun`.
  """
  @spec capture_cased_events(
          publisher :: atom() | pid(),
          fun :: function()
        ) :: [map()]
  def capture_cased_events(publisher, fun) do
    :erlang.trace(publisher, true, [:receive])
    fun.()

    collect_events(publisher)
    |> Enum.reverse()
  end

  @spec collect_events(
          publisher :: atom() | pid(),
          collected :: [map()]
        ) :: [map()]
  defp collect_events(publisher, collected \\ []) do
    receive do
      {:trace, ^publisher, :receive, {:"$gen_cast", {:publish, json}}} ->
        event = Jason.decode!(json)
        collect_events(publisher, [event | collected])

      _other ->
        collect_events(publisher, collected)
    after
      100 ->
        collected
    end
  end
end
