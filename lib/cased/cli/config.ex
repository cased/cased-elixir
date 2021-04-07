defmodule Cased.CLI.Config do
  @moduledoc false
  use Agent
  @api_endpoint "https://api.cased.com"
  @credentials_keys [:token, :app_key]
  @config_keys [:clear_screen, :api_endpoint]

  # Read API
  def started?() do
    Process.whereis(__MODULE__) != nil
  end

  def configuration() do
    Agent.get(__MODULE__, & &1)
  end

  def get(key, default \\ nil) do
    Agent.get(__MODULE__, &Map.get(&1, key, default))
  end

  def use_credentials? do
    not is_nil(Cased.CLI.Config.get(:token))
  end

  def valid_app_key, do: valid_app_key(get(:app_key))
  def valid_app_key("guard_application" <> _key), do: true
  def valid_app_key(_key), do: false

  def clear_screen do
    get(:clear_screen, false)
  end

  def api_endpoint do
    get(:api_endpoint, @api_endpoint)
  end

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

  def credentials_path do
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
