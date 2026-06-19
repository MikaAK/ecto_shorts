# Query-Building Refactor — Plan Index

The spec (`docs/superpowers/specs/2026-06-19-query-building-api-refactor-design.md`)
covers the whole query-building pipeline. Per the writing-plans scope check, it is
split into **six sequential plans**, each producing working, testable software. A
plan is fully expanded into bite-sized TDD tasks **before** it is executed; this
index is the map.

| # | Plan | Delivers | Key decisions |
|---|---|---|---|
| 01 | `TermResolver` foundation | A pure, dialect-agnostic translator: operator canonicalization (atom + string safe-list), field resolution, casting, routing family, and the **core** canonical-term output. No wiring yet — unit-tested in isolation. | D-ELIXIR-FIRST, D-WIRE (string ops), D-COLLISION, routing (§3.4) |
| 02 | Pure Expr + `comparison_impl` decomposition | Behavior-preserving refactor: split the ~373-line `comparison_impl` into per-family dispatchers; make `CommonExpr` pure (column passed in). Guarded by the existing `assert_sql` suite. *(Shrinking `build_dynamic` to a thin adapter moves to Plan 05 — it depends on `TermResolver` being wired.)* | D1, D-CommonExpr-FIELD, B1/B2 |
| 03 | Operand convention + new capabilities | `value`/`field`/`from`/`parent` operands, sibling `as:`, binary arithmetic, `overlaps`, exact array equality, `shift`/`unit` date-math, `trim`/`ltrim`/`rtrim`. | D-OPERAND, D-SIBLING, D-LIST, D-ADD-SHIFT, D-TRIM |
| 04 | Behavior changes | D-NULL (plain-SQL nulls), D-RAISE (incl. malformed-value & `gt nil`), D-ONE-WAY, D-PROVIDER, single-pass `sort_filter_params` (D2), aggregate→HAVING + auto-GROUP-BY. | D-NULL, D-RAISE, D-ONE-WAY, D-PROVIDER, D2 |
| 05 | CommonFilters wiring + thin adapter | Route predicates through `TermResolver` → a thin `build_dynamic` adapter (the tidying removed from `Postgres`); move `common_field_for` into `TermResolver`; aggregate→HAVING; integrate end-to-end; reconcile both suites. | integration, D-CommonExpr-FIELD |
| 06 | Validate step (HTTP entry) | Allow-listing, casting-to-errors-as-data, configurable limits; settles the §8 open items (error-data shape, registered-alias registry, limit defaults). | D-WIRE, D-RAISE (HTTP→4xx) |

**Test reconciliation** (the ~67 audit CHANGEs in `docs/superpowers/specs/test-audit.md`)
folds into whichever plan owns each behavior — not a separate plan. Each plan's
tasks include updating the specific tests its decision touches.

**Sequencing:** strictly in order — 02 depends on 01's canonical-term shape, 03–04
extend it, 05 wires it in, 06 sits in front for HTTP. Each plan is independently
green (`mix test` passes) at its end.

**Status:** Plan 01 is fully expanded (`...-01-term-resolver.md`). Plans 02–06 are
expanded just-in-time before execution.
