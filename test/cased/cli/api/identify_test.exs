defmodule Cased.CLI.Api.IdentityTest do
  use Cased.TestCase

  import Mock

  alias Cased.CLI.Api.Identity

  @config %{app_key: "test-key", api_endpoint: "http://test-app.cased.com"}

  @success_indentify %Mojito.Response{
    body:
      "{\"url\":\"https://test-app.cased.com/gde\",\"api_url\":\"https://test-api.cased.com/cli/applications/users/identify/gde\",\"code\":\"gde\"}",
    status_code: 201
  }

  @not_found_indentify %Mojito.Response{
    body: "{\"error\":\"not_found\",\"message\":\"The requested resource was not found.\"}",
    status_code: 404
  }
  @created_indentify %Mojito.Response{
    body:
      "{\"id\":\"guard_user_identity_request_1r1Upg\",\"ip_address\":\"111.11.11.11\",\"user\":{\"id\":\"user_1pcI\",\"email\":\"user.test@app.cased.com\"},\"updated_at\":\"2021-04-11T12:14:45.458855Z\",\"created_at\":\"2021-04-11T12:14:33.527851Z\"}",
    status_code: 200
  }

  describe "identify/0" do
    test "create identify session" do
      with_mocks([
        {Mojito, [:passthrough],
         [
           post: fn "http://test-app.cased.com/cli/applications/users/identify",
                    _headers,
                    _,
                    _opts ->
             {:ok, @success_indentify}
           end
         ]}
      ]) do
        assert Identity.identify(@config) ==
                 {:ok,
                  %{
                    "api_url" => "https://test-api.cased.com/cli/applications/users/identify/gde",
                    "code" => "gde",
                    "url" => "https://test-app.cased.com/gde"
                  }}
      end
    end
  end

  describe "check/1" do
    test "returns not_found if identify session isn't create" do
      with_mocks([
        {Mojito, [:passthrough],
         [
           get: fn "http://test-app.cased.com/cli/applications/users/identify/gde", _headers ->
             {:error, @not_found_indentify}
           end
         ]}
      ]) do
        assert Identity.check(
                 @config,
                 %{api_url: "http://test-app.cased.com/cli/applications/users/identify/gde"}
               ) ==
                 {:error,
                  %{"error" => "not_found", "message" => "The requested resource was not found."}}
      end
    end

    test "returns user identity" do
      with_mocks([
        {Mojito, [:passthrough],
         [
           get: fn "http://test-app.cased.com/cli/applications/users/identify/gde", _headers ->
             {:ok, @created_indentify}
           end
         ]}
      ]) do
        assert Identity.check(
                 @config,
                 %{api_url: "http://test-app.cased.com/cli/applications/users/identify/gde"}
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
end
