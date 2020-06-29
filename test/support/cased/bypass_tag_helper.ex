defmodule Cased.BypassTagHelper do
  @moduledoc """
  Provides helpers to support configuring Bypass in test `setup`.
  """

  @doc """
  Configure Bypass with options:

  ## Examples

  Don't do any configuration (no-op):

  ```
  @tag :bypass
  ```

  Configure Bypass to return the contents of `test/fixtures/foo.json`:

  ```
  @tag bypass: [fixture: "foo"]
  ```

  Configure Bypass to return a status of `502`:

  ```
  @tag bypass: [status: 502]
  ```

  Configure Bypass to parse page numbers and return the contents of `test/fixtures/foo.PAGE.json`:

  ```
  @tag bypass: [fixture: "foo", paginated: true]
  ```
  """

  # Support `@tag :bypass` — do nothing!
  def configure_bypass(_bypass, true), do: :noop

  # Support `@tag bypass: a_keyword_list`
  def configure_bypass(bypass, settings) when is_list(settings) do
    do_configure_bypass(bypass, Map.new(settings))
  end

  defp do_configure_bypass(bypass, %{paginated: true} = settings) do
    status = Map.get(settings, :status, 200)

    if status in 200..299 do
      Bypass.expect(bypass, fn conn ->
        %{"page" => page} = Plug.Conn.Query.decode(conn.query_string)
        fixture = File.read!("test/fixtures/#{settings.fixture}.#{page}.json")
        Plug.Conn.resp(conn, status, fixture)
      end)
    else
      Bypass.expect(bypass, fn conn ->
        Plug.Conn.resp(conn, status, Map.get(settings, :body, ""))
      end)
    end
  end

  defp do_configure_bypass(bypass, settings) do
    status = Map.get(settings, :status, 200)

    if status in 200..299 do
      Bypass.expect_once(bypass, fn conn ->
        fixture = File.read!("test/fixtures/#{settings.fixture}.json")
        Plug.Conn.resp(conn, status, fixture)
      end)
    else
      Bypass.expect_once(bypass, fn conn ->
        Plug.Conn.resp(conn, status, Map.get(settings, :body, ""))
      end)
    end
  end
end
