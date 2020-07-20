defmodule Cased.Context do
  @moduledoc """
  Used to set contextual data when publishing audit events with `Cased.publish/2`.

  Stored using the process dictionary, the context is tied to the current process.
  """

  @typedoc false
  @type stack :: [map()]

  @process_dict_key :cased_context

  @doc """
  Get the context as a map.

  ## Example

  Setting a value and retrieving the context as a map:

  ```
  iex> Cased.Context.put(:location, "https://example.com")
  :ok
  iex> Cased.Context.to_map()
  %{location: "https://example.com"}
  """
  @spec to_map() :: map()
  def to_map() do
    get_stack()
    |> List.foldl(%{}, &DeepMerge.deep_merge/2)
  end

  @doc """
  Add a value to the context.

  ## Example

  Adding a `:location` to the context:

  ```
  iex> Cased.Context.put(:location, "https://example.com")
  :ok
  ```

  Note that the return value of `put/2` is `:ok` rather than what you might
  expect for, e.g., `Map.put/2`, since we don't incur the cost of recalculating
  the full context when a value is added.
  """
  @spec put(key :: atom(), value :: any()) :: :ok
  def put(key, value) do
    merge(%{key => value})
  end

  @doc """
  Add a value to the context for the duration of a function execution.

  ## Example

  Adding a `:location` to the context, temporarily:

  ```
  iex> Cased.Context.put(:location, "https://example.com", fn ->
  iex>   # Use Cased.publish/2
  iex>   :your_return_value
  iex> end)
  :your_return_value
  ```

  Note that, unlike `put/2`, the return value of `put/3` is the value of the
  last statement in your function.
  """
  @spec put(key :: atom(), value :: any(), scope :: function()) :: any()
  def put(key, value, scope) do
    merge(%{key => value}, scope)
  end

  @doc """
  Add multiple values value to the context.

  ## Example

  Adding a `:location` and `:http_method` to the context:

  ```
  iex> Cased.Context.merge(%{
  iex>   location: "https://example.com",
  iex>   http_method: :patch
  iex> })
  :ok
  ```

  Note that the return value of `merge/2` is `:ok` rather than what you might
  expect for, e.g., `Map.merge/2`, since we don't incur the cost of
  recalculating the full context when a value is added.
  """
  @spec merge(data :: map()) :: :ok
  def merge(data) when is_map(data) do
    [data | get_stack()]
    |> put_stack()

    :ok
  end

  @doc """
  Add multiple values to the context for the duration of a function execution.

  ## Example

  Adding a `:location` and `:http_method` to the context, temporarily:

  ```
  iex> tmp_context = %{
  iex>   location: "https://example.com",
  iex>   http_method: :patch
  iex> }
  iex> Cased.Context.merge(tmp_context, fn ->
  iex>   # Use Cased.publish/2
  iex>   :your_return_value
  iex> end)
  :your_return_value
  ```

  Note that, unlike `merge/2`, the return value of `merge/3` is the value of the
  last statement in your function.
  """
  @spec merge(data :: map(), function()) :: any()
  def merge(data, scope) do
    merge(data)
    result = scope.()
    pop_stack()
    result
  end

  @doc """
  Reset the context data.

  ## Examples

  Setting a value in the context and then resetting it (note `reset/0` returns
  `:ok` as context data was deleted):

  ```
  iex> Cased.Context.put(:item, "value")
  iex> Cased.Context.to_map()
  %{item: "value"}
  iex> Cased.Context.reset()
  :ok
  iex> Cased.Context.to_map()
  %{}
  ```

  Resetting an empty context returns `nil`:

  ```
  iex> Cased.Context.reset()
  nil
  ```
  """
  @spec reset() :: nil | :ok
  def reset() do
    case Process.delete(@process_dict_key) do
      nil ->
        nil

      [] ->
        nil

      _other ->
        :ok
    end
  end

  ##
  # Utilities

  @doc false
  @spec get(key :: atom(), default :: any()) :: any()
  def get(key, default \\ nil) do
    to_map()
    |> Map.get(key, default)
  end

  @doc false
  @spec has_key?(atom()) :: boolean()
  def has_key?(key) do
    get_stack()
    |> Enum.any?(&Map.has_key?(&1, key))
  end

  @doc false
  @spec stack_size() :: non_neg_integer()
  def stack_size() do
    get_stack()
    |> length()
  end

  @doc false
  @spec has_stack?() :: boolean()
  def has_stack? do
    !is_nil(Process.get(@process_dict_key))
  end

  @spec get_stack() :: stack()
  defp get_stack() do
    Process.get(@process_dict_key, [])
  end

  @spec put_stack(stack :: stack()) :: any() | nil
  defp put_stack(stack) do
    Process.put(@process_dict_key, stack)
  end

  @spec pop_stack() :: nil | map()
  defp pop_stack() do
    get_stack()
    |> tl()
    |> put_stack()
  end
end
