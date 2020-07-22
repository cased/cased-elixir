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
        body: [
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
    body: [
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
        ) :: {processed_node :: map(), node_pii :: map()}
  defp collect_from_node(node, audit_event, handlers) do
    node
    |> Enum.reduce({%{}, %{}}, &do_collect_from_node(&1, &2, audit_event, handlers))
  end

  @spec do_collect_from_node(
          {key :: String.t() | atom(), value :: any()},
          acc :: {processed_node :: map(), node_pii :: map()},
          audit_event :: map(),
          handlers :: [Cased.Sensitive.Handler.t()]
        ) :: {processed_node :: map(), node_pii :: map()}

  # Value is manually marked as sensitive; split data and ranges
  defp do_collect_from_node(
         {key, %Cased.Sensitive.String{} = value},
         {processed_node, node_pii} = _acc,
         _audit_event,
         _handlers
       ) do
    range =
      value
      |> Cased.Sensitive.String.to_range(key)

    {
      Map.put(processed_node, key, value.data),
      Map.put(node_pii, key, [range])
    }
  end

  # Value is a string; extract ranges
  defp do_collect_from_node(
         {key, value},
         {processed_node, node_pii} = _acc,
         audit_event,
         handlers
       ) do
    case ranges(handlers, audit_event, key, value) do
      [] ->
        {
          Map.put(processed_node, key, value),
          node_pii
        }

      key_pii ->
        {
          Map.put(processed_node, key, value),
          Map.put(node_pii, key, key_pii)
        }
    end
  end

  # Value is something else; skip
  defp do_collect_from_node(_other, acc, _audit_event, _handlers), do: acc

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
end
