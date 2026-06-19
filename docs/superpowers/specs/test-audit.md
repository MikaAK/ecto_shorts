# Test Audit — existing suite vs. the v3.0.0 spec

Each existing test was checked against the spec
(`2026-06-19-query-building-api-refactor-design.md`). The spec is the source of
truth; where a test disagrees, the test is presumed wrong and is changed
deliberately (per §5 / decision G4). Per-test detail is in `test-audit/batch-*.md`.

## Totals (~456 tests)

| Batch | Scope | KEEP | CHANGE | NEEDS-DECISION |
|---|---|---|---|---|
| A | comparison, negation, casting, enum, boolean | 72 | 5 | 9 |
| B | aggregates, strings, date/datetime, having | 45 | 21 | 3 |
| C | array, map, field_types, schemaless, association | 25 | 12 | 4 |
| D | join, select, order, group, distinct, pagination, preload, exclude | 151 | 1 | 1 |
| E | parent_as, subquery, set ops, CTE, windows, ties, lock, update, bindings, parser | 78 | 28 | 20 |
| **Total** | | **~371** | **~67** | **~37** |

~81% of tests are unaffected. The changes cluster tightly by decision; the
"needs-decision" items dedupe to ~11 real questions (below).

## CHANGE items, grouped by driving decision

- **D-WIRE — date-math shape (~21):** every `date_wrappers`/`datetime_wrappers`
  test feeds `interval:` and tuple forms; the spec's caller key is a map with
  `unit:`. SQL expectations stay correct — only the input key/shape changes.
- **D-LIST — `:elements` removal & overlap (~13):** all schemaless `:elements`
  tests and the `field_types` `in:`→overlap test move to a bare list (membership)
  or the new `overlaps` operator.
- **D-OPERAND — `parent_as` (5):** new `%{parent: %{as:, field:}}` form, valid
  only inside a subquery/exists.
- **D-NULL — null padding removed (~6):** tests asserting `is_nil(x) OR x NOT IN …`
  for non-nil `!=`/not-in/`==`-with-list now assert plain SQL.
- **D-RAISE / D-PROVIDER (~7):** association-given-a-scalar, out-of-range `:at`,
  `:reverse_order`-without-order, and out-of-contract provider returns move from
  warn-and-skip to raising.

## NEW tests needed (behavior the spec introduces, not yet covered)
- the `overlaps` operator (list-column overlap)
- the operand convention: `{field:}`, `{from: "alias", …}`, `{parent: {as:, field:}}`
- string operator keys / full JSON-body request shapes (D-WIRE)
- date-math map form `%{count:, unit:}`
- raising on `:reverse_order`-without-order and on invalid `:at` positions (D-RAISE)
- the validate step's behavior on untrusted input (allow-list, casting, error data)

## OPEN QUESTIONS (deduplicated — your ruling needed before tests change)

**Q1 — Subquery source on the Elixir API.** ~8 quantified tests pass
`from: Comment` (a module). D-WIRE requires a registered string alias for *client*
input. Does the Elixir-facing API still accept a module (alias required only over
HTTP), or is the alias the only form everywhere?

**Q2 — `%{field: %{gt: nil}}` (a non-nil operator given nil).** A test expects it
to raise. §3.9 doesn't list it; the default for a meaningless combo is
warn-and-skip. Raise, or warn-and-skip?

**Q3 — List-column operator completeness.** With `:elements` gone the spec has
`overlaps` and `count` but **no array-equality operator**, and doesn't define what
an explicit `==`/`!=` + list means on a list column. Tests assert array equality
(`tags == ["a","b"]`). Add an `equals`/`==` array form? Define `==`/`!=`-with-list
on array columns as equality vs membership?

**Q4 — Multi-key JSONB containment.** `%{data: %{contains: [k1: v1, k2: v2]}}`
today expands to two ANDed `@>` checks. §2.2 shows only the single-key `contains`.
Keep the keyword-list expansion, and in what shape?

**Q5 — Date-math caller key set.** Is the caller key `unit:` only, or also
`interval:`, or a keyword list `[count: 1, interval: "month"]`? And the datetime
`add` operand (`%{field:, count:, interval:}`) vs §1.5a's arithmetic `add`
(ordered list) are two different `add`s — which is canonical for each?

**Q6 — `trim`/`ltrim`/`rtrim` operators.** Not in the spec's operator lists and no
test uses them. Confirm they are intentionally out of scope (vs. add to the core).

**Q7 — Atom-keyed fields on schemaless sources.** §3.3 gates *text* field names
behind `:allowed_keys`. Confirm atom keys stay "use as-is" (an Elixir caller is
trusted), while text keys (HTTP) require the allow-list.

**Q8 — Malformed *value shapes*: warn or raise?** §3.9 covers does-not-apply
(warn) and provider-*return* (raise), but not a malformed value shape — e.g. a
`:lock` value that isn't `%{name: …}`, an unresolvable lock name, or
`reverse_order: false`. Are these caller-mistakes (raise) or warn-and-skip?

**Q9 — Provider `{:error, reason}` return.** §3.10 lists "error" as an in-contract
shape but also says out-of-contract returns raise. Confirm `{:error, …}` stays a
quiet warn-and-skip (in-contract), not a raise.

**Q10 — White-box internal tests (`parser_test`, `update_expr_test`).** These test
internal modules slated for rename/removal (D-INTERNAL). Re-point them through the
public `convert_params_to_filter`, delete them, or keep direct and accept churn?

**Q11 — Sibling-binding references (gap you raised).** No operand can reference a
column on a *sibling* named binding within the same query (`{field:}` = current
binding; `{parent:}` = outer query). Proposed fix: `{field: :col, as: "binding"}`,
validated against the query's bindings — and the same for `:select` of a sibling
binding's columns. Confirm scope (operand RHS only, or also left-hand filtering /
select).

## RESOLUTIONS (decided; folded into the spec)

| Q | Decision | Spec |
|---|---|---|
| Q1 | Elixir accepts a schema **module** subquery source; HTTP requires a **registered string alias**. | §1.5a, D-ELIXIR-FIRST |
| Q2 | `%{field: %{gt: nil}}` (ordering operator vs nil) **raises**. | §3.9, D-RAISE |
| Q3 | `eq`/`ne` + list on a **list column** = exact array equality; bare list = membership (routing by column type). No new operator. | §1.5, D-LIST |
| Q4 | Multi-key `contains` is **kept** — every key/value must be contained (ANDed). | §1.5, §2.2 |
| Q5 | Date-math caller key is **`%{count:, unit:}` only**; the timestamp-shift word is **`shift`** (not `add`), so it never clashes with arithmetic `add`. | §1.5, D-WIRE, D-ADD-SHIFT |
| Q6 | `trim`/`ltrim`/`rtrim` are **added** to the core text transforms. | §1.5, D-TRIM |
| Q7 | **Atom** keys (Elixir) are trusted and pass through; **text** keys (HTTP) are gated by schema/`:allowed_keys`. | §1.7, §3.3, D-ELIXIR-FIRST |
| Q8 | Malformed **value shapes raise** (Elixir) / 4xx (HTTP). | §3.9, D-RAISE |
| Q9 | Provider in-contract `{:error, reason}` **warns-and-skips**; only out-of-contract returns raise. | §3.9, §3.10, D-PROVIDER |
| Q10 | White-box internal tests **re-point to the public API**; tests for removed internals (e.g. `Parser`) are deleted. | §5, D-INTERNAL |
| Q11 | Add a `%{field: :col, as: :binding}` **sibling-binding** reference, usable in operand RHS, left-hand filter, `:select`, and `:order_by`. | §1.5a, §3.4, D-SIBLING |

With these settled, every `NEEDS-DECISION` row in `batch-*.md` now has a ruling;
the per-test changes can proceed mechanically during implementation.
