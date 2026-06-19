# Test Organization for Multi-Adapter Support

**Date:** 2026-06-19
**Status:** Superseded in part — see "Revision" below.

## Revision: mirror `lib/`, not semantic families

The feature-family scheme below (`filters/{predicates,structural,clauses}/` +
`filters_schemaless/`) was implemented, then **reverted**: the family names mapped to
nothing in `lib/`, so a reader could not navigate from a test back to the module it
covers. The final structure mirrors `lib/` path-for-path instead.

**Final structure:**

```
test/ecto_shorts/
  actions/                              # mirrors lib/ecto_shorts/actions/
  common_filters_test.exs               # common_filters.ex — entry routing, assoc shorthand, sorter
  common_filters/
    builder_test.exs                    # builder.ex (+ :exclude)
    predicate_builder_test.exs          # predicate_builder.ex — casting, boolean groups, field resolution
    filters/                            # mirrors common_filters/filters/ — one file per filter module
  common_params/
  dynamic_builders/
    postgres/                           # scalar_/array_/map_/common_expr — unit tests
                                        #   + operator/predicate behavior (no 1:1 lib module)
                                        #     as `describe` blocks tagged @describetag feature:
    contract/contract_test.exs          # walks EctoShorts.FilterContract.cases/0
  query_binding_test.exs                # query_binding.ex (+ :at out-of-range, parent_as)
```

**Operator/predicate tests** (comparison, string, negation, array, JSONB, dates,
casting) have no 1:1 lib module — they are produced by the dynamic-builder adapter +
`predicate_builder.ex`, exercised through the public `common_filters.ex` entry. Each
is merged into the test file of the module that **implements** it.

**Schemaless variants** are not a separate tree: each module's test file holds both
schema-backed and schemaless cases, the latter tagged `@describetag schema_mode:
:schemaless`. The `feature:` axis is preserved per merged block via `@describetag`,
so `mix test --only feature:<name>` / `--only schema_mode:schemaless` still works.

**One file per lib module — no shared files.** Every filter module in
`common_filters/filters/` has its own dedicated test file, including the
set-operation family (`union`, `union_all`, `intersect`, `intersect_all`, `except`,
`except_all` — six files) and the ordering modules (`order_by`, `prepend_order_by`,
`reverse_order` — separate files). `:first` is implemented by `Limit`
(`builder.ex` → `Limit.build_query(:limit, …)`), so its tests live in
`filters/limit_test.exs`, not a `first` file.

The retained decisions from the original design — the data-driven cross-adapter
contract (`test/support/filter_contract.ex` + `dynamic_builders/contract/`) and the
`adapter:`/`feature:`/`schema_mode:` tag axes — are unchanged.

---

_Original design (semantic families) follows; kept for history._

**Date:** 2026-06-19
**Status:** Superseded by the Revision above.

## Problem

The test suite (73 files) mirrors `lib/` module-for-module. Two failures:

1. **Hard to find relevant tests.** `test/ecto_shorts/common_filters/` is 40+ flat
   files. There is no grouping above the per-feature filename.
2. **No place for a second DB adapter.** The only DB-specific tests live buried in
   `dynamic_builders/postgres/`. A NoSQL adapter — which does **not** produce an
   `Ecto.Query` AST — has nowhere to slot in, and the adapter-agnostic filter
   semantics are entangled with Postgres-specific output assertions.

### Root cause: four axes, one folder tree

A test is locatable along four independent axes, but a single folder hierarchy can
encode only one:

| Axis | Example question |
|---|---|
| Layer | "integration vs filter-pipeline vs adapter-internal?" |
| Feature | "where are the `:in` operator tests?" |
| Schema mode | "schema-backed or schemaless?" |
| Adapter | "Postgres or NoSQL?" |

Today's structure forces three of these into filenames or silent duplication. That
is the friction.

## Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Adapter test model | **Shared contract + adapter specifics** | A contract suite every `DynamicBuilder` must satisfy, plus thin per-adapter suites for dialect-only features. Matches the `DynamicBuilder` behaviour extension point. |
| Schema-mode duplication | **Keep separate, mirror dirs** | Literal stack traces over DRY. No macro generates schema/schemaless variants. |
| Contract mechanism | **Data-driven (example list + visible loop)**, not a test-generating macro | Failures point at real test lines; consistent with the no-macro-magic preference. |
| Primary folder axis | **Layer (≈ mirror lib)** | Keeps Elixir's idiomatic convention and `mix test` / IDE jump-to-test tooling working. |
| Remaining axes | **Filenames (feature) + ExUnit tags (schema mode, adapter)** | Find by any axis without moving a file. |

## Target structure

```
test/ecto_shorts/
  actions/                  # UNCHANGED — repo integration, hits DB (DataCase)
  common_params/            # UNCHANGED
  *_test.exs                # UNCHANGED — top-level module units (config, utils, source…)

  filters/                  # filter pipeline, schema-backed
    predicates/             #   WHERE/value semantics — what rows match
    structural/             #   query shape — joins, bindings, CTEs, subqueries
    clauses/                #   terminal clauses — ordering, paging, projection
  filters_schemaless/       # MIRROR of filters/ — schemaless variants, same subfolders
    predicates/             #   only files with a genuine schemaless variant appear;
    structural/             #   no empty stubs
    clauses/

  dynamic_builders/         # adapter internals (mirror lib)
    postgres/               #   array_expr, map_expr, scalar_expr, common_expr (existing)
    contract/               # NEW — adapter-neutral contract (data-driven)
    # mongo/  ← later, slots in with zero restructuring
```

### Feature families

The 40 flat `common_filters/*` files regroup by what they shape:

```
predicates/   comparison_operators, negation, string_matching, string_transformations,
              boolean_composition, aggregate_operators, date_wrappers, datetime_wrappers,
              enum_casting, typed_value_casting, field_types_opt, map_field,
              association_filter, predicate_builder, invalid_schema_field

structural/   join, subquery, with_cte, recursive_ctes, set_operation, parent_as,
              with_named_binding, out_of_range_binding, lock, put_query_prefix,
              preload, windows, distinct, group_by, having, exclude, update_expr

clauses/      sorting, order_modifier, first, last, limit, offset, page, with_ties,
              select, select_merge, update
```

The three families are the contract. A borderline file (e.g. `having`) may shift
bucket during execution; the bucketing is a starting map, not a frozen index.

### Naming: "integration" / "end-to-end" reserved for DB tests

"Integration" and "end-to-end" are synonyms — both connote exercising the whole
stack, including a real database. They apply **only** to DB-hitting tests under
`actions/` (`DataCase`, sandbox, `async: false`).

Filter tests assert the `convert_params_to_filter` pipeline *output* (an `Ecto.Query`
AST) and never touch the DB; they are **feature tests**, not integration tests, and
must not be named `end_to_end` / `integration`.

Consequence: the existing `common_filters_plan03_04_end_to_end_test.exs` is **not** a
layer of its own. Its cases are distributed into the feature files they actually
exercise (`overlaps` → `predicates/`, `trim` → `predicates/string_transformations`,
etc.). A filename derived from a release-plan number is itself a "hard to find"
symptom and is removed.

## Mechanisms

### Cross-adapter contract (data, not macro)

```elixir
# test/support/filter_contract.ex
defmodule EctoShorts.FilterContract do
  @moduledoc "Adapter-agnostic filter cases every DynamicBuilder must satisfy."
  def cases do
    [
      %{name: "eq scalar", params: %{id: %{==: 1}},      semantics: {:eq, :id, 1}},
      %{name: "in list",   params: %{id: %{in: [1, 2]}}, semantics: {:in, :id, [1, 2]}},
      # …
    ]
  end
end
```

Each adapter's `dynamic_builders/<adapter>/contract_test.exs` writes a **visible loop**
over `FilterContract.cases()`, asserting its own output shape:

- Postgres → an `Ecto.Query` (via existing `assert_query`/`assert_sql`).
- NoSQL → that adapter's query document/map.

The `for`-bound case name appears in each assertion's description, so a failure names
the case and points at the real test line. Dialect-only behavior (PG arrays/JSONB,
NoSQL-only operators) stays in ordinary files alongside the contract file.

### Tags (the remaining axes)

```elixir
@moduletag adapter: :postgres        # every file asserting postgres output
@moduletag schema_mode: :schemaless  # every filters_schemaless/ file
@moduletag feature: :comparison      # per feature file
```

```bash
mix test --only adapter:postgres
mix test --only schema_mode:schemaless
mix test --only feature:comparison
```

Find by any axis without relocating a file.

## What does NOT change

- `actions/`, `common_params/`, and top-level `*_test.exs` module units stay put.
- `dynamic_builders/postgres/` existing files stay; only the new `contract/` is added.
- No macro generates schema vs schemaless variants — they remain literal, separate files.
- Test *content* is moved/regrouped and tagged, not rewritten. Behavior coverage is
  preserved; this is a reorganization, not a test-logic change.

## Out of scope

- Implementing the NoSQL adapter itself. This design only ensures the test tree has a
  ready, zero-restructuring slot for it.
- Changing `EctoShorts.Testing` / `DataCase` helper APIs.
- Adding or removing test cases beyond what the regroup mechanically requires.
