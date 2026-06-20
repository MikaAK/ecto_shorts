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
