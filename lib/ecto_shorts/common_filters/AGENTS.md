# lib/ecto_shorts/common_filters — Filter Pipeline

This directory implements the query language for EctoShorts. The entry point is `common_filters.ex` in the parent directory. Everything in this directory is called by that entry point.

## How the pipeline works

When you call `CommonFilters.convert_params_to_filter(Post, %{published: true, limit: 10}, [])`, the steps are:

1. **Source coercion** (`common_schema.ex`) — converts the source (schema module, `{source, schema}` tuple, or existing query) into an `Ecto.Query`.
2. **Param sorting** (`common_filters.ex:sort_filter_params/1`) — reorders the params keyword list: `:where` entries first, then everything else, then `:or_where`, then terminal filters (`:last`, `:subquery`).
3. **Reduction** (`common_filters.ex:reduce_filters/6`) — walks the sorted list and calls `apply_filter/6` for each entry.
4. **Dispatch** (`apply_filter/6`) — routes each key to the right handler:
   - `:as`, `:at` — retarget subsequent filters to a named or positional binding
   - `:where`, `:or_where`, `:having`, `:or_having` — recurse or call `QueryBuilders`
   - `:and`, `:all`, `:or`, `:any` — boolean grouping, recurse
   - association keys (matched against schema) — implicit join + recurse
   - known filter keys (`:join`, `:order_by`, etc.) — call `QueryBuilders`
   - unknown keys — treated as field-level predicates, passed to `QueryBuilders` as `{key, value}`
5. **QueryBuilders dispatch** (`query_builders.ex`) — selects the active `QueryBuilder` and calls `build_query/6`.
6. **Builder** (`builder.ex`) — the default `QueryBuilder`. Routes structural filters to sub-modules in `filters/` and field predicates to `predicate_builder.ex`.
7. **PredicateBuilder** (`predicate_builder.ex`) — resolves field type, normalizes the operator, determines routing family, and produces a `Predicate` struct.
8. **DynamicBuilders dispatch** (`dynamic_builders.ex` in parent) — selects the active `DynamicBuilder` adapter and calls `build_dynamic/3`.

## Files in this directory

| File | Role |
|---|---|
| `builder.ex` | Default `QueryBuilder` implementation. Routes each filter to a sub-module. |
| `predicate_builder.ex` | Resolves field predicates into `Predicate` structs for the dynamic builder. |
| `predicate.ex` | The `Predicate` struct — carries field, routing family, negation, and operator-value. |

## Sub-directories

- `filters/` — one module per structural filter key (`:join`, `:order_by`, `:limit`, etc.). See [filters/AGENTS.md](filters/AGENTS.md).

## Key design rules

**Params are collections, not single operations.** A params map `%{a: 1, b: 2}` is two separate operations. Never pattern-match a map to infer meaning for the whole container. Walk with a reducer and assign meaning at the `{key, value}` boundary.

**Unknown field keys are field predicates.** If a key is not a known filter key and not a schema association, it is treated as a field comparison and forwarded to the active `QueryBuilder` as `{key, value}`. A warning is logged if the field does not exist on the schema.

**Keyword lists preserve order and duplicates.** Use a keyword list (not a map) when clause order matters or when you need duplicate keys — for example, multiple `:where` or `:join` entries.

**Sorting is transparent.** `sort_filter_params/1` reorders entries but does not remove or modify them. The sort is stable within each group.

## Reducer Contract

Params in the filter pipeline are always a **collection of operations**, not a single operation node.

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
