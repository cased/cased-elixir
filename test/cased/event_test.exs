defmodule Cased.EventTest do
  use Cased.TestCase

  describe "query/2" do
    test "creates a request when given valid options", %{client: client} do
      assert %Cased.Request{
               client: ^client,
               method: :get,
               path: "/events",
               key: @example_key,
               query: %{
                 page: 1,
                 per_page: 25
               }
             } = Cased.Event.query(client)
    end

    test "raises an exception when given invalid options", %{client: client} do
      assert_raise Cased.RequestError, fn ->
        Cased.Event.query(client, page: "invalid")
      end
    end
  end
end
