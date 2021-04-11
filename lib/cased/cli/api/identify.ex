defmodule Cased.CLI.Api.Identity do
  @moduledoc "Identity"

  @request_timeout 15_000

  alias Cased.CLI.Config
  alias Cased.CLI.Identity

  @spec identify(Config.t()) :: {:ok, map()} | {:error, Mojito.error()}
  def identify(config) do
    Mojito.post(identify_url(config), build_headers(config), "", timeout: @request_timeout)
    |> case do
      {:ok, %{status_code: 201, body: resp}} ->
        Jason.decode(resp)

      error ->
        error
    end
  end

  @spec check(Config.t(), Identity.State.t()) :: {:ok, map()} | {:error, map() | Mojito.Error.t()}
  def check(config, %{api_url: url} = _state) do
    case Mojito.get(url, build_headers(config)) do
      {:ok, %{body: resp, status_code: 200}} ->
        Jason.decode(resp)

      {_, %{body: resp, status_code: 404}} ->
        {:error, Jason.decode!(resp)}

      {_, response} ->
        {:error, response}
    end
  end

  defp identify_url(%{api_endpoint: endpoint} = _config) do
    endpoint <> "/cli/applications/users/identify"
  end

  defp build_headers(%{app_key: key} = _config) do
    [{"Accept", "application/json"} | Cased.Headers.create(key)]
  end
end
