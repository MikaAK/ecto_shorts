# Operator-Routing: Mermaid + Table Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the fragile Cytoscape operator-routing graph with an ExDoc-native Mermaid flowchart (clickable nodes → docs, tooltips) plus a reference table, and strip the Cytoscape machinery from the docs hook.

**Architecture:** Two files change. `lib/ecto_shorts/dynamic_builders.ex` swaps its ` ```cytoscape ` moduledoc block for a ` ```mermaid ` flowchart and a Markdown table. `mix.exs`'s `before_closing_body_tag/1` drops the Cytoscape CDN script, all Cytoscape JS (`renderCytoscape`, `wireCytoscape`, `injectCytoscapeStyles`, the `reviveFns` eval, the cytoscape loop) and adds `securityLevel: "loose"` to `mermaid.initialize` so Mermaid clicks/tooltips work. Mermaid and Graphviz rendering stay.

**Tech Stack:** Elixir/Mix (`ex_doc`), Mermaid 11 (CDN), Viz.js (CDN). No JS test runner exists — verification is `mix docs` building cleanly, grepping the generated HTML for expected/absent markers, and a headless Brave render (`exdoc:loaded` fires) checking the SVG, console, and click target.

## Global Constraints

- Only `mix.exs` and `lib/ecto_shorts/dynamic_builders.ex` change. Do not touch the Mermaid or Graphviz render loops' behavior beyond adding `securityLevel`.
- Mermaid `click` navigation + tooltips require `securityLevel: "loose"` in `mermaid.initialize`; the default `"strict"` disables them silently.
- The hook string is an Elixir heredoc (`"""`).
- Mermaid node labels must escape special characters with **numeric** entity codes so they render literally and don't break parsing: `<` → `#60;`, `>` → `#62;`, `&` → `#38;`. `==`, `!=`, `@`, spaces, and parentheses need no escaping.
- Adapter doc links point to `EctoShorts.DynamicBuilders.Postgres.html` (the four expr sub-modules are `@moduledoc false`; `Normalizer` is not a module). `Normalizer` and operator nodes get no click target.
- `mix docs` must build with no new warnings.

---

### Task 1: Replace the cytoscape block with a Mermaid flowchart + reference table

**Files:**
- Modify: `lib/ecto_shorts/dynamic_builders.ex` — the `## Operator routing` section (intro prose at lines ~11-13 and the ` ```cytoscape ` block at lines ~15-52).

**Interfaces:**
- Consumes: nothing from other tasks.
- Produces: a ` ```mermaid ` block (rendered by the hook's existing mermaid loop) and a Markdown table. No code symbols.

- [ ] **Step 1: Replace the intro prose and the cytoscape block**

In `lib/ecto_shorts/dynamic_builders.ex`, replace this exact text —

```
  Once the adapter is resolved, each filter operator is normalised and routed to
  one of the Postgres expression sub-modules. Drag the adapter hubs apart to see
  which operators each one owns, and how `Normalizer` rewrites aliases:

  ```cytoscape
  {
    "title": "Operator routing",
    "height": 520,
    "layout": {
      "name": "concentric",
      "minNodeSpacing": 40,
      "concentric": "function(n){ return n.data('tier'); }",
      "levelWidth": "function(){ return 1; }"
    },
    "elements": [
      {"data": {"id": "norm",   "label": "Normalizer",  "tier": 3, "kind": "module"}},
      {"data": {"id": "scalar", "label": "ScalarExpr",  "tier": 2, "href": "EctoShorts.DynamicBuilders.Postgres.html"}},
      {"data": {"id": "array",  "label": "ArrayExpr",   "tier": 2, "href": "EctoShorts.DynamicBuilders.Postgres.html"}},
      {"data": {"id": "common", "label": "CommonExpr",  "tier": 2, "href": "EctoShorts.DynamicBuilders.Postgres.html"}},
      {"data": {"id": "map",    "label": "MapExpr",     "tier": 2, "href": "EctoShorts.DynamicBuilders.Postgres.html"}},

      {"data": {"id": "eq",   "label": "==, !=, <, >, in", "tier": 1}},
      {"data": {"id": "like", "label": "like, ilike",      "tier": 1}},
      {"data": {"id": "agg",  "label": "avg, sum, max, min", "tier": 1}},
      {"data": {"id": "arr",  "label": "&&, @> (array)",   "tier": 1}},
      {"data": {"id": "cur",  "label": "before, after, since, until", "tier": 1}},
      {"data": {"id": "ex",   "label": "exists",           "tier": 1}},
      {"data": {"id": "json", "label": "@>, <@, jsonb_exists", "tier": 1}},

      {"data": {"source": "eq",   "target": "scalar"}},
      {"data": {"source": "like", "target": "scalar"}},
      {"data": {"source": "agg",  "target": "scalar"}},
      {"data": {"source": "arr",  "target": "array"}},
      {"data": {"source": "cur",  "target": "common"}},
      {"data": {"source": "ex",   "target": "common"}},
      {"data": {"source": "json", "target": "map"}},

      {"data": {"source": "norm", "target": "eq",   "label": "eq->=="}},
      {"data": {"source": "norm", "target": "like", "label": "downcase->lower"}}
    ]
  }
  ```
```

— with this exact text (note the two-space moduledoc indentation; the fenced blocks are indented two spaces like the original):

```
  Once the adapter is resolved, each filter operator is normalised and routed to
  one of the Postgres expression sub-modules. The diagram below shows that
  routing — **click an adapter to open its documentation** — and the table that
  follows lists every operator's destination.

  ```mermaid
  flowchart LR
    eq["== != #60; #62; in"] --> scalar["ScalarExpr"]
    like["like ilike"] --> scalar
    agg["avg sum max min"] --> scalar
    arr["#38;#38; @#62; (array)"] --> array["ArrayExpr"]
    cur["before after since until"] --> common["CommonExpr"]
    ex["exists"] --> common
    json["@#62; #60;@ jsonb_exists"] --> map["MapExpr"]

    norm["Normalizer"] -. "eq → ==" .-> eq
    norm -. "downcase → lower" .-> like

    click scalar href "EctoShorts.DynamicBuilders.Postgres.html" "Scalar comparisons, in, like/ilike, aggregates"
    click array href "EctoShorts.DynamicBuilders.Postgres.html" "Postgres array operators"
    click common href "EctoShorts.DynamicBuilders.Postgres.html" "Cursor, timestamp, and exists filters"
    click map href "EctoShorts.DynamicBuilders.Postgres.html" "JSONB operators"
  ```

  | Operator(s) | Routes to | What it does |
  | --- | --- | --- |
  | `==` `!=` `<` `>` `in` | [`ScalarExpr`](EctoShorts.DynamicBuilders.Postgres.html) | Comparisons, equality, membership |
  | `like` `ilike` | [`ScalarExpr`](EctoShorts.DynamicBuilders.Postgres.html) | Pattern matching |
  | `avg` `sum` `max` `min` | [`ScalarExpr`](EctoShorts.DynamicBuilders.Postgres.html) | Aggregate comparisons |
  | `&&` `@>` (array) | [`ArrayExpr`](EctoShorts.DynamicBuilders.Postgres.html) | Postgres array operators |
  | `before` `after` `since` `until` | [`CommonExpr`](EctoShorts.DynamicBuilders.Postgres.html) | Cursor / timestamp filters |
  | `exists` | [`CommonExpr`](EctoShorts.DynamicBuilders.Postgres.html) | Existence subqueries |
  | `@>` `<@` `jsonb_exists` | [`MapExpr`](EctoShorts.DynamicBuilders.Postgres.html) | JSONB operators |
```

- [ ] **Step 2: Build the docs and verify the block converted to mermaid**

Run: `mix docs 2>&1 | tail -2`
Expected: ends with `View html docs at "doc/index.html"`, no new warnings.

Run: `grep -o 'code class="mermaid"\|code class="cytoscape"' doc/EctoShorts.DynamicBuilders.html | sort -u`
Expected: only `code class="mermaid"` (no `cytoscape`).

Run: `grep -c 'DynamicBuilders.Postgres.html' doc/EctoShorts.DynamicBuilders.html`
Expected: a non-zero count (the table links + click targets are present).

- [ ] **Step 3: Commit**

```bash
git add lib/ecto_shorts/dynamic_builders.ex
git commit -m "Render operator routing as a Mermaid flowchart + table

Clickable adapter nodes navigate to the Postgres module docs, with a
reference table below for exact operator lookup."
```

---

### Task 2: Remove Cytoscape machinery from the hook + enable mermaid clicks

**Files:**
- Modify: `mix.exs` — the entire `before_closing_body_tag(:html)` clause and its leading doc comment (currently lines ~128-478).

**Interfaces:**
- Consumes: the Mermaid block authored in Task 1.
- Produces: a slimmed hook with `securityLevel: "loose"`; no Cytoscape symbols remain.

- [ ] **Step 1: Replace the doc comment and the `before_closing_body_tag(:html)` clause**

In `mix.exs`, replace everything from the comment line `# Injects mermaid.js, Viz.js (Graphviz) and Cytoscape.js into the generated` through the `end` that closes `defp before_closing_body_tag(:html) do` (the `end` immediately before `defp before_closing_body_tag(_), do: ""`) with exactly:

```elixir
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
```

Leave `defp before_closing_body_tag(_), do: ""` and everything after it unchanged.

- [ ] **Step 2: Build the docs and verify Cytoscape is gone and securityLevel is set**

Run: `mix docs 2>&1 | tail -2`
Expected: ends with `View html docs at "doc/index.html"`, no new warnings.

Run: `grep -o 'renderCytoscape\|wireCytoscape\|reviveFns\|cytoscape@3\|es-cy-frame\|securityLevel' doc/EctoShorts.DynamicBuilders.html | sort -u`
Expected: only `securityLevel` (none of the cytoscape markers remain).

- [ ] **Step 3: Headless render — verify mermaid renders, no errors, click target present**

Run:
```bash
cd /Users/kurthogarth/Documents/GitHub/ecto_shorts
BRAVE="/Applications/Brave Browser.app/Contents/MacOS/Brave Browser"
"$BRAVE" --headless=new --no-sandbox --disable-gpu --enable-logging=stderr --v=0 \
  --virtual-time-budget=9000 "file://$PWD/doc/EctoShorts.DynamicBuilders.html" \
  --dump-dom 2>/tmp/r-con.txt >/tmp/r-dom.html
echo "=== console errors ==="; grep -iE 'TypeError|Uncaught|ReferenceError|SyntaxError|mermaid' /tmp/r-con.txt | head
echo "=== mermaid rendered to svg? ==="; grep -c 'mermaid-graph-0' /tmp/r-dom.html
echo "=== click target present in svg? ==="; grep -oc 'DynamicBuilders.Postgres.html' /tmp/r-dom.html
echo "=== escaped labels render literally? ==="; grep -oc 'jsonb_exists' /tmp/r-dom.html
```
Expected: no console errors; `mermaid-graph-0` present (≥1); `DynamicBuilders.Postgres.html` count ≥1 (click links bound into the SVG); `jsonb_exists` present.

- [ ] **Step 4: Commit**

```bash
git add mix.exs
git commit -m "Remove Cytoscape rendering; enable mermaid click navigation

Strip the Cytoscape CDN script, styles, renderCytoscape/wireCytoscape, and
the reviveFns eval from the docs hook. Add securityLevel: loose to
mermaid.initialize so click-to-docs and tooltips work. Mermaid and Graphviz
rendering are unchanged."
```

---

## Self-Review

**Spec coverage:**
- Mermaid flowchart with operators→adapters, dashed Normalizer alias edges, click directives + tooltips → Task 1 Step 1. ✓
- Reference table with linked adapters → Task 1 Step 1. ✓
- Intro prose reworded (no "drag the hubs") → Task 1 Step 1. ✓
- Label escaping with numeric codes (`#60;`/`#62;`/`#38;`) → Task 1 Step 1 labels; verified in Task 2 Step 3. ✓
- Remove cytoscape script/styles/renderCytoscape/wireCytoscape/reviveFns/loop → Task 2 Step 1 (whole-clause replacement) + verified absent in Task 2 Step 2. ✓
- Add `securityLevel: "loose"` → Task 2 Step 1; verified in Task 2 Step 2. ✓
- Keep `exdoc:loaded`, mermaid loop, dot loop → preserved verbatim in Task 2 Step 1. ✓
- Build clean; click navigates; labels literal → Task 2 Steps 2-3. ✓

**Placeholder scan:** No TBD/TODO; both edits give exact before/after text and exact verification commands.

**Type consistency:** No code symbols cross tasks. The Mermaid node ids (`scalar`/`array`/`common`/`map`) used in `click` directives match the node definitions in the same block. Click targets and table links use the identical URL `EctoShorts.DynamicBuilders.Postgres.html`. ✓
