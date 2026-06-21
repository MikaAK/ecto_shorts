# lib/ecto_shorts — Module Map

This directory contains everything that gets compiled into the library. The files here fall into four groups.

## Public API modules

These are the modules callers import into their applications.

| File | What it does |
|---|---|
| `actions.ex` | All CRUD, bulk, batch, and transaction helpers. This is the main entry point for reading and writing data. |
| `common_filters.ex` | Converts a params map into an Ecto query. This is the query language at the heart of `Actions`. |
| `common_changes.ex` | Changeset helpers for associations, conditional changes, and value coercion. |
| `common_params.ex` | Prepares data for `insert_all` and `update_all`. Handles validation, timestamps, and conflict resolution. |
| `common_query.ex` | Low-level query utilities (binding count, query coercion). Used internally by the filter pipeline. |
| `common_schema.ex` | Schema reflection helpers — reads field types, associations, and query fields from a schema module. |
| `testing.ex` | Assertion helpers for comparing queries and dynamic expressions in tests. |
| `config.ex` | Reads application config (`:repo`, `:replica`, adapter modules). All other modules call this. |

## Behaviour modules (extension points)

These define contracts for custom implementations. Most callers do not need to implement these.

| File | What it defines |
|---|---|
| `query_builder.ex` | How a filter key is turned into a query modification. Default: `common_filters/builder.ex`. |
| `dynamic_builder.ex` | How a single filter condition is turned into an Ecto `DynamicExpr`. Default: `dynamic_builders/postgres.ex`. |
| `query_provider.ex` | How named query fragments (subqueries, lock strings, window definitions) are resolved. No default. |
| `query_builders.ex` | Dispatcher — selects and calls the active `QueryBuilder`. |
| `dynamic_builders.ex` | Dispatcher — selects and calls the active `DynamicBuilder`. |

## Internal helpers

These are used by the modules above. You rarely need to look at them directly.

| File | What it does |
|---|---|
| `query_binding.ex` | Generates function clauses for root, named, and positional binding shapes at compile time. |
| `schema_helpers.ex` | Checks whether a value is a schema struct, detects persisted records. |
| `filter_error.ex` | Exception raised when a filter value is structurally invalid (cannot be safely skipped). |
| `log_utils.ex` | Shared warning logger for unknown fields and skipped filters. |
| `types.ex` | Thin wrapper around `Ecto.Type.cast/2` used for value coercion. |
| `utils.ex` | Miscellaneous utilities (key atomization, etc.). |

## Sub-directories

Each sub-directory has its own AGENTS.md with more specific context.

- `actions/` — the five action groups (CRUD, Bulk, Multi, Batch, Transaction). See [actions/AGENTS.md](actions/AGENTS.md).
- `common_filters/` — the filter pipeline internals. See [common_filters/AGENTS.md](common_filters/AGENTS.md).
- `common_params/` — timestamp and placeholder helpers. See [common_params/AGENTS.md](common_params/AGENTS.md).
- `dynamic_builders/` — the database adapter system. See [dynamic_builders/AGENTS.md](dynamic_builders/AGENTS.md).

## Configuration

All configuration lives under the `:ecto_shorts` key in your application config:

```elixir
config :ecto_shorts,
  repo: MyApp.Repo,
  replica: MyApp.Repo.Replica
```

Runtime overrides use the same key names as options in any function call. The `_module` suffix (`:dynamic_builder_module`) is for app config only; bare keys (`:dynamic_builder`) are for per-call overrides.

## Reducer Contract

Params in EctoShorts are always a **collection of operations**, not a single operation node.

**Rule:** When you receive a map or keyword list as a value, ALWAYS iterate every entry via `Map.to_list/1` or `Enum.reduce/3`. Meaning is assigned at the `{key, value}` entry boundary.

**Antipattern — map-as-opcode:**
```elixir
# WRONG: pattern-matching on a partial map shape as if it were a command
defp apply_select(query, %{map: params}) do ...
```
This assumes `%{map: params}` is a shape-tagged command. It is not — `map:` would be treated as a field alias. Maps have no opcodes in EctoShorts.

**Correct:**
```elixir
# RIGHT: iterate every entry
defp apply_select(query, params) when is_map(params) and not is_struct(params) do
  Enum.reduce(Map.to_list(params), query, fn {k, v}, acc -> ... end)
end
```

## Public vs Internal Forms

- **Public API**: maps, keyword lists, scalars. These come from callers and JSON decoders.
- **Internal dispatch**: tuples like `{:map, fields}`, `{dir, field}`, `{sort_key, limit}`. These are created internally between filter modules and must never appear in public documentation examples.

A tuple value in a public example is a documentation bug.

## String-Key Safety

All string keys are normalized to atoms by `EctoShorts.CommonFilters.Normalizer` before entering the filter pipeline. Filter modules receive atom-keyed data and must not do string→atom conversion themselves.

**Never use `String.to_atom/1`** — it creates atoms unboundedly and is a DoS risk. Use `String.to_existing_atom/1` with rescue, or schema reflection via `Enum.find(known_atoms, fn a -> Atom.to_string(a) == key end)`.

## Error Protocol

- Return `{:ok, result}` or `{:error, reason_atom}`.
- Never return bare `:skip`.
- Never use `throw/catch` for control flow.
- Callers match `{:error, _} ->` not `:skip ->`.
