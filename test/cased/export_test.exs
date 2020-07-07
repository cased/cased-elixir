defmodule Cased.ExportTest do
  use Cased.TestCase

  describe "create/2" do
    test "creates a request when given simple options", %{client: client} do
      assert %Cased.Request{
               client: ^client,
               method: :post,
               path: "/exports",
               key: @example_key2,
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
               method: :post,
               path: "/exports",
               key: @example_key,
               body: %{
                 format: "json",
                 audit_trails: [:organizations, :default],
                 fields: ~w(actions timestamp)
               }
             } =
               Cased.Export.create(client,
                 audit_trails: [:organizations, :default],
                 # for policy with default audit trail
                 key: @example_key,
                 fields: ~w(actions timestamp)
               )
    end

    test "creates a request, passing a single audit trail", %{client: client} do
      assert %Cased.Request{
               client: ^client,
               method: :post,
               path: "/exports",
               key: @example_key2,
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
               method: :post,
               path: "/exports",
               key: @example_key,
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
    test "returns the decoded JSON when selecting the :decoded response processing strategy", %{
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
  end
end
