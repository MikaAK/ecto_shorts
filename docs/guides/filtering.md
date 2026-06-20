# Filtering Guide

EctoShorts provides a data-driven query language: you pass a map (or keyword
list) of params and get back an `Ecto.Query`. This guide walks you from the
simplest equality check to advanced array, JSONB, and boolean-group patterns.

For an exhaustive key/operator table see [Filter Keys](../reference/filter-keys.md).

---

## 1. The Idea

Every call to `EctoShorts.CommonFilters.convert_params_to_filter/2,3` turns a
params map into a composable `Ecto.Query`:

```elixir
EctoShorts.CommonFilters.convert_params_to_filter(User, %{status: :active})
#=> #Ecto.Query<from u0 in User, where: u0.status == ^:active>
```

You can also reach the same result through `EctoShorts.Actions.all/2,3`, which
calls `convert_params_to_filter` internally and then runs the query:

```elixir
EctoShorts.Actions.all(User, %{status: :active})
#=> [%User{...}, ...]
```

`source` may be:
- a schema module — `User`
- an existing `Ecto.Query.t` — for composing with a pre-built base query
- a `{source_string, schema_module}` tuple — for schemaless queries (important
  for arrays; see section 8)

`params` may be a map or a keyword list. Use a keyword list when you need
duplicate keys or explicit evaluation order (for example, repeated `where:` or
`or_where:` entries).

---

## 2. Equality and Comparison

### Direct value (equality)

Passing a bare value for a field generates an equality check:

```elixir
EctoShorts.CommonFilters.convert_params_to_filter(User, %{role: :admin})
#=> #Ecto.Query<from u0 in User, where: u0.role == ^:admin>
```

### Named comparison operators

Wrap the value in an operator map to use `>`, `>=`, `<`, `<=`, `!=`:

| Operator key | SQL        |
|--------------|------------|
| `:eq`        | `=`        |
| `:neq`       | `!=`       |
| `:gt`        | `>`        |
| `:gte`       | `>=`       |
| `:lt`        | `<`        |
| `:lte`       | `<=`       |

```elixir
EctoShorts.CommonFilters.convert_params_to_filter(User, %{age: %{gte: 18, lte: 50}})
#=> #Ecto.Query<from u0 in User, where: u0.age >= ^18, where: u0.age <= ^50>
```

Multiple operators in one field map are ANDed together.

### Nil checks with `:is_nil`

```elixir
EctoShorts.CommonFilters.convert_params_to_filter(User, %{deleted_at: %{is_nil: true}})
#=> #Ecto.Query<from u0 in User, where: is_nil(u0.deleted_at)>

EctoShorts.CommonFilters.convert_params_to_filter(User, %{deleted_at: %{is_nil: false}})
#=> #Ecto.Query<from u0 in User, where: not is_nil(u0.deleted_at)>
```

You can also pass `nil` directly as an equality check:

```elixir
EctoShorts.CommonFilters.convert_params_to_filter(User, %{deleted_at: nil})
#=> #Ecto.Query<from u0 in User, where: is_nil(u0.deleted_at)>
```

---

## 3. Membership (IN / NOT IN)

Use `:in` to match rows where the field value is one of a list:

```elixir
EctoShorts.CommonFilters.convert_params_to_filter(User, %{status: %{in: [:active, :pending]}})
#=> #Ecto.Query<from u0 in User, where: u0.status in ^[:active, :pending]>
```

Use `:not_in` to exclude:

```elixir
EctoShorts.CommonFilters.convert_params_to_filter(User, %{status: %{not_in: [:banned, :deleted]}})
#=> #Ecto.Query<from u0 in User, where: u0.status not in ^[:banned, :deleted]>
```

Passing a bare list is equivalent to `:in` for scalar (non-array) fields:

```elixir
EctoShorts.CommonFilters.convert_params_to_filter(User, %{status: [:active, :pending]})
#=> #Ecto.Query<from u0 in User, where: u0.status in ^[:active, :pending]>
```

---

## 4. Pattern Matching (LIKE / ILIKE)

Use `:like` for case-sensitive pattern matching and `:ilike` for
case-insensitive:

```elixir
EctoShorts.CommonFilters.convert_params_to_filter(User, %{name: %{ilike: "ada"}})
#=> #Ecto.Query<from u0 in User, where: ilike(u0.name, ^"%ada%")>
```

A pattern that does **not** already contain `%` or `_` is automatically
wrapped in `%…%`. If your pattern already contains a wildcard, it is used as-is:

```elixir
EctoShorts.CommonFilters.convert_params_to_filter(User, %{email: %{like: "admin@%"}})
#=> #Ecto.Query<from u0 in User, where: like(u0.email, ^"admin@%")>
```

Negated forms:

```elixir
EctoShorts.CommonFilters.convert_params_to_filter(User, %{name: %{not_ilike: "bot"}})
#=> #Ecto.Query<from u0 in User, where: not ilike(u0.name, ^"%bot%")>

EctoShorts.CommonFilters.convert_params_to_filter(User, %{name: %{not_like: "test%"}})
#=> #Ecto.Query<from u0 in User, where: not like(u0.name, ^"test%")>
```

You can also pass a list of patterns; any row that matches at least one is
included (`LIKE ANY` / `ILIKE ANY`):

```elixir
EctoShorts.CommonFilters.convert_params_to_filter(User, %{name: %{ilike: ["ada", "grace"]}})
#=> #Ecto.Query<from u0 in User, where: fragment("? ILIKE ANY(?)", u0.name, ^["%ada%", "%grace%"])>
```

---

## 5. Null Checks

The `:is_nil` operator was shown in section 2. It is the idiomatic way to
filter on `NULL`/`NOT NULL`:

```elixir
# Rows where the field IS NULL
EctoShorts.CommonFilters.convert_params_to_filter(Post, %{published_at: %{is_nil: true}})
#=> #Ecto.Query<from p0 in Post, where: is_nil(p0.published_at)>

# Rows where the field IS NOT NULL
EctoShorts.CommonFilters.convert_params_to_filter(Post, %{published_at: %{is_nil: false}})
#=> #Ecto.Query<from p0 in Post, where: not is_nil(p0.published_at)>
```

---

## 6. Boolean Groups

By default, every top-level key in the params map is combined with `AND`. For
more control EctoShorts provides four boolean group keys.

### `:where` — explicit AND predicate

Wraps a nested map of predicates, evaluated before everything else:

```elixir
EctoShorts.CommonFilters.convert_params_to_filter(User, %{where: %{status: :active, role: :admin}})
#=> #Ecto.Query<from u0 in User, where: u0.status == ^:active, where: u0.role == ^:admin>
```

### `:or_where` — OR predicate (applied after all `:where` clauses)

`or_where` is always sorted to run **after** all regular `where` predicates,
regardless of the order you write them in the params map. This prevents `OR`
from accidentally widening the result set unexpectedly.

```elixir
EctoShorts.CommonFilters.convert_params_to_filter(User, %{
  where: %{status: :active},
  or_where: %{status: :pending}
})
#=> #Ecto.Query<from u0 in User, where: u0.status == ^:active, or_where: u0.status == ^:pending>
```

### `:and` / `:all` — explicit AND grouping

Alias for grouping multiple conditions together with AND (same as the default):

```elixir
EctoShorts.CommonFilters.convert_params_to_filter(Post, %{and: %{published: true, views: %{gt: 0}}})
#=> #Ecto.Query<from p0 in Post, where: p0.published == ^true, where: p0.views > ^0>
```

### `:or` / `:any` — explicit OR grouping

Expands each entry inside the map as an OR WHERE clause:

```elixir
EctoShorts.CommonFilters.convert_params_to_filter(User, %{
  or: %{role: :admin, role: :moderator}
})
```

For OR over different fields, use a keyword list (maps deduplicate keys):

```elixir
EctoShorts.CommonFilters.convert_params_to_filter(User, [
  or: [role: :admin, status: :active]
])
```

### Evaluation order

When params is a keyword list, EctoShorts reorders entries before evaluation:

1. `:where` entries — applied first
2. All other filters (ordering, joins, structural, etc.)
3. `:or_where` entries — applied after all `where`
4. Terminal filters (`:last`, `:subquery`) — applied last

---

## 7. Association Filters (Auto-Join)

Any key that matches a declared association on the schema is treated as an
association shorthand: EctoShorts ensures the join exists and applies the
nested params to that binding.

```elixir
EctoShorts.CommonFilters.convert_params_to_filter(Post, %{comments: %{approved: true}})
#=> #Ecto.Query<from p0 in Post,
#     join: c1 in assoc(p0, :comments),
#     where: c1.approved == ^true>
```

The nested map supports all the same operators as a top-level filter:

```elixir
EctoShorts.CommonFilters.convert_params_to_filter(Post, %{
  comments: %{body: %{ilike: "hello"}}
})
#=> #Ecto.Query<from p0 in Post,
#     join: c1 in assoc(p0, :comments),
#     where: ilike(c1.body, ^"%hello%")>
```

---

## 8. Arrays

### Schema-backed array fields — auto-routed

When the field type is known from the schema (e.g. `field :tags, {:array, :string}`),
EctoShorts automatically routes to the array expression builder. Passing a list
value triggers overlap (`&&`) semantics:

```elixir
# Schema-backed: tags is {:array, :string}
EctoShorts.CommonFilters.convert_params_to_filter(Post, %{tags: %{in: ["elixir", "ecto"]}})
#=> #Ecto.Query<from p0 in Post, where: fragment("? && ?", p0.tags, ^["elixir", "ecto"])>
```

You can also pass a bare list, which resolves to array equality (all elements
must match exactly):

```elixir
EctoShorts.CommonFilters.convert_params_to_filter(Post, %{tags: ["elixir", "ecto"]})
#=> #Ecto.Query<from p0 in Post, where: p0.tags == ^["elixir", "ecto"]>
```

### Schemaless sources — use the `:array` wrapper

**Important gotcha:** when you use a schemaless source (`{"posts", Post}` or a
plain string table name), EctoShorts has no schema type information at runtime.
Without a type, `%{tags: %{in: [...]}}` routes to the **scalar** `IN` operator,
not array overlap.

To force array routing on a schemaless source, wrap the value in `:array`:

```elixir
# Without :array wrapper — WRONG for array fields on schemaless sources
# %{tags: %{in: ["elixir"]}} would generate scalar IN, not array overlap

# With :array wrapper — correct
EctoShorts.CommonFilters.convert_params_to_filter(
  {"posts", Post},
  %{tags: %{array: %{in: ["elixir", "ecto"]}}}
)
#=> #Ecto.Query<from p0 in "posts", where: fragment("? && ?", p0.tags, ^["elixir", "ecto"])>
```

The `:array` key unwraps its inner map and passes all entries to the array
expression builder, so you can use any array-compatible operator inside it:

```elixir
# Element membership (single value)
%{tags: %{array: %{in: "elixir"}}}

# Array length check
%{tags: %{array: %{count: %{gte: 2}}}}
```

---

## 9. Operator Wrappers

Beyond `:array`, two more wrappers route to specialised expression builders.

### `:aggregate`

Compares an aggregate function result against a value. The wrapper accepts a
map with `:fn`, `:compare`, and `:value`:

```elixir
EctoShorts.CommonFilters.convert_params_to_filter(Post, %{
  views: %{aggregate: %{fn: :avg, compare: :gt, value: 100}}
})
```

This produces a `HAVING avg(views) > 100` clause when used with `:group_by`.
Supported aggregate functions: `:avg`, `:count`, `:max`, `:min`, `:sum`.

You can also use the shorthand operator form directly (the aggregate function
as the outer key):

```elixir
%{views: %{avg: %{gt: 100}}}
```

### `:overlaps`

Explicit array overlap operator. Forces array routing even on scalar-typed
fields — useful when the field stores JSON-encoded arrays or when you want to
be explicit:

```elixir
EctoShorts.CommonFilters.convert_params_to_filter(Post, %{
  tags: %{overlaps: ["elixir", "phoenix"]}
})
#=> #Ecto.Query<from p0 in Post, where: fragment("? && ?", p0.tags, ^["elixir", "phoenix"])>
```

### Temporal convenience operators

`EctoShorts.DynamicBuilders.Postgres.CommonExpr` provides convenience operators
that translate to `<`, `>`, `>=`, `<=` against the `:id` or `:inserted_at`
field automatically:

| Operator     | Implied field  | SQL         |
|--------------|----------------|-------------|
| `:ids`       | `:id`          | `id IN (…)` |
| `:before`    | `:id`          | `id < ?`    |
| `:after`     | `:id`          | `id > ?`    |
| `:since`     | `:id`          | `id >= ?`   |
| `:until`     | `:id`          | `id <= ?`   |
| `:start_date`| `:inserted_at` | `inserted_at >= ?` |
| `:end_date`  | `:inserted_at` | `inserted_at <= ?` |
| `:since_date`| `:inserted_at` | `inserted_at >= ?` |
| `:until_date`| `:inserted_at` | `inserted_at <= ?` |

```elixir
EctoShorts.CommonFilters.convert_params_to_filter(Post, %{
  after: 100,
  start_date: ~U[2024-01-01 00:00:00Z]
})
#=> #Ecto.Query<from p0 in Post,
#     where: p0.id > ^100,
#     where: p0.inserted_at >= ^~U[2024-01-01 00:00:00Z]>
```

---

## 10. Reference

For an exhaustive table of every structural filter key, every predicate
operator, boolean group key, and wrapper key — including type, example value,
and SQL equivalent — see [../reference/filter-keys.md](../reference/filter-keys.md).

### Quick cheat sheet

**Structural keys** (shape the query): `:preload`, `:join`, `:order_by`,
`:prepend_order_by`, `:reverse_order`, `:group_by`, `:having`, `:or_having`,
`:select`, `:select_merge`, `:distinct`, `:limit`, `:first`, `:last`,
`:offset`, `:page`, `:lock`, `:with_cte`, `:recursive_ctes`,
`:with_named_binding`, `:with_ties`, `:windows`, `:union`, `:union_all`,
`:intersect`, `:intersect_all`, `:except`, `:except_all`, `:subquery`,
`:update`, `:put_query_prefix`, `:as`, `:at`, `:exclude`.

**Predicate operators** (inside a field value map): `:eq`, `:neq`, `:gt`,
`:gte`, `:lt`, `:lte`, `:in`, `:not_in`, `:like`, `:ilike`, `:not_like`,
`:not_ilike`, `:is_nil`.

**Boolean group keys**: `:where`, `:or_where`, `:and` (alias `:all`), `:or`
(alias `:any`).

**Wrapper keys**: `:array`, `:aggregate`, `:overlaps`.

**Temporal convenience keys** (top-level, imply field): `:ids`, `:before`,
`:after`, `:since`, `:until`, `:start_date`, `:end_date`, `:since_date`,
`:until_date`.
