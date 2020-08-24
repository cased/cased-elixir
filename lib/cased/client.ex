defmodule Cased.Client do
  @moduledoc """
  A client for the Cased API.
  """
  import Norm

  defstruct keys: %{},
            environment_key: nil,
            url: "https://api.cased.com",
            timeout: 15_000

  @type t :: %__MODULE__{
          keys: %{atom() => String.t()},
          environment_key: nil | String.t(),
          url: String.t(),
          timeout: pos_integer() | :infinity
        }

  ##
  # Client creation

  @type create_opts :: [create_opt()]

  @type create_opt ::
          {:keys, keyword()}
          | {:key, String.t()}
          | {:environment_key, String.t()}
          | {:url, String.t()}
          | {:timeout, pos_integer() | :infinity}

  @doc """
  Create a Cased client.

  ## Examples

  Create a client with the policy key for your `default` audit trail:

  ```
  iex> {:ok, client} = Cased.Client.create(key: "policy_live_...")
  ```

  Create a client key with policy keys for specific audit trails:

  ```elixir
  iex> {:ok, client} = Cased.Client.create(
  ...>   keys: [
  ...>     default: "policy_live_...",
  ...>     users: "policy_live_users..."
  ...>   ]
  ...> )
  ```

  If you plan on using the API to interact with policies themselves, you need to provide an `:environment_key`, for example:

  ```elixir
  iex> {:ok, client} = Cased.Client.create(
  ...>   key: "policy_live_...",
  ...>   environment_key: "environment_live_..."
  ...> )
  )

  Clients can be configured using runtime environment variables, your application
  configuration, hardcoded values, or any combination you choose.

  Just using runtime environment variable:

  ```
  iex> {:ok, client} = Cased.Client.create(
  ...>   key: System.fetch_env!("CASED_POLICY_KEY")
  ...> )
  ```

  Just using application configuration:

  ```
  iex> {:ok, client} = Cased.Client.create(
  ...>   key: Application.fetch_env!(:your_app, :cased_policy_key)
  ...> )
  ```

  Either/or:

  ```
  iex> {:ok, client} = Cased.Client.create!
  ...>   (key: System.get_env("CASED_POLICY_KEY") || Application.fetch_env!(:your_app, :cased_policy_key)
  ...> )
  ```

  In the event your client is misconfigured, you'll get a `Cased.ConfigurationError` exception struct instead:

  Not providing required options:

  ```
  iex> {:error, %Cased.ConfigurationError{}} = Cased.Client.create()
  ```

  You can also use `Cased.Client.create!/1` if you know you're passing the correct configuration options (otherwise it raises a `Cased.ConfigurationError` exception):

  ```
  iex> client = Cased.Client.create!(key: "policy_live_...")
  ```

  To simplify using clients across your application, consider writing a centralized function to handle constructing them:

  ```
  defmodule YourApp do

    # Rest of contents ...

    def cased_client do
      default_policy_key = System.get_env("CASED_POLICY_KEY")
        || Application.fetch_env!(:your_app, :cased_policy_key)
      Cased.Client.create!(key: default_policy_key)
    end
  end
  ```

  For reuse, consider caching your client structs in `GenServer` state, ETS, or another Elixir caching mechanism.

  """
  @spec create(opts :: create_opts()) :: {:ok, t()} | {:error, any()}
  def create(opts \\ []) do
    simple_opts = Keyword.take(opts, [:environment_key, :url, :timeout])

    struct!(__MODULE__, simple_opts)
    |> Map.put(:keys, parse_keys(opts))
    |> validate()
  end

  @doc """
  Create a client or raise an exception.
  """
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
          {spec(is_atom), spec(is_binary and (&Regex.match?(~r/\Apolicy_(live|test)_\S+\Z/, &1)))}
        ),
      environment_key:
        spec(is_nil or (is_binary and (&Regex.match?(~r/\Aenvironment_(live|test)_\S+\Z/, &1)))),
      timeout: spec(&(&1 == :infinity || (is_integer(&1) && &1 > 0))),
      url: spec(is_binary() and (&(!is_nil(URI.parse(&1).host))))
    })
    |> selection()
  end
end
