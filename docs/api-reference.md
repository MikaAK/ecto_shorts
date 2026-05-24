# EctoShorts API Reference

## EctoShorts.Actions

All functions accept an optional final keyword list of options. Common options:

| Option | Type | Description |
|---|---|---|
| `:repo` | module | Override the write repo for this call |
| `:replica` | module | Override the read repo for this call |
| `:dynamic_builder` | module | Per-call DynamicBuilder override (runtime key, no `_module` suffix) |
| `:query_builder_module` | module | Per-call QueryBuilder override via `EctoShorts.QueryBuilders` |

### Read functions

```elixir
all(schema_or_queryable) :: [struct]
all(schema_or_queryable, params) :: [struct]
all(schema_or_queryable, params, opts) :: [struct]

get(schema_or_queryable, id) :: {:ok, struct} | {:error, term}
get(schema_or_queryable, id, opts) :: {:ok, struct} | {:error, term}

find(schema_or_queryable, params) :: struct | nil
find(schema_or_queryable, params, opts) :: struct | nil

find_by_id(schema_or_queryable, id) :: struct | nil
find_by_id(schema_or_queryable, id, opts) :: struct | nil

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

```elixir
insert_all(schema, entries) :: {:ok, list} | {:error, term}
insert_all(schema, entries, opts) :: {:ok, list} | {:error, term}

update_all(schema, params, updates) :: {:ok, count} | {:error, term}
update_all(schema, params, updates, opts) :: {:ok, count} | {:error, term}

delete_all(schema, params) :: {:ok, count} | {:error, term}
delete_all(schema, params, opts) :: {:ok, count} | {:error, term}
```

### Multi / list operations

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

```elixir
batch(schema, params, batch_size, fun) :: {:ok, term} | {:error, term}
batch(schema, params, batch_size, fun, opts) :: {:ok, term} | {:error, term}

batch_find(schema, field, entries, opts) :: {:ok, [struct]} | {:error, term}
```

`batch/4,5` processes matching records in chunks of `batch_size`, calling `fun` on each chunk. `batch_find/4` takes `entries` as a list of maps and looks up records matching each map's field value.

### Transaction helpers

```elixir
transaction(fun) :: {:ok, term} | {:error, term}
transaction(fun, opts) :: {:ok, term} | {:error, term}

transact(fun) :: {:ok, term} | {:error, term}
transact(fun, opts) :: {:ok, term} | {:error, term}
```

`transaction/1,2` wraps the function in `Repo.transaction/1`. `transact/1,2` wraps and expects the function to return `{:ok, value}` or `{:error, reason}`, propagating errors as transaction rollbacks.

---

## EctoShorts.CommonFilters

### Entry Points

```elixir
convert_params_to_filter(params) :: Ecto.Query.t
convert_params_to_filter(source, params) :: Ecto.Query.t
convert_params_to_filter(source, params, opts) :: Ecto.Query.t
```

`source` may be a schema module, an `Ecto.Query.t`, or a `{source_string, schema_module}` tuple for schemaless queries.

### Structural Filter Keys

| Key | Type | Description |
|---|---|---|
| `:preload` | atom or list | Preload associations onto results |
| `:join` | atom or list | Add join clauses |
| `:order_by` | keyword or list | Order results |
| `:prepend_order_by` | keyword or list | Prepend order clauses before existing ones |
| `:reverse_order` | boolean | Reverse the current order |
| `:group_by` | atom or list | Group results |
| `:having` | map | Post-group predicates |
| `:or_having` | map | OR post-group predicates |
| `:select` | atom, list, or map | Shape the select clause |
| `:select_merge` | atom, list, or map | Merge into the existing select clause |
| `:distinct` | boolean or list | Deduplicate results |
| `:limit` | integer | Alias for `:first` |
| `:first` | integer | Limit to first N records |
| `:last` | integer | Limit to last N records (terminal filter) |
| `:offset` | integer | Skip N records |
| `:page` | integer | Page number (works with `:first` as page size) |
| `:lock` | string or atom | Row-level locking clause |
| `:with_cte` | keyword list | Common table expressions |
| `:recursive_ctes` | boolean | Enable recursive CTEs |
| `:with_named_binding` | keyword list | Attach a named binding to the query |
| `:with_ties` | boolean | Include tied rows at the limit boundary |
| `:windows` | keyword list | Window function definitions |
| `:union` | Ecto.Query.t | UNION set operation |
| `:union_all` | Ecto.Query.t | UNION ALL set operation |
| `:intersect` | Ecto.Query.t | INTERSECT set operation |
| `:intersect_all` | Ecto.Query.t | INTERSECT ALL set operation |
| `:except` | Ecto.Query.t | EXCEPT set operation |
| `:except_all` | Ecto.Query.t | EXCEPT ALL set operation |
| `:subquery` | Ecto.Query.t | Wrap current query as subquery (terminal) |
| `:update` | keyword list | Update expressions for `update_all` |
| `:update_expr` | keyword list | Raw update expression |
| `:put_query_prefix` | string | Set the query prefix (schema/tenant) |
| `:as` | atom | Retarget subsequent filters to named binding |
| `:at` | integer | Retarget subsequent filters to positional binding |

### Predicate Filter Keys (inside `:where` / `:or_where` maps)

| Operator | Example value | SQL equivalent |
|---|---|---|
| direct value | `5` | `field = 5` |
| `:eq` | `5` | `field = 5` |
| `:neq` | `5` | `field != 5` |
| `:gt` | `5` | `field > 5` |
| `:gte` | `5` | `field >= 5` |
| `:lt` | `5` | `field < 5` |
| `:lte` | `5` | `field <= 5` |
| `:in` | `[1, 2, 3]` | `field IN (1, 2, 3)` |
| `:not_in` | `[1, 2, 3]` | `field NOT IN (1, 2, 3)` |
| `:like` | `"hello%"` | `field LIKE 'hello%'` |
| `:ilike` | `"hello"` | `field ILIKE '%hello%'` |
| `:not_like` | `"hello%"` | `field NOT LIKE 'hello%'` |
| `:not_ilike` | `"hello"` | `field NOT ILIKE '%hello%'` |
| `:is_nil` | `true/false` | `field IS NULL` / `field IS NOT NULL` |

### Boolean Group Keys

| Key | Description |
|---|---|
| `:and` | Explicit AND grouping of multiple predicates |
| `:or` | Explicit OR grouping of multiple predicates |
| `:where` | AND predicate filter (default) |
| `:or_where` | OR predicate filter applied after all `:where` clauses |

### Operator Wrapper Keys

| Wrapper | Example | Routes to |
|---|---|---|
| `:arithmetic` | `%{score: %{arithmetic: %{compare: :>, add: %{field: :base, value: 5}}}}` | `CommonExpr` arithmetic |
| `:aggregate` | `%{score: %{aggregate: %{fn: :avg, compare: :>, value: 5}}}` | `CommonExpr` aggregate |
| `:elements` | `%{tags: %{elements: %{in: ["a", "b"]}}}` | `ArrayExpr` (forces array routing) |

### Usage Examples

```elixir
# Equality and comparison
CommonFilters.convert_params_to_filter(User, %{age: %{gte: 18, lte: 50}})

# Pattern match (case-insensitive)
CommonFilters.convert_params_to_filter(User, %{name: %{ilike: "steven"}})

# Multiple values
CommonFilters.convert_params_to_filter(User, %{status: %{in: [:active, :pending]}})

# Null check
CommonFilters.convert_params_to_filter(User, %{deleted_at: %{is_nil: true}})

# Association filter (auto-join)
CommonFilters.convert_params_to_filter(Post, %{comments: %{body: %{ilike: "hello"}}})

# Array field overlap (schema-backed, auto-routed)
CommonFilters.convert_params_to_filter(Post, %{tags: %{in: ["elixir", "ecto"]}})

# Array field overlap (schemaless, requires :elements wrapper)
CommonFilters.convert_params_to_filter({"posts", Post}, %{tags: %{elements: %{in: ["elixir", "ecto"]}}})

# OR predicates
CommonFilters.convert_params_to_filter(User, %{
  where: %{status: :active},
  or_where: %{status: :pending}
})

# Pagination
CommonFilters.convert_params_to_filter(Post, %{first: 20, offset: 40, order_by: [desc: :inserted_at]})
```

---

## EctoShorts.CommonChanges

```elixir
preload_change_assoc(changeset, key) :: Ecto.Changeset.t
preload_change_assoc(changeset, key, opts) :: Ecto.Changeset.t

preload_changeset_assoc(changeset, key) :: Ecto.Changeset.t
preload_changeset_assoc(changeset, key, opts) :: Ecto.Changeset.t

put_or_cast_assoc(changeset, key) :: Ecto.Changeset.t
put_or_cast_assoc(changeset, key, opts) :: Ecto.Changeset.t
```

`put_or_cast_assoc/2,3` inspects the changeset's change for `key`. If the value is a list of maps with `:id` keys only, it performs a many-to-many member update (add/remove members). Otherwise it delegates to `cast_assoc` or `put_assoc` based on whether the value contains new data.

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

`put_new_change/3` adds a change only if the field does not already have a change. `put_new_value/3` adds the value only if the field is currently nil in both changes and the data.

---

## EctoShorts.CommonParams

```elixir
convert_to_insert_params(schema, params) :: map
convert_to_insert_params(schema, params, opts) :: map
```

Converts params to a map suitable for `insert_all`, adding `:inserted_at` and `:updated_at` timestamps automatically.

```elixir
build_on_conflict_options(schema, conflict_target, update_fields) :: keyword
```

Builds the `:on_conflict` and `:conflict_target` options for `Ecto.Repo.insert_all/3`.

---

## EctoShorts.Testing

Assertion helpers for verifying query construction without running against the database.

```elixir
assert_query(query, expected_fragment) :: :ok | no_return
refute_query(query, unexpected_fragment) :: :ok | no_return
```

```elixir
assert_sql(query, pattern) :: :ok | no_return
assert_sql(query, pattern, opts) :: :ok | no_return

refute_sql(query, pattern) :: :ok | no_return
refute_sql(query, pattern, opts) :: :ok | no_return
```

`assert_sql` and `refute_sql` convert the query to a SQL string and check for the pattern. `opts` accepts `:adapter` to specify the SQL dialect for rendering.

```elixir
assert_dynamic(expr, expected) :: :ok | no_return
refute_dynamic(expr, unexpected) :: :ok | no_return
```

---

## Cross-References

- [System Architecture](system-architecture.md) -- filter pipeline and adapter extension points
- [Configuration Guide](configuration-guide.md) -- repo, replica, adapter configuration
- [Testing Guide](testing-guide.md) -- EctoShorts.Testing usage in tests
