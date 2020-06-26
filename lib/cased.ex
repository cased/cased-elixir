defmodule Cased do
  @moduledoc """
  Documentation for Cased.
  """

  @spec publish(publisher :: GenServer.server(), data :: term()) :: :ok | {:error, Jason.EncodeError.t() | Exception.t()}
  def publish(publisher, data) do
    case Jason.encode(data) do
      {:ok, json} ->
        GenServer.cast(publisher, {:publish, json})

      other ->
        other
    end
  end

  @spec publish!(publisher :: GenServer.server(), data :: term()) :: :ok | no_return()
  def publish!(publisher, data) do
    case publish(publisher, data) do
      :ok ->
        :ok

      {:error, err} ->
        raise err
    end
  end
end
