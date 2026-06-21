# Extending EctoShorts

EctoShorts exposes three behaviour-based extension points that let you plug in
custom logic at different stages of the filter pipeline.

| Behaviour | What you override |
|---|---|
| `EctoShorts.QueryBuilder` | How a single filter key is applied to the query |
| `EctoShorts.DynamicBuilder` | How a filter predicate is compiled to an Ecto `DynamicExpr` |
| `EctoShorts.QueryProvider` | Named query fragments referenced by structural filters |

All three follow the same pattern: implement the behaviour, then configure it
globally via `config :ecto_shorts` or pass it per-call as a keyword option.

---

## `EctoShorts.QueryBuilder`

### When to use it

`QueryBuilder` is the right extension point when you want to intercept or
replace how EctoShorts processes one or more filter keys.  Common uses:

* Adding a completely new filter key (see "Adding a new filter" below).
* Changing how an existing key works for your application.
* Delegating most keys to the default implementation while overriding a few.

### The callback

```elixir
@callback build_query(
              filter :: atom(),
              source :: term(),
              query :: Ecto.Query.t(),
              selected_binding :: {:as, atom()} | {:at, pos_integer()},
              term :: term(),
              opts :: keyword()
            ) :: Ecto.Query.t()
```

* `filter` — the filter key being processed (e.g. `:limit`, `:where`).
* `source` — the schema module, `{source, schema}` tuple, or `Ecto.Query.t()`.
* `query` — the query accumulated so far; apply your change and return the result.
* `selected_binding` — which binding in the query this entry targets.
* `term` — the value from the params associated with `filter`.
* `opts` — keyword options forwarded from the call site.

Must return an `Ecto.Query.t()`.  Never return `nil` or raise; return `query`
unchanged if you want to skip the entry.

### Worked example

```elixir
defmodule MyApp.CustomQueryBuilder do
  @behaviour EctoShorts.QueryBuilder

  @impl true
  def build_query(filter, source, query, selected_binding, term, opts) do
    # Handle a custom `:published_after` filter:
    case filter do
      :published_after ->
        date = term
        Ecto.Query.where(query, [p], p.published_at > ^date)

      _ ->
        # Fall through to the default implementation for all other keys:
        EctoShorts.CommonFilters.Builder.build_query(
          filter, source, query, selected_binding, term, opts
        )
    end
  end
end
```

#### Global configuration

```elixir
# config/config.exs
config :ecto_shorts, query_builder_module: MyApp.CustomQueryBuilder
```

#### Per-call override

```elixir
EctoShorts.CommonFilters.convert_params_to_filter(
  Post,
  %{published_after: ~D[2025-01-01]},
  query_builder: MyApp.CustomQueryBuilder
)
# => #Ecto.Query<from p0 in Post, where: p0.published_at > ^~D[2025-01-01]>
```

Note: the runtime option key is `:query_builder` (no `_module` suffix).
The `_module` suffix is for app config only.

### `QueryBinding.query_binding_contracts/1` requirement

Every module that implements `build_query/6` as a filter sub-module (not a
custom `QueryBuilder` pass-through) must call
`EctoShorts.QueryBinding.query_binding_contracts(__MODULE__)` at module-body
level — outside any function.  This generates one function clause per binding
shape (root, named, and positional) at compile time.

```elixir
defmodule MyApp.Filters.PublishedAfter do
  @behaviour EctoShorts.QueryBuilder

  # Generate binding patterns at compile time:
  {_target_var, _patterns} =
    EctoShorts.QueryBinding.query_binding_contracts(__MODULE__)

  @impl true
  def build_query(:published_after, _source, query, _selected_binding, date, _opts) do
    Ecto.Query.where(query, [p], p.published_at > ^date)
  end
end
```

### Adding a new filter

Follow these steps to add a new filter key end-to-end:

1. **Create the filter module** at
   `lib/ecto_shorts/common_filters/filters/my_filter.ex`.
   Implement `@behaviour EctoShorts.QueryBuilder` with a `build_query/6`
   callback.  Call
   `EctoShorts.QueryBinding.query_binding_contracts(__MODULE__)` at
   module-body level (outside any function).

2. **Register the key** in `CommonFilters`:
   * Add your module to the existing alias block.
   * Add a `@my_filters [:my_key]` module attribute.
   * Append `@my_filters` to `@all_filters` via `Enum.concat`.

3. **Add a dispatch clause** with a `when filter in @my_filters` guard,
   placed before the final `@predicate_filters` clause:

   ```elixir
   defp do_build_query(filter, source, query, selected_binding, term, opts)
        when filter in @my_filters do
     MyFilter.build_query(filter, source, query, selected_binding, term, opts)
   end
   ```

4. **Add tests** in
   `test/ecto_shorts/common_filters/filters/my_filter_test.exs`.
   Put schema-backed and schemaless cases in the same file; tag schemaless
   cases with `@describetag schema_mode: :schemaless`.

---

## `EctoShorts.DynamicBuilder`

### When to use it

`DynamicBuilder` is the right extension point when you need to change how a
specific filter condition is compiled into a database expression.  The built-in
implementation, `EctoShorts.DynamicBuilders.Postgres`, handles all
PostgreSQL-specific logic.

> Only `Ecto.Adapters.Postgres` ships with a built-in `DynamicBuilder`.
> Other adapters are not currently supported.

### The callback

```elixir
@callback build_dynamic(predicate, selected_binding, opts) :: dynamic_expr() | nil
```

* `predicate` — an `EctoShorts.CommonFilters.Predicate` struct containing the
  resolved field name, expression family, negation flag, and operator-value pair.
* `selected_binding` — `{:as, atom()}` for a named binding or
  `{:at, pos_integer()}` for a positional binding.
* `opts` — keyword options forwarded from the call site.

Return a dynamic expression (from `Ecto.Query.dynamic/2`) or `nil` when
the predicate contributes no `WHERE` clause.

### Worked example

```elixir
defmodule MyApp.CustomDynamicBuilder do
  @behaviour EctoShorts.DynamicBuilder

  @impl true
  def build_dynamic(predicate, selected_binding, opts) do
    # Delegate everything to the built-in Postgres builder, then add your own:
    case predicate do
      %{field: :score, operator: :above_threshold, value: threshold} ->
        import Ecto.Query
        dynamic([p], p.score > ^threshold and p.active == true)

      _ ->
        # Fall through to the built-in Postgres implementation:
        EctoShorts.DynamicBuilders.Postgres.build_dynamic(predicate, selected_binding, opts)
    end
  end
end
```

#### Global configuration

```elixir
# config/config.exs
config :ecto_shorts, dynamic_builder_module: MyApp.CustomDynamicBuilder
```

#### Per-call override

```elixir
EctoShorts.Actions.all(Post, %{published: true},
  dynamic_builder: MyApp.CustomDynamicBuilder
)
# => [%Post{published: true, ...}, ...]
```

Note: the runtime option key is `:dynamic_builder` (no `_module` suffix).
The `_module` suffix is for app config only.

---

## `EctoShorts.QueryProvider`

### When to use it

`QueryProvider` lets you give names to reusable query expressions that cannot
be expressed as plain data.  Structural filters like `:join` and `:lock` can
reference an expression by name; EctoShorts calls your provider to resolve it.

```elixir
# Reference a named join in your filter params:
EctoShorts.Actions.all(Post, %{join: %{name: :active_users}},
  query_provider: MyApp.QueryProvider
)
```

### The callback

```elixir
@callback query_expression(
              selected_binding(),
              expression_key(),
              expression_params(),
              opts()
            ) :: {:ok, term()} | {:error, term()} | nil
```

* `selected_binding` — which binding in the query this expression applies to.
* `expression_key` — the atom that names the expression (e.g. `:active_users`).
* `expression_params` — the value associated with the key in the filter params.
* `opts` — keyword options forwarded from the call site.

Return values:

* `{:ok, Ecto.Query.t()}` — a subquery or fragment query.
* `{:ok, function}` — a 1-arity function `(Ecto.Query.t() -> Ecto.Query.t())`.
* `{:ok, keyword()}` — a keyword list of query options (e.g. a window definition).
* `{:error, reason}` — EctoShorts logs a warning and skips the expression.
* `nil` — silently skipped without a warning.

### Worked example

```elixir
defmodule MyApp.QueryProvider do
  @behaviour EctoShorts.QueryProvider

  @impl true
  def query_expression(_selected_binding, expression_key, _expression_params, _opts) do
    case expression_key do
      :active_users ->
        import Ecto.Query
        {:ok, from(u in "users", where: u.active == true)}

      :recent_posts ->
        import Ecto.Query
        cutoff = DateTime.add(DateTime.utc_now(), -7, :day)
        {:ok, from(p in "posts", where: p.inserted_at > ^cutoff)}

      _ ->
        {:error, :unsupported_expression_key}
    end
  end
end
```

#### Global configuration

```elixir
# config/config.exs
config :ecto_shorts, query_provider_module: MyApp.QueryProvider
```

#### Per-call override

```elixir
EctoShorts.CommonFilters.convert_params_to_filter(
  Post,
  %{join: %{name: :recent_posts}},
  query_provider: MyApp.QueryProvider
)
# => #Ecto.Query<from p0 in Post, join: p1 in ^#Ecto.Query<...>>
```

Note: the runtime option key is `:query_provider` (no `_module` suffix).
The `_module` suffix is for app config only.

---

## Configuration key reference

| App config key | Runtime opt key | Default | Purpose |
|---|---|---|---|
| `:query_builder_module` | `:query_builder` | default builder | `QueryBuilder` implementation |
| `:dynamic_builder_module` | `:dynamic_builder` | auto-detected (Postgres) | `DynamicBuilder` implementation |
| `:query_provider_module` | `:query_provider` | `nil` | `QueryProvider` implementation |

The runtime opt keys (no `_module` suffix) are passed directly to
`EctoShorts.CommonFilters.convert_params_to_filter/3` or
`EctoShorts.Actions.*` and override the app config for that single call only.
