defmodule Cased.PolicyTest do
  use Cased.TestCase

  describe "get/3" do
    test "creates a request when given valid options", %{client: client} do
      assert %Cased.Request{
               client: ^client,
               id: :policy,
               method: :get,
               path: "/policies/policy_...",
               key: @environment_key
             } = Cased.Policy.get(client, "policy_...")
    end

    test "creates a request when given valid options with a custom environment key", %{
      client: client
    } do
      assert %Cased.Request{
               client: ^client,
               id: :policy,
               method: :get,
               path: "/policies/policy_...",
               key: @environment_key2
             } = Cased.Policy.get(client, "policy_...", key: @environment_key2)
    end

    test "raises an exception when given invalid options", %{client: client} do
      assert_raise Cased.RequestError, fn ->
        Cased.Policy.get(client, "policy_...", key: @bad_environment_key)
      end
    end
  end

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
