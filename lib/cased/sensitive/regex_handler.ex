defmodule Cased.Sensitive.RegexHandler do
  @moduledoc """
  A handler to mask strings by regular expression.

  ## Examples

  Create a handler using `Cased.Sensitive.Handler.from_spec/1`:
  ```
  {Cased.Sensitive.RegexHandler, :username, ~r/@\w+/}
  |> Cased.Sensitive.Handler.from_spec()
  ```

  The same, created manually:

  ```
  Cased.Sensitive.RegexHandler.create(:username, ~r/@\w+/)
  ```
  """

  @behaviour Cased.Sensitive.Handler

  @enforce_keys [:label, :regex]
  defstruct [:label, :regex]

  @type t :: %__MODULE__{
          label: atom(),
          regex: Regex.t()
        }

  @impl Cased.Sensitive.Handler
  @spec new(label :: atom(), regex :: Regex.t()) :: t()
  def new(label, regex), do: %__MODULE__{label: label, regex: regex}

  @impl Cased.Sensitive.Handler
  def ranges(handler, _audit_event, {key, value}) do
    value
    |> Cased.Sensitive.String.new()
    |> Cased.Sensitive.String.matches(handler.regex)
    |> Enum.map(fn {begin_offset, end_offset} ->
      %Cased.Sensitive.Range{
        label: handler.label,
        key: key,
        begin_offset: begin_offset,
        end_offset: end_offset
      }
    end)
  end
end
