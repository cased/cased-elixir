defmodule Cased.CLI.Config do
  @moduledoc false
  use Agent
  @api_endpoint "https://api.cased.com"
  @keys [:token, :app_key, :run_via_iex, :clear_screen, :api_endpoint]

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
      [Map.take(Map.new(args), @keys)],
      name: __MODULE__
    )
  end

  def handle_init(opts) do
    config =
      opts
      |> load_user_token(:env)
      |> load_user_token(:credentails)
      |> load_app_key(:env)

    Cased.CLI.Runner.started(:config)
    config
  end

  def handle_configure(config, opts) do
    Map.merge(config, opts)
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
end
