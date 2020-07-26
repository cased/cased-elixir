defmodule Cased.Policy do
  @moduledoc """
  Data modeling a Cased policy.
  """
  import Norm

  defstruct [
    :id,
    :url,
    :name,
    :description,
    :expired,
    :api_key,
    :export,
    :audit_trails,
    :pii,
    :created_at,
    :updated_at
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          url: String.t(),
          name: String.t(),
          description: String.t(),
          expired: boolean(),
          api_key: String.t(),
          pii: boolean(),
          export: boolean(),
          audit_trails: [Cased.AuditTrail.t()],
          created_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  @type get_opts :: [get_opt()]
  @type get_opt :: {:key, nil | String.t()}

  @default_get_opts [
    key: nil
  ]

  @spec get(
          client :: Cased.Client.t(),
          policy_id :: String.t(),
          opts :: get_opts()
        ) :: Cased.Request.t() | no_return()

  @doc """
  Build a request to retrieve a policy.

  ## Options

  - `:key` — A Cased environment key allowing access to policies.

  If `:key` is omitted, the client is expected to be configured with an environment key.
  """
  def get(client, policy_id, opts \\ []) do
    opts =
      @default_get_opts
      |> Keyword.merge(opts)

    with {:ok, options} <- validate_get_opts(opts, client) do
      %Cased.Request{
        client: client,
        id: :policy,
        method: :get,
        path: "/policies/#{policy_id}",
        key: options.key || client.environment_key
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
      key: Cased.Key.pattern(:environment, client)
    })
    |> selection()
  end

  @type query_opts :: [query_opt()]
  @type query_opt ::
          {:per_page, pos_integer()}
          | {:page, pos_integer()}
          | {:key, nil | String.t()}

  @default_query_opts [
    page: 1,
    per_page: 25,
    key: nil
  ]

  @doc """
  Build a request to retrieve policies.

  ## Options

  - `:per_page` — Number of results per page (default: `#{
    inspect(Keyword.fetch!(@default_query_opts, :per_page))
  }`).
  - `:page` — Requested page (default: `#{inspect(Keyword.fetch!(@default_query_opts, :page))}`).
  - `:key` — A Cased environment key allowing access to policies.

  If `:key` is omitted, the client is expected to be configured with an environment key.
  """
  @spec query(client :: Cased.Client.t(), opts :: query_opts()) ::
          Cased.Request.t() | no_return()
  def query(client, opts \\ []) do
    opts =
      @default_query_opts
      |> Keyword.merge(opts)

    with {:ok, options} <- validate_query_opts(opts, client) do
      {key, query} = Map.pop(options, :key)

      %Cased.Request{
        client: client,
        id: :policies,
        method: :get,
        path: "/policies",
        key: key || client.environment_key,
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
      per_page: spec(&Enum.member?(1..100, &1)),
      page: spec(is_integer() and (&(&1 > 0))),
      key: Cased.Key.pattern(:environment, client)
    })
  end

  @doc false
  @spec from_json!(map()) :: t()
  def from_json!(object) do
    {:ok, created_at, _} = DateTime.from_iso8601(object["created_at"])
    {:ok, updated_at, _} = DateTime.from_iso8601(object["updated_at"])

    %__MODULE__{
      id: object["id"],
      url: object["url"],
      name: object["name"],
      description: object["description"],
      expired: object["expired"],
      api_key: object["api_key"],
      export: get_in(object, ~w(policy export)),
      pii: get_in(object, ~w(policy pii)),
      audit_trails:
        Enum.map(get_in(object, ~w(policy audit_trails)) || [], &Cased.AuditTrail.from_json/1),
      created_at: created_at,
      updated_at: updated_at
    }
  end
end
