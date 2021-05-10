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
  def user_agent_header do
    vsn =
      case :application.get_key(:cased, :vsn) do
        {:ok, version} -> version
        _ -> '0.1.0'
      end

    {"user-agent", "cased-elixir/v" <> List.to_string(vsn)}
  end

  @type pagination_info ::
          nil | %{first: non_neg_integer(), last: non_neg_integer(), self: non_neg_integer()}

  @spec get_pagination_info(response :: Mojito.response()) :: pagination_info()
  def get_pagination_info(response) do
    response.headers
    |> Mojito.Headers.get("link")
    |> parse_pagination_info()
  end

  @link_pattern ~r/<.+?page=(\d+).*?>;\s+rel="(?<rel>\S+?)"/

  @doc false
  @spec parse_pagination_info(value :: nil | String.t()) :: pagination_info()
  def parse_pagination_info(nil), do: nil

  def parse_pagination_info(value) do
    Regex.scan(@link_pattern, value)
    |> Enum.map(fn
      [_, page, rel] ->
        {
          String.to_existing_atom(rel),
          String.to_integer(page)
        }
    end)
    |> Map.new()
  end
end
