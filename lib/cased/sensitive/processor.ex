defmodule Cased.Sensitive.Processor do
  @moduledoc """
  Processes audit events for sensitive data.
  """

  @default_process_opts [
    return: :embedded,
    handlers: []
  ]

  @type process_opts :: [process_opt()]

  @type process_opt ::
          {:return, :embedded | :pii}
          | {:handlers, [Cased.Sensitive.Handler.spec()]}

  @type address :: [String.t() | non_neg_integer()]

  @doc """
  Process an audit event, collecting any sensitive data found.

  ## Examples

  Process an audit event, returning any sensitive data in a new :".cased" key:

  ```
  iex> audit_event = %{action: "comment.create", body: "Hi, @username"}
  iex> Cased.Sensitive.Processor.process(audit_event, handlers: [
  iex>   {Cased.Sensitive.RegexHandler, :username, ~r/@\\w+/}
  iex> ])
  %{
    ".cased": %{
      pii: %{
        ".body" => [
          %Cased.Sensitive.Range{
            begin_offset: 4,
            end_offset: 13,
            key: :body,
            label: :username
          }
        ]
      }
    },
    action: "comment.create",
    body: "Hi, @username"
  }
  ```

  Return just the sensitive data:

  ```
  iex> audit_event = %{action: "comment.create", body: "Hi, @username"}
  iex> Cased.Sensitive.Processor.process(audit_event, handlers: [
  iex>   {Cased.Sensitive.RegexHandler, :username, ~r/@\\w+/}
  iex> ], return: :pii)
  %{
    ".body" => [
      %Cased.Sensitive.Range{
        begin_offset: 4,
        end_offset: 13,
        key: :body,
        label: :username
      }
    ]
  }
  ```
  """
  @spec process(
          audit_event :: map(),
          opts :: process_opts()
        ) :: map()
  def process(audit_event, opts \\ []) do
    opts =
      @default_process_opts
      |> Keyword.merge(opts)

    handlers =
      opts[:handlers]
      |> Enum.map(&Cased.Sensitive.Handler.from_spec/1)

    {processed_audit_event, pii_data} =
      audit_event
      |> collect(handlers)

    case {opts[:return], pii_data} do
      {:pii, _} ->
        pii_data

      {:embedded, d} when map_size(d) == 0 ->
        processed_audit_event

      {:embedded, _} ->
        processed_audit_event
        |> Map.put(:".cased", %{pii: pii_data})
    end
  end

  # Collect data and PII from an audit event, using handlers
  @spec collect(audit_event :: map(), handlers :: [Cased.Sensitive.Handler.t()]) :: {map(), map()}
  defp collect(audit_event, handlers) do
    collect_from_node(audit_event, audit_event, handlers)
  end

  # Collect data and PII from a node, using handlers
  @spec collect_from_node(
          node :: any(),
          audit_event :: map(),
          handlers :: [Cased.Sensitive.Handler.t()]
        ) :: {processed_node :: map(), pii :: map()}
  defp collect_from_node(node, audit_event, handlers) do
    node
    |> Enum.reduce({%{}, %{}, []}, &do_collect_from_node(&1, &2, audit_event, handlers))
    |> Tuple.delete_at(2)
  end

  @spec do_collect_from_node(
          {key :: any(), value :: any()},
          acc :: {results :: map(), pii :: map(), parent_address :: address()},
          audit_event :: map(),
          handlers :: [Cased.Sensitive.Handler.t()]
        ) :: {results :: map(), pii :: map(), address :: address()}

  # Value is manually marked as sensitive; split data and ranges
  defp do_collect_from_node(
         {key, %Cased.Sensitive.String{} = value},
         {processed_node, pii, parent_address} = _acc,
         _audit_event,
         _handlers
       ) do
    range =
      value
      |> Cased.Sensitive.String.to_range(key)

    address = [key | parent_address]

    {
      Map.put(processed_node, key, value.data),
      Map.put(pii, build_path(address), [range]),
      parent_address
    }
  end

  # Value is another type of struct; just store the value
  defp do_collect_from_node(
         {key, value},
         {results, pii, parent_address} = _acc,
         _audit_event,
         _handlers
       )
       when is_struct(value) do
    {
      Map.put(results, key, value),
      pii,
      parent_address
    }
  end

  # Value is a list; recurse
  defp do_collect_from_node(
         {key, values},
         {results, pii, parent_address} = _acc,
         audit_event,
         handlers
       )
       when is_list(values) do
    address = [key | parent_address]

    acc = {_result = [], pii}

    {result, pii} =
      values
      |> Enum.with_index()
      |> Enum.reduce(
        acc,
        &collect_from_list_element(&1, &2, address, audit_event, handlers)
      )

    {
      Map.put(results, key, result |> Enum.reverse()),
      pii,
      parent_address
    }
  end

  # Value is a map; recurse
  defp do_collect_from_node(
         {key, values},
         {results, pii, parent_address} = _acc,
         audit_event,
         handlers
       )
       when is_map(values) do
    address = [key | parent_address]

    acc = {_result = %{}, pii}

    {result, pii} =
      values
      |> Enum.reduce(
        acc,
        &collect_from_map_pair(&1, &2, address, audit_event, handlers)
      )

    {
      Map.put(results, key, result),
      pii,
      parent_address
    }
  end

  # Value is a scalar; extract ranges
  defp do_collect_from_node(
         {key, value},
         {results, pii, parent_address} = _acc,
         audit_event,
         handlers
       ) do
    address = [key | parent_address]

    case ranges(handlers, audit_event, key, value) do
      [] ->
        {
          Map.put(results, key, value),
          pii,
          parent_address
        }

      key_pii ->
        {
          Map.put(results, key, value),
          Map.put(pii, build_path(address), key_pii),
          parent_address
        }
    end
  end

  @spec collect_from_map_pair(
          {key :: any(), value :: any()},
          acc :: {results :: map(), pii :: map()},
          parent_address :: address(),
          audit_event :: map(),
          handlers :: [Cased.Sensitive.Handler.t()]
        ) :: {results :: map(), pii :: map()}
  defp collect_from_map_pair(pair, {results, pii}, parent_address, audit_event, handlers) do
    do_collect_from_node(pair, {results, pii, parent_address}, audit_event, handlers)
    |> Tuple.delete_at(2)
  end

  @spec collect_from_list_element(
          {value :: any(), offset :: non_neg_integer()},
          acc :: {results :: map(), pii :: map()},
          parent_address :: address(),
          audit_event :: map(),
          handlers :: [Cased.Sensitive.Handler.t()]
        ) :: {results :: list(), pii :: map()}
  defp collect_from_list_element(
         {value, offset},
         {results, pii},
         parent_address,
         audit_event,
         handlers
       ) do
    {collected_result, pii, _} =
      do_collect_from_node(
        {offset, value},
        {%{}, pii, parent_address},
        audit_event,
        handlers
      )

    result = collected_result[offset]

    {[result | results], pii}
  end

  # Extract the sensitive value ranges from a value, using handlers
  @spec ranges(
          handlers :: [Cased.Sensitive.Handler.t()],
          audit_event :: map(),
          key :: atom() | String.t(),
          value :: any()
        ) :: [Cased.Sensitive.Range.t()]
  defp ranges(handlers, audit_event, key, value) do
    handlers
    |> Enum.flat_map(fn %module{} = handler ->
      module.ranges(handler, audit_event, {key, value})
    end)
  end

  @doc false
  @spec build_path(address :: address()) :: String.t()
  def build_path(address) do
    address
    |> Enum.reverse()
    |> Enum.map(fn
      value when is_integer(value) ->
        "[#{value}]"

      value ->
        # Normalize atoms
        value = to_string(value)

        key =
          if String.contains?(value, ".") do
            ~s("#{value}")
          else
            value
          end

        ".#{key}"
    end)
    |> Enum.join("")
  end
end
