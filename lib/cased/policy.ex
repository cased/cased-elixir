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

  @type query_opts :: [query_opt()]
  @type query_opt ::
          {:per_page, pos_integer()}
          | {:page, pos_integer()}

  @default_query_opts [
    page: 1,
    per_page: 25
  ]

  @doc """
  Build a request to retrieve policies.

  Note that the client must be configured with an `:environment_key`.

  ## Options

  - `:per_page` — Number of results per page (default: `#{
    inspect(Keyword.fetch!(@default_query_opts, :per_page))
  }`).
  - `:page` — Requested page (default: `#{inspect(Keyword.fetch!(@default_query_opts, :page))}`).
  """
  @spec query(client :: Cased.Client.t(), opts :: query_opts()) ::
          Cased.Request.t() | no_return()
  def query(client, opts \\ []) do
    opts =
      @default_query_opts
      |> Keyword.merge(opts)

    with :ok <- validate_query_client(client),
         {:ok, query} <- validate_query_opts(opts) do
      %Cased.Request{
        client: client,
        id: :policies,
        method: :get,
        path: "/policies",
        key: client.environment_key,
        query: query
      }
    else
      {:error, details} ->
        raise %Cased.RequestError{details: details}
    end
  end

  @spec validate_query_client(client :: Cased.Client.t()) :: :ok | {:error, atom()}
  defp validate_query_client(%{environment_key: nil}) do
    {:error, "client missing :environment_key"}
  end

  defp validate_query_client(_), do: :ok

  @spec validate_query_opts(opts :: keyword()) ::
          {:ok, map()} | {:error, list()}
  defp validate_query_opts(opts) do
    conform(Map.new(opts), query_opts_schema())
  end

  # Option schema for `query/2`.
  @spec query_opts_schema() :: struct()
  defp query_opts_schema() do
    schema(%{
      per_page: spec(&Enum.member?(1..100, &1)),
      page: spec(is_integer() and (&(&1 > 0))),
      key: spec(is_binary())
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
