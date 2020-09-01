defmodule Cased.TestHelperTest do
  use Cased.TestCase, async: true

  defmodule Publisher do
    use GenServer

    def init(state) do
      {:ok, state}
    end

    def handle_call(_, _from, state) do
      {:reply, nil, state}
    end
  end

  @events [
    %{"id" => 1},
    %{"id" => 2},
    %{"id" => 3}
  ]

  setup do
    {:ok, publisher} = GenServer.start_link(Publisher, %{})
    {:ok, publisher: publisher}
  end

  describe "capture_cased_events/2" do
    test "captures events sent via GenServer.call/2", %{publisher: publisher} do
      sent_events =
        Cased.TestHelper.capture_cased_events(publisher, fn -> publish_events(publisher) end)

      assert sent_events == @events
    end
  end

  describe "assert_publishes_cased_events/3" do
    test "counts events sent via GenServer.call/2", %{publisher: publisher} do
      Cased.TestHelper.assert_publishes_cased_events(publisher, length(@events), fn ->
        publish_events(publisher)
      end)
    end
  end

  describe "assert_publishes_cased_events/2" do
    test "checks for any events sent via GenServer.call/2", %{publisher: publisher} do
      Cased.TestHelper.assert_publishes_cased_events(publisher, fn ->
        publish_events(publisher)
      end)
    end
  end

  describe "assert_publishes_no_cased_events/2" do
    test "checks for any events sent via GenServer.call/2", %{publisher: publisher} do
      Cased.TestHelper.assert_publishes_no_cased_events(publisher, fn -> :noop end)
    end
  end

  defp publish_events(publisher) do
    for event <- @events do
      GenServer.call(publisher, {:publish, Jason.encode!(event)})
    end
  end
end
