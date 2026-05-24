# EctoShorts: Product and Design Requirements

## Problem Statement

Elixir applications that use Ecto accumulate large volumes of repetitive query boilerplate. Every feature needs variations of `from x in Schema, where: x.field == ^value` expanded with `order_by`, `limit`, `preload`, and join clauses. This boilerplate scales poorly: as the number of schemas and query shapes grows, so does the surface area for bugs and inconsistency.

EctoShorts solves this by exposing a **data-driven query API**. Callers pass a parameter map describing what they want; EctoShorts compiles that map into an `Ecto.Query` at runtime. No hand-written query fragments are required for standard filter patterns.

## Intended Users

- Elixir and Phoenix developers building applications on top of Ecto.
- Teams using PostgreSQL as their primary database (the only fully-supported adapter in v3).
- Library authors who want to expose a filterable data layer without committing to a specific query shape.

## Core Value Propositions

### 1. Unified Filter API

A single entry point, `EctoShorts.CommonFilters.convert_params_to_filter/3`, converts any map or keyword list into an `Ecto.Query`. Callers never write `where` clauses directly for standard patterns.

```elixir
EctoShorts.Actions.all(User, %{
  age: %{gte: 18, lte: 50},
  name: %{ilike: "steven"},
  preload: [:address],
  last: 5
})
```

### 2. Bulk, Batch, and Multi Operations

`EctoShorts.Actions` wraps not just single-record CRUD but also:
- `insert_all`, `update_all`, `delete_all` for set-based operations
- `create_many`, `update_many`, `delete_many` for list-oriented batch work
- `batch` for chunked processing
- `transaction` and `transact` for explicit transaction control
- `find_or_create`, `find_and_upsert`, `find_and_update` for common upsert patterns

### 3. Pluggable Adapters

Three behaviour contracts let consumers override any layer of the pipeline:

| Behaviour | Override point |
|---|---|
| `EctoShorts.QueryBuilder` | How a filter key maps to an Ecto query clause |
| `EctoShorts.DynamicBuilder` | How a value is compiled into a dynamic expression |
| `EctoShorts.QueryProvider` | Named query fragments for locks and structural filters |

Adapters can be set globally via application config or passed as runtime opts on any `Actions` call.

### 4. Changeset Helpers

`EctoShorts.CommonChanges` removes boilerplate around association management:
- `put_or_cast_assoc/3` detects whether to `put_assoc` or `cast_assoc` based on the incoming data.
- Many-to-many shorthand: passing a list of IDs triggers a member-update that adds or removes association members without touching unrelated records.

## Architecture Decisions

### Adapter Pattern for DB Extensibility

The `DynamicBuilder` behaviour decouples expression generation from query construction. PostgreSQL-specific operators (array overlap, `ilike`, `@>`) live entirely inside `EctoShorts.DynamicBuilders.Postgres`. Adding a new database dialect requires only implementing the behaviour without touching any filter routing code.

### Compile-Time Binding Generation

Filter sub-modules call `EctoShorts.QueryBinding.query_binding_contracts/1` at module body level. This macro generates one function clause per binding shape (root binding, named bindings via `:as`, and up to `max_positional_bindings` positional bindings via `:at`). The result is that binding dispatch is a zero-overhead pattern match at runtime with no conditional logic.

Trade-off: increasing `max_positional_bindings` increases compile time. The default cap is 10.

### Separate Replica and Primary Routing

`EctoShorts.Actions` routes reads (`all`, `get`, `find`, `exists?`, `stream`, `aggregate`) through the configured replica repo and writes (`create`, `update`, `delete`) through the primary repo. If no replica is configured the primary is used for both. This makes replica support opt-in and transparent to callers.

### Modular Filter Sub-Modules

Each structural filter (`join`, `order_by`, `group_by`, `having`, `select`, `with_cte`, etc.) lives in its own module under `lib/ecto_shorts/common_filters/`. `CommonFilters` is a thin dispatcher that sorts params and delegates to each sub-module. This keeps individual modules small and testable independently.

### Parameter Sorting

Before reduction, params are sorted into a deterministic order: `:where` clauses first, all structural filters next, `:or_where` clauses after, and terminal filters (`:last`, `:subquery`) last. This ensures that predicates are applied before limits and that `or_where` always follows `where`, which matches SQL semantics.

## V3.0.0 Design Goals

1. **Clean QueryBuilder API** -- Replace ad-hoc dispatch with a consistent `build_query/6` callback that all filter sub-modules implement.
2. **Introduce DynamicBuilders** -- Separate the concern of building `Ecto.Query.dynamic/1` expressions from query construction, enabling the adapter pattern above.
3. **Support schemaless queries** -- Accept `{source, schema}` tuples in addition to schema modules, so callers can query sources without a compiled schema module.
4. **Keyword list params** -- Accept both maps and keyword lists as filter params throughout the pipeline.
5. **Operator wrappers** -- Add `:arithmetic`, `:aggregate`, and `:elements` wrapper keys to allow unambiguous routing for operations that would otherwise conflict with schema field names.

## Non-Goals

- **Multi-database support beyond PostgreSQL** -- MySQL, SQLite, and other adapters are not shipped. The `DynamicBuilder` behaviour exists to allow community implementations, but none are bundled.
- **ORM-level migrations** -- EctoShorts does not generate or manage Ecto migrations.
- **Schema generation** -- No code generation for schema modules.
- **Query result transformation** -- EctoShorts returns raw Ecto structs. Serialization is out of scope.

## Success Metrics

- **Filter expressiveness**: All standard SQL filter patterns (equality, comparison, range, like, in, null, array, association, aggregate, arithmetic) expressible without custom code.
- **Test coverage**: Maintained above 90% via `mix coveralls`.
- **Dual test coverage**: Every filter has both a schema-backed test and a schemaless test.
- **Developer adoption**: Installable with a single `mix.exs` dependency, no mandatory configuration beyond `:repo`.
- **Static analysis**: Zero Credo warnings at strict level; Dialyzer passes on the public API.

## Cross-References

- [Codebase Summary](codebase-summary.md) -- directory layout, module inventory, key file index
- [System Architecture](system-architecture.md) -- component diagrams, filter pipeline, adapter extension points
- [API Reference](api-reference.md) -- complete function signatures for all public modules
- [Configuration Guide](configuration-guide.md) -- repo, replica, and adapter configuration
- [Testing Guide](testing-guide.md) -- test setup, DataCase, dual-file pattern
- [Code Standards](code-standards.md) -- adding filters, Credo, Dialyzer
