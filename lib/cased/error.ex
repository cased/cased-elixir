defmodule Cased.Error do
  @moduledoc false

  defmacro __using__(default_message) do
    quote do
      defexception message: unquote(default_message), details: nil

      @type t :: %__MODULE__{
              message: String.t(),
              details: any()
            }

      import unquote(__MODULE__)
    end
  end

  def message(exc) do
    "#{exc.__struct__}: #{exc.message} (details: #{inspect(exc.details)})"
  end
end
