# EctoShorts API Reference

This reference lists every public function in the EctoShorts API. For a
narrative guide to filtering, see the [Filtering Guide](../guides/filtering.md).
For an exhaustive table of every recognized filter key and predicate operator,
see the [Filter Key Reference](filter-keys.md).

---

## EctoShorts.Actions

`EctoShorts.Actions` is the primary public boundary for data operations. Every
function accepts an optional trailing keyword list of options. The options below
apply across all function families; function-specific options are noted inline.

| Option | Type | Description |
|---|---|---|
| `:repo` | module | Override the write repo for this call |
| `:replica` | module | Override the read repo for this call |
| `:dynamic_builder` | module | Per-call DynamicBuilder override (runtime key; app-config uses `:dynamic_builder_module`) |
| `:query_builder` | module | Per-call QueryBuilder override |
| `:query_provider` | module | Per-call QueryProvider override |

### Read functions

Read functions use the configured `:replica` (falling back to `:repo` when no
replica is set). They all accept the full `EctoShorts.CommonFilters` param
language for `params`.

```elixir
all(schema_or_queryable) :: [struct]
all(schema_or_queryable, params) :: [struct]
all(schema_or_queryable, params, opts) :: [struct]

get(schema_or_queryable, id) :: {:ok, struct} | {:error, term}
get(schema_or_queryable, id, opts) :: {:ok, struct} | {:error, term}

find(schema_or_queryable, params) :: {:ok, struct | nil} | {:error, term}
find(schema_or_queryable, params, opts) :: {:ok, struct | nil} | {:error, term}

exists?(schema_or_queryable, params) :: boolean
exists?(schema_or_queryable, params, opts) :: boolean

preload(struct_or_list, preloads) :: struct | [struct]
preload(struct_or_list, preloads, opts) :: struct | [struct]

stream(schema_or_queryable, params) :: {:ok, Enum.t} | {:error, term}
stream(schema_or_queryable, params, opts) :: {:ok, Enum.t} | {:error, term}

aggregate(schema_or_queryable, aggregate_fn, field) :: {:ok, term} | {:error, term}
aggregate(schema_or_queryable, aggregate_fn, field, opts) :: {:ok, term} | {:error, term}
```

`stream/2,3` must be called inside a transaction.

### Single-record writes

Write functions use the configured `:repo`. Each write function builds a
changeset through the schema's `changeset/2` callback (or `create_changeset/2`
/ `update_changeset/2` if defined).

```elixir
create(schema, params) :: {:ok, struct} | {:error, Ecto.Changeset.t}
create(schema, params, opts) :: {:ok, struct} | {:error, Ecto.Changeset.t}

update(schema_or_struct, id_or_params, params) :: {:ok, struct} | {:error, Ecto.Changeset.t}
update(schema_or_struct, id_or_params, params, opts) :: {:ok, struct} | {:error, Ecto.Changeset.t}

delete(struct_or_list) :: {:ok, struct} | {:error, term}
delete(struct_or_list, opts) :: {:ok, struct} | {:error, term}
delete(schema, id, opts) :: {:ok, struct} | {:error, term}
```

### Compound operations

Compound operations combine a read phase (using the replica) and a write phase
(using the primary repo) inside a single call. They return `{:ok, struct}` on
success or `{:error, term}` on failure.

```elixir
find_and_create(schema, find_params, create_params) :: {:ok, struct} | {:error, term}
find_and_create(schema, find_params, create_params, opts) :: {:ok, struct} | {:error, term}

find_and_update(schema, find_params, update_params) :: {:ok, struct} | {:error, term}
find_and_update(schema, find_params, update_params, opts) :: {:ok, struct} | {:error, term}

find_and_upsert(schema, find_params, upsert_params) :: {:ok, struct} | {:error, term}
find_and_upsert(schema, find_params, upsert_params, opts) :: {:ok, struct} | {:error, term}

find_and_delete(schema, params) :: {:ok, struct | nil} | {:error, term}
find_and_delete(schema, params, opts) :: {:ok, struct | nil} | {:error, term}

find_or_create(schema, params) :: {:ok, struct} | {:error, term}
find_or_create(schema, params, opts) :: {:ok, struct} | {:error, term}
```

### Set-based operations

Set-based operations operate directly on the database without loading structs
into memory. They are the fastest path for bulk reads, mass updates, and mass
deletes.

```elixir
insert_all(schema, entries) :: {:ok, list} | {:error, term}
insert_all(schema, entries, opts) :: {:ok, list} | {:error, term}

update_all(schema, params, updates) :: {:ok, count} | {:error, term}
update_all(schema, params, updates, opts) :: {:ok, count} | {:error, term}

delete_all(schema, params) :: {:ok, count} | {:error, term}
delete_all(schema, params, opts) :: {:ok, count} | {:error, term}
```

### Multi / list operations

Multi operations run per-record operations inside an `Ecto.Multi` transaction,
giving you all-or-nothing semantics with full changeset validation per record.

```elixir
create_many(schema, params_list) :: {:ok, [struct]} | {:error, term}
create_many(schema, params_list, opts) :: {:ok, [struct]} | {:error, term}

find_many(schema, params) :: {:ok, [struct]} | {:error, term}
find_many(schema, params, opts) :: {:ok, [struct]} | {:error, term}

update_many(schema, id_params_list) :: {:ok, [struct]} | {:error, term}
update_many(schema, id_params_list, opts) :: {:ok, [struct]} | {:error, term}

delete_many(schema_or_list, params_or_ids) :: {:ok, [struct]} | {:error, term}
delete_many(schema_or_list, params_or_ids, opts) :: {:ok, [struct]} | {:error, term}

find_or_create_many(schema, params_list) :: {:ok, [struct]} | {:error, term}
find_or_create_many(schema, params_list, opts) :: {:ok, [struct]} | {:error, term}

find_and_upsert_many(schema, params_list) :: {:ok, [struct]} | {:error, term}
find_and_upsert_many(schema, params_list, opts) :: {:ok, [struct]} | {:error, term}
```

### Batch operations

Batch operations process large result sets in chunks, calling a function on
each chunk rather than loading everything into memory at once.

```elixir
batch(schema, params, batch_size, fun) :: {:ok, term} | {:error, term}
batch(schema, params, batch_size, fun, opts) :: {:ok, term} | {:error, term}

batch_find(schema, field, entries, opts) :: {:ok, [struct]} | {:error, term}
```

`batch/4,5` processes matching records in chunks of `batch_size`, calling
`fun` on each chunk. `batch_find/4` takes `entries` as a list of maps and
looks up records matching each map's field value.

### Transaction helpers

Transaction helpers wrap arbitrary function bodies in a database transaction.
Use `transact/1,2` when your function already returns `{:ok, _}` / `{:error, _}`
tuples and you want automatic rollback on error.

```elixir
transaction(fun) :: {:ok, term} | {:error, term}
transaction(fun, opts) :: {:ok, term} | {:error, term}

transact(fun) :: {:ok, term} | {:error, term}
transact(fun, opts) :: {:ok, term} | {:error, term}
```

`transaction/1,2` wraps the function in `Repo.transaction/1`. `transact/1,2`
wraps and expects the function to return `{:ok, value}` or `{:error, reason}`,
propagating errors as transaction rollbacks.

---

## EctoShorts.CommonFilters

`EctoShorts.CommonFilters` is EctoShorts' query language. You pass a source
and a params map; each key in the map is dispatched to the appropriate filter
sub-module to build up an `Ecto.Query`. See the
[Filter Pipeline](../explanation/filter-pipeline.md) for a detailed walkthrough
of how params are evaluated.

### Entry points

```elixir
convert_params_to_filter(source, params) :: Ecto.Query.t
convert_params_to_filter(source, params, opts) :: Ecto.Query.t
```

`source` may be a schema module, an `Ecto.Query.t`, or a
`{source_string, schema_module}` tuple for schemaless queries.

**Options:**

| Option | Description |
|---|---|
| `:sorter` | Custom function to reorder the params keyword list before evaluation |
| `:query_builder` | Custom `EctoShorts.QueryBuilder` module for this call |
| `:query_provider` | Custom `EctoShorts.QueryProvider` module for this call |
| `:dynamic_builder` | Per-call adapter for dynamic expression building (no `_module` suffix; app-config uses `:dynamic_builder_module`) |

### Structural filter keys

Structural keys shape the query at the clause level. Each key maps to a
dedicated filter sub-module. For a complete table with types and SQL
equivalents, see [Filter Key Reference](filter-keys.md#structural-filter-keys).

| Key | Type | Description |
|---|---|---|
| `:preload` | atom or list | Preload associations onto results |
| `:join` | keyword list | Add join clauses |
| `:order_by` | keyword or list | Order results |
| `:prepend_order_by` | keyword or list | Prepend order clauses before existing ones |
| `:reverse_order` | boolean | Reverse the current order |
| `:group_by` | atom or list | Group results |
| `:having` | map | Post-group predicates |
| `:or_having` | map | OR post-group predicates |
| `:select` | atom, list, or map | Shape the select clause |
| `:select_merge` | atom, list, or map | Merge into the existing select clause |
| `:distinct` | boolean or list | Deduplicate results |
| `:limit` | integer | Cap the number of rows returned |
| `:first` | integer | Alias for `:limit` |
| `:last` | integer | Limit to last N records (terminal filter) |
| `:offset` | integer | Skip N records |
| `:page` | map | Offset-based or cursor-based pagination (see below) |
| `:lock` | string, atom, or map | Row-level locking clause |
| `:with_cte` | keyword list | Common table expressions |
| `:recursive_ctes` | boolean | Enable recursive CTEs |
| `:with_named_binding` | keyword list | Attach a named binding to the query |
| `:with_ties` | boolean | Include tied rows at the limit boundary |
| `:windows` | keyword list | Window function definitions |
| `:union` | `Ecto.Query.t` | UNION set operation |
| `:union_all` | `Ecto.Query.t` | UNION ALL set operation |
| `:intersect` | `Ecto.Query.t` | INTERSECT set operation |
| `:intersect_all` | `Ecto.Query.t` | INTERSECT ALL set operation |
| `:except` | `Ecto.Query.t` | EXCEPT set operation |
| `:except_all` | `Ecto.Query.t` | EXCEPT ALL set operation |
| `:subquery` | `Ecto.Query.t` | Wrap current query as subquery (terminal) |
| `:update` | keyword list | Update expressions for `update_all` |
| `:update_expr` | keyword list | Raw update expression |
| `:put_query_prefix` | string | Set the query prefix (schema/tenant) |
| `:as` | map | Retarget subsequent filters to named binding |
| `:at` | map | Retarget subsequent filters to positional binding |

**`:page` shapes:**

- Offset-based: `%{index: N, size: M}` — computes `LIMIT M OFFSET (N-1)*M`
- Cursor forward: `%{after: cursor, by: field, size: N}` — `WHERE field > cursor ORDER BY field ASC LIMIT N`
- Cursor backward: `%{before: cursor, by: field, size: N}` — `WHERE field < cursor ORDER BY field DESC LIMIT N`
- Pass `nil` as the cursor for the first page (no WHERE added)

### Predicate filter keys

Predicate operators appear inside field-level maps. For a complete table
including negation patterns and null checks, see
[Filter Key Reference](filter-keys.md#predicate-operators).

| Operator | Alias | Example value | SQL equivalent |
|---|---|---|---|
| direct value | — | `5` | `field = 5` |
| `:==` | `:eq` | `5` | `field = 5` |
| `:!=` | `:ne` | `5` | `field != 5` |
| `:>` | `:gt` | `5` | `field > 5` |
| `:>=` | `:gte` | `5` | `field >= 5` |
| `:<` | `:lt` | `5` | `field < 5` |
| `:<=` | `:lte` | `5` | `field <= 5` |
| `:in` | — | `[1, 2, 3]` | `field IN (1, 2, 3)` |
| `:nin` | — | `[1, 2, 3]` | `field NOT IN (1, 2, 3)` |
| `:overlaps` | — | `["a", "b"]` | `field && ARRAY['a','b']` |
| `:like` | — | `"hello%"` | `field LIKE 'hello%'` |
| `:ilike` | — | `"hello"` | `field ILIKE '%hello%'` |

To negate string operators use `%{not: %{like: v}}` or `%{not: %{ilike: v}}`.
For `IS NULL` pass `nil` directly; for `IS NOT NULL` use `%{"!=": nil}`.

### Boolean group keys

Boolean group keys control how predicate sets combine at the SQL level.
Use keyword lists when clause order or duplicate keys matter.

| Key | Aliases | Description |
|---|---|---|
| `:where` | — | AND predicate filter (default) |
| `:or_where` | — | OR predicate filter; always applied after all `:where` clauses |
| `:and` | `:all` | Expands contents as `WHERE` predicates |
| `:or` | `:any` | Expands contents as `OR WHERE` predicates |

### Operator wrapper keys

Wrapper keys force routing to a specific expression builder. The `:array`
wrapper is needed only for schemaless queries where field types cannot be
inferred from the schema.

| Wrapper | Example | Routes to |
|---|---|---|
| `:arithmetic` | `%{score: %{arithmetic: %{compare: :>, add: %{field: :base, value: 5}}}}` | `CommonExpr` arithmetic |
| `:aggregate` | `%{score: %{aggregate: %{fn: :avg, compare: :>, value: 5}}}` | `CommonExpr` aggregate |
| `:array` | `%{tags: %{array: %{in: ["a", "b"]}}}` | `ArrayExpr` (forces array routing) |

### Usage examples

```elixir
# Equality and comparison
EctoShorts.CommonFilters.convert_params_to_filter(User, %{age: %{gte: 18, lte: 50}})

# Pattern match (case-insensitive)
EctoShorts.CommonFilters.convert_params_to_filter(User, %{name: %{ilike: "steven"}})

# Multiple values
EctoShorts.CommonFilters.convert_params_to_filter(User, %{status: %{in: [:active, :pending]}})

# IS NULL check
EctoShorts.CommonFilters.convert_params_to_filter(Post, %{deleted_at: nil})

# IS NOT NULL check
EctoShorts.CommonFilters.convert_params_to_filter(Post, %{deleted_at: %{"!=": nil}})

# Association filter (auto-join)
EctoShorts.CommonFilters.convert_params_to_filter(Post, %{comments: %{body: %{ilike: "hello"}}})

# Array field overlap (schema-backed, auto-routed)
EctoShorts.CommonFilters.convert_params_to_filter(Post, %{tags: %{in: ["elixir", "ecto"]}})

# Array field overlap (schemaless, requires :array wrapper)
EctoShorts.CommonFilters.convert_params_to_filter({"posts", Post}, %{tags: %{array: %{in: ["elixir", "ecto"]}}})

# OR predicates
EctoShorts.CommonFilters.convert_params_to_filter(User, %{
  where: %{status: :active},
  or_where: %{status: :pending}
})

# Offset-based pagination
EctoShorts.CommonFilters.convert_params_to_filter(Post, %{page: %{index: 2, size: 20}})

# Cursor-based pagination
EctoShorts.CommonFilters.convert_params_to_filter(Post, %{page: %{after: last_id, by: :id, size: 10}})

# Ordering and limit
EctoShorts.CommonFilters.convert_params_to_filter(Post, %{first: 20, offset: 40, order_by: [desc: :inserted_at]})
```

---

## EctoShorts.CommonChanges

`EctoShorts.CommonChanges` provides changeset helpers for managing association
changes, conditional transformation, and common field mutations. These
functions compose directly with `Ecto.Changeset` pipelines.

```elixir
preload_change_assoc(changeset, key) :: Ecto.Changeset.t
preload_change_assoc(changeset, key, opts) :: Ecto.Changeset.t

preload_changeset_assoc(changeset, key) :: Ecto.Changeset.t
preload_changeset_assoc(changeset, key, opts) :: Ecto.Changeset.t

put_or_cast_assoc(changeset, key) :: Ecto.Changeset.t
put_or_cast_assoc(changeset, key, opts) :: Ecto.Changeset.t
```

`put_or_cast_assoc/2,3` inspects the changeset's change for `key`. If the
value is a list of maps with `:id` keys only, it performs a many-to-many
member update (add/remove members). Otherwise it delegates to `cast_assoc`
or `put_assoc` based on whether the value contains new data.

```elixir
apply_when(changeset, condition, fun) :: Ecto.Changeset.t
```

Applies `fun` to the changeset only when `condition` is truthy.

```elixir
has_nil_change?(changeset, field) :: boolean
has_empty_change?(changeset, field) :: boolean
changeset_field_nil?(changeset, field) :: boolean
changeset_field_empty?(changeset, field) :: boolean
validate_not_unset(changeset, field) :: Ecto.Changeset.t
```

```elixir
truncate_datetime_change(changeset, field) :: Ecto.Changeset.t
truncate_datetime_change(changeset, field, precision) :: Ecto.Changeset.t

trim_string_change(changeset, field) :: Ecto.Changeset.t

put_new_change(changeset, field, value) :: Ecto.Changeset.t
put_new_value(changeset, field, value) :: Ecto.Changeset.t
```

`put_new_change/3` adds a change only if the field does not already have a
change. `put_new_value/3` adds the value only if the field is currently nil
in both changes and the data.

---

## EctoShorts.CommonParams

`EctoShorts.CommonParams` prepares parameter maps for Ecto's bulk operations.
Use it to build the entries list for `insert_all` and to generate conflict
options for upserts.

```elixir
convert_to_insert_params(schema, params) :: map
convert_to_insert_params(schema, params, opts) :: map
```

Converts params to a map suitable for `insert_all`, adding `:inserted_at` and
`:updated_at` timestamps automatically.

```elixir
build_on_conflict_options(schema, conflict_target, update_fields) :: keyword
```

Builds the `:on_conflict` and `:conflict_target` options for
`Ecto.Repo.insert_all/3`.

---

## EctoShorts.Testing

`EctoShorts.Testing` provides assertion helpers for verifying query
construction without executing queries against a live database. The module
operates at three levels: query structure (via inspect output), SQL text (via
`Ecto.Adapters.SQL.to_sql/3`), and dynamic expressions (via
`Macro.to_string/1`).

**Usage:**

```elixir
# Direct — pass the repo explicitly
EctoShorts.Testing.assert_sql(MyApp.Repo, q1, q2)

# Bound — use the macro to bind the repo at compile time
defmodule MyApp.QueryTest do
  use ExUnit.Case
  use EctoShorts.Testing, repo: MyApp.Repo

  test "builds same query" do
    q1 = from p in Post, where: p.published == ^true
    q2 = EctoShorts.CommonFilters.convert_params_to_filter(Post, %{published: true})
    assert_query(q1, q2)
    assert_sql(q1, q2)
  end
end
```

### Function signatures

```elixir
# Query structure comparison (no repo needed)
assert_query(query_a, query_b) :: :ok | no_return
refute_query(query_a, query_b) :: :ok | no_return

# SQL text comparison (repo required)
assert_sql(repo, query_a, query_b) :: :ok | no_return
assert_sql(repo, query_a, query_b, kind) :: :ok | no_return

refute_sql(repo, query_a, query_b) :: :ok | no_return
refute_sql(repo, query_a, query_b, kind) :: :ok | no_return

# Dynamic expression comparison (no repo needed)
assert_dynamic(expr_a, expr_b) :: :ok | no_return
refute_dynamic(expr_a, expr_b) :: :ok | no_return
```

`kind` is `:all` (default), `:update_all`, or `:delete_all`.

When you `use EctoShorts.Testing, repo: MyRepo`, the bound helpers inject
two-argument `assert_sql(q1, q2)` and `refute_sql(q1, q2)` forms that
forward to the three/four-argument versions with the bound repo.

---

## Cross-References

- [Filter Key Reference](filter-keys.md) — exhaustive key and operator tables
- [Filter Pipeline](../explanation/filter-pipeline.md) — filter evaluation walkthrough
- [System Architecture](../explanation/architecture.md) — adapter extension points
- [Configuration Guide](configuration.md) — repo, replica, adapter configuration
- [Testing Guide](../testing-guide.md) — EctoShorts.Testing usage in tests
