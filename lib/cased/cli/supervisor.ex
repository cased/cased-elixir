defmodule Cased.CLI.Supervisor do
  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(args) do
    Cased.CLI.Runner.autorun(Keyword.get(args, :run_via_iex, false))

    children = [
      {Cased.CLI.Runner, args},
      {Cased.CLI.Config, args},
      Cased.CLI.Identity,
      Cased.CLI.Session,
      Cased.CLI.Recorder
    ]

    opts = [strategy: :one_for_one, name: __MODULE__]
    Supervisor.init(children, opts)
  end
end
