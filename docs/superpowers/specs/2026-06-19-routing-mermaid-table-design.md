# Operator-Routing Visualization: Mermaid + Table (replace Cytoscape) — Design

**Date:** 2026-06-19
**Status:** Approved (pending spec review)
**Scope:** Replace the interactive Cytoscape operator-routing graph with an ExDoc-native Mermaid flowchart plus a reference table, and remove the Cytoscape rendering machinery from the docs hook.

## Why

The operator-routing visualization is a fixed ~12-node relationship. Cytoscape.js is built for large, explorable graphs; at this size its interactivity adds little while costing a lot of fragility:

- Construction on a detached, zero-size container threw `Cannot read properties of undefined (reading 'x1')`.
- Wheel/trackpad zoom required a custom scroll-guard + pinch handler.
- Layout callbacks required an `eval`-based function reviver (a security surface).

Two ExDoc-native representations cover the goal — *see which operator routes to which adapter, and jump to the relevant docs* — more simply and reliably:

1. A **Mermaid flowchart** renders declaratively (ExDoc-blessed), with built-in clickable nodes (`click <id> href "<url>" "<tooltip>"`) that navigate to the docs and show tooltips. This replaces the proposed custom pop-up card.
2. A **reference table** is the always-visible "info card" for precise lookup.

## Verified facts (sources)

- Mermaid `click` navigation and tooltips are **disabled** under the default `securityLevel: "strict"` and **enabled** under `securityLevel: "loose"`; under strict, `click` fails silently.
  - https://mermaid.ai/open-source/syntax/flowchart.html
  - https://github.com/mermaid-js/mermaid/issues/6809
- ExDoc renders custom JS via `before_closing_body_tag/1` and fires `window`'s `exdoc:loaded` event on initial load and on in-page navigation (v0.37.0+). Diagram transforms must run on that event, not `DOMContentLoaded`.
  - https://ex-doc.hexdocs.pm/readme.html

## Changes

### A. `lib/ecto_shorts/dynamic_builders.ex` — `## Operator routing` section

Replace the ` ```cytoscape ` block with two artifacts.

**A1. Mermaid flowchart** (` ```mermaid `), `flowchart LR`:

- Seven operator nodes route into four adapter nodes:
  - `ScalarExpr` ← `==, !=, <, >, in`; `like, ilike`; `avg, sum, max, min`
  - `ArrayExpr` ← `&&, @> (array)`
  - `CommonExpr` ← `before, after, since, until`; `exists`
  - `MapExpr` ← `@>, <@, jsonb_exists`
- `Normalizer` connects to the operator side with **dashed** edges labeled with example aliases (`eq → ==`, `downcase → lower`).
- Each adapter node carries a click directive:
  `click scalar href "EctoShorts.DynamicBuilders.Postgres.html" "Scalar comparisons, in, like/ilike, aggregates"` (and equivalently for `array`, `common`, `map`).
- `Normalizer` and operator nodes have no click target (no own doc page).

**Label-escaping requirement (gotcha):** operator labels contain `<`, `>`, `&`. Raw, these break Mermaid parsing and — under `securityLevel: "loose"` — could be interpreted as HTML. Every label must escape them using Mermaid's **numeric** entity codes (numeric is documented and reliable; named codes like `#lt;` are not guaranteed):

| Literal | Use in label |
|---|---|
| `<` | `#60;` |
| `>` | `#62;` |
| `&` | `#38;` |

`==`, `!=`, `@`, spaces, and parentheses are safe and need no escaping. So:
- `== != < > in` → `== != #60; #62; in`
- `&&, @> (array)` → `#38;#38;, @#62; (array)`
- `@>, <@, jsonb_exists` → `@#62;, #60;@, jsonb_exists`

The implementation plan must verify these render literally in the generated SVG before completion.

**A2. Reference table** immediately below the flowchart:

| Operator(s) | Routes to | What it does |
|---|---|---|
| `==` `!=` `<` `>` `in` | [`ScalarExpr`](EctoShorts.DynamicBuilders.Postgres.html) | Comparisons, equality, membership |
| `like` `ilike` | [`ScalarExpr`](EctoShorts.DynamicBuilders.Postgres.html) | Pattern matching |
| `avg` `sum` `max` `min` | [`ScalarExpr`](EctoShorts.DynamicBuilders.Postgres.html) | Aggregate comparisons |
| `&&` `@>` (array) | [`ArrayExpr`](EctoShorts.DynamicBuilders.Postgres.html) | Postgres array operators |
| `before` `after` `since` `until` | [`CommonExpr`](EctoShorts.DynamicBuilders.Postgres.html) | Cursor / timestamp filters |
| `exists` | [`CommonExpr`](EctoShorts.DynamicBuilders.Postgres.html) | Existence subqueries |
| `@>` `<@` `jsonb_exists` | [`MapExpr`](EctoShorts.DynamicBuilders.Postgres.html) | JSONB operators |

(In Markdown table cells, backticked operators render literally; no Mermaid escaping needed here.)

**A3. Intro prose:** reword the existing paragraph — remove "Drag the adapter hubs apart…"; replace with guidance that the diagram shows routing and that **clicking an adapter opens its documentation**, with the table below for exact lookup.

### B. `mix.exs` — `before_closing_body_tag/1`

**Remove:**
- The Cytoscape CDN `<script src=".../cytoscape@3...">` tag.
- `injectCytoscapeStyles`, `renderCytoscape`, `wireCytoscape`.
- The `reviveFns` helper and its SECURITY comment (only Cytoscape used it).
- The `for (const codeEl of document.querySelectorAll("pre code.cytoscape"))` loop and `injectCytoscapeStyles()` call.

**Change:**
- Add `securityLevel: "loose"` to the existing `mermaid.initialize({ ... })` call, so `click` navigation and tooltips work.

**Keep:**
- The `exdoc:loaded` `window` listener and the `mermaidInitialized` guard.
- The Mermaid render loop (`pre code.mermaid`).
- The Graphviz/Viz.js render loop (`pre code.dot`) and its CDN script.
- `replacePre`.

**Security note:** `securityLevel: "loose"` permits HTML in Mermaid diagram text. Diagram source comes only from this project's own doc comments (same trust model as before). If untrusted doc contributions are ever accepted, revisit this.

## Out of scope

- Any custom pop-up/hover card component (superseded by Mermaid click + tooltip and the table).
- Changes to other Mermaid or Graphviz diagrams elsewhere in the docs.
- Re-introducing Cytoscape for a genuinely large graph later (would be its own design).

## Verification

- `mix docs` builds with no new warnings.
- Generated `EctoShorts.DynamicBuilders.html`:
  - Contains a `<pre><code class="mermaid">` block in the Operator routing section and the reference table.
  - No longer contains `code class="cytoscape"`, `renderCytoscape`, `wireCytoscape`, `cytoscape@3`, or `reviveFns`.
- Headless render (Brave/Chromium, `exdoc:loaded` fired): the mermaid block is replaced by an `<svg>`; no console errors; clicking an adapter node navigates to `EctoShorts.DynamicBuilders.Postgres.html`.
- Manual: tooltips show on adapter-node hover; operator labels render with literal `<`, `>`, `&`.
