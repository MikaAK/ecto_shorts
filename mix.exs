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
          EctoShorts.DynamicBuilder,
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
          EctoShorts.QueryProvider,
          EctoShorts.Utils
        ]
      ]
    ]
  end

  # Injects mermaid.js, Viz.js (Graphviz) and Cytoscape.js into the generated
  # HTML docs so that ```mermaid, ```dot and ```cytoscape code blocks are
  # rendered as diagrams. Only applies to the HTML formatter.
  #
  # A ```cytoscape block holds a JSON object that is passed almost verbatim to
  # cytoscape(); at minimum supply `elements`, e.g.
  #
  #   {
  #     "elements": [
  #       {"data": {"id": "filters", "label": "CommonFilters"}},
  #       {"data": {"id": "builders", "label": "DynamicBuilders"}},
  #       {"data": {"source": "filters", "target": "builders"}}
  #     ]
  #   }
  #
  # Optional keys: `layout` (defaults to "breadthfirst") and `style`.
  defp before_closing_body_tag(:html) do
    """
    <script defer src="https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.min.js"></script>
    <script src="https://cdn.jsdelivr.net/npm/@viz-js/viz@3/lib/viz-standalone.min.js"></script>
    <script src="https://cdn.jsdelivr.net/npm/cytoscape@3/dist/cytoscape.min.js"></script>
    <script>
      document.addEventListener("DOMContentLoaded", function () {
        mermaid.initialize({
          startOnLoad: false,
          theme: document.body.className.includes("dark") ? "dark" : "default"
        });

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

        // Render ```cytoscape blocks (interactive, pan/zoom/drag graphs).
        // String values that look like a function literal ("function(...){...}"
        // or "(...) => ...") are revived into real functions so layouts such as
        // `concentric` can use callbacks that JSON cannot express.
        //
        // SECURITY: this evals strings drawn from ```cytoscape blocks in our own
        // doc source, so an author can run arbitrary JS at doc-view time. That is
        // not a new trust boundary (doc authors already control the page), but if
        // doc contributions are ever accepted from untrusted sources, replace the
        // eval below with a whitelist of named layout callbacks.
        const reviveFns = (value) => {
          if (typeof value === "string" && /^\\s*(function\\b|\\(?[\\w,\\s]*\\)?\\s*=>)/.test(value)) {
            try { return (0, eval)("(" + value + ")"); } catch (_e) { return value; }
          }
          if (Array.isArray(value)) return value.map(reviveFns);
          if (value && typeof value === "object") {
            const out = {};
            for (const k of Object.keys(value)) out[k] = reviveFns(value[k]);
            return out;
          }
          return value;
        };

        const dark = document.body.className.includes("dark");
        for (const codeEl of document.querySelectorAll("pre code.cytoscape")) {
          const preEl = codeEl.parentElement;
          let spec;
          try {
            spec = reviveFns(JSON.parse(codeEl.textContent));
          } catch (err) {
            console.error("Cytoscape JSON parse failed:", err);
            continue;
          }

          const graphEl = document.createElement("div");
          graphEl.style.width = "100%";
          graphEl.style.height = (spec.height || 400) + "px";
          graphEl.style.border = "1px solid " + (dark ? "#444" : "#ddd");
          graphEl.style.borderRadius = "4px";
          replacePre(preEl, graphEl);

          cytoscape({
            container: graphEl,
            elements: spec.elements || [],
            layout: spec.layout || { name: "breadthfirst", directed: true, padding: 10 },
            style: spec.style || [
              {
                selector: "node",
                style: {
                  "label": "data(label)",
                  "background-color": dark ? "#7c9cff" : "#3b5bdb",
                  "color": dark ? "#eee" : "#222",
                  "font-size": "11px",
                  "text-valign": "center",
                  "text-halign": "center",
                  "text-margin-y": -14
                }
              },
              {
                selector: "edge",
                style: {
                  "width": 1.5,
                  "line-color": dark ? "#888" : "#aaa",
                  "target-arrow-color": dark ? "#888" : "#aaa",
                  "target-arrow-shape": "triangle",
                  "curve-style": "bezier"
                }
              }
            ]
          });
        }
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
