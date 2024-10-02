defmodule EctoShorts.MixProject do
  use Mix.Project

  def project do
    [
      app: :ecto_shorts,
      version: "2.4.0",
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "Helper tools for making ecto interactions more pleasant and shorter",
      docs: docs(),
      package: package(),
      aliases: aliases(),
      elixirc_paths: elixirc_paths(Mix.env()),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        credo: :test,
        doctor: :test,
        coverage: :test,
        dialyzer: :test,
        "ecto.drop": :test,
        "ecto.migrate": :test,
        "ecto.create": :test,
        "ecto.setup": :test,
        "coveralls.lcov": :test,
        "coveralls.json": :test,
        "coveralls.html": :test
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
      {:ecto, "~> 3.0"},
      {:ecto_sql, "~> 3.10"},
      {:postgrex, ">= 0.0.0", optional: true},

      {:error_message, "~> 0.1"},

      {:excoveralls, ">= 0.0.0", only: [:dev, :test], runtime: false},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:dialyxir, "~> 1.1", only: :test, runtime: false},
      {:credo, ">= 0.0.0", only: [:dev, :test], runtime: false},
      {:blitz_credo_checks, "~> 0.1", only: [:dev, :test], runtime: false}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  def aliases do
    [
      "ecto.setup": ["ecto.drop", "ecto.create", "ecto.migrate"]
    ]
  end

  defp package do
    [
      maintainers: ["Mika Kalathil"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/MikaAK/ecto_shorts"},
      files: ~w(mix.exs README.md CHANGELOG.md lib config docs)
    ]
  end

  defp docs do
    [
      main: "EctoShorts",
      source_url: "https://github.com/MikaAK/ecto_shorts",
      extras: [
        "README.md",
        "CHANGELOG.md",
        # Tutorials (Learning-oriented)
        "docs/tutorials/index.md",
        "docs/tutorials/getting-started.md",
        "docs/tutorials/complete-application.md",
        # How-to guides (Problem-oriented)
        "docs/how-to/index.md",
        "docs/how-to/filtering-data.md",
        "docs/how-to/managing-associations.md",
        "docs/how-to/crud-operations.md",
        "docs/how-to/custom-filters.md",
        "docs/how-to/configuration.md",
        "docs/how-to/graphql-integration.md",
        # Explanation (Understanding-oriented)
        "docs/explanation/index.md",
        "docs/explanation/why-ecto-shorts.md",
        "docs/explanation/architecture.md",
        "docs/explanation/comparison.md",
        "docs/explanation/best-practices.md",

        # Reference (Technical-oriented)
        "docs/reference/index.md",
        "docs/reference/actions.md",
        "docs/reference/api-reference.md",
        "docs/reference/filter-options.md"
      ],
      groups_for_extras: [
        "Tutorials": ~r{docs/tutorials/},
        "How-to Guides": ~r{docs/how-to/},
        "Reference": ~r{docs/reference/},
        "Explanation": ~r{docs/explanation/}
      ],
      groups_for_modules: [
        "Main Modules": [
          EctoShorts.Actions,
          EctoShorts.CommonChanges
        ],

        "Support Modules": [
          EctoShorts.CommonFilters,
          EctoShorts.SchemaHelpers
        ],

        "Misc Modules": [
          EctoShorts.Actions.Error
        ],

        "Query Builder Modules": [
          EctoShorts.QueryBuilder,
          EctoShorts.QueryBuilder.Schema,
          EctoShorts.QueryBuilder.Common
        ]
      ]
    ]
  end
end
