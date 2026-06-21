# lib/ecto_shorts/dynamic_builders — Database Adapter System

This directory contains the code that turns a resolved filter predicate into an Ecto `DynamicExpr` — the internal representation of a `WHERE` clause condition.

## Two layers

There are two files at this level:

| File | Role |
|---|---|
| `dynamic_builders.ex` (parent directory) | **Dispatcher** — selects which adapter to use and calls it |
| `postgres.ex` | **Postgres adapter** — receives the resolved predicate and dispatches to a sub-module |

The dispatcher (`dynamic_builders.ex`) resolves the adapter in this order:
1. The `:dynamic_builder` option at the call site.
2. `Config.dynamic_builder_module/0` (from app config).
3. Auto-detected from `repo.__adapter__/0` — Postgres is the only built-in adapter.

## How the Postgres adapter works

`postgres.ex` receives a `Predicate` struct and uses its `:routing` field to decide which sub-module handles the expression:

| Routing value | Sub-module | What it handles |
|---|---|---|
| `:scalar` | `postgres/scalar_expr.ex` | Comparisons, equality, `in`, `like`, `ilike`, negation, aggregates, arithmetic |
| `:array` | `postgres/array_expr.ex` | Postgres array operators (`&&`, `@>`, `<@`, array `in`) |
| `:map` | `postgres/map_expr.ex` | JSONB operators (`@>`, `<@`, `jsonb_exists`) |
| `:common` | `postgres/common_expr.ex` | Cursor pagination (`:before`, `:after`, `:since`, `:until`), `:exists` |

`postgres.ex` also calls `postgres/field_accessors.ex` to resolve which binding variable to use for a given field and binding selector.

## Sub-directory

- `postgres/` — the Postgres adapter and its sub-modules. See [postgres/AGENTS.md](postgres/AGENTS.md).

## Adding a new adapter

To support a different database, implement `EctoShorts.DynamicBuilder` (see `dynamic_builder.ex` in the parent directory). You only need one callback: `build_dynamic/3`.

## Reducer Contract

Dynamic builders dispatch based on resolved predicate structures, not raw params collections.

**Rule:** When receiving a `Predicate` struct from `PredicateBuilder`, use its `:routing` field to select the appropriate expression builder. Do not re-examine field types or make routing decisions — that has already been done.

## Public vs Internal Forms

- **Public API**: filter params maps and keyword lists passed to `CommonFilters.convert_params_to_filter/3`.
- **Internal dispatch**: `Predicate` structs created by `PredicateBuilder`, carrying fully resolved field type, operator, routing family, and negation state.

Tuples like `{:scalar, expr}` are internal and must never appear in public filter examples.

## String-Key Safety

All string keys are normalized to atoms by `EctoShorts.CommonFilters.Normalizer` before reaching the dynamic builder. Adapter implementations receive atom-keyed predicates and must not do string→atom conversion themselves.

## Error Protocol

- Return `{:ok, dynamic_expr}` or `{:error, reason_atom}`.
- Never return bare `:skip`.
- Callers match `{:error, _} ->` not `:skip ->`.
