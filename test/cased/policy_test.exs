defmodule Cased.PolicyTest do
  use Cased.TestCase

  describe "query/2" do
    test "creates a request when given valid options", %{client: client} do
      assert %Cased.Request{
               client: ^client,
               id: :policies,
               method: :get,
               path: "/policies",
               key: @environment_key,
               query: %{
                 page: 1,
                 per_page: 25
               }
             } = Cased.Policy.query(client)
    end

    test "raises an exception when the client is missing an environment key", %{client: client} do
      bad_client = %{client | environment_key: nil}

      assert_raise Cased.RequestError, fn ->
        Cased.Policy.query(bad_client)
      end
    end

    test "raises an exception when given invalid options", %{client: client} do
      assert_raise Cased.RequestError, fn ->
        Cased.Policy.query(client, page: "invalid")
      end
    end
  end
end
