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
      before_closing_body_tag: &before_closing_body_tag/1,
      extras: [
        "docs/getting-started.md",
        "docs/guides/filtering.md",
        "docs/guides/crud-actions.md",
        "docs/guides/associations-changes.md",
        "docs/guides/pagination-ordering.md",
        "docs/guides/bulk-and-transactions.md",
        "docs/guides/extending.md",
        "docs/reference/api-reference.md",
        "docs/reference/filter-keys.md",
        "docs/reference/configuration.md",
        "docs/explanation/architecture.md",
        "docs/explanation/filter-pipeline.md",
        "docs/testing-guide.md"
      ],
      groups_for_extras: [
        "Getting Started": ["docs/getting-started.md"],
        Guides: Path.wildcard("docs/guides/*.md"),
        Reference: Path.wildcard("docs/reference/*.md"),
        Explanation: Path.wildcard("docs/explanation/*.md")
      ],
      groups_for_modules: [
        Core: [
          EctoShorts.Actions,
          EctoShorts.CommonChanges,
          EctoShorts.CommonFilters,
          EctoShorts.CommonParams,
          EctoShorts.Actions.Source
        ],
        "Actions (internal)": [
          EctoShorts.Actions.Batch,
          EctoShorts.Actions.Bulk,
          EctoShorts.Actions.CRUD,
          EctoShorts.Actions.Multi,
          EctoShorts.Actions.Transaction,
          EctoShorts.Actions.Error
        ],
        Testing: [
          EctoShorts.Testing
        ],
        "Dynamic Expressions": [
          EctoShorts.DynamicBuilders,
          EctoShorts.DynamicBuilder,
          EctoShorts.DynamicBuilders.Postgres
        ],
        "Postgres Expressions": [
          EctoShorts.DynamicBuilders.Postgres.ArrayExpr,
          EctoShorts.DynamicBuilders.Postgres.CommonExpr,
          EctoShorts.DynamicBuilders.Postgres.FieldAccessors,
          EctoShorts.DynamicBuilders.Postgres.MapExpr,
          EctoShorts.DynamicBuilders.Postgres.ScalarExpr,
          EctoShorts.DynamicBuilders.Postgres.ScalarExpr.Aggregate,
          EctoShorts.DynamicBuilders.Postgres.ScalarExpr.Comparison,
          EctoShorts.DynamicBuilders.Postgres.ScalarExpr.Membership,
          EctoShorts.DynamicBuilders.Postgres.ScalarExpr.String,
          EctoShorts.DynamicBuilders.Postgres.ScalarExpr.StringTransform
        ],
        "Common Filters": [
          EctoShorts.CommonFilters.Builder,
          EctoShorts.CommonFilters.Predicate,
          EctoShorts.CommonFilters.PredicateBuilder,
          EctoShorts.CommonFilters.Distinct,
          EctoShorts.CommonFilters.Except,
          EctoShorts.CommonFilters.ExceptAll,
          EctoShorts.CommonFilters.GroupBy,
          EctoShorts.CommonFilters.Having,
          EctoShorts.CommonFilters.Intersect,
          EctoShorts.CommonFilters.IntersectAll,
          EctoShorts.CommonFilters.Join,
          EctoShorts.CommonFilters.Last,
          EctoShorts.CommonFilters.Limit,
          EctoShorts.CommonFilters.Lock,
          EctoShorts.CommonFilters.Offset,
          EctoShorts.CommonFilters.OrHaving,
          EctoShorts.CommonFilters.OrderBy,
          EctoShorts.CommonFilters.Page,
          EctoShorts.CommonFilters.Preload,
          EctoShorts.CommonFilters.PrependOrderBy,
          EctoShorts.CommonFilters.PutQueryPrefix,
          EctoShorts.CommonFilters.RecursiveCtes,
          EctoShorts.CommonFilters.ReverseOrder,
          EctoShorts.CommonFilters.Select,
          EctoShorts.CommonFilters.SelectMerge,
          EctoShorts.CommonFilters.SubQuery,
          EctoShorts.CommonFilters.Union,
          EctoShorts.CommonFilters.UnionAll,
          EctoShorts.CommonFilters.Update,
          EctoShorts.CommonFilters.UpdateExpr,
          EctoShorts.CommonFilters.Windows,
          EctoShorts.CommonFilters.WithCte,
          EctoShorts.CommonFilters.WithNamedBinding,
          EctoShorts.CommonFilters.WithTies
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
          EctoShorts.FilterError,
          EctoShorts.LogUtils,
          EctoShorts.Logger,
          EctoShorts.QueryBinding,
          EctoShorts.QueryBuilder,
          EctoShorts.QueryBuilders,
          EctoShorts.QueryProvider,
          EctoShorts.Types,
          EctoShorts.Utils
        ]
      ]
    ]
  end

  # Injects mermaid.js and Viz.js (Graphviz) into the generated HTML docs so
  # that ```mermaid and ```dot code blocks are rendered as diagrams. Only
  # applies to the HTML formatter.
  #
  # securityLevel: "loose" is required for mermaid `click` navigation and
  # tooltips; the default "strict" disables them silently. Diagram source
  # comes only from this project's own doc comments.
  defp before_closing_body_tag(:html) do
    """
    <script defer src="https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.min.js"></script>
    <script src="https://cdn.jsdelivr.net/npm/@viz-js/viz@3/lib/viz-standalone.min.js"></script>
    <script>
      let mermaidInitialized = false;
      window.addEventListener("exdoc:loaded", function () {
        if (!mermaidInitialized) {
          mermaid.initialize({
            startOnLoad: false,
            securityLevel: "loose",
            theme: document.body.className.includes("dark") ? "dark" : "default"
          });
          mermaidInitialized = true;
        }

        function replacePre(preEl, graphEl) {
          preEl.insertAdjacentElement("afterend", graphEl);
          preEl.remove();
        }

        let id = 0;
        for (const codeEl of document.querySelectorAll("pre code.mermaid")) {
          const preEl = codeEl.parentElement;
          const graphEl = document.createElement("div");
          const graphId = "mermaid-graph-" + id++;
          mermaid.render(graphId, codeEl.textContent).then(({ svg, bindFunctions }) => {
            graphEl.innerHTML = svg;
            bindFunctions?.(graphEl);
            replacePre(preEl, graphEl);
          });
        }

        // Render ```dot (Graphviz) blocks via Viz.js.
        Viz.instance().then(function (viz) {
          for (const codeEl of document.querySelectorAll("pre code.dot")) {
            const preEl = codeEl.parentElement;
            const graphEl = document.createElement("div");
            try {
              graphEl.appendChild(viz.renderSVGElement(codeEl.textContent));
              replacePre(preEl, graphEl);
            } catch (err) {
              console.error("Graphviz render failed:", err);
            }
          }
        });
      });
    </script>
    """
  end

  defp before_closing_body_tag(_), do: ""

  defp aliases do
    [
      setup: ["deps.get", "ecto.setup"],
      "ecto.setup": ["ecto.create", "ecto.migrate"],
      "ecto.reset": ["ecto.drop", "ecto.setup"]
    ]
  end
end
