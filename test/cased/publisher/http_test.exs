defmodule Cased.Publisher.HTTPTest do
  use ExUnit.Case, async: true

  @key "policy_test_abcd"

  setup do
    bypass = Bypass.open()
    publisher = start_supervised!({Cased.Publisher.HTTP, key: @key, url: "http://localhost:#{bypass.port}"})
    {:ok, publisher: publisher, bypass: bypass}
  end

  test "handles publish", %{publisher: publisher, bypass: bypass} do
    # Get application version for user-agent header check
    {:ok, vsn} = :application.get_key(:cased, :vsn)

    Bypass.expect bypass, fn conn ->
      # Check headers
      assert {"authorization", "Bearer " <> @key} in conn.req_headers
      assert {"content-type", "application/json"} in conn.req_headers
      assert {"user-agent", "cased-elixir/v#{List.to_string(vsn)}"} in conn.req_headers
      # Stub response
      Plug.Conn.resp(conn, 200, ~s({"id":"test-response"}))
    end

    assert :ok == GenServer.cast(publisher, {:publish, ~s({"data":"fake"})})

    # Waits for `Cased.Publisher.HTTP.handle_cast/2` to complete
    assert %{} = :sys.get_state(publisher)
  end
end
