defmodule Cased.Client do
  import Norm

  @default_audit_trail :default

  defstruct keys: %{},
            url: "https://api.cased.com",
            timeout: 15_000

  @type t :: %__MODULE__{
          keys: %{atom() => String.t()},
          url: String.t(),
          timeout: pos_integer() | :infinity
        }

  ##
  # Client creation

  @type create_opts :: [create_opt()]

  @type create_opt ::
          {:keys, keyword()}
          | {:key, String.t()}
          | {:url, String.t()}
          | {:timeout, pos_integer() | :infinity}

  @spec create(opts :: create_opts()) :: {:ok, t()} | {:error, any()}
  def create(opts \\ []) do
    simple_opts = Keyword.take(opts, [:url, :timeout])

    struct!(__MODULE__, simple_opts)
    |> Map.put(:keys, parse_keys(opts))
    |> validate()
  end

  @spec create!(opts :: create_opts()) :: t() | no_return()
  def create!(opts) do
    case create(opts) do
      {:ok, client} ->
        client

      {:error, exc} ->
        raise exc
    end
  end

  ##
  # Utilities

  @spec parse_keys(opts :: keyword()) :: map()
  @doc false
  def parse_keys(opts) do
    keys =
      opts
      |> Keyword.get(:keys, [])
      |> Map.new()

    case opts[:key] do
      nil ->
        keys

      value ->
        Map.put(keys, :default, value)
    end
  end

  # Validate a client against a schema to make sure that it's configured correctly.
  @spec validate(client :: t()) ::
          {:ok, valid_client :: t()} | {:error, Cased.ConfigurationError.t()}
  defp validate(client) do
    case conform(client, client_schema()) do
      {:error, details} ->
        {:error,
         %Cased.ConfigurationError{
           message: "invalid client configuration",
           details: details
         }}

      other ->
        other
    end
  end

  # Options schema for client creation.
  defp client_schema do
    schema(%{
      keys:
        coll_of(
          {spec(is_atom),
           spec(is_binary and (&Regex.match?(~r/\Apolicy_(live|test)_\S+\Z/, &1)))},
          min_count: 1
        ),
      timeout: spec(&(&1 == :infinity || (is_integer(&1) && &1 > 0))),
      url: spec(is_binary() and (&(!is_nil(URI.parse(&1).host))))
    })
    |> selection()
  end
end
