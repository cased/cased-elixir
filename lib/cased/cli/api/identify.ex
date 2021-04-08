defmodule Cased.CLI.Api.Identity do
  @moduledoc "Identity"

  alias Cased.CLI.Config

  @request_timeout 15_000

  def identify() do
    case Mojito.post(identify_url(), build_headers(), "", timeout: @request_timeout) do
      {:ok, %{status_code: 201, body: resp}} ->
        Jason.decode(resp)

      error ->
        error
    end
  end

  def check(%{api_url: url} = _state) do
    case Mojito.get(url, build_headers()) do
      {:ok, %{body: resp, status_code: 200}} ->
        Jason.decode(resp)

      {_, response} ->
        {:error, response}
    end
  end

  defp identify_url() do
    Config.api_endpoint() <> "/cli/applications/users/identify"
  end

  defp build_headers() do
    [{"Accept", "application/json"} | Cased.Headers.create(Config.app_key())]
  end
end
