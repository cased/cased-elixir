defmodule Cased do
  @moduledoc """
  Documentation for Cased.
  """

  import Norm

  defmodule ConfigurationError do
    @moduledoc false
    defexception message: "invalid configuration", details: nil

    @type t :: %__MODULE__{
            message: String.t(),
            details: nil | any()
          }

    def message(exc) do
      "#{exc.message}\ndetails #{inspect(exc.details)}"
    end
  end

  defmodule RequestError do
    @moduledoc false
    defexception message: "invalid request configuration", details: nil

    @type t :: %__MODULE__{
            message: String.t(),
            details: nil | any()
          }

    def message(exc) do
      "#{exc.message}\ndetails #{inspect(exc.details)}"
    end
  end

  defmodule ResponseError do
    @moduledoc false
    defexception message: "invalid response", details: nil, response: nil

    @type t :: %__MODULE__{
            message: String.t(),
            details: nil | any(),
            response: nil | Mojito.response()
          }

    def message(%{response: nil} = exc) do
      "#{exc.message}\ndetails #{inspect(exc.details)}\nstatus code: (none)"
    end

    def message(exc) do
      "#{exc.message}\ndetails #{inspect(exc.details)}\nstatus code: #{exc.status_code}"
    end
  end

  @type publish_opts :: [publish_opt()]

  @type publish_opt ::
          {:publishers, [GenServer.server()]}
          | {:handlers, [Cased.Sensitive.Handler.t() | Cased.Sensitive.Handler.spec()]}

  @default_publish_opts [
    publishers: [Cased.Publisher.HTTP],
    handlers: []
  ]

  @doc """
  Publish an audit event to Cased.
  """
  @spec publish(audit_event :: map(), opts :: publish_opts()) ::
          :ok | {:error, Jason.EncodeError.t() | Exception.t()}
  def publish(audit_event, opts \\ []) do
    opts =
      @default_publish_opts
      |> Keyword.merge(opts)

    audit_event =
      audit_event
      |> Map.merge(Cased.Context.to_map())

    case validate_publish_opts(opts) do
      {:ok, %{publishers: publishers, handlers: handlers}} ->
        Cased.Sensitive.Processor.process(audit_event, handlers: handlers)
        |> do_publish(publishers)

      {:error, details} ->
        {:error, %ConfigurationError{details: details}}
    end
  end

  @spec do_publish(data :: term(), publishers :: [GenServer.server()]) ::
          :ok | {:error, Jason.EncodeError.t() | Exception.t()}
  defp do_publish(data, publishers) do
    case Jason.encode(data) do
      {:ok, json} ->
        for publisher <- publishers do
          GenServer.cast(publisher, {:publish, json})
        end

        :ok

      other ->
        other
    end
  end

  @doc """
  Publish an audit event to Cased, raising an exception in the event of failure.
  """
  @spec publish!(data :: term(), opts :: publish_opts()) :: :ok | no_return()
  def publish!(data, opts \\ []) do
    case publish(data, opts) do
      :ok ->
        :ok

      {:error, err} ->
        raise err
    end
  end

  defp validate_publish_opts(opts) do
    opts
    |> Map.new()
    |> conform(publish_opts_schema())
  end

  defp publish_opts_schema() do
    schema(%{
      # Effectively [GenServer.server()]
      publishers: coll_of(spec(is_pid() or is_atom() or is_tuple())),
      # TODO: Use is_struct() vs is_map(), post-Elixir v1.10
      handlers: coll_of(spec(is_tuple() or is_map()))
    })
    |> selection()
  end
end
