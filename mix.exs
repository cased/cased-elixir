defmodule Cased.MixProject do
  use Mix.Project

  def project do
    [
      app: :cased,
      version: "1.0.0",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      docs: [
        main: "readme",
        logo: "priv/images/cased.png",
        extras: ["README.md"]
      ],
      dialyzer: dialyzer(),
      elixirc_paths: elixirc_paths(Mix.env())
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_doc, "~> 0.22", only: :dev, runtime: false},
      {:mojito, "~> 0.7.3"},
      {:jason, "~> 1.2.1"},
      {:bypass, "~> 2.0", only: :test},
      {:dialyxir, "~> 1.0", only: [:dev], runtime: false},
      {:norm, "~> 0.12"},
      {:plug, "~> 1.10.3"},
      {:deep_merge, "~> 1.0.0"}
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
    ]
  end

  defp dialyzer() do
    [
      plt_add_apps: [:mix, :ex_unit],
      check_plt: true
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp package do
    [
      description:
        "Cased provides user and employee activity audit trails to companies that need to monitor access to information or demonstrate regulatory compliance.",
      files: [
        "lib",
        "mix.exs",
        "README.md",
        ".formatter.exs"
      ],
      licenses: ["MIT"],
      links: %{
        Website: "https://cased.com",
        GitHub: "https://github.com/cased/cased-elixir",
        Changelog: "https://github.com/cased/cased-elixir/releases"
      }
    ]
  end
end
