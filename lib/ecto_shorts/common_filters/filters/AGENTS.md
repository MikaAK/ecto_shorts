# lib/ecto_shorts/common_filters/filters — Structural Filter Modules

Each file in this directory handles one named filter key. When `builder.ex` receives a known filter key (`:join`, `:order_by`, `:limit`, etc.), it calls the corresponding module here.

## Filter key → module map

| Filter key(s) | File | What it does |
|---|---|---|
| `:distinct` | `distinct.ex` | Adds a `DISTINCT` clause |
| `:except` | `except.ex` | Set operation: rows in query A but not in query B |
| `:except_all` | `except_all.ex` | Like `:except` but keeps duplicates |
| `:exclude` | (handled inline) | Removes a clause from an existing query |
| `:first` | (handled by `:last`) | Returns first N rows |
| `:group_by` | `group_by.ex` | Groups rows before aggregation |
| `:having` | `having.ex` | Filters grouped results after aggregation |
| `:intersect` | `intersect.ex` | Set operation: rows appearing in both queries |
| `:intersect_all` | `intersect_all.ex` | Like `:intersect` but keeps duplicates |
| `:join` | `join.ex` | Joins associations, schemas, tables, subqueries, or fragments |
| `:last` | `last.ex` | Returns last N rows (reverses order, applies limit, reverses result) |
| `:limit` | `limit.ex` | Caps the number of rows returned |
| `:lock` | `lock.ex` | Applies a row lock (string, named, or function) |
| `:offset` | `offset.ex` | Skips N rows before returning results |
| `:or_having` | `or_having.ex` | OR version of `:having` |
| `:order_by` | `order_by.ex` | Sets result ordering |
| `:page` | `page.ex` | Shorthand for offset-based pagination (`page: N, page_size: M`) |
| `:preload` | `preload.ex` | Eager-loads associations |
| `:prepend_order_by` | `prepend_order_by.ex` | Adds a sort rule ahead of existing ones |
| `:put_query_prefix` | `put_query_prefix.ex` | Sets the schema/namespace prefix for the query |
| `:recursive_ctes` | `recursive_ctes.ex` | Enables recursive CTE mode |
| `:reverse_order` | `reverse_order.ex` | Inverts the current ordering |
| `:select` | `select.ex` | Controls which fields are returned |
| `:select_merge` | `select_merge.ex` | Adds fields into an existing `:select` |
| `:subquery` | `sub_query.ex` | Wraps the current query as a subquery |
| `:union` | `union.ex` | Set operation: combines two result sets |
| `:union_all` | `union_all.ex` | Like `:union` but keeps duplicates |
| `:update` | `update.ex` | Defines `update_all` expressions |
| `:windows` | `windows.ex` | Defines window functions |
| `:with_cte` | `with_cte.ex` | Defines a named CTE |
| `:with_named_binding` | `with_named_binding.ex` | Registers a named binding |
| `:with_ties` | `with_ties.ex` | Keeps tied rows at the limit boundary |

There is also `update_expr.ex` which builds update operation tuples for `convert_to_update_params/3`. It is used by `CommonParams`, not directly by the filter pipeline.

## How each module is structured

Every module in this directory:

1. Declares `@behaviour EctoShorts.QueryBuilder` to implement the `build_query/6` contract.
2. Calls `EctoShorts.QueryBinding.query_binding_contracts(__MODULE__)` at the module body level (outside any function). This macro generates one function clause per binding shape — root, named (`:as`), and up to `max_positional_bindings` positional (`:at`) bindings — at compile time. **This call must appear before any `build_query` function definitions.**
3. Defines `build_query/6` clauses that accept the filter key, source, current query, selected binding, filter value, and opts, and return an updated query.

## Adding a new filter

See the "Adding a new filter" section in the root AGENTS.md (which is the CLAUDE.md content).

## Testing

Each module in this directory has a matching test file at:

```
test/ecto_shorts/common_filters/filters/<filter_name>_test.exs
```

Each test file contains both schema-backed and schemaless cases. Schemaless cases are tagged with `@describetag schema_mode: :schemaless`.

## Reducer Contract

Each filter module receives params that may be maps or keyword lists.

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
