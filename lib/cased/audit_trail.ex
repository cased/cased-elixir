defmodule Cased.AuditTrail do
  @moduledoc """
  Data modeling a Cased audit trail.
  """

  @enforce_keys [:id, :name]
  defstruct [:id, :name]

  @type t :: %__MODULE__{
          id: nil | String.t(),
          name: String.t()
        }

  @doc false
  @spec from_json(String.t() | map()) :: t()
  def from_json(name) when is_binary(name) do
    %__MODULE__{
      # id not given
      id: nil,
      name: name
    }
  end

  def from_json(json) do
    %__MODULE__{
      id: json["id"],
      name: json["name"]
    }
  end
end
