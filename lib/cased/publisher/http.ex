defmodule Cased.Publisher.HTTP do
  use GenServer

  import Norm
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

  @doc """
  Start and link a publisher process.
  """
  @spec start_link(opts :: init_opts()) :: GenServer.on_start()
  def start_link(opts) do
    opts =
      @default_init_opts
      |> Keyword.merge(opts)

    case validate_init_opts(opts) do
      {:ok, opts} ->
        GenServer.start_link(__MODULE__, opts, name: __MODULE__)

      {:error, details} ->
        {:error,
         %Cased.ConfigurationError{message: "invalid publisher configuration", details: details}}
    end
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
      opts
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
        Logger.info(
          "Received HTTP #{response.status_code} response from Cased with body: #{
            inspect(response.body)
          }"
        )

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
    headers = Cased.Headers.create(opts[:key])

    opts
    |> Keyword.drop([:key])
    |> Keyword.put(:headers, headers)
    |> Map.new()
  end

  # Validate the options to `init/1`.
  @spec validate_init_opts(opts :: init_opts()) :: {:ok, init_opts()} | {:error, [map()]}
  defp validate_init_opts(opts) do
    case conform(Map.new(opts), init_opts_schema()) do
      {:ok, _} ->
        {:ok, opts}

      other ->
        other
    end
  end

  # Schema for options to `init/1`. Used by `validate_init_opts/1`.
  @spec init_opts_schema() :: struct()
  defp init_opts_schema do
    schema(%{
      key: spec(is_binary() and (&Regex.match?(~r/\Apublish_(live|test)_\S+\Z/, &1))),
      timeout: spec(&(&1 == :infinity || (is_integer(&1) && &1 > 0))),
      silence: spec(is_boolean()),
      url: spec(is_binary() and (&(!is_nil(URI.parse(&1).host))))
    })
    |> selection()
  end
end
