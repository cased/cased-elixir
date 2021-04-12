defmodule Cased.CLI.Api.IdentityTest do
  use Cased.TestCase

  alias Cased.CLI.Api.Identity

  setup do
    bypass = Bypass.open()
    endpoint = "http://localhost:#{bypass.port}"
    config = %{app_key: "test-key", api_endpoint: endpoint}
    {:ok, bypass: bypass, config: config, url: endpoint}
  end

  describe "identify/0" do
    test "create identify session", %{bypass: bypass, config: config, url: url} do
      Bypass.expect_once(bypass, "POST", "/cli/applications/users/identify", fn conn ->
        Plug.Conn.resp(
          conn,
          201,
          ~s<{"url": "#{url}/gde","api_url": "#{url}/cli/applications/users/identify/gde", "code":"gde"}>
        )
      end)

      assert Identity.identify(config) ==
               {:ok,
                %{
                  "api_url" => "#{url}/cli/applications/users/identify/gde",
                  "code" => "gde",
                  "url" => "#{url}/gde"
                }}
    end
  end

  describe "check/1" do
    test "returns not_found if identify session isn't create", %{
      bypass: bypass,
      config: config,
      url: url
    } do
      Bypass.expect_once(bypass, "GET", "/cli/applications/users/identify/gde", fn conn ->
        Plug.Conn.resp(
          conn,
          404,
          ~s<{"error": "not_found", "message": "The requested resource was not found."}>
        )
      end)

      assert Identity.check(
               config,
               %{api_url: "#{url}/cli/applications/users/identify/gde"}
             ) ==
               {:error,
                %{"error" => "not_found", "message" => "The requested resource was not found."}}
    end

    test "returns user identity", %{bypass: bypass, config: config, url: url} do
      Bypass.expect_once(bypass, "GET", "/cli/applications/users/identify/gde", fn conn ->
        Plug.Conn.resp(
          conn,
          200,
          ~s<{"id": "guard_user_identity_request_1r1Upg", "ip_address": "111.11.11.11", "user": {"id": "user_1pcI", "email": "user.test@app.cased.com"}, "updated_at":"2021-04-11T12:14:45.458855Z", "created_at": "2021-04-11T12:14:33.527851Z"}>
        )
      end)

      assert Identity.check(
               config,
               %{api_url: "#{url}/cli/applications/users/identify/gde"}
             ) ==
               {:ok,
                %{
                  "created_at" => "2021-04-11T12:14:33.527851Z",
                  "id" => "guard_user_identity_request_1r1Upg",
                  "ip_address" => "111.11.11.11",
                  "updated_at" => "2021-04-11T12:14:45.458855Z",
                  "user" => %{"email" => "user.test@app.cased.com", "id" => "user_1pcI"}
                }}
    end
  end
end
