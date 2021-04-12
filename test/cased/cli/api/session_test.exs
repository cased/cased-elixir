defmodule Cased.CLI.Api.SessionTest do
  use Cased.TestCase

  alias Cased.CLI.Api.Session

  setup do
    bypass = Bypass.open()
    endpoint = "http://localhost:#{bypass.port}"
    config = %{app_key: "test-key", api_endpoint: endpoint}
    {:ok, bypass: bypass, config: config, url: endpoint}
  end

  describe "create/3" do
    test "returns error when reason is require", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "POST", "/cli/sessions", fn conn ->
        Plug.Conn.resp(conn, 400, ~s<{"error": "reason_required"}>)
      end)

      assert Session.create(config, %{user: %{"id" => "user_1pc"}}) == {
               :invalid,
               %{"error" => "reason_required"}
             }
    end

    test "returns valid session", %{bypass: bypass, config: config, url: url} do
      Bypass.expect_once(bypass, "POST", "/cli/sessions", fn conn ->
        Plug.Conn.resp(
          conn,
          200,
          ~s<{"id": "guard_session_1r1", "url":"#{url}/shell/programs/TestElixirApp/sessions/guard_session_1r1","api_url": "#{
            url
          }/cli/sessions/guard_session_1r1","api_record_url": "#{url}/cli/sessions/guard_session_1r1/record","state": "approved","auto_approval_reason": "peer_approval_disabled","metadata": {},"reason": null,"ip_address": "111.11.11.11","forwarded_ip_address": null,"command": null,"created_at": "2021-04-11T12:54:25.604439Z","updated_at": "2021-04-11T12:54:25.954834Z","requester": {"id": "user_1pcI","email": "test@app.cased.com"},"guard_application": {"id": "guard_application_1pn","name": "TestElixirApp","settings": {"record_output": true,"message_of_the_day": "","reason_required": false}}}>
        )
      end)

      assert Session.create(config, %{user: %{"id" => "user_1pc"}}) == {
               :ok,
               %{
                 "api_record_url" => "#{url}/cli/sessions/guard_session_1r1/record",
                 "api_url" => "#{url}/cli/sessions/guard_session_1r1",
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
                 "url" => "#{url}/shell/programs/TestElixirApp/sessions/guard_session_1r1"
               }
             }
    end
  end
end
