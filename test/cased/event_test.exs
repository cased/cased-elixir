defmodule Cased.EventTest do
  use Cased.TestCase

  describe "get/3" do
    test "creates a request when given valid options", %{client: client} do
      assert %Cased.Request{
               client: ^client,
               id: :audit_trail_event,
               method: :get,
               path: "/audit-trails/default/events/event_...",
               key: @default_key
             } = Cased.Event.get(client, "event_...")
    end

    test "creates a request when given valid options for a specific audit trail", %{
      client: client
    } do
      assert %Cased.Request{
               client: ^client,
               id: :audit_trail_event,
               method: :get,
               path: "/audit-trails/organizations/events/event_...",
               key: @organizations_key
             } = Cased.Event.get(client, "event_...", audit_trail: :organizations)
    end

    test "raises an exception when given invalid options", %{client: client} do
      assert_raise Cased.RequestError, fn ->
        Cased.Event.get(client, "event_...", audit_trail: "bad-audit-trail")
      end
    end
  end

  describe "query/2" do
    test "creates a request when given valid options", %{client: client} do
      assert %Cased.Request{
               client: ^client,
               id: :events,
               method: :get,
               path: "/events",
               key: @default_key,
               query: %{
                 page: 1,
                 per_page: 25
               }
             } = Cased.Event.query(client)
    end

    test "creates a request for an audit trail, using its key", %{client: client} do
      assert %Cased.Request{
               client: ^client,
               id: :audit_trail_events,
               method: :get,
               path: "/audit-trails/organizations/events",
               key: @organizations_key,
               query: %{
                 page: 1,
                 per_page: 25
               }
             } = Cased.Event.query(client, audit_trail: :organizations)
    end

    test "raises an exception when given invalid options", %{client: client} do
      assert_raise Cased.RequestError, fn ->
        Cased.Event.query(client, page: "invalid")
      end
    end
  end
end
