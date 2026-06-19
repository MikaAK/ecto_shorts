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

        function injectCytoscapeStyles() {
          if (document.getElementById("es-cy-styles")) return;
          const css = document.createElement("style");
          css.id = "es-cy-styles";
          css.textContent = `
            .es-cy-frame { margin: 1.2em 0; border: 1px solid; border-radius: 8px; overflow: hidden; }
            .es-cy-bar { display: flex; align-items: center; gap: .5rem; flex-wrap: wrap;
              padding: .45rem .6rem; border-bottom: 1px solid; font-size: 13px; }
            .es-cy-title { font-weight: 600; margin-right: auto; }
            .es-cy-controls { display: flex; align-items: center; gap: .25rem; }
            .es-cy-btn { display: inline-flex; align-items: center; justify-content: center;
              width: 26px; height: 26px; padding: 0; border: 1px solid; border-radius: 6px;
              background: transparent; cursor: pointer; font-size: 14px; line-height: 1; }
            .es-cy-btn:focus-visible { outline: 2px solid #4c6ef5; outline-offset: 1px; }
            .es-cy-open { width: auto; padding: 0 .5rem; font-size: 12px; display: none;
              text-decoration: none; }
            .es-cy-open.is-shown { display: inline-flex; }
            .es-cy-search { height: 26px; padding: 0 .5rem; border: 1px solid; border-radius: 6px;
              background: transparent; font-size: 12px; min-width: 8rem; color: inherit; }
            .es-cy-canvas { position: relative; width: 100%; }
            .es-cy-hint { position: absolute; inset: 0; display: flex; align-items: center;
              justify-content: center; font-size: 12px; pointer-events: none; opacity: 1;
              transition: opacity .25s ease; }
            .es-cy-frame.is-active .es-cy-hint { opacity: 0; }
            @media (prefers-reduced-motion: reduce) { .es-cy-hint { transition: none; } }
            @media (max-width: 600px) { .es-cy-title { width: 100%; margin-bottom: .25rem; } }
          `;
          document.head.appendChild(css);
        }

        function renderCytoscape(spec, dark) {
          const c = dark
            ? { frameBorder: "#3a3a3a", bar: "#2a2a2a", barText: "#ddd", canvas: "#1b1b1b",
                chipBg: "#23262e", chipText: "#cdd3e0", chipBorder: "#3a4150",
                cardBg: "#3b5bdb", cardText: "#fff", cardBorder: "#4c6ef5",
                edge: "#666", edgeEmph: "#9ab0ff", hint: "#888", btnBorder: "#444" }
            : { frameBorder: "#e2e2e2", bar: "#f7f7f8", barText: "#222", canvas: "#fff",
                chipBg: "#f1f3f9", chipText: "#2b3242", chipBorder: "#cfd6e6",
                cardBg: "#3b5bdb", cardText: "#fff", cardBorder: "#2f49b0",
                edge: "#bbb", edgeEmph: "#3b5bdb", hint: "#999", btnBorder: "#d0d0d0" };

          const frame = document.createElement("div");
          frame.className = "es-cy-frame";
          frame.style.borderColor = c.frameBorder;
          frame.style.background = c.canvas;

          const bar = document.createElement("div");
          bar.className = "es-cy-bar";
          bar.style.borderColor = c.frameBorder;
          bar.style.background = c.bar;
          bar.style.color = c.barText;

          const title = document.createElement("span");
          title.className = "es-cy-title";
          title.textContent = spec.title || "";
          bar.appendChild(title);
          frame.appendChild(bar);

          const canvas = document.createElement("div");
          canvas.className = "es-cy-canvas";
          canvas.style.height = (spec.height || 400) + "px";
          canvas.style.background = c.canvas;

          const hint = document.createElement("div");
          hint.className = "es-cy-hint";
          hint.style.color = c.hint;
          hint.textContent = "Click to interact";
          canvas.appendChild(hint);
          frame.appendChild(canvas);

          const elements = (spec.elements || []).map((el) => {
            const d = el.data || {};
            const isModule = !!d.href || d.kind === "module";
            return isModule ? Object.assign({ classes: "module" }, el) : el;
          });

          const cy = cytoscape({
            container: canvas,
            elements: elements,
            layout: spec.layout || { name: "breadthfirst", directed: true, padding: 16 },
            minZoom: 0.3,
            maxZoom: 3,
            style: spec.style || [
              { selector: "node", style: {
                  "shape": "round-rectangle", "label": "data(label)", "width": "label",
                  "height": "label", "padding": "8px", "text-valign": "center",
                  "text-halign": "center", "text-wrap": "none", "font-size": "13px",
                  "font-family": "ui-monospace, SFMono-Regular, Menlo, monospace",
                  "background-color": c.chipBg, "color": c.chipText,
                  "border-width": 1, "border-color": c.chipBorder } },
              { selector: "node.module", style: {
                  "background-color": c.cardBg, "color": c.cardText, "border-color": c.cardBorder,
                  "font-family": "inherit", "font-weight": "bold" } },
              { selector: "edge", style: {
                  "width": 1.5, "line-color": c.edge, "target-arrow-color": c.edge,
                  "target-arrow-shape": "triangle", "curve-style": "bezier" } },
              { selector: ".es-dim", style: { "opacity": 0.15 } },
              { selector: ".es-emph", style: {
                  "width": 2.5, "line-color": c.edgeEmph, "target-arrow-color": c.edgeEmph } }
            ]
          });

          cy.ready(() => cy.fit(undefined, 24));
          frame._es = { c, bar, hint, canvas };
          return { frame, cy };
        }

        function wireCytoscape(cy, frame, spec, dark) {
          const { c, bar } = frame._es;
          const reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

          // --- Controls in the title bar ---
          const controls = document.createElement("span");
          controls.className = "es-cy-controls";

          const search = document.createElement("input");
          search.className = "es-cy-search";
          search.type = "search";
          search.placeholder = "Search…";
          search.setAttribute("aria-label", "Search nodes");
          search.style.borderColor = c.btnBorder;
          controls.appendChild(search);

          const open = document.createElement("a");
          open.className = "es-cy-btn es-cy-open";
          open.textContent = "Open docs ↗";
          open.style.borderColor = c.btnBorder;
          open.style.color = c.barText;
          controls.appendChild(open);

          function mkBtn(label, glyph, fn) {
            const b = document.createElement("button");
            b.type = "button";
            b.className = "es-cy-btn";
            b.textContent = glyph;
            b.setAttribute("aria-label", label);
            b.title = label;
            b.style.borderColor = c.btnBorder;
            b.style.color = c.barText;
            b.addEventListener("click", fn);
            controls.appendChild(b);
            return b;
          }
          const zoomBy = (factor) => {
            const r = cy.container().getBoundingClientRect();
            cy.zoom({ level: cy.zoom() * factor,
                      renderedPosition: { x: r.width / 2, y: r.height / 2 } });
          };
          mkBtn("Zoom in", "+", () => zoomBy(1.2));
          mkBtn("Zoom out", "−", () => zoomBy(1 / 1.2));
          mkBtn("Fit to view", "⤢", () => { clearFocus(); cy.fit(undefined, 24); });
          bar.appendChild(controls);

          // --- Scroll-guard: wheel-zoom only after the graph is activated ---
          cy.userZoomingEnabled(false);
          function activate() { frame.classList.add("is-active"); cy.userZoomingEnabled(true); }
          function deactivate() { frame.classList.remove("is-active"); cy.userZoomingEnabled(false); }
          cy.on("tap", activate);
          frame.addEventListener("focusin", activate);
          frame.addEventListener("mouseleave", deactivate);
          frame.addEventListener("focusout", (e) => {
            if (!frame.contains(e.relatedTarget)) deactivate();
          });

          // --- Search filter ---
          search.addEventListener("input", () => {
            const q = search.value.trim().toLowerCase();
            if (!q) { cy.elements().removeClass("es-dim"); return; }
            cy.nodes().forEach((n) => {
              const match = String(n.data("label") || "").toLowerCase().includes(q);
              n.toggleClass("es-dim", !match);
            });
            cy.edges().forEach((e) => {
              const hidden = e.source().hasClass("es-dim") || e.target().hasClass("es-dim");
              e.toggleClass("es-dim", hidden);
            });
          });

          // --- Click-focus highlighting + navigation ---
          let lastTapId = null, lastTapAt = 0;
          function clearFocus() {
            cy.elements().removeClass("es-dim es-emph");
            open.classList.remove("is-shown");
            open.removeAttribute("href");
          }
          function focusNode(node) {
            const keep = node.closedNeighborhood();
            cy.elements().addClass("es-dim");
            keep.removeClass("es-dim");
            node.connectedEdges().removeClass("es-dim").addClass("es-emph");
            const href = node.data("href");
            if (href) {
              open.href = href;
              open.classList.add("is-shown");
            } else {
              open.classList.remove("is-shown");
              open.removeAttribute("href");
            }
          }
          cy.on("tap", "node", (evt) => {
            const node = evt.target;
            const href = node.data("href");
            const now = evt.timeStamp || 0;
            if (href && node.id() === lastTapId && now - lastTapAt < 300) {
              window.location.href = href;   // double-tap navigates
              return;
            }
            lastTapId = node.id();
            lastTapAt = now;
            focusNode(node);
          });
          cy.on("tap", (evt) => { if (evt.target === cy) clearFocus(); });

          if (reduceMotion) { /* cy animations already off; nothing extra needed */ }
        }

        const dark = document.body.className.includes("dark");
        injectCytoscapeStyles();
        for (const codeEl of document.querySelectorAll("pre code.cytoscape")) {
          const preEl = codeEl.parentElement;
          let spec;
          try {
            spec = reviveFns(JSON.parse(codeEl.textContent));
          } catch (err) {
            console.error("Cytoscape JSON parse failed:", err);
            continue;
          }
          const { frame, cy } = renderCytoscape(spec, dark);
          wireCytoscape(cy, frame, spec, dark);
          replacePre(preEl, frame);
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
