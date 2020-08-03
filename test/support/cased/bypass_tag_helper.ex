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

        conn
        |> Plug.Conn.put_resp_header(
          "link",
          [
            ~s(<http://localhost:#{bypass.port}/#{settings.fixture}?page=1&per_page=25>; rel="first"),
            ~s(<http://localhost:#{bypass.port}/#{settings.fixture}?page=3&per_page=25>; rel="last"),
            ~s(<http://localhost:#{bypass.port}/#{settings.fixture}?page=#{page}&per_page=25>; rel="self")
          ]
          |> Enum.join(", ")
        )
        |> Plug.Conn.resp(status, fixture)
      end)
    else
      Bypass.expect(bypass, fn conn ->
        Plug.Conn.resp(conn, status, Map.get(settings, :body, ""))
      end)
    end
  end

  defp do_configure_bypass(bypass, settings) do
    status = Map.get(settings, :status, 200)

    fixture =
      case Map.get(settings, :fixture) do
        nil ->
          nil

        :empty ->
          ""

        name ->
          File.read!("test/fixtures/#{name}.json")
      end

    cond do
      status in 200..299 ->
        Bypass.expect_once(bypass, fn conn ->
          Plug.Conn.resp(conn, status, fixture)
        end)

      status == 302 ->
        redirect_url = "http://localhost:#{bypass.port}#{settings.redirect_path}"

        Bypass.expect_once(bypass, fn conn ->
          conn
          |> Plug.Conn.put_resp_header("location", redirect_url)
          |> Plug.Conn.resp(status, "")
        end)

        Bypass.expect_once(bypass, "GET", settings.redirect_path, fn conn ->
          Plug.Conn.resp(conn, settings.redirect_status, fixture)
        end)

      true ->
        Bypass.expect_once(bypass, fn conn ->
          Plug.Conn.resp(conn, status, Map.get(settings, :body, ""))
        end)
    end
  end
end
