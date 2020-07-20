defmodule Cased.Export do
  @moduledoc """
  Data modeling a Cased export.
  """
  import Norm

  @enforce_keys [
    :id,
    :audit_trails,
    :download_url,
    :events_found_count,
    :fields,
    :format,
    :phrase,
    :state,
    :updated_at,
    :created_at
  ]
  defstruct [
    :id,
    :audit_trails,
    :download_url,
    :events_found_count,
    :fields,
    :format,
    :phrase,
    :state,
    :updated_at,
    :created_at
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          audit_trails: [String.t()],
          download_url: String.t(),
          events_found_count: non_neg_integer(),
          fields: [String.t()],
          format: String.t(),
          phrase: nil | String.t(),
          state: String.t(),
          updated_at: DateTime.t(),
          created_at: DateTime.t()
        }

  @type create_opts :: [create_opt()]
  @type create_opt ::
          {:audit_trails, [atom()]}
          | {:audit_trail, atom()}
          | {:fields, [String.t()]}
          | {:key, String.t()}

  @doc """
  Build a request to create an export of audit trail fields.

  ## Options

  The following options are available:

  - `:audit_trails` — The list of audit trails to export
  - `:audit_trail` — When passing a single audit trail, you can use this instead of `:audit_trails`.
  - `:fields` — The fields to export
  - `:key` — The Cased policy key allowing access to the audit trails and fields.

  The only required option is `:fields`.

  - When both `:audit_trail` and `:audit_trails` are omitted, `:audit_trail` is assumed to be `default`.
  - When `:key` is omitted, the key configured for the `:audit_trail` (or first of `:audit_trails`) in
  the client is used.
  """
  @spec create(client :: Cased.Client.t(), opts :: create_opts()) ::
          Cased.Request.t() | no_return()
  def create(client, opts \\ []) do
    opts = normalize_create_opts(opts)

    with {:ok, params} <- validate_create_opts(opts, client) do
      {key, params} =
        Map.pop_lazy(params, :key, fn ->
          primary_audit_trail = params.audit_trails |> List.first()
          client.keys[primary_audit_trail]
        end)

      %Cased.Request{
        client: client,
        method: :post,
        path: "/exports",
        key: key,
        body: Map.put(params, :format, "json")
      }
    else
      {:error, details} ->
        raise %Cased.RequestError{details: details}
    end
  end

  @spec normalize_create_opts(opts :: keyword()) :: keyword()
  defp normalize_create_opts(opts) do
    if Keyword.has_key?(opts, :audit_trail) || Keyword.has_key?(opts, :audit_trails) do
      opts
    else
      opts
      |> Keyword.put(:audit_trail, :default)
    end
  end

  @spec validate_create_opts(opts :: keyword(), client :: Cased.Client.t()) ::
          {:ok, map()} | {:error, list()}
  defp validate_create_opts(opts, client) do
    conform(Map.new(opts), create_opts_schema(client))
    |> case do
      {:ok, {:multiple_audit_trails, params}} ->
        {:ok, params}

      {:ok, {:single_audit_trail, params}} ->
        {audit_trail, params} = Map.pop(params, :audit_trail)
        {:ok, Map.put(params, :audit_trails, [audit_trail])}

      {:error, _} = err ->
        err
    end
  end

  # Option schema for `create/2`.
  @spec create_opts_schema(client :: Cased.Client.t()) :: struct()
  defp create_opts_schema(client) do
    audit_trail_spec = spec(is_atom() and (&Map.has_key?(client.keys, &1)))
    fields_spec = coll_of(spec(is_binary() or is_atom()))

    single_schema =
      schema(%{
        fields: fields_spec,
        audit_trail: audit_trail_spec
      })

    multi_schema =
      schema(%{
        fields: fields_spec,
        audit_trails: coll_of(audit_trail_spec, min_count: 1, distinct: true)
      })

    alt(
      single_audit_trail: single_schema |> selection(),
      multiple_audit_trails: multi_schema |> selection()
    )
  end

  @spec from_json!(map()) :: t() | no_return()
  def from_json!(data) do
    data =
      data
      |> Map.update("created_at", nil, &normalize_datetime/1)
      |> Map.update("updated_at", nil, &normalize_datetime/1)

    %__MODULE__{
      id: data["id"],
      audit_trails: Map.get(data, "audit_trails", []),
      download_url: data["download_url"],
      events_found_count: data["events_found_count"],
      fields: Map.get(data, "fields", []),
      format: data["format"],
      phrase: data["phrase"],
      state: data["state"],
      updated_at: data["updated_at"],
      created_at: data["created_at"]
    }
  end

  defp normalize_datetime(nil), do: nil

  defp normalize_datetime(datetime) do
    case DateTime.from_iso8601(datetime) do
      {:ok, result, _} ->
        result

      {:error, _} ->
        raise ArgumentError, "Bad datetime: #{datetime}"
    end
  end
end
