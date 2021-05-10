defmodule Cased.CLI.Supervisor do
  @moduledoc false

  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @spec init(keyword()) :: no_return
  def init(args) do
    cased_children = [
      {Cased.CLI.Runner, args},
      {Cased.CLI.Config, args},
      Cased.CLI.Identity,
      Cased.CLI.Session,
      Cased.CLI.Recorder
    ]

    children =
      case :init.get_argument(:hidden) do
        {:ok, _} -> []
        _ -> cased_children
      end

    opts = [strategy: :one_for_one, name: __MODULE__]
    Supervisor.init(children, opts)
  end
end
