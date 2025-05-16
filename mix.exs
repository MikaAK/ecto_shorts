defmodule EctoShorts.MixProject do
  use Mix.Project

  def project do
    [
      app: :ecto_shorts,
      version: "2.5.0",
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "Helper tools for making ecto interactions more pleasant and shorter",
      docs: docs(),
      package: package(),
      elixirc_paths: elixirc_paths(Mix.env()),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        doctor: :test,
        coverage: :test,
        dialyzer: :test,
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
      {:credo, ">= 0.0.0", only: [:dev, :test]},
      {:excoveralls, ">= 0.0.0", only: [:dev, :test]},
      {:ex_doc, ">= 0.0.0", only: :dev},
      {:dialyxir, "~> 1.1", only: :test, runtime: false}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp package do
    [
      maintainers: ["Mika Kalathil"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/MikaAK/ecto_shorts"},
      files: ~w(mix.exs README.md CHANGELOG.md lib config)
    ]
  end

  defp docs do
    [
      main: "EctoShorts",
      source_url: "https://github.com/MikaAK/ecto_shorts",
      groups_for_docs: [
        group_for_function("Batch API"),
        group_for_function("Changeset API"),
        group_for_function("Filter API"),
        group_for_function("Multi API"),
        group_for_function("Schema API"),
        group_for_function("Query API"),
        group_for_function("Query Builder API"),
        group_for_function("Transaction API")
      ],
      groups_for_modules: [
        "Actions API": [
          EctoShorts.Actions.Error
        ],
        "Changeset API": [
          EctoShorts.CommonChanges
        ],
        "Dynamic Expression API": [
          EctoShorts.DynamicExpression,
          EctoShorts.DynamicExpressions,
          EctoShorts.DynamicExpressions.Postgres,
          EctoShorts.DynamicExpressions.Postgres.Array,
          EctoShorts.DynamicExpressions.Postgres.Field
        ],
        "Query API": [
          EctoShorts.CommonQuery,
          EctoShorts.CommonQueries,
          EctoShorts.CommonQueryAPI
        ],
        "Query Builder API": [
          EctoShorts.QueryBuilder,
          EctoShorts.QueryBuilders.Common,
          EctoShorts.QueryBuilders.Schema
        ],
        "Schema API": [
          EctoShorts.CommonParams,
          EctoShorts.CommonSchemas,
          EctoShorts.SchemaHelpers
        ],
        "Testing API": [
          EctoShorts.Testing
        ],
        "Utility API": [
          EctoShorts.Utils
        ]
      ]
    ]
  end

  defp group_for_function(group), do: {String.to_atom(group), &(&1[:group] == group)}
end
