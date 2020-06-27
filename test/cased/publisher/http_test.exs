defmodule Cased.Publisher.HTTPTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureLog

  @key "publish_test_abcd"

  setup context do
    bypass = Bypass.open()

    publisher =
      start_supervised!(
        {Cased.Publisher.HTTP,
         key: @key, url: "http://localhost:#{bypass.port}", silence: context[:silence] || false}
      )

    {:ok, publisher: publisher, bypass: bypass}
  end

  test "handles publish", %{publisher: publisher, bypass: bypass} do
    # Get application version for user-agent header check
    {:ok, vsn} = :application.get_key(:cased, :vsn)

    Bypass.expect_once(bypass, fn conn ->
      # Check headers
      assert {"authorization", "Bearer " <> @key} in conn.req_headers
      assert {"content-type", "application/json"} in conn.req_headers
      assert {"user-agent", "cased-elixir/v#{List.to_string(vsn)}"} in conn.req_headers
      # Stub response
      Plug.Conn.resp(conn, 200, ~s({"id":"test-response"}))
    end)

    publish(publisher)
  end

  @tag silence: true
  test "handles publish with silence", %{publisher: publisher} do
    assert capture_log(fn ->
             publish(publisher)
           end) =~ "Silenced Cased publish"
  end

  describe "start_link/1" do
    test "returns an error when misconfigured" do
      assert {:error, %Cased.ConfigurationError{message: "invalid publisher configuration"}} =
               Cased.Publisher.HTTP.start_link([])
    end
  end

  defp publish(publisher) do
    assert :ok == GenServer.cast(publisher, {:publish, ~s({"data":"fake"})})

    # Waits for `Cased.Publisher.HTTP.handle_cast/2` to complete
    assert %{} = :sys.get_state(publisher)
  end
end
