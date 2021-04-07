defmodule Cased.CLI.Api.Session do
  @moduledoc "Session API"

  @session_path "/cli/sessions"
  @request_timeout 15_000

  def retrive(%{user: %{"id" => user_token}} = _identity, session_id) do
    Mojito.get(
      api_endpoint() <> @session_path <> "/#{session_id}" <> "?user_token=#{user_token}",
      build_headers()
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
        %{user: %{"id" => user_token}} = _identity,
        %{api_url: url} = _session
      ) do
    Mojito.post("#{url}/cancel?user_token=#{user_token}", build_headers())
    |> case do
      {:ok, %{status_code: code, body: body}} when code in 200..299 ->
        Jason.decode(body)

      {:ok, %{status_code: code, body: body}} when code in 400..499 ->
        {:error, Jason.decode!(body)}

      {_, %{body: body}} ->
        {:error, body}
    end
  end

  def create(%{user: %{"id" => user_token}} = _identity, attrs \\ %{}) do
    Mojito.post(
      api_endpoint() <> @session_path <> "?user_token=#{user_token}",
      build_headers(),
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
    %{api_record_url: url} = _session,
    %{user: %{"id" => user_token}} = _identify,
    asciicast_data
  ) do
    Mojito.put(
      url <> "?user_token=#{user_token}",
      build_headers(),
      Jason.encode!(%{recording: asciicast_data}),
      timeout: @request_timeout
    )
  end

  defp api_endpoint(), do: Cased.CLI.Config.api_endpoint()


  defp build_headers() do
    [{"Accept", "application/json"} | Cased.Headers.create(Cased.CLI.Config.get(:app_key, ""))]
  end
end
