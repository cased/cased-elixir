defmodule Cased.Event do
  import Norm

  defstruct [:audit_trail, :id, :url, :data, :created_at]

  @type t :: %__MODULE__{
          audit_trail: Cased.AuditTrail.t(),
          id: String.t(),
          url: String.t(),
          created_at: DateTime.t(),
          data: %{String.t() => any()}
        }

  @default_audit_trail :default

  @type query_opts :: [query_opt()]
  @type query_opt ::
          {:phrase, String.t()}
          | {:variables, keyword()}
          | {:per_page, pos_integer()}
          | {:page, pos_integer()}

  @default_query_opts [
    audit_trail: @default_audit_trail,
    page: 1,
    per_page: 25
  ]

  @doc """
  Build a request to retrieve events from an audit trail.

  ## Options

  - `:phrase` — The search phrase.
  - `:variables` — Cased Policy variables.
  - `:per_page` — Number of results per page (default: `#{inspect(@default_query_opts[:per_page])}`).
  - `:page` — Requested page (default: `#{inspect(@default_query_opts[:page])}`).
  """
  @spec query(client :: Cased.Client.t(), opts :: query_opts()) ::
          Cased.Request.t() | no_return()
  def query(client, opts \\ []) do
    opts =
      @default_query_opts
      |> Keyword.merge(opts)

    with {:ok, options} <- validate_query_opts(opts, client) do
      {audit_trail, query} = Map.pop(options, :audit_trail)

      %Cased.Request{
        client: client,
        method: :get,
        path: "/events",
        key: client.keys[audit_trail],
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
    {:ok, created_at, _} = DateTime.from_iso8601(event["created_at"])

    %__MODULE__{
      id: event["id"],
      audit_trail: Cased.AuditTrail.from_json(event["audit_trail"]),
      url: event["url"],
      created_at: created_at,
      data: event["event"]
    }
  end
end
