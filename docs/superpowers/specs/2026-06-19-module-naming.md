# Module Naming — Decisions for the Query-Building Family

A cohesive-naming pass over the EctoShorts module family. Goal: accurate names,
one coherent family. Driving constraint: **released public API cannot be renamed**,
and the public `Common*` family is **anchored by the frozen `CommonChanges`**, so
the whole public `Common*` set keeps its prefix for cohesion.

## Frozen — do NOT rename

| Reason | Modules |
|---|---|
| Released public API (predates / anchors the family) | `EctoShorts`, `EctoShorts.Actions` (+ public `Actions.Error`, `Actions.Source`), `EctoShorts.CommonChanges` |
| Public `Common*` family (kept cohesive with `CommonChanges`) | `CommonFilters`, `CommonParams` (+ `Placeholders`/`Timestamps`), `CommonSchema`, `CommonQuery` |
| Behaviours / extension points (callers implement them) | `EctoShorts.QueryBuilder`, `EctoShorts.DynamicBuilder`, `EctoShorts.QueryProvider` |
| Established helpers | `Config`, `Types`, `QueryBinding`, `SchemaHelpers`, `Testing`, `Utils`, `LogUtils` |

Rationale: renaming public or extension modules breaks callers; renaming part of
the `Common*` family while `CommonChanges` is frozen would *destroy* cohesion.

## Renames — new / internal modules, where a clearer name adds accuracy

| # | From | To | Why |
|---|---|---|---|
| 1 | `EctoShorts.QueryBuilder.PredicateBuilder` (struct + builder, just-added) | `EctoShorts.CommonFilters.PredicateBuilder` and struct `EctoShorts.CommonFilters.Predicate` | They are the heart of the CommonFilters pipeline → join its family. Avoids nesting under the `QueryBuilder` *behaviour* (a behaviour shouldn't double as a namespace). |
| 2 | The ~30 filter implementations `EctoShorts.CommonFilters.<Name>` (files in `common_filters/filters/`) | `EctoShorts.CommonFilters.Filters.<Name>` | Module name should mirror the file path; groups all filter impls under one namespace, distinct from `Builder`/`Parser`/`Predicate`/`PredicateBuilder`. Internal + new-in-3.0.0 → safe. |
| 3 | `EctoShorts.DynamicBuilders.Postgres.CommonExpr` | `EctoShorts.DynamicBuilders.Postgres.ShorthandExpr` | "Common" says nothing; it handles the id/date **shorthand** operators (`ids`, `before`, `start_date`, `exists`). Keeps the cohesive `*Expr` family: Scalar / Array / Map / Shorthand. |
| 4 | `EctoShorts.DynamicBuilders` (the bare selector module with `build_dynamic`) | `EctoShorts.DynamicBuilders.Resolver` | Removes the confusing near-twin of the `DynamicBuilder` **behaviour**. After this, `DynamicBuilders` is purely a namespace: `DynamicBuilders.Resolver` picks the adapter, `DynamicBuilders.Postgres` is an adapter, `DynamicBuilder` (singular) is the contract. `Postgres` stays put (no frozen-module move). |

## Things deliberately NOT changed
- The `*Expr` family names `ScalarExpr` / `ArrayExpr` / `MapExpr` — already accurate.
- `CommonFilters.Builder` / `CommonFilters.Parser` — stay at the `CommonFilters.*`
  level (their files are *not* in `filters/`), distinct from the `Filters.*` impls.
- `Actions.*` internal submodule names (Batch/Bulk/CRUD/Multi/Transaction) — fine.
- Minor casing (`SubQuery`): leave unless it lands in the `.Filters.` move anyway.

## Migration notes (caller-visible, v3.0.0)
- `EctoShorts.DynamicBuilders.build_dynamic/4` → `EctoShorts.DynamicBuilders.Resolver.build_dynamic/4`.
- The `Predicate`/`PredicateBuilder` modules live under `CommonFilters` (new, no prior release).
- Filter impl modules move under `CommonFilters.Filters.*` (internal; only matters to anyone who reached into them directly).

## Application
Names above are applied to the spec and Plans 01–05. The `.Filters.` rename (#2)
is mostly a code-time change (the planning docs reference filters by key/path, not
module name); it is recorded here and applied during implementation.
