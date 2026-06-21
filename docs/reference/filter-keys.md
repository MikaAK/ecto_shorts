# Filter Key Reference

This is the single exhaustive reference for every key recognized by
`EctoShorts.CommonFilters.convert_params_to_filter/3`. For a narrative
explanation of how filters are combined and evaluated, see
[Filter Pipeline](../explanation/filter-pipeline.md). For guided examples,
see the [Filtering Guide](../guides/filtering.md).

## String Keys

All filter keys listed below are accepted as either atom or string keys. For example, 
`%{where: %{...}}` and `%{"where" => %{...}}` are equivalent. This enables 
direct use of JSON-decoded payloads and Phoenix controller params.

---

## Structural Filter Keys

Structural keys shape the query at the clause level. Each key maps to a
dedicated filter sub-module under `EctoShorts.CommonFilters.Filters`.

| Key | Value type | SQL equivalent | Notes |
|---|---|---|---|
| `:distinct` | `boolean` or `list` | `SELECT DISTINCT` / `DISTINCT ON (...)` | `true` removes all duplicates; a list adds `DISTINCT ON` columns |
| `:except` | `Ecto.Query.t` | `EXCEPT` | Set subtraction; returns rows in left not in right |
| `:except_all` | `Ecto.Query.t` | `EXCEPT ALL` | Like `:except` but preserves duplicates |
| `:exclude` | atom or list | removes a named query clause | Strips an existing clause from the query (e.g. `:where`, `:limit`) |
| `:first` | integer | `LIMIT N` | Alias for `:limit`; returns at most N records |
| `:group_by` | atom or list | `GROUP BY field` | Groups rows before aggregation |
| `:having` | map or keyword | `HAVING ...` | Post-aggregation predicate; same operator set as `:where` |
| `:intersect` | `Ecto.Query.t` | `INTERSECT` | Returns rows shared by both queries |
| `:intersect_all` | `Ecto.Query.t` | `INTERSECT ALL` | Like `:intersect` but preserves duplicates |
| `:join` | keyword list | `JOIN ...` | Supports `association:`, `schema:`, `table:`, `query:`, `subquery:`, `fragment:`, `type:`, `qualifier:` |
| `:last` | integer | `LIMIT N` (reversed) | Terminal filter — runs after all others; reverses order then takes N |
| `:limit` | integer | `LIMIT N` | Cap the number of rows returned |
| `:lock` | string, atom, or `%{name: ...}` | `FOR UPDATE` etc. | Row-level locking; supply a raw string, a named provider key, or a 1-arity function |
| `:offset` | integer | `OFFSET N` | Skip N rows before returning results |
| `:or_having` | map or keyword | `OR HAVING ...` | OR-combined post-aggregation predicate |
| `:order_by` | keyword or list | `ORDER BY ...` | `[asc: :field]` or `[desc: :field]` or a list of either |
| `:page` | map | `LIMIT N OFFSET M` or cursor `WHERE` | See [Page shapes](#page-shapes) below |
| `:prepend_order_by` | keyword or list | `ORDER BY ...` | Inserts ordering ahead of existing `ORDER BY` clauses |
| `:preload` | atom, list, or keyword | (Ecto preload) | Eager-loads associations after the query executes |
| `:put_query_prefix` | string | `SET search_path` / schema prefix | Sets the query prefix for multi-tenant or schema-prefixed tables |
| `:recursive_ctes` | boolean | `WITH RECURSIVE` | Enables recursive CTE behavior |
| `:reverse_order` | boolean | flips `ORDER BY` direction | Inverts all current ordering expressions |
| `:select` | atom, list, or map | `SELECT ...` | Controls which fields are returned |
| `:select_merge` | atom, list, or map | `SELECT ..., added` | Merges into an existing `:select` without replacing it |
| `:subquery` | `Ecto.Query.t` | wraps as subquery | Terminal filter — wraps the current query as a subquery |
| `:union` | `Ecto.Query.t` | `UNION` | Combines result sets; removes duplicates |
| `:union_all` | `Ecto.Query.t` | `UNION ALL` | Combines result sets; keeps duplicates |
| `:update` | keyword list | `UPDATE SET ...` | Update expressions for `update_all` |
| `:windows` | keyword list | `WINDOW ...` | Window function definitions |
| `:with_cte` | keyword list | `WITH name AS (...)` | Common table expression definitions |
| `:with_named_binding` | keyword list | (binding alias) | Attaches a named binding to the query for later reference |
| `:with_ties` | boolean | `WITH TIES` | Includes tied rows at the limit boundary when used with `FETCH FIRST N ROWS WITH TIES` |

### Page shapes

The `:page` key accepts one of two shapes:

**Offset-based** — computes `LIMIT size OFFSET (index - 1) * size`:

```elixir
%{page: %{index: 2, size: 20}}
# => LIMIT 20 OFFSET 20
```

**Cursor forward** — adds a `WHERE field > cursor` predicate, orders ascending, and limits:

```elixir
%{page: %{after: last_id, by: :id, size: 10}}
# => WHERE id > $1 ORDER BY id ASC LIMIT 10
```

**Cursor backward** — adds a `WHERE field < cursor` predicate, orders descending, and limits:

```elixir
%{page: %{before: first_id, by: :id, size: 10}}
# => WHERE id < $1 ORDER BY id DESC LIMIT 10
```

Pass `nil` as the cursor value for the first page:

```elixir
%{page: %{after: nil, by: :id, size: 10}}
# => ORDER BY id ASC LIMIT 10  (no WHERE)
```

---

## Predicate Operators

Predicate operators appear inside field-level maps passed to `:where`,
`:or_where`, `:having`, `:or_having`, or as direct field filters.

### Comparison operators

| Operator | Alias | Example value | SQL equivalent | Notes |
|---|---|---|---|---|
| `:==` | `:eq` | `5` | `field = 5` | Also: pass the value directly as `%{field: 5}` |
| `:!=` | `:ne` | `5` | `field != 5` | |
| `:>` | `:gt` | `5` | `field > 5` | |
| `:>=` | `:gte` | `5` | `field >= 5` | |
| `:<` | `:lt` | `5` | `field < 5` | |
| `:<=` | `:lte` | `5` | `field <= 5` | |

```elixir
# Direct equality (shorthand)
EctoShorts.CommonFilters.convert_params_to_filter(User, %{age: 18})

# Explicit operator
EctoShorts.CommonFilters.convert_params_to_filter(User, %{age: %{gte: 18}})

# Range using two operators
EctoShorts.CommonFilters.convert_params_to_filter(User, %{age: %{gte: 18, lte: 65}})
```

### List operators

| Operator | Example value | SQL equivalent | Notes |
|---|---|---|---|
| `:in` | `[1, 2, 3]` | `field IN (1, 2, 3)` | Array fields auto-route to `ArrayExpr` when schema-backed |
| `:nin` | `[1, 2, 3]` | `field NOT IN (1, 2, 3)` | Negated membership |
| `:overlaps` | `["a", "b"]` | `field && ARRAY['a','b']` | Postgres array overlap; array fields only |

```elixir
EctoShorts.CommonFilters.convert_params_to_filter(User, %{role: %{in: [:admin, :moderator]}})
EctoShorts.CommonFilters.convert_params_to_filter(User, %{role: %{nin: [:banned]}})
```

### String operators

| Operator | Example value | SQL equivalent | Notes |
|---|---|---|---|
| `:like` | `"hello%"` | `field LIKE 'hello%'` | Case-sensitive pattern; `%` and `_` are wildcards |
| `:ilike` | `"hello"` | `field ILIKE '%hello%'` | Case-insensitive; wraps value in `%…%` automatically |

To negate string operators, use the `:not` wrapper:

```elixir
# NOT LIKE
EctoShorts.CommonFilters.convert_params_to_filter(Post, %{title: %{not: %{like: "draft%"}}})

# NOT ILIKE
EctoShorts.CommonFilters.convert_params_to_filter(Post, %{title: %{not: %{ilike: "spam"}}})
```

### Null checks

Pass `nil` directly as the field value for `IS NULL`. Use `%{!=: nil}` (or
`%{not: %{==: nil}}`) for `IS NOT NULL`:

```elixir
# IS NULL
EctoShorts.CommonFilters.convert_params_to_filter(Post, %{deleted_at: nil})

# IS NOT NULL
EctoShorts.CommonFilters.convert_params_to_filter(Post, %{deleted_at: %{"!=": nil}})
```

---

## Boolean Group Keys

Boolean group keys control how predicate sets are combined. They can appear
at the top level of the params map or nested inside each other.

| Key | Aliases | Description |
|---|---|---|
| `:where` | — | AND predicate filter; applied first in evaluation order |
| `:or_where` | — | OR predicate filter; always applied after all `:where` clauses |
| `:and` | `:all` | Expands its contents as `WHERE` predicates (AND-combined) |
| `:or` | `:any` | Expands its contents as `OR WHERE` predicates |

```elixir
# Explicit where + or_where
EctoShorts.CommonFilters.convert_params_to_filter(User, [
  where: %{status: :active},
  or_where: %{role: :admin}
])
# => WHERE (status = 'active') OR (role = 'admin')

# :and grouping — equivalent to top-level predicates
EctoShorts.CommonFilters.convert_params_to_filter(User, %{
  and: %{status: :active, age: %{gte: 18}}
})

# :or grouping
EctoShorts.CommonFilters.convert_params_to_filter(User, %{
  or: %{status: :active, status: :pending}
})
```

---

## Operator Wrapper Keys

Wrapper keys force routing to a specific expression builder or apply an
expression modifier. They appear as keys inside a field-level map.

| Wrapper | Routes to | Example |
|---|---|---|
| `:arithmetic` | `CommonExpr` arithmetic | `%{score: %{arithmetic: %{compare: :>, add: %{field: :base, value: 5}}}}` |
| `:aggregate` | `CommonExpr` aggregate | `%{views: %{aggregate: %{fn: :avg, compare: :>, value: 100}}}` |
| `:array` | `ArrayExpr` (forces array routing) | `%{tags: %{array: %{in: ["elixir", "ecto"]}}}` |
| `:not` | negation wrapper | `%{title: %{not: %{like: "draft%"}}}` |

The `:array` wrapper is needed only for schemaless queries where the field
type cannot be inferred from a compiled schema:

```elixir
# Schema-backed: type is inferred automatically
EctoShorts.CommonFilters.convert_params_to_filter(Post, %{tags: %{in: ["elixir"]}})

# Schemaless: must use :array wrapper to route to ArrayExpr
EctoShorts.CommonFilters.convert_params_to_filter(
  {"posts", Post},
  %{tags: %{array: %{in: ["elixir"]}}}
)
```

---

## Binding Selector Keys

Binding selectors retarget subsequent filters to a specific binding. They
are first-class top-level keys, not wrapped in another key.

| Key | Value shape | Effect |
|---|---|---|
| `:as` | `%{binding_name => filter_map}` | Apply the nested filters to the named binding |
| `:at` | `%{position => filter_map}` | Apply the nested filters to the positional binding (1-based); also accepts `:first` and `:last` |

```elixir
# Apply select to a named binding
EctoShorts.CommonFilters.convert_params_to_filter(Post, %{
  join: :comments,
  as: %{comments: %{select: :body}}
})

# Apply filter to the second binding (1-based)
EctoShorts.CommonFilters.convert_params_to_filter(Post, %{
  join: :comments,
  at: %{2 => %{body: %{ilike: "hello"}}}
})
```

---

## Cross-References

- [Filter Pipeline](../explanation/filter-pipeline.md) — how params flow through evaluation
- [Filtering Guide](../guides/filtering.md) — hands-on usage examples
- [API Reference](api-reference.md) — full function signatures
