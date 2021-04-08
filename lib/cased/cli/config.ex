defmodule Cased.CLI.Config do
  @moduledoc """
  Cased CLI Configuration

  All configuration items can be set via Environment variables _or_ via `Application` config
  """

  use Agent

  @api_endpoint "https://api.cased.com"
  @credentials_keys [:token, :app_key]
  @config_keys [:clear_screen, :api_endpoint, :autorun]

  @doc """
  **Required**

  Configure your application key.

  Application key can be configured in two ways:
  * Environment variable: `GUARD_APPLICATION_KEY=guard_application_xxxx`
  * Application config: `config :cased, app_key: "guard_application_xxxx"`
  """
  @spec app_key() :: String.t()
  def app_key, do: get(:app_key, "")

  @doc """
  **Optional**

  User token can be configured in two ways:
  * Environment variable: `GUARD_USER_TOKEN=user_xxxxxxxxx`
  * Application config: `config :cased, token: "user_xxxxxxx"`
  """
  @spec token() :: String.t() | nil
  def token, do: get(:token, nil)

  @doc false
  @spec clear_screen() :: boolean
  def clear_screen, do: get(:clear_screen, false)

  @doc "API endpoind url"
  @spec api_endpoint() :: String.t()
  def api_endpoint, do: get(:api_endpoint, @api_endpoint)

  @doc """
  Turn off\on autorun Cased session.

  Autorun can be configured in two ways:
  * Environment variables: `autorun=true`
  * Application config: `config :cased, autorun: true`
  """
  @spec autorun() :: boolean()
  def autorun, do: get(:autorun, false)

  @doc "Returns all configurations"
  @spec configuration() :: map()
  def configuration() do
    Agent.get(__MODULE__, & &1)
  end

  @spec get(atom(), any()) :: any()
  def get(key, default \\ nil) do
    Agent.get(__MODULE__, &Map.get(&1, key, default))
  end

  @spec use_credentials?() :: boolean()
  def use_credentials?, do: not is_nil(get(:token))

  @doc "Validates app_key"
  @spec valid_app_key() :: boolean()
  def valid_app_key, do: valid_app_key(get(:app_key))
  def valid_app_key("guard_application" <> _key), do: true
  def valid_app_key(_key), do: false

  @doc false
  @spec configure(map()) :: map()
  def configure(opts) do
    Agent.update(__MODULE__, __MODULE__, :handle_configure, [opts])
  end

  # Agent API
  def start(opts \\ %{}) do
    case Process.whereis(__MODULE__) do
      nil -> start_link(opts)
      _ -> configure(opts)
    end
  end

  def start_link(args) do
    Agent.start_link(
      __MODULE__,
      :handle_init,
      [Map.take(Map.new(args), @credentials_keys ++ @config_keys)],
      name: __MODULE__
    )
  end

  def handle_init(opts) do
    config =
      opts
      |> load_user_token(:env)
      |> load_user_token(:credentails)
      |> load_app_key(:env)
      |> load_env()
      |> load_default()

    Cased.CLI.Runner.started(:config)
    config
  end

  def handle_configure(config, opts) do
    Map.merge(config, opts)
  end

  defp load_env(opts) do
    Enum.reduce(@config_keys, opts, fn key, acc -> load_env(acc, key) end)
  end

  defp load_env(opts, key) do
    Application.get_env(:cased, key, System.get_env(Atom.to_string(key)))
    |> prepare_param
    |> case do
      nil -> opts
      value -> Map.put_new(opts, key, value)
    end
  end

  defp load_default(opts) do
    opts
    |> Map.put_new(:api_endpoint, @api_endpoint)
    |> Map.put_new(:clear_screen, false)
  end

  defp load_app_key(%{app_key: key} = opts, _) when is_binary(key) do
    opts
  end

  defp load_app_key(opts, :env) do
    Application.get_env(:cased, :guard_application_key, System.get_env("GUARD_APPLICATION_KEY"))
    |> case do
      key when is_binary(key) ->
        Map.merge(opts, %{app_key: key})

      _ ->
        opts
    end
  end

  defp load_user_token(%{token: token} = opts, _) when is_binary(token) do
    opts
  end

  defp load_user_token(opts, :env) do
    Application.get_env(:cased, :guard_user_token, System.get_env("GUARD_USER_TOKEN"))
    |> case do
      token when is_binary(token) ->
        Map.merge(opts, %{token: token})

      _ ->
        opts
    end
  end

  defp load_user_token(opts, :credentails) do
    case File.read(credentials_path()) do
      {:ok, token} -> Map.merge(opts, %{token: String.trim(token)})
      _ -> opts
    end
  end

  defp credentials_path do
    Path.expand(Path.join(["~", ".cguard", "credentials"]))
  end

  defp prepare_param(value) when is_boolean(value), do: value

  defp prepare_param(value) when is_binary(value) do
    case String.trim(value) do
      val when val in ["true", "1", "t"] -> true
      val when val in ["false", "0", "f"] -> false
      val -> val
    end
  end

  defp prepare_param(value), do: value
end
