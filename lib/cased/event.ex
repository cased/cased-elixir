defmodule Cased.Event do
  @moduledoc """
  Data modeling a Cased audit event.
  """
  import Norm

  defstruct [:audit_trail, :id, :url, :data, :published_at, :processed_at]

  @type t :: %__MODULE__{
          audit_trail: Cased.AuditTrail.t(),
          id: String.t(),
          url: String.t(),
          published_at: DateTime.t(),
          processed_at: DateTime.t(),
          data: %{String.t() => any()}
        }

  @default_audit_trail :default

  @type get_opts :: [get_opt()]
  @type get_opt ::
          {:audit_trail, String.t()}
          | {:key, String.t()}

  @default_get_opts [
    audit_trail: @default_audit_trail
  ]

  @spec get(
          client :: Cased.Client.t(),
          event_id :: String.t(),
          opts :: get_opts()
        ) :: Cased.Request.t() | no_return()
  @doc """
  Build a request to retrieve an event.

  ## Options

  All optional:

  - `:audit_trail` — The audit trail, used to ensure the event comes from the
    given audit trail.
  - `:key` — A Cased policy key allowing access to events.

  If `:key` is omitted:
  - If an `:audit_trail` is provided, the key configured on the client for that
    audit trail will be used.
  - If an `:audit_trail` is **not** provided, the key configured on the client
    for the `:default` audit trail will be used.

  # If `:audit_trail` is omitted, the `#{inspect(Keyword.fetch!(@default_get_opts, :audit_trail))}` audit trail is assumed.
  """
  def get(client, event_id, opts \\ []) do
    opts =
      @default_get_opts
      |> Keyword.merge(opts)

    with {:ok, options} <- validate_get_opts(opts, client) do
      audit_trail = Map.get(options, :audit_trail)

      key = Map.get_lazy(options, :key, fn -> Map.fetch!(client.keys, audit_trail) end)

      %Cased.Request{
        client: client,
        id: :audit_trail_event,
        method: :get,
        path: "/audit-trails/#{audit_trail}/events/#{event_id}",
        key: key
      }
    else
      {:error, details} ->
        raise %Cased.RequestError{details: details}
    end
  end

  @spec validate_get_opts(opts :: keyword(), client :: Cased.Client.t()) ::
          {:ok, map()} | {:error, list()}
  defp validate_get_opts(opts, client) do
    conform(Map.new(opts), get_opts_schema(client))
  end

  # Option schema for `query/2`.
  @spec get_opts_schema(client :: Cased.Client.t()) :: struct()
  defp get_opts_schema(client) do
    schema(%{
      audit_trail: spec(is_atom() and (&Map.has_key?(client.keys, &1))),
      key: spec(is_binary())
    })
  end

  @type query_opts :: [query_opt()]
  @type query_opt ::
          {:phrase, String.t()}
          | {:key, String.t()}
          | {:variables, keyword()}
          | {:per_page, pos_integer()}
          | {:page, pos_integer()}

  @default_query_opts [
    page: 1,
    per_page: 25
  ]

  @doc """
  Build a request to retrieve events from an audit trail.

  ## Options

  - `:phrase` — The search phrase.
  - `:audit_trail` — The audit trail.
  - `:key` — A Cased policy key allowing access to events.
  - `:variables` — Cased Policy variables.
  - `:per_page` — Number of results per page (default: `#{
    inspect(Keyword.fetch!(@default_query_opts, :per_page))
  }`).
  - `:page` — Requested page (default: `#{inspect(Keyword.fetch!(@default_query_opts, :page))}`).

  If `:key` is omitted:
  - If an `:audit_trail` is provided, the key configured on the client for that
    audit trail will be used.
  - If an `:audit_trail` is **not** provided, the key configured on the client
    for the `:default` audit trail will be used.
  """
  @spec query(client :: Cased.Client.t(), opts :: query_opts()) ::
          Cased.Request.t() | no_return()
  def query(client, opts \\ []) do
    opts =
      @default_query_opts
      |> Keyword.merge(opts)

    with {:ok, options} <- validate_query_opts(opts, client) do
      {audit_trail, query} = Map.pop(options, :audit_trail)

      {id, path, key} =
        if audit_trail do
          {:audit_trail_events, "/audit-trails/#{audit_trail}/events",
           Map.get_lazy(options, :key, fn -> Map.fetch!(client.keys, audit_trail) end)}
        else
          {:events, "/events", Map.get(options, :key, client.keys.default)}
        end

      %Cased.Request{
        client: client,
        id: id,
        method: :get,
        path: path,
        key: key,
        query: query
      }
    else
      {:error, details} ->
        raise %Cased.RequestError{details: details}
    end
  end

  @spec validate_query_opts(opts :: keyword(), client :: Cased.Client.t()) ::
          {:ok, map()} | {:error, list()}
  defp validate_query_opts(opts, client) do
    conform(Map.new(opts), query_opts_schema(client))
  end

  # Option schema for `query/2`.
  @spec query_opts_schema(client :: Cased.Client.t()) :: struct()
  defp query_opts_schema(client) do
    schema(%{
      phrase: spec(is_binary()),
      variables: spec(&Keyword.keyword?/1),
      per_page: spec(&Enum.member?(1..100, &1)),
      page: spec(is_integer() and (&(&1 > 0))),
      audit_trail: spec(is_atom() and (&Map.has_key?(client.keys, &1)))
    })
  end

  @doc false
  @spec from_json!(map()) :: t()
  def from_json!(event) do
    {:ok, published_at, _} = DateTime.from_iso8601(event["published_at"])
    {:ok, processed_at, _} = DateTime.from_iso8601(event["processed_at"])

    %__MODULE__{
      id: event["id"],
      audit_trail: Cased.AuditTrail.from_json(event["audit_trail"]),
      url: event["url"],
      published_at: published_at,
      processed_at: processed_at,
      data: event["event"]
    }
  end
end
