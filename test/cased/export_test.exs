defmodule Cased.ExportTest do
  use Cased.TestCase

  @export_id "export_1dQ9BRmzZAa8ktZIuhV92DPBke4"

  describe "create/2" do
    test "creates a request when given simple options", %{client: client} do
      assert %Cased.Request{
               client: ^client,
               id: :export_create,
               method: :post,
               path: "/exports",
               key: @organizations_key,
               body: %{
                 format: "json",
                 audit_trails: [:organizations],
                 fields: ~w(actions timestamp)
               }
             } =
               Cased.Export.create(client,
                 audit_trails: [:organizations],
                 fields: ~w(actions timestamp)
               )
    end

    test "creates a request, customizing the key", %{client: client} do
      assert %Cased.Request{
               client: ^client,
               id: :export_create,
               method: :post,
               path: "/exports",
               key: @default_key,
               body: %{
                 format: "json",
                 audit_trails: [:organizations, :default],
                 fields: ~w(actions timestamp)
               }
             } =
               Cased.Export.create(client,
                 audit_trails: [:organizations, :default],
                 # for policy with default audit trail
                 key: @default_key,
                 fields: ~w(actions timestamp)
               )
    end

    test "creates a request, passing a single audit trail", %{client: client} do
      assert %Cased.Request{
               client: ^client,
               id: :export_create,
               method: :post,
               path: "/exports",
               key: @organizations_key,
               body: %{
                 format: "json",
                 audit_trails: [:organizations],
                 fields: ~w(actions timestamp)
               }
             } =
               Cased.Export.create(client,
                 audit_trail: :organizations,
                 fields: ~w(actions timestamp)
               )
    end

    test "creates a request, just using the :fields option", %{client: client} do
      assert %Cased.Request{
               client: ^client,
               id: :export_create,
               method: :post,
               path: "/exports",
               key: @default_key,
               body: %{
                 format: "json",
                 audit_trails: [:default],
                 fields: ~w(actions timestamp)
               }
             } = Cased.Export.create(client, fields: ~w(actions timestamp))
    end
  end

  describe "from_json/1" do
    @tag bypass: [fixture: "export"]
    test "create: returns the decoded JSON when selecting the :decoded response processing strategy",
         %{
           client: client
         } do
      export =
        client
        |> Cased.Export.create(fields: ~w(actions timestamp))
        |> Cased.Request.run!()

      assert %Cased.Export{
               format: "json",
               download_url:
                 "https://api.cased.com/exports/export_1dQ9BRmzZAa8ktZIuhV92DPBke4/download"
             } = export
    end

    @tag bypass: [fixture: "export"]
    test "get: returns the decoded JSON when selecting the :decoded response processing strategy",
         %{
           client: client
         } do
      export =
        client
        |> Cased.Export.get(@export_id)
        |> Cased.Request.run!()

      assert %Cased.Export{
               format: "json",
               download_url: "https://api.cased.com/exports/#{@export_id}/download"
             } = export
    end
  end

  describe "get/2" do
    test "creates a request when given an id", %{client: client} do
      assert %Cased.Request{
               id: :export,
               client: client,
               method: :get,
               path: "/exports/#{@export_id}",
               key: @default_key
             } == Cased.Export.get(client, @export_id)
    end
  end

  describe "get_download/2" do
    test "creates a request when given an id", %{client: client} do
      assert %Cased.Request{
               client: client,
               id: :export_download,
               method: :get,
               path: "/exports/#{@export_id}/download",
               key: @default_key
             } == Cased.Export.get_download(client, @export_id)
    end

    @tag bypass: [status: 500]
    test "raises an exception on an HTTP 500",
         %{
           client: client
         } do
      request =
        client
        |> Cased.Export.get_download(@export_id)

      assert_raise Cased.ResponseError, fn ->
        request
        |> Cased.Request.run!()
      end
    end

    @tag bypass: [status: 202, fixture: :empty]
    test "returns :pending on an HTTP 202",
         %{
           client: client
         } do
      assert :pending ==
               client
               |> Cased.Export.get_download(@export_id)
               |> Cased.Request.run!()
    end

    @tag bypass: [
           status: 302,
           redirect_status: 200,
           redirect_path: "/stub",
           fixture: "export_download"
         ]
    test "returns raw JSON after redirect",
         %{
           client: client
         } do
      result =
        client
        |> Cased.Export.get_download(@export_id)
        |> Cased.Request.run!()

      assert %{"example" => "export download"} == Jason.decode!(result)
    end
  end
end
