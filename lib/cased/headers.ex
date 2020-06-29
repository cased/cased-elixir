defmodule Cased.Headers do
  @moduledoc false

  @static_headers [{"content-type", "application/json"}]

  @doc false
  @spec create(key :: String.t()) :: Mojito.headers()
  def create(key) do
    [
      authorization_header(key),
      user_agent_header()
    ] ++ @static_headers
  end

  @doc false
  @spec authorization_header(key :: String.t()) :: Mojito.header()
  def authorization_header(key) do
    {"authorization", "Bearer " <> key}
  end

  @doc false
  @spec user_agent_header() :: Mojito.header()
  def user_agent_header() do
    {:ok, vsn} = :application.get_key(:cased, :vsn)

    {"user-agent", "cased-elixir/v" <> List.to_string(vsn)}
  end
end
