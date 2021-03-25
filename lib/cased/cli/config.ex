defmodule Cased.CLI.Config do
  @moduledoc false
  use Agent

  # Read API
  def started?() do
    Process.whereis(__MODULE__) != nil
  end

  def configuration() do
    Agent.get(__MODULE__, & &1)
  end

  def get(key) do
    Agent.get(__MODULE__, &Map.get(&1, key))
  end

  def use_credentials? do
    not is_nil(Cased.CLI.Config.get(:token))
  end

  def configure(opts) do
    Agent.update(__MODULE__, __MODULE__, :handle_configure, [opts])
  end

  # Agent API
  def start(opts \\ %{}) do
    case Process.whereis(__MODULE__) do
      nil ->
        Agent.start_link(__MODULE__, :handle_init, [opts], name: __MODULE__)

      _ ->
        configure(opts)
    end
  end

  def handle_init(opts) do
    opts
    |> load_user_token(:env)
    |> load_user_token(:credentails)
    |> load_app_key(:env)
  end

  def handle_configure(config, opts) do
    Map.merge(config, opts)
  end

  defp load_app_key(%{app_key: key} = opts, _) when is_binary(key) do
    opts
  end

  defp load_app_key(opts, :env) do
    case Application.get_env(:cased, :guard_application_key) do
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
    case Application.get_env(:cased, :guard_user_token) do
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
