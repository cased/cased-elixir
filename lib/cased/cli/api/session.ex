defmodule Cased.CLI.Api.Session do
  @moduledoc "Session API"

  @session_path "/cli/sessions"
  @request_timeout 15_000

  alias Cased.CLI.Config
  alias Cased.CLI.Identity

  def retrive(config, %{user: %{"id" => user_token}} = _identity, session_id) do
    Mojito.get(
      api_endpoint(config) <> @session_path <> "/#{session_id}" <> "?user_token=#{user_token}",
      build_headers(config)
    )
    |> case do
      {:ok, %{status_code: code, body: body}} when code in 200..299 ->
        Jason.decode(body)

      {:ok, %{status_code: code, body: body}} when code in 400..499 ->
        {:error, Jason.decode!(body)}

      {:error, %Mojito.Error{reason: reason}} ->
        {:error, reason}

      {_, %{body: body}} ->
        {:error, body}
    end
  end

  def cancel(
        config,
        %{user: %{"id" => user_token}} = _identity,
        %{api_url: url} = _session
      ) do
    Mojito.post("#{url}/cancel?user_token=#{user_token}", build_headers(config))
    |> case do
      {:ok, %{status_code: code, body: body}} when code in 200..299 ->
        Jason.decode(body)

      {:ok, %{status_code: code, body: body}} when code in 400..499 ->
        {:error, Jason.decode!(body)}

      {_, %{body: body}} ->
        {:error, body}
    end
  end

  @spec create(Config.t(), Identity.State.t(), map()) ::
          {:ok, map()} | {:invalid, map()} | {:error, binary()}
  def create(config, %{user: %{"id" => user_token}} = _identity, attrs \\ %{}) do
    Mojito.post(
      api_endpoint(config) <> @session_path <> "?user_token=#{user_token}",
      build_headers(config),
      Jason.encode!(attrs),
      timeout: @request_timeout
    )
    |> case do
      {:ok, %{status_code: code, body: body}} when code in 200..299 ->
        Jason.decode(body)

      {:ok, %{status_code: code, body: body}} when code in 400..499 ->
        {:invalid, Jason.decode!(body)}

      {_, %{body: body}} ->
        {:error, body}
    end
  end

  def put_record(
        config,
        %{api_record_url: url} = _session,
        %{user: %{"id" => user_token}} = _identify,
        asciicast_data
      ) do
    Mojito.put(
      url <> "?user_token=#{user_token}",
      build_headers(config),
      Jason.encode!(%{recording: asciicast_data}),
      timeout: @request_timeout
    )
  end

  defp api_endpoint(%{api_endpoint: endpoint} = _config), do: endpoint

  defp build_headers(%{app_key: key} = _config) do
    [{"Accept", "application/json"} | Cased.Headers.create(key)]
  end
end
