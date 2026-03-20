defmodule EctoShorts.MixProject do
  use Mix.Project

  def project do
    [
      app: :ecto_shorts,
      version: "3.0.0",
      elixir: "~> 1.15",
      start_permanent: Mix.env() === :prod,
      aliases: aliases(),
      deps: deps(),
      description: "Build and compose Ecto queries with a data-driven API",
      docs: docs(),
      package: package(),
      compilers: Mix.compilers(),
      elixirc_paths: elixirc_paths(Mix.env()),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        doctor: :test,
        coverage: :test,
        dialyzer: :test,
        "coveralls.cobertura": :test,
        "coveralls.detail": :test,
        "coveralls.html": :test,
        "coveralls.json": :test,
        "coveralls.lcov": :test,
        "coveralls.post": :test
      ],
      dialyzer: [
        plt_add_apps: [:ex_unit, :mix],
        plt_local_path: "dialyzer",
        plt_core_path: "dialyzer",
        plt_ignore_apps: [],
        list_unused_filters: true,
        ignore_warnings: ".dialyzer-ignore.exs",
        flags: [:unmatched_returns, :no_improper_lists]
      ]
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
      # documentation
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false, warn_if_outdated: true},
      # code quality
      {:credo, ">= 0.0.0", only: [:dev, :test], runtime: false},
      {:blitz_credo_checks, ">= 0.0.0", only: [:dev, :test], runtime: false},
      {:dialyxir, ">= 0.0.0", only: [:dev, :test], runtime: false},
      {:excoveralls, ">= 0.0.0", only: :test},
      # ecto
      {:ecto, ">= 3.0.0"},
      {:ecto_sql, ">= 3.0.0"},
      {:postgrex, ">= 0.0.0", optional: true},
      # testing
      {:factory_ex, ">= 0.0.0", only: :test},
      # utility
      {:error_message, ">= 0.0.0"}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp package do
    [
      maintainers: ["Mika Kalathil", "Kurt Hogarth"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/MikaAK/ecto_shorts"},
      files: ~w(mix.exs README.md CHANGELOG.md lib config)
    ]
  end

  defp docs do
    [
      main: "EctoShorts",
      source_url: "https://github.com/MikaAK/ecto_shorts",
      groups_for_modules: [
        Core: [
          EctoShorts.Actions,
          EctoShorts.CommonChanges,
          EctoShorts.CommonFilters,
          EctoShorts.CommonParams,
          EctoShorts.Actions.Source
        ],
        Actions: [
          EctoShorts.Actions.Batch,
          EctoShorts.Actions.Multi,
          EctoShorts.Actions.Error
        ],
        Testing: [
          EctoShorts.Testing
        ],
        "Dynamic Expressions": [
          EctoShorts.DynamicBuilders,
          EctoShorts.Dynamic,
          EctoShorts.Adapter.DynamicBuilder,
          EctoShorts.DynamicBuilders.Postgres
        ],
        "Schema & Query Introspection": [
          EctoShorts.CommonQuery,
          EctoShorts.CommonSchema,
          EctoShorts.SchemaHelpers
        ],
        "CommonParams API": [
          EctoShorts.CommonParams.Placeholders,
          EctoShorts.CommonParams.Timestamps
        ],
        "Configuration & Utilities": [
          EctoShorts.Config,
          EctoShorts.Logger,
          EctoShorts.Adapter.QueryProvider,
          EctoShorts.Utils
        ]
      ]
    ]
  end

  defp aliases do
    [
      setup: ["deps.get", "ecto.setup"],
      "ecto.setup": ["ecto.create", "ecto.migrate"],
      "ecto.reset": ["ecto.drop", "ecto.setup"]
    ]
  end
end
