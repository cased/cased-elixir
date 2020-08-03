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

  @spec query_opts_schema(client :: Cased.Client.t()) :: struct()
  defp query_opts_schema(client) do
    schema(%{
      per_page: spec(&Enum.member?(1..100, &1)),
      page: spec(is_integer() and (&(&1 > 0))),
      key: Cased.Key.pattern(:environment, client)
    })
  end

  @type window :: [window_constraint()]
  @type window_constraint :: {:gt | :gte | :lt | :lte, DateTime.t()}

  @type create_or_update_opts :: [create_or_update_opt()]
  @type create_or_update_opt ::
          {:name, String.t()}
          | {:description, String.t()}
          | {:audit_trails, [String.t()]}
          | {:fields, [atom()]}
          | {:window, window()}
          | {:pii, boolean()}
          | {:export, boolean()}
          | {:expires, DateTime.t()}
          | {:key, nil | String.t()}

  @default_create_or_update_opts [
    key: nil
  ]

  @require_one_create_or_update_opts [
    :audit_trails,
    :fields,
    :window,
    :pii,
    :export,
    :expires
  ]

  @spec create(
          client :: Cased.Client.t(),
          opts :: create_or_update_opts()
        ) :: Cased.Request.t() | no_return()

  @create_or_update_doc """
  ## Options

  Requires all of:

  - `:name` — The audit trail policy name to be referenced by Cased SDK clients.
  - `:description` — A human readable description describing the intent of the audit trail policy.

  Requires at least one of:

  - `:audit_trails` — The list of audit trails accessible by this audit trail policy.
  - `:fields` — The fields that are accessible by this audit trail policy and their field configuration.
  - `:window` — The window of time accessible to this audit trail policy.
  - `:pii` — Determines if the audit trail policy can access any Personally Identifiable Information.
  - `:export` — Determines if the audit events accessible by the audit trail policy are exportable.
  - `:expires` — When the policy is no longer accessible.

  May include:

  - `:key` — A Cased environment key allowing access to policies.

  If `:key` is omitted, the client is expected to be configured with an environment key.
  """

  @doc """
  Build a request to create a policy.

  #{@create_or_update_doc}
  """
  def create(client, opts \\ []) do
    opts =
      @default_create_or_update_opts
      |> Keyword.merge(opts)

    with {:ok, options} <- validate_create_or_update_opts(opts, client) do
      unless Enum.any?(@require_one_create_or_update_opts, &Map.has_key?(options, &1)) do
        raise %Cased.RequestError{
          details: "requires one of #{@require_one_create_or_update_opts |> inspect()}"
        }
      end

      {key, body} = Map.pop(options, :key)

      body =
        case body do
          %{window: window} ->
            %{body | window: Map.new(window)}

          _ ->
            body
        end

      %Cased.Request{
        client: client,
        id: :policy_create,
        method: :post,
        path: "/policies",
        key: key || client.environment_key,
        body: body
      }
    else
      {:error, details} ->
        raise %Cased.RequestError{details: details}
    end
  end

  @spec validate_create_or_update_opts(opts :: keyword(), client :: Cased.Client.t()) ::
          {:ok, map()} | {:error, list()}
  defp validate_create_or_update_opts(opts, client) do
    conform(Map.new(opts), create_or_update_opts_schema(client))
  end

  @spec create_or_update_opts_schema(client :: Cased.Client.t()) :: struct()
  defp create_or_update_opts_schema(client) do
    schema(%{
      audit_trails: coll_of(spec(is_atom() or is_binary()), min_count: 1),
      description: spec(is_binary()),
      fields: coll_of(spec(is_atom() or is_binary())),
      export: spec(is_boolean()),
      expires:
        spec(fn
          %DateTime{} -> true
          _ -> false
        end),
      key: Cased.Key.pattern(:environment, client),
      name: spec(is_binary()),
      pii: spec(is_boolean()),
      window: spec(is_list() and (&valid_window?/1))
    })
    |> selection([:name, :description, :key])
  end

  ##
  # Update

  @spec update(
          client :: Cased.Client.t(),
          policy_id :: String.t(),
          opts :: create_or_update_opts()
        ) :: Cased.Request.t() | no_return()
  @doc """
  Build a request to update a policy.

  #{@create_or_update_doc}
  """
  def update(client, policy_id, opts \\ []) do
    opts =
      @default_create_or_update_opts
      |> Keyword.merge(opts)

    with {:ok, options} <- validate_create_or_update_opts(opts, client) do
      unless Enum.any?(@require_one_create_or_update_opts, &Map.has_key?(options, &1)) do
        raise %Cased.RequestError{
          details: "requires one of #{@require_one_create_or_update_opts |> inspect()}"
        }
      end

      {key, body} = Map.pop(options, :key)

      body =
        case body do
          %{window: window} ->
            %{body | window: Map.new(window)}

          _ ->
            body
        end

      %Cased.Request{
        client: client,
        id: :policy_update,
        method: :put,
        path: "/policies/#{policy_id}",
        key: key || client.environment_key,
        body: body
      }
    else
      {:error, details} ->
        raise %Cased.RequestError{details: details}
    end
  end

  ##
  # Window validation

  @window_comps ~w(gt gte lt lte)a

  # Matches a window with valid constraints.
  #
  # A valid window may indicate a period after a datetime:
  # |--->
  #
  # Before a datetime:
  # <---|
  #
  # Or between two datetimes:
  # |<--->|
  #
  # Either inclusively or exclusively.
  @spec valid_window?(window :: window()) :: boolean()
  defp valid_window?([constraint]), do: valid_window_constraint?(constraint)

  defp valid_window?([_, _] = window) do
    with true <- Enum.all?(window, &valid_window_constraint?/1),
         false <- overlapping_constraints?(window),
         false <- divergent_constraints?(window) do
      true
    else
      _ ->
        false
    end
  end

  defp valid_window?(_), do: false

  @spec valid_window_constraint?(constraint :: window_constraint()) :: boolean()
  defp valid_window_constraint?({comp, %DateTime{}}) when comp in @window_comps, do: true
  defp valid_window_constraint?(_), do: false

  # Matches invalid windows where there are two gt/gte or lt/lte constraints.
  #
  # Going into the future:
  # |---|===>
  #
  # Or, going into the past:
  # <===|---|
  #
  @spec overlapping_constraints?(window :: window()) :: boolean()
  defp overlapping_constraints?(window) do
    length(window) == 2 &&
      !(get_window_constraint(window, :lt) && get_window_constraint(window, :gt))
  end

  # Matches invalid windows that represent a time period that is:
  #
  # Any time besides a datetime range.
  # <---|...|--->
  #
  # Any time besides a specific datetime.
  # <---|.|--->
  #
  # Any time (diverging from a single datetime).
  # <---|--->
  @spec divergent_constraints?(window :: window()) :: boolean()
  defp divergent_constraints?(window) do
    {_, lt_datetime} = window |> get_window_constraint(:lt)
    {_, gt_datetime} = window |> get_window_constraint(:gt)

    DateTime.compare(lt_datetime, gt_datetime) in [:lt, :eq]
  end

  @window_directions [
    lt: [:lt, :lte],
    gt: [:lt, :gte]
  ]

  # Gets the lt/lte or gt/gte constraint of a window
  @spec get_window_constraint(window :: window(), direction :: :lt | :gt) ::
          nil | window_constraint()
  defp get_window_constraint(window, direction) do
    matches = @window_directions[direction]

    window
    |> Enum.find(fn {comp, _} -> comp in matches end)
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
