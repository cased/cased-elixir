defmodule Cased.Sensitive.Handler do
  @moduledoc """
  Behaviour used to identify sensitive data.

  Implementing custom handlers only requires two functions:

  - `c:new/2`, which is called by `from_spec/1`, passing any custom configuration.
  - `c:ranges/3`, which is called for each value in an audit event by `Cased.Sensitive.Processor.process/2`.

  See `Cased.Sensitive.RegexHandler` and tests for example implementations.
  """
  @type handler_module :: module()

  @typedoc """
  A tuple structure used to declare the options for a handler.

  ## Examples

  Configuring a `Cased.Sensitive.RegexHandler` to detect `@`-prefixed usernames:

  ```
  {Cased.Sensitive.RegexHandler, :username, ~r/@\w+/}
  ```

  For your own, custom defined handlers:

  ```
  {MyApp.CustomHandler, :custom_label_for_handler, custom_configuration_for_handler}
  ```
  """
  @type spec :: {
          module :: handler_module(),
          label :: atom(),
          config :: any()
        }

  @type t :: %{
          :__struct__ => handler_module(),
          :label => atom(),
          optional(atom()) => any()
        }

  @doc """
  Create a handler with a given label and custom configuration.
  """
  @callback new(label :: atom(), config :: any()) :: t()

  @doc """
  Extract `Cased.Sensitive.Range` structs for a given `value` at `key`.

  Note that `value` can be of any type; your implementation should return an
  empty list for any unsupported values.
  """
  @callback ranges(
              handler :: t(),
              audit_event :: map(),
              {
                key :: Cased.Sensitive.Range.key(),
                value :: any()
              }
            ) :: [Cased.Sensitive.Range.t()]

  @doc """
  Create a handler from a handler specification (commonly loaded from application config).

  ## Examples

  Creating a `Cased.Sensitive.RegexHandler` from the tuple specification:

  ```
  iex> handler_spec = {Cased.Sensitive.RegexHandler, :username, ~r/@\w+/}
  iex> Cased.Sensitive.Handler.from_spec(handler)
  %Cased.Sensitive.RegexHandler{label: :username, regex: ~r/@\w+/}
  ```
  """
  @spec from_spec(raw_handler :: spec()) :: t()
  def from_spec(%{} = handler), do: handler
  def from_spec({module, label, config}), do: module.new(label, config)
end
