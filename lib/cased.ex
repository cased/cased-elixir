defmodule Cased do
  @moduledoc """
  Documentation for Cased.
  """

  import Norm

  defmodule ConfigurationError do
    @moduledoc false
    use Cased.Error, "invalid configuration options were provided"
  end

  defmodule RequestError do
    @moduledoc false
    use Cased.Error, "invalid request configuration"
  end

  defmodule ResponseError do
    @moduledoc false
    defexception message: "invalid response", details: nil, response: nil

    @type t :: %__MODULE__{
            message: String.t(),
            response: nil | Mojito.response(),
            details: nil | any()
          }
  end

  @type publish_opts :: [publish_opt()]

  @type publish_opt ::
          {:publisher, GenServer.server()}
          | {:handlers, [Cased.Sensitive.Handler.t() | Cased.Sensitive.Handler.spec()]}

  @default_publish_opts [
    publisher: Cased.Publisher.HTTP,
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
      {:ok, %{publisher: publisher, handlers: handlers}} ->
        Cased.Sensitive.Processor.process(audit_event, handlers: handlers)
        |> do_publish(publisher)

      {:error, details} ->
        {:error, %ConfigurationError{details: details}}
    end
  end

  @spec do_publish(data :: term(), publisher :: GenServer.server()) ::
          :ok | {:error, Jason.EncodeError.t() | Exception.t()}
  defp do_publish(data, publisher) do
    case Jason.encode(data) do
      {:ok, json} ->
        GenServer.cast(publisher, {:publish, json})

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
      # Effectively GenServer.server()
      publisher: spec(is_pid() or is_atom() or is_tuple()),
      # TODO: Use is_struct() vs is_map(), post-Elixir v1.10
      handlers: coll_of(spec(is_tuple() or is_map()))
    })
    |> selection()
  end
end
