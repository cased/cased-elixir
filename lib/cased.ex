defmodule Cased do
  @moduledoc """
  Documentation for Cased.
  """

  defmodule ConfigurationError do
    defexception message: "invalid configuration options were provided", details: nil
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
