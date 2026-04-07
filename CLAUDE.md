# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# Setup
mix deps.get
mix ecto.setup          # creates + migrates the dev DB

# Test (requires a running PostgreSQL instance)
mix test                                          # all tests
mix test test/path/to_file_test.exs               # single file
mix test test/path/to_file_test.exs:42            # single test by line

# Code quality
mix credo                # static analysis (blitz_credo_checks rules apply)
mix dialyzer             # type checking (PLT stored in ./dialyzer/)

# Coverage
mix coveralls            # console report
mix coveralls.html       # HTML report
```

The test DB is `ecto_shorts_test` on `localhost:5432` (postgres user, no password by default). Tests run inside `Ecto.Adapters.SQL.Sandbox` transactions and use `EctoShorts.DataCase` as the base case for any test that hits the database.

## Architecture

EctoShorts is a library (not an application) that exposes a data-driven query API on top of Ecto. Version 3.0.0 is on this branch.

### Core public API

| Module | Role |
|---|---|
| `EctoShorts.Actions` | Repo wrapper — `all/3`, `get/3`, `create/3`, `update/3`, `delete/3`, etc. Reads use the replica; writes use the primary repo. |
| `EctoShorts.CommonFilters` | Main query language. Converts a map or keyword list of params into an `Ecto.Query`. |
| `EctoShorts.CommonChanges` | Changeset helpers — `put_or_cast_assoc`, many-to-many member-update shorthand. |
| `EctoShorts.CommonParams` | Helpers for building param maps (timestamps, placeholders). |

### Filter pipeline (`CommonFilters`)

`convert_params_to_filter/3` is the entry point:

1. Coerces params to a keyword list.
2. Runs a **sorter** that reorders entries: `where` → all others → `or_where` → terminal filters (`last`, `subquery`).
3. Reduces over the sorted list, dispatching each key via `apply_filters/6`.

`apply_filters` routes keys into one of several families:
- **Binding operators** (`:as`, `:at`) — retarget subsequent filters to a named or positional binding.
- **Predicate filters** (`:where`, `:or_where`) and boolean groups (`:and`, `:or`) — build `DynamicExpr` via `DynamicBuilders`.
- **Association shorthand** — any key matching a declared schema association triggers an implicit join and recurses with the association's source.
- **Structural filters** (`:join`, `:order_by`, `:group_by`, `:having`, `:select`, `:with_cte`, `:subquery`, etc.) — delegated to dedicated sub-modules under `lib/ecto_shorts/common_filters/`.

### Dynamic expression layer

`EctoShorts.DynamicBuilders` selects a database-specific adapter:
1. `:dynamic_builder` option at call time (runtime override)
2. Auto-detected from `repo.__adapter__/0` — only `Ecto.Adapters.Postgres` is currently supported

To set a global default via app config, use `:dynamic_builder_module` (see Config table below).

The concrete implementation lives in `EctoShorts.DynamicBuilders.Postgres`, which delegates to four sub-modules:
- `ScalarExpr` — comparisons, equality, `in`, `like`, `ilike`, negation, aggregates
- `ArrayExpr` — Postgres array operators
- `CommonExpr` — cursor operators (`:before`, `:after`, `:since`, `:until`), timestamp filters, `:exists`
- `MapExpr` — JSONB operators (`@>`, `<@`, `jsonb_exists`)
- `Normalizer` — normalises raw filter values and aliases operators (`:eq`→`:==`, `:downcase`→`:lower`, etc.)

### Operator wrappers

Three wrapper keys provide unambiguous namespacing for operations that could conflict with schema field names:

| Wrapper | Example | Effect |
|---|---|---|
| `:arithmetic` | `%{score: %{arithmetic: %{compare: :>, add: %{field: :base, value: 5}}}}` | Computed field comparison using `+`, `-`, `*`, `/` or datetime ops |
| `:aggregate` | `%{score: %{aggregate: %{fn: :avg, compare: :>, value: 5}}}` | SQL aggregate function comparison |
| `:elements` | `%{tags: %{elements: %{in: ["a", "b"]}}}` | Forces `ArrayExpr` routing regardless of schema |

`:downcase` and `:upcase` are aliases for `:lower` and `:upper`.

### Adapter behaviours (extension points)

| Behaviour | Purpose |
|---|---|
| `EctoShorts.Adapter.QueryBuilder` | Override how a filter key is applied to the query. Implement `build_query/6` and set `config :ecto_shorts, query_builder_module: MyModule`. |
| `EctoShorts.Adapter.DynamicBuilder` | Override dynamic expression building for a different DB dialect. Implement `build_dynamic/4` and pass `:dynamic_builder` at call time or set `config :ecto_shorts, dynamic_builder_module: MyModule`. |
| `EctoShorts.Adapter.QueryProvider` | Supply named query fragments referenced by the `:lock` filter or other structural filters. |

`:dynamic_builder` (no `_module`) can be passed as a runtime opt to any `Actions` or `CommonFilters` call for a per-call DynamicBuilder override. `:query_builder_module` is the runtime opt key for overriding the `QueryBuilders` adapter.

### Configuration keys (`config :ecto_shorts, ...`)

| Key | Default | Notes |
|---|---|---|
| `:repo` | `nil` | Primary repo for writes |
| `:replica` | `nil` | Read replica; falls back to `:repo` |
| `:dynamic_builder_module` | auto-detected | `DynamicBuilder` implementation (runtime opt key is `:dynamic_builder`) |
| `:query_builder_module` | `nil` | `QueryBuilder` override (same key for app config and runtime opts) |
| `:query_provider_module` | `nil` | Named query-fragment provider |
| `:error_module` | `EctoShorts.Actions.Error` | Error-response builder for `Actions` |
| `:max_positional_bindings` | `nil` (default 10) | Upper bound for `:at` positional bindings |

### Test support

- `test/support/data_case.ex` — `EctoShorts.DataCase`, wraps each test in a sandbox transaction.
- `test/support/schema/` — lightweight Ecto schemas used across all tests (`Post`, `User`, `Comment`, `Book`, etc.).
- Tests are split between `test/ecto_shorts/common_filters/` (schema-backed) and `test/ecto_shorts/common_filters_schemaless/` (schemaless `{source, schema}` tuple queries) — new filter tests usually need entries in both directories.

## Gotchas

### `:hints` is compile-time only

The `:hints` config key (index hint strings passed to joins) is read with `Application.compile_env/2` inside `CommonFilters.Join`. Changes take effect only after recompilation — setting them at runtime has no effect.

### `QueryBinding` generates clauses at compile time

Every filter sub-module calls `EctoShorts.QueryBinding.query_binding_contracts/1` at the top of its body to generate one function clause per binding shape (root, named, and up to `max_positional_bindings` positional bindings). Increasing `max_positional_bindings` increases compile time proportionally. New filter modules must call `query_binding_contracts` before defining their `build_query` clauses.

### `:elements` required for schemaless array operations

Without schema type information, `%{tags: %{in: ["a", "b"]}}` on a schemaless source routes to `ScalarExpr` (scalar `IN`), not array overlap (`&&`). Use the `:elements` wrapper to force `ArrayExpr` routing: `%{tags: %{elements: %{in: ["a", "b"]}}}`. Schema-backed sources are unaffected — field type inference routes automatically.

## Adding a new filter

1. Create `lib/ecto_shorts/common_filters/my_filter.ex` implementing `@behaviour EctoShorts.Adapter.QueryBuilder` with a `build_query/6` callback. Call `EctoShorts.QueryBinding.query_binding_contracts(__MODULE__)` at module body level (outside any function).
2. In `CommonFilters`, add your module to the existing alias block and add a new `@my_filters [:my_key]` module attribute.
3. Append `@my_filters` to `@all_filters` via `Enum.concat`.
4. Add a dispatch clause with a `when filter in @my_filters` guard:
   ```elixir
   defp do_build_query(filter, source, query, selected_binding, term, opts)
        when filter in @my_filters do
     MyFilter.build_query(filter, source, query, selected_binding, term, opts)
   end
   ```
   Place it before the final `@predicate_filters` clause.
5. Add tests in both `test/ecto_shorts/common_filters/` and `test/ecto_shorts/common_filters_schemaless/`.
