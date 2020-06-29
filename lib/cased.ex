defmodule Cased do
  @moduledoc """
  Documentation for Cased.
  """

  defmodule ConfigurationError do
    use Cased.Error, "invalid configuration options were provided"
  end

  defmodule RequestError do
    @moduledoc """
    Models an error that occurred during request configuration.
    """
    use Cased.Error, "invalid request configuration"
  end

  defmodule ResponseError do
    @moduledoc """
    Models an error that occurred while retrieving a response or processing it.
    """
    defexception message: "invalid response", details: nil, response: nil
    import Cased.Error

    @type t :: %__MODULE__{
            message: String.t(),
            response: nil | Mojito.response(),
            details: nil | any()
          }
  end

  @spec publish(data :: term(), publisher :: GenServer.server()) ::
          :ok | {:error, Jason.EncodeError.t() | Exception.t()}
  def publish(data, publisher \\ Cased.Publisher.HTTP) do
    case Jason.encode(data) do
      {:ok, json} ->
        GenServer.cast(publisher, {:publish, json})

      other ->
        other
    end
  end

  @spec publish!(data :: term(), publisher :: GenServer.server()) :: :ok | no_return()
  def publish!(data, publisher \\ Cased.Publisher.HTTP) do
    case publish(data, publisher) do
      :ok ->
        :ok

      {:error, err} ->
        raise err
    end
  end
end
