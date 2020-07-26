defmodule Cased.Key do
  @moduledoc false

  import Norm

  @doc false
  @spec pattern(
          prefix :: atom(),
          client :: Cased.Client.t()
        ) :: Norm.Core.Spec.Or.t()
  def pattern(:environment, client) do
    spec(
      (is_nil() and fn _ -> !!client.environment_key end) or
        (is_binary() and (&Regex.match?(~r/\Aenvironment_(live|test)_\S+\Z/, &1)))
    )
  end
end
