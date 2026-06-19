# Cytoscape Docs Experience Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the bare Cytoscape rendering in ExDoc output into a framed, readable, interactive graph with viewport controls, search, click-to-highlight, and double-click navigation.

**Architecture:** All behavior lives in the `before_closing_body_tag/1` HTML hook in `mix.exs`. The current inline `cytoscape` render loop is replaced by: (1) a one-time injected `<style>` block for frame chrome, (2) a `renderCytoscape(spec, dark)` builder that produces a framed card and themes nodes as monospace "code-token chips" or solid "module cards", and (3) a `wireCytoscape(cy, frame, spec, dark)` function that attaches fit-on-load, scroll-guard, zoom/fit controls, search/filter, click-focus highlighting, and double-click/affordance navigation. The example block in `lib/ecto_shorts/dynamic_builders.ex` gains a title and per-node `href`s.

**Tech Stack:** Elixir/Mix (`ex_doc`), Cytoscape.js 3 (CDN), plain browser JS + CSS embedded in a heredoc string. No JS test runner exists in this project — verification per task is `mix docs` building cleanly plus grepping the generated HTML for expected markers, with a final manual browser checklist.

## Global Constraints

- Changes are confined to `mix.exs` (the `before_closing_body_tag/1` clause) and `lib/ecto_shorts/dynamic_builders.ex` (the example block). Do not touch `mermaid`/`dot` rendering.
- The hook string is an Elixir heredoc (`"""`). Any literal backslash in embedded JS regex must be doubled (`\\s`, `\\(`) — see the existing `reviveFns` regex at `mix.exs:198`.
- Backward compatible: existing `cytoscape` specs with only `elements` must still render. New fields are optional: `title` (string), node `data.href` (string), node `data.kind` (`"module"`/`"operator"`).
- A node is a "module card" when its `data.href` is set OR `data.kind === "module"`; otherwise it is an "operator chip".
- Accessibility floor: control buttons keyboard-focusable with visible focus and `aria-label`; `prefers-reduced-motion: reduce` disables animations; title bar wraps on narrow widths.
- `mix docs` must build with no new warnings.

---

### Task 1: Framed card + readable code-token / module-card node theme

Replace the inline cytoscape render loop with a one-time `<style>` injection and a `renderCytoscape` builder that produces a bordered card with a title bar and a themed, fit-to-view graph. No controls/interactions yet beyond fit-on-load — this task's deliverable is a framed, readable, building graph.

**Files:**
- Modify: `mix.exs` — replace the cytoscape section (currently `mix.exs:187-257`, from the comment `// Render ```cytoscape blocks` through the closing `}` of the `for` loop), keeping the `reviveFns` helper and its SECURITY comment intact.

**Interfaces:**
- Consumes: `replacePre(preEl, graphEl)` (`mix.exs:156`), `reviveFns(value)` (`mix.exs:197`), the `dark` boolean (`mix.exs:210`).
- Produces: `renderCytoscape(spec, dark)` returning `{ frame, cy }` where `frame` is the outer `.es-cy-frame` element and `cy` is the Cytoscape instance; a one-time `injectCytoscapeStyles()` that appends a `<style id="es-cy-styles">` once.

- [ ] **Step 1: Replace the cytoscape section in `mix.exs`**

In `mix.exs`, the block to replace begins at the line `// Render ```cytoscape blocks (interactive, pan/zoom/drag graphs).` (keep the `reviveFns` definition that follows the SECURITY comment — it stays) and ends at the `}` closing the `for (const codeEl of document.querySelectorAll("pre code.cytoscape"))` loop. Replace **only the `dark` declaration and the `for` loop** (currently `mix.exs:210-257`) with:

```javascript
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
            .es-cy-open { width: auto; padding: 0 .5rem; font-size: 12px; display: none; }
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
          const { frame } = renderCytoscape(spec, dark);
          replacePre(preEl, frame);
        }
```

- [ ] **Step 2: Build the docs and verify the frame markers appear**

Run: `mix docs 2>&1 | tail -3`
Expected: ends with `View html docs at "doc/index.html"`, no new warnings.

Run: `grep -o 'es-cy-frame\|renderCytoscape\|es-cy-styles' doc/EctoShorts.DynamicBuilders.html | sort -u`
Expected output includes `es-cy-frame`, `es-cy-styles`, and `renderCytoscape` (the script text is embedded in every page).

- [ ] **Step 3: Verify the cytoscape block still parses and the old floating-label style is gone**

Run: `grep -c 'text-margin-y' doc/EctoShorts.DynamicBuilders.html`
Expected: `0` (the old label offset is removed).

Run: `grep -o '<code class="cytoscape">' doc/EctoShorts.DynamicBuilders.html | head -1`
Expected: `<code class="cytoscape">`

- [ ] **Step 4: Commit**

```bash
git add mix.exs
git commit -m "Frame and theme Cytoscape graphs in ExDoc output

Code-token chips for operators, solid cards for module nodes, a bordered
title-bar frame, and fit-on-load. Replaces the bare 400px container."
```

---

### Task 2: Interactions — scroll-guard, zoom/fit controls, search, click-focus, navigation

Add `wireCytoscape(cy, frame, spec, dark)` and call it from the render loop. This delivers the full interactive experience: scroll-guard, zoom in/out/fit buttons, search filter, click-to-highlight neighbors, and double-click / "Open docs" navigation.

**Files:**
- Modify: `mix.exs` — add `wireCytoscape` (after `renderCytoscape`, before the `dark` declaration) and call it in the loop.

**Interfaces:**
- Consumes: `renderCytoscape` returns `{ frame, cy }`; `frame._es` holds `{ c, bar, hint, canvas }` where `c` is the color map from Task 1.
- Produces: `wireCytoscape(cy, frame, spec, dark)` (returns nothing; mutates the frame's bar and binds cy events).

- [ ] **Step 1: Add `wireCytoscape` and call it**

In `mix.exs`, immediately after the `renderCytoscape` function's closing `}` (the line `return { frame, cy };` then `}`), insert:

```javascript
        function wireCytoscape(cy, frame, spec, dark) {
          const { c, bar, hint } = frame._es;
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
```

Then update the loop body (the `const { frame } = renderCytoscape(spec, dark);` line) to:

```javascript
          const { frame, cy } = renderCytoscape(spec, dark);
          wireCytoscape(cy, frame, spec, dark);
          replacePre(preEl, frame);
```

- [ ] **Step 2: Build the docs and verify the controls are present in the embedded script**

Run: `mix docs 2>&1 | tail -3`
Expected: ends with `View html docs at "doc/index.html"`, no new warnings.

Run: `grep -o 'wireCytoscape\|es-cy-controls\|userZoomingEnabled\|es-cy-open' doc/EctoShorts.DynamicBuilders.html | sort -u`
Expected: all four markers (`es-cy-controls`, `es-cy-open`, `userZoomingEnabled`, `wireCytoscape`) appear.

- [ ] **Step 3: Manual browser check**

Open `doc/EctoShorts.DynamicBuilders.html` in a browser. Confirm:
- Graph is centered/fit on load, labels readable inside nodes.
- "Click to interact" hint shows, fades after clicking the graph; page scroll works over the graph until clicked.
- Zoom in / zoom out / fit buttons work; fit re-centers and clears any dimming.
- Typing in search dims non-matching nodes; clearing restores.
- Clicking a node dims the rest and emphasizes its edges; clicking the background clears it.

- [ ] **Step 4: Commit**

```bash
git add mix.exs
git commit -m "Add controls, scroll-guard, search, and focus to Cytoscape graphs

Zoom/fit buttons, search filter, click-to-highlight neighbors, and
double-click + Open-docs navigation for nodes carrying an href."
```

---

### Task 3: Wire navigation into the routing example + reduced-motion verification

Give the `DynamicBuilders` routing graph a title and per-node `href`s so the new navigation/highlight behavior is demonstrated, and confirm the reduced-motion path.

**Files:**
- Modify: `lib/ecto_shorts/dynamic_builders.ex` — the `## Operator routing` ` ```cytoscape ` block (the adapter/Normalizer nodes).

**Interfaces:**
- Consumes: node `data.href` and top-level `title` from Task 1/2.
- Produces: a rendered graph where the 4 adapter nodes and Normalizer are module cards linking to their ExDoc pages.

- [ ] **Step 1: Confirm the exact ExDoc page filenames for the adapter modules**

Run: `ls doc/ | grep -i 'ScalarExpr\|ArrayExpr\|CommonExpr\|MapExpr\|Normalizer'`
Expected: files like `EctoShorts.DynamicBuilders.Postgres.ScalarExpr.html` (use whatever the actual names are in the next step's hrefs; adjust if the module namespace differs).

- [ ] **Step 2: Add `title` and `href`s to the routing block**

In `lib/ecto_shorts/dynamic_builders.ex`, in the ` ```cytoscape ` block: add `"title": "Operator routing",` as the first key (before `"height"`), and add an `"href"` to each adapter/Normalizer node's `data`. Replace the five tier-2/3 node lines with (using the filenames confirmed in Step 1):

```json
      {"data": {"id": "norm",   "label": "Normalizer",  "tier": 3, "href": "EctoShorts.DynamicBuilders.Postgres.Normalizer.html"}},
      {"data": {"id": "scalar", "label": "ScalarExpr",  "tier": 2, "href": "EctoShorts.DynamicBuilders.Postgres.ScalarExpr.html"}},
      {"data": {"id": "array",  "label": "ArrayExpr",   "tier": 2, "href": "EctoShorts.DynamicBuilders.Postgres.ArrayExpr.html"}},
      {"data": {"id": "common", "label": "CommonExpr",  "tier": 2, "href": "EctoShorts.DynamicBuilders.Postgres.CommonExpr.html"}},
      {"data": {"id": "map",    "label": "MapExpr",     "tier": 2, "href": "EctoShorts.DynamicBuilders.Postgres.MapExpr.html"}},
```

Leave the seven operator nodes (`eq`, `like`, `agg`, `arr`, `cur`, `ex`, `json`) as plain chips with no `href`.

- [ ] **Step 3: Build the docs and verify the hrefs and title rendered into the block**

Run: `mix docs 2>&1 | tail -3`
Expected: ends with `View html docs at "doc/index.html"`, no new warnings.

Run: `grep -o 'Operator routing\|Postgres.ScalarExpr.html' doc/EctoShorts.DynamicBuilders.html | sort -u`
Expected: both `Operator routing` and `Postgres.ScalarExpr.html` appear inside the cytoscape code block.

- [ ] **Step 4: Manual check — navigation + reduced motion**

Open `doc/EctoShorts.DynamicBuilders.html`:
- Adapter nodes render as solid cards; operators as monospace chips.
- Clicking an adapter node shows "Open docs ↗" in the bar; clicking it (or double-clicking the node) navigates to that module's page.
- In browser devtools, emulate `prefers-reduced-motion: reduce` and reload: the hint shows/hides without a fade transition, and the graph still functions.

- [ ] **Step 5: Commit**

```bash
git add lib/ecto_shorts/dynamic_builders.ex
git commit -m "Wire routing graph adapters to their ExDoc pages

Title the operator-routing graph and link each adapter/Normalizer node
to its module docs, demonstrating click-highlight and navigation."
```

---

## Self-Review

**Spec coverage:**
- Readability (labels inside, monospace chips/module cards) → Task 1 node style. ✓
- Framed viewport, fit-on-load, bounded zoom, scroll-guard → Task 1 frame + Task 2 scroll-guard. ✓
- Controls (zoom/fit) + search/filter → Task 2. ✓
- Click highlight + double-click/affordance navigation, `data.href`/`data.kind` model → Task 1 (module-card inference) + Task 2 (focus/nav). ✓
- Example block title + adapter hrefs → Task 3. ✓
- Quality floor (reduced-motion, keyboard-focus, responsive, light/dark) → Task 1 CSS + Task 2 buttons/aria + reduceMotion. ✓
- Backward compatibility (additive fields, mermaid/dot untouched) → Task 1 keeps `reviveFns`, optional fields. ✓

**Placeholder scan:** No TBD/TODO; all steps carry full code or exact commands. Task 3 Step 1 intentionally confirms real filenames before hardcoding hrefs (not a placeholder — a verification gate).

**Type consistency:** `renderCytoscape` returns `{ frame, cy }`; `frame._es = { c, bar, hint, canvas }`; `wireCytoscape(cy, frame, spec, dark)` reads `frame._es`. `clearFocus`/`focusNode` are defined inside `wireCytoscape` and referenced only there (the Fit button calls `clearFocus`, defined in the same scope). Class names `es-dim`/`es-emph` match between the Task 1 style selectors and Task 2 toggles. ✓
