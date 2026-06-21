# lib/ecto_shorts/dynamic_builders/postgres — Postgres Adapter

This directory contains the PostgreSQL-specific implementation of `EctoShorts.DynamicBuilder`. Every file here contributes to building Ecto `DynamicExpr` values for Postgres-flavoured SQL.

## Entry point

`postgres.ex` in this directory is the main adapter module. It implements `EctoShorts.DynamicBuilder` and receives a fully resolved `Predicate` struct from `PredicateBuilder`. It uses the predicate's `:routing` field to dispatch to one of the sub-modules.

## Sub-modules

| File | Routing value | What expressions it builds |
|---|---|---|
| `scalar_expr.ex` | `:scalar` | The most common case. Handles `==`, `!=`, `>`, `<`, `>=`, `<=`, `in`, `not in`, `like`, `ilike`, `is_nil`, negation, aggregates (`count`, `sum`, `avg`, `min`, `max`), and arithmetic comparisons. See `scalar_expr/` for sub-modules. |
| `array_expr.ex` | `:array` | Postgres array operators: `&&` (overlap), `@>` (contains), `<@` (contained by), array-specific `in`. Used when the field type is `{:array, _}` or the `:array` wrapper is used. |
| `map_expr.ex` | `:map` | JSONB operators: `@>` (contains), `<@` (contained by), `jsonb_exists`. Used when the field type is `:map` or `:string` (for JSONB columns). |
| `common_expr.ex` | `:common` | Cursor-style pagination: `:before`, `:after`, `:since`, `:until`. Also handles the `:exists` operator. |
| `field_accessors.ex` | (called by all) | Resolves the binding variable for a given field and binding selector. Returns an `Ecto.Query` field reference compatible with `dynamic/2`. |

There is also a `Normalizer` module (inside `scalar_expr.ex` or a sibling file) that converts operator aliases before dispatch:
- `:eq` → `:==`
- `:neq` → `:!=`
- `:lt` → `:<`
- `:lte` → `:<=`
- `:gt` → `:>`
- `:gte` → `:>=`
- `:downcase` → `:lower`
- `:upcase` → `:upper`

## Sub-directory

- `scalar_expr/` — further sub-modules for scalar expression families. See [scalar_expr/AGENTS.md](scalar_expr/AGENTS.md).

## Routing decision

The routing family (`:scalar`, `:array`, `:map`, `:common`) is assigned in `PredicateBuilder` (in the `common_filters/` directory), not here. By the time `postgres.ex` sees the predicate, routing is already resolved. The Postgres adapter does not re-examine field types.

## Schemaless queries

When the source is a schemaless `{source, schema}` tuple with `schema: nil`, field type information is unavailable. The routing family defaults to `:scalar`. To force array routing on a schemaless source, use the `:array` wrapper: `%{tags: %{array: %{in: ["a", "b"]}}}`.

## Reducer Contract

Each sub-module in this directory (`scalar_expr.ex`, `array_expr.ex`, etc.) receives a fully resolved `Predicate` struct. The routing family has already been determined.

**Rule:** Use the predicate's `:operator` and `:value` fields directly. Do not iterate or re-interpret the structure — the predicate is a single resolved operation, not a collection.

## Public vs Internal Forms

- **Public API**: filter params maps and keyword lists passed to `CommonFilters.convert_params_to_filter/3`.
- **Internal dispatch**: `Predicate` structs created by `PredicateBuilder`. These carry operator, value, routing family, and negation state.

A Postgres adapter never exposes tuples like `{:scalar, expr}` in public examples.

## String-Key Safety

All string keys have been normalized to atoms before the Postgres adapter receives them. Implementations must not call `String.to_atom/1`.

## Error Protocol

- Return `{:ok, dynamic_expr}` or `{:error, reason_atom}`.
- Never return bare `:skip`.
- Callers match `{:error, _} ->` not `:skip ->`.
