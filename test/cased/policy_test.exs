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

  describe "create/2" do
    @base_create_opts [
      name: "casedtest",
      description: "A test policy"
    ]

    test "creates a request with an :audit_trails option", %{client: client} do
      audit_trails = [:one, :two, :three]

      assert %Cased.Request{
               client: ^client,
               id: :policy_create,
               method: :post,
               path: "/policies",
               key: @environment_key,
               body: %{
                 name: "casedtest",
                 description: "A test policy",
                 audit_trails: ^audit_trails
               }
             } =
               Cased.Policy.create(
                 client,
                 [{:audit_trails, audit_trails} | @base_create_opts]
               )
    end

    test "creates a request with a :fields option", %{client: client} do
      fields = ~w(one two three)

      assert %Cased.Request{
               client: ^client,
               id: :policy_create,
               method: :post,
               path: "/policies",
               key: @environment_key,
               body: %{
                 name: "casedtest",
                 description: "A test policy",
                 fields: ^fields
               }
             } =
               Cased.Policy.create(
                 client,
                 [{:fields, fields} | @base_create_opts]
               )
    end

    test "creates a request with a valid :window option", %{client: client} do
      date1 = make_datetime("2021-01-23T23:50:07Z")
      date2 = make_datetime("2021-02-23T23:50:07Z")

      assert %Cased.Request{
               client: ^client,
               id: :policy_create,
               method: :post,
               path: "/policies",
               key: @environment_key,
               body: %{
                 name: "casedtest",
                 description: "A test policy",
                 window: %{
                   gte: ^date1,
                   lte: ^date2
                 }
               }
             } =
               Cased.Policy.create(
                 client,
                 [{:window, gte: date1, lte: date2} | @base_create_opts]
               )
    end

    test "creates a request with a :pii option", %{client: client} do
      assert %Cased.Request{
               client: ^client,
               id: :policy_create,
               method: :post,
               path: "/policies",
               key: @environment_key,
               body: %{
                 name: "casedtest",
                 description: "A test policy",
                 pii: false
               }
             } =
               Cased.Policy.create(
                 client,
                 [{:pii, false} | @base_create_opts]
               )
    end

    test "creates a request with an :export option", %{client: client} do
      assert %Cased.Request{
               client: ^client,
               id: :policy_create,
               method: :post,
               path: "/policies",
               key: @environment_key,
               body: %{
                 name: "casedtest",
                 description: "A test policy",
                 export: false
               }
             } =
               Cased.Policy.create(
                 client,
                 [{:export, false} | @base_create_opts]
               )
    end

    test "creates a request with an :expires option", %{client: client} do
      datetime = make_datetime("2021-01-23T23:50:07Z")

      assert %Cased.Request{
               client: ^client,
               id: :policy_create,
               method: :post,
               path: "/policies",
               key: @environment_key,
               body: %{
                 name: "casedtest",
                 description: "A test policy",
                 expires: ^datetime
               }
             } =
               Cased.Policy.create(
                 client,
                 [{:expires, datetime} | @base_create_opts]
               )
    end

    test "raises an exception when enough options aren't given", %{client: client} do
      assert_raise Cased.RequestError, fn ->
        Cased.Policy.create(client, name: "casedtest", description: "description")
      end
    end

    test "raises an exception when given no options", %{client: client} do
      assert_raise Cased.RequestError, fn ->
        Cased.Policy.create(client, [])
      end
    end

    test "raises an exception when given a bad :expires option", %{client: client} do
      assert_raise Cased.RequestError, fn ->
        Cased.Policy.create(client, [{:expires, :bad_expires} | @base_create_opts])
      end
    end

    test "raises an exception when :window is given bad values", %{client: client} do
      date1 = make_datetime("2021-01-23T23:50:07Z")
      date2 = make_datetime("2021-02-23T23:50:07Z")

      bad_windows = [
        # Unidirectional; into the future
        # |---|===>
        [gt: date1, gte: date2],
        [gt: date1, gt: date2],
        [gte: date1, gte: date2],
        # Unidirectional; into the past
        # <===|----|
        [lt: date1, lte: date2],
        [lt: date1, lt: date2],
        [lte: date1, lte: date2],
        # Diverging; negative window; any time besides a datetime range
        # <---|...|--->
        [lt: date1, gt: date2],
        # Diverging; negative window; any time besides a specific datetime
        # <---|.|--->
        [lt: date1, gt: date1],
        # Diverging; any time
        # <---|--->
        [lte: date1, gte: date1]
      ]

      for bad_window <- bad_windows do
        assert_raise Cased.RequestError, fn ->
          Cased.Policy.create(client, [{:window, bad_window} | @base_create_opts])
        end
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

  defp make_datetime(input) do
    {:ok, datetime, 0} = DateTime.from_iso8601(input)
    datetime
  end
end
