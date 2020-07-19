defmodule Cased.Sensitive.Range do
  @enforce_keys [:key, :begin_offset, :end_offset]
  defstruct [
    :key,
    :begin_offset,
    :end_offset,
    label: nil
  ]

  @type key :: atom()

  @type t :: %__MODULE__{
          key: key(),
          begin_offset: non_neg_integer(),
          end_offset: non_neg_integer(),
          label: nil | atom()
        }

  defimpl Jason.Encoder do
    def encode(range, opts) do
      data = %{
        label: range.label,
        begin: range.begin_offset,
        end: range.end_offset
      }

      Jason.Encode.map(data, opts)
    end
  end
end
