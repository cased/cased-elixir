defmodule Cased.Publisher.HTTP do
  use GenServer
  require Logger

  @typedoc """
  Available options to initialize the publisher.
  """
  @type init_opts :: [init_opt()]
  @type init_opt ::
      {:key, String.t()}
    | {:url, String.t()}
    | {:silence, boolean()}
    | {:timeout, pos_integer() | :infinity}

  @default_init_opts [
    url: "https://publish.cased.com",
    timeout: 15_000,
    silence: false
  ]

  @type config :: %{
    url: String.t(),
    headers: Mojito.headers(),
    silence: boolean(),
    timeout: pos_integer() | :infinity
  }

  @static_headers [{"content-type", "application/json"}]

  @doc """
  Start and link a publisher process.
  """
  @spec start_link(opts :: init_opts()) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  ##
  # Callbacks

  @doc """
  Build publisher configuration.
  """
  @spec init(opts :: init_opts()) :: {:ok, any()}
  @impl true
  def init(opts) do
    config =
      @default_init_opts
      |> Keyword.merge(opts)
      |> parse_config()

    {:ok, config}
  end

  @impl true
  @spec handle_cast({:publish, json :: String.t()}, config()) :: {:noreply, config()}
  def handle_cast({:publish, _json}, %{silence: true} = config) do
    Logger.debug("Silenced Cased publish")
    {:noreply, config}
  end
  def handle_cast({:publish, json}, config) do
    case Mojito.post(config.url, config.headers, json, timeout: config.timeout) do
      {:ok, response} ->
        Logger.info("Received HTTP #{response.status_code} response from Cased with body: #{inspect(response.body)}")

      {:error, err} ->
        Logger.warn("Error publishing to Cased: #{inspect(err)}")
    end

    {:noreply, config}
  end

  ##
  # Utilities

  # Parse the raw `init/1` options to the configuration.
  @spec parse_config(opts :: init_opts()) :: config()
  defp parse_config(opts) do
    headers = [
      authorization_header(opts[:key]),
      user_agent_header()
    ] ++ @static_headers

    opts
    |> Keyword.drop([:key])
    |> Keyword.put(:headers, headers)
    |> Map.new
  end

  # Build the authorization header
  @spec authorization_header(key :: String.t()) :: Mojito.header()
  defp authorization_header(key) do
    {"authorization", "Bearer " <> key}
  end

  # Build the user-agent header
  @spec user_agent_header() :: Mojito.header()
  defp user_agent_header() do
    {:ok, vsn} = :application.get_key(:cased, :vsn)

    {"user-agent", "cased-elixir/v" <> List.to_string(vsn)}
  end
end
