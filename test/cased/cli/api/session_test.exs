defmodule Cased.CLI.Api.SessionTest do
  use Cased.TestCase

  import Mock

  alias Cased.CLI.Api.Session

  @config %{app_key: "test-key", api_endpoint: "http://test-app.cased.com"}

  @reason_required %Mojito.Response{
    body: "{\"error\":\"reason_required\"}",
    status_code: 400
  }

  @valid_session %Mojito.Response{
    body:
      "{\"id\":\"guard_session_1r1\",\"url\":\"http://test-app.cased.com/shell/programs/TestElixirApp/sessions/guard_session_1r1\",\"api_url\":\"http://test-api.cased.com/cli/sessions/guard_session_1r1\",\"api_record_url\":\"http://test-api.cased.com/cli/sessions/guard_session_1r1/record\",\"state\":\"approved\",\"auto_approval_reason\":\"peer_approval_disabled\",\"metadata\":{},\"reason\":null,\"ip_address\":\"111.11.11.11\",\"forwarded_ip_address\":null,\"command\":null,\"created_at\":\"2021-04-11T12:54:25.604439Z\",\"updated_at\":\"2021-04-11T12:54:25.954834Z\",\"requester\":{\"id\":\"user_1pcI\",\"email\":\"test@app.cased.com\"},\"guard_application\":{\"id\":\"guard_application_1pn\",\"name\":\"TestElixirApp\",\"settings\":{\"record_output\":true,\"message_of_the_day\":\"\",\"reason_required\":false}}}",
    status_code: 200
  }

  describe "create/3" do
    test "returns valid session when reason and approve isn't require" do
      with_mocks([
        {Mojito, [:passthrough],
         [
           post: fn
             "http://test-app.cased.com/cli/sessions?user_token=user_1pc", _headers, _, _opts ->
               {:ok, @reason_required}
           end
         ]}
      ]) do
        assert Session.create(@config, %{user: %{"id" => "user_1pc"}}) == {
                 :invalid,
                 %{"error" => "reason_required"}
               }
      end
    end

    test "returns invalid session with `reason_required`" do
      with_mocks([
        {Mojito, [:passthrough],
         [
           post: fn
             "http://test-app.cased.com/cli/sessions?user_token=user_1pc", _headers, _, _opts ->
               {:ok, @valid_session}
           end
         ]}
      ]) do
        assert Session.create(@config, %{user: %{"id" => "user_1pc"}}) == {
                 :ok,
                 %{
                   "api_record_url" =>
                     "http://test-api.cased.com/cli/sessions/guard_session_1r1/record",
                   "api_url" => "http://test-api.cased.com/cli/sessions/guard_session_1r1",
                   "auto_approval_reason" => "peer_approval_disabled",
                   "command" => nil,
                   "created_at" => "2021-04-11T12:54:25.604439Z",
                   "forwarded_ip_address" => nil,
                   "guard_application" => %{
                     "id" => "guard_application_1pn",
                     "name" => "TestElixirApp",
                     "settings" => %{
                       "message_of_the_day" => "",
                       "reason_required" => false,
                       "record_output" => true
                     }
                   },
                   "id" => "guard_session_1r1",
                   "ip_address" => "111.11.11.11",
                   "metadata" => %{},
                   "reason" => nil,
                   "requester" => %{"email" => "test@app.cased.com", "id" => "user_1pcI"},
                   "state" => "approved",
                   "updated_at" => "2021-04-11T12:54:25.954834Z",
                   "url" =>
                     "http://test-app.cased.com/shell/programs/TestElixirApp/sessions/guard_session_1r1"
                 }
               }
      end
    end
  end
end
