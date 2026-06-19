# Cytoscape Docs Experience — Design

**Date:** 2026-06-19
**Status:** Approved (pending spec review)
**Scope:** Polish the interactive Cytoscape graph rendering in ExDoc HTML output.

## Problem

The `before_closing_body_tag/1` hook in `mix.exs` renders ` ```cytoscape ` blocks
into a bare 400px container. Three problems make the current experience unsatisfying:

1. **Text is hard to read.** Labels float above nodes (`text-margin-y: -14`) at 11px,
   overlap on dense graphs, and have no background to separate them from edges.
2. **The graph is not "in place."** It can pan out of frame with no way to recover,
   the wheel may fight page scroll, and nothing fits/centers the view on load.
3. **Clicking does nothing useful.** Nodes are draggable but a click has no meaning —
   no focus, no relationship reveal, no navigation.

The goal is a smooth, meaningful experience: a framed viewport with controls,
readable nodes, and clicks that both reveal relationships and navigate to docs.

## Design Principles

- **Additive and backward compatible.** Existing `mermaid` and `dot` rendering is
  untouched. Existing `cytoscape` specs keep working; new behavior is opt-in via one
  new optional field (`data.href`).
- **Default in the hook.** Styling, controls, and interactions live in
  `before_closing_body_tag/1` so every `cytoscape` block across the docs gets the
  polished experience. Authors supply only `elements` and an optional per-node `href`.
- **One signature, everything else quiet.** The bold choice is the code-token
  aesthetic; controls and chrome stay disciplined.

## Signature: the graph reads as code

The nodes *are* Elixir atoms and modules (`:==`, `&&`, `@>`, `ScalarExpr`). The visual
language makes that literal:

- **Operator nodes** (leaf tokens) render as **monospace code-token chips** — rounded
  rectangles auto-sized to their label, monospace font, a subtle token-like fill.
- **Adapter / module nodes** render as **solid module cards** — heavier fill, sans
  label, visually the "destinations" that tokens route into.

Tier is encoded by shape + fill, not by guessing from position.

### Distinguishing node roles

A node is styled as a module card (vs. a code-token chip) when it carries an `href`
in its data, OR an explicit `data.kind` of `"module"`. Operator chips have neither.
This keeps the author contract simple: give a node an `href` and it becomes a
navigable module card automatically.

## Behavior

### 1. Framed viewport ("in place")

- Bordered card with a **title bar** (left: optional `spec.title`; right: controls).
- **Fit-to-view on load** (`cy.fit` with padding) so the graph is centered, not adrift.
- **Bounded zoom**: `minZoom`/`maxZoom` so the view cannot get lost.
- **Scroll-guard**: the page scrolls normally when the pointer passes over the graph.
  Wheel-zoom engages only after the graph is activated (pointer click / keyboard focus).
  A quiet "Click to interact" hint overlays the graph until first activation, then fades.
  Cytoscape `userZoomingEnabled` is toggled on activation and off on blur / pointer-leave.

### 2. Controls (top-right of title bar)

Small, icon-style, keyboard-focusable buttons with visible focus rings and `aria-label`s:

| Control | Action |
|---|---|
| Zoom in | `cy.zoom` step up, animated, centered |
| Zoom out | `cy.zoom` step down, animated, centered |
| Fit / reset | `cy.fit` to all elements; also clears any active focus selection |
| Search box | Filter by label substring (see below) |

### 3. Search / filter

- A small text input in the title bar.
- On input: nodes whose label does **not** contain the (case-insensitive) query dim to
  ~15% opacity along with their connected edges; matching nodes stay full opacity.
- Empty query restores full opacity for everything.
- Search composes with click-focus: clearing search does not clear a focus selection
  and vice-versa; Fit/reset clears both.

### 4. Click = highlight + navigate

- **First click on a node** focuses it: the node and its direct neighbors keep full
  opacity; all other nodes/edges dim to ~15%; edges incident to the focused node are
  emphasized (heavier line / arrow color). This is the "show me relationships" behavior.
- **Click on background** clears the focus and restores full opacity.
- **Navigation**: when a focused node has `data.href`, an **"Open docs ↗"** affordance
  appears (a small chip near the node or in the title bar). Activating it — or
  **double-clicking** the node — navigates to that URL (same tab). Nodes without `href`
  never navigate; they only highlight.
- Keyboard: nodes are not natively focusable in Cytoscape canvas; navigation parity is
  provided by the search box + Enter-to-open-first-match-with-href as a stretch, but the
  baseline keyboard guarantee is that all title-bar controls are reachable and operable.

## Accessibility / quality floor

- `prefers-reduced-motion: reduce` → disable focus-dim transitions and animated zoom
  (state still changes, just instantly).
- All controls keyboard-reachable, visible focus outline, `aria-label` on icon buttons.
- Responsive: on narrow widths the title bar wraps (controls below title); graph height
  respects `spec.height` (default 400) with a sensible min.
- Color: light and dark variants for every fill/stroke/label, selected from
  `document.body.className.includes("dark")` as today.

## Data model

Backward-compatible additions to the spec JSON parsed from a ` ```cytoscape ` block:

| Field | Type | Default | Meaning |
|---|---|---|---|
| `title` | string | none | Shown in the frame's title bar |
| `height` | number | 400 | Viewport height in px (already supported) |
| `layout` | object | concentric/breadthfirst | Cytoscape layout (string fn values revived — already supported) |
| `style` | array | built-in chip/card theme | Override styling entirely (already supported) |
| node `data.href` | string | none | Makes the node a navigable module card; double-click / "Open docs ↗" navigates |
| node `data.kind` | `"module"` \| `"operator"` | inferred | Force a node's role independent of `href` |

When `style` is omitted, the hook supplies the chip/card theme. When provided, the
author's style wins (full escape hatch, unchanged).

## Example block update

The `## Operator routing` graph in `lib/ecto_shorts/dynamic_builders.ex` gains:

- `"title": "Operator routing"`.
- `href` on the four adapter nodes (`ScalarExpr`, `ArrayExpr`, `CommonExpr`, `MapExpr`)
  and `Normalizer`, each pointing at its ExDoc page
  (e.g. `EctoShorts.DynamicBuilders.Postgres.ScalarExpr.html`).
- Operator nodes left as plain chips (no `href`).

## Out of scope

- Layout switcher UI (considered, rejected — a good default beats a toggle).
- Persisting view state across page loads.
- Server-side / static pre-rendering of the graph (stays client-side like mermaid/dot).
- Vendoring the CDN scripts locally (tracked separately).

## Verification

- `mix docs` builds without warnings.
- Generated `EctoShorts.DynamicBuilders.html` contains `<code class="cytoscape">` and the
  `cytoscape@3` script.
- Manual: open the page; confirm fit-on-load, readable in-node labels, working
  zoom/fit/search, click-focus dimming, double-click navigation on adapter nodes, and
  reduced-motion behavior via an emulated media query.
