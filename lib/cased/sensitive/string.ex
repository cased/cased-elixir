defmodule Cased.Sensitive.String do
  @moduledoc """
  Used to mask sensitive string values.
  """

  @enforce_keys [:data, :label]
  defstruct [
    :data,
    :label
  ]

  @type t :: %__MODULE__{
          data: String.t(),
          label: nil | atom() | String.t()
        }

  @type new_opts :: [new_opt()]
  @type new_opt :: {:label, String.t() | atom()}

  @doc """
  Create a new `Cased.Sensitive.String` struct.

  ## Example

  ```
  Cased.Sensitive.String.new("john@example.com", label: :email)
  ```
  """
  @spec new(raw_string :: String.t(), opts :: new_opts()) :: t()
  def new(raw_string, opts \\ []) do
    %__MODULE__{
      data: raw_string,
      label: Keyword.get(opts, :label, nil)
    }
  end

  @doc """
  Extract all `{begin_offset, end_offset}` values for matches of a given regular expression.

  ## Examples

  ```
  Cased.Sensitive.String.new("Hello @username and @username")
  |> Cased.Sensitive.String.matches(~r/@\w+/)
  # => [{6, 15}, {20, 29}]
  ```
  """
  @spec matches(string :: t(), regex :: Regex.t()) :: [{non_neg_integer(), non_neg_integer()}]
  def matches(string, regex) do
    Regex.scan(regex, string.data, return: :index)
    |> List.flatten()
    |> Enum.map(fn {offset, length} ->
      {offset, offset + length}
    end)
  end

  @doc """
  Check two sensitive strings for equality.

  ## Examples

  Two strings with the same data and label are equivalent:

  ```
  iex> string1 = Cased.Sensitive.String.new("text", label: "username")
  iex> string2 = Cased.Sensitive.String.new("text", label: "username")
  iex> Cased.Sensitive.String.equal?(string1, string2)
  true
  ```

  If the contents are different, two sensitive strings are not equal:

  ```
  iex> string1 = Cased.Sensitive.String.new("text", label: "username")
  iex> string2 = Cased.Sensitive.String.new("txet", label: "username")
  iex> Cased.Sensitive.String.equal?(string1, string2)
  false
  ```

  If the labels are different, two sensitive strings are not equal:

  ```
  iex> string1 = Cased.Sensitive.String.new("text", label: "username")
  iex> string2 = Cased.Sensitive.String.new("text", label: "email")
  iex> Cased.Sensitive.String.equal?(string1, string2)
  false
  ```
  """
  @spec equal?(string1 :: t(), string2 :: t()) :: boolean()
  def equal?(string1, string2) do
    string1.data == string2.data && string1.label == string2.label
  end

  @spec to_range(string :: t(), key :: String.t()) :: Cased.Sensitive.Range.t()
  def to_range(string, key) do
    %Cased.Sensitive.Range{
      label: string.label,
      key: key,
      begin_offset: 0,
      end_offset: byte_size(string.data)
    }
  end
end
