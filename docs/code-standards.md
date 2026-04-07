# EctoShorts Code Standards

## Module Naming

Module names mirror the directory hierarchy exactly:

| File path | Module name |
|---|---|
| `lib/ecto_shorts/actions/crud.ex` | `EctoShorts.Actions.CRUD` |
| `lib/ecto_shorts/common_filters/join.ex` | `EctoShorts.CommonFilters.Join` |
| `lib/ecto_shorts/dynamic_builders/postgres/scalar_expr.ex` | `EctoShorts.DynamicBuilders.Postgres.ScalarExpr` |
| `lib/ecto_shorts/adapter/query_builder.ex` | `EctoShorts.Adapter.QueryBuilder` |

Acronyms in module names use all-caps: `CRUD`, `CTE`, `SQL`.

## Adding a New Filter

1. **Create the filter module** at `lib/ecto_shorts/common_filters/my_filter.ex`.
   - Declare `@behaviour EctoShorts.Adapter.QueryBuilder`.
   - Call `EctoShorts.QueryBinding.query_binding_contracts(__MODULE__)` at module body level (outside any function).
   - Implement `build_query/6`.

2. **Add alias and module attribute** in `CommonFilters` (`lib/ecto_shorts/common_filters.ex`):
   - Add `MyFilter` to the existing alias block.
   - Add `@my_filters [:my_key]` (or more keys if the family handles multiple).

3. **Append the list** to `@all_filters` via `Enum.concat`.

4. **Add a dispatch clause** with a `when filter in @my_filters` guard, placed **before** the final `@predicate_filters` clause:
   ```elixir
   defp do_build_query(filter, source, query, selected_binding, term, opts)
        when filter in @my_filters do
     MyFilter.build_query(filter, source, query, selected_binding, term, opts)
   end
   ```

5. **Write tests** in both:
   - `test/ecto_shorts/common_filters/my_filter_test.exs` (schema-backed)
   - `test/ecto_shorts/common_filters_schemaless/my_filter_test.exs` (schemaless)

   Cover: basic usage, edge cases, binding selectors (`:as`, `:at`).

## Adding a New Dynamic Expression Operator

Dynamic expressions live in `lib/ecto_shorts/dynamic_builders/postgres/`. The entry point is `EctoShorts.DynamicBuilders.Postgres`, which dispatches to `ScalarExpr`, `ArrayExpr`, `CommonExpr`, or `MapExpr`.

1. Identify which sub-module owns the new operator type (scalar comparison, array operation, arithmetic/aggregate, map/JSONB).
2. Add a new function clause to the appropriate sub-module's `build_dynamic/4` or `build_expr/3`.
3. Add a normalizer clause in `Normalizer` if the new operator requires value coercion before expression building.
4. Add unit tests in `test/ecto_shorts/dynamic_builders/`.

## Custom QueryBuilder Adapter

A `QueryBuilder` adapter replaces how a filter key is applied to the query.

```elixir
defmodule MyApp.CustomQueryBuilder do
  @behaviour EctoShorts.Adapter.QueryBuilder

  @impl true
  def build_query(query, binding, key, value, source, opts) do
    # Return {:ok, updated_query} or {:error, reason}
    {:ok, query}
  end
end
```

Register globally:

```elixir
config :ecto_shorts, query_builder_module: MyApp.CustomQueryBuilder
```

Or pass at runtime (to `EctoShorts.QueryBuilders`):

```elixir
EctoShorts.QueryBuilders.build_query(:where, schema, query, binding, term, query_builder_module: MyApp.CustomQueryBuilder)
```

## Custom DynamicBuilder Adapter

A `DynamicBuilder` adapter replaces dynamic expression compilation (e.g. for a different DB dialect).

```elixir
defmodule MyApp.CustomDynamicBuilder do
  @behaviour EctoShorts.Adapter.DynamicBuilder

  @impl true
  def build_dynamic(field, value, binding, opts) do
    # Return an Ecto.Query.dynamic/1 expression
    dynamic([{^binding, x}], field(x, ^field) == ^value)
  end
end
```

Register globally:

```elixir
config :ecto_shorts, dynamic_builder_module: MyApp.CustomDynamicBuilder
```

Or pass as the `:dynamic_builder` runtime option (note: no `_module` suffix for runtime key):

```elixir
EctoShorts.Actions.all(MySchema, params, dynamic_builder: MyApp.CustomDynamicBuilder)
```

## Credo Configuration

Static analysis uses `credo` with `blitz_credo_checks` extensions. Run with:

```bash
mix credo
```

The `.credo.exs` file at the repo root configures enabled checks. `blitz_credo_checks` adds project-specific rules on top of the standard Credo set. Do not disable checks without discussion -- fix the underlying issue instead.

Common checks enforced:
- Module documentation (`@moduledoc`) on all public modules
- Function documentation (`@doc`) on all public functions
- Typespec (`@spec`) on all public functions
- No `IO.inspect` or `IO.puts` in non-test code

## Dialyzer

Type checking uses `dialyxir`. The PLT (persistent lookup table) is stored in `./dialyzer/`. Run with:

```bash
mix dialyzer
```

On first run or after dependency changes, PLT build takes several minutes. Subsequent runs are fast.

All public functions must have `@spec` annotations. Do not suppress Dialyzer warnings without a documented reason in a `@dialyzer` attribute with an explanatory comment.

## Test Conventions

See [Testing Guide](testing-guide.md) for full detail. Summary:

- **Base case**: all DB tests use `EctoShorts.DataCase`, which wraps each test in an `Ecto.Adapters.SQL.Sandbox` transaction that rolls back after the test.
- **Sandbox mode**: set to `:shared` for tests that spawn processes; default is `:manual`.
- **No persistent state**: never rely on data left by a previous test. Use `DataCase` and factories for all fixtures.
- **Dual-file pattern**: every filter module has one test file in `common_filters/` (schema-backed) and one in `common_filters_schemaless/` (schemaless). Both must pass.
- **Factory pattern**: use `factory_ex` for test data creation. Do not write raw `Repo.insert!/1` calls in tests.

## Cross-References

- [Testing Guide](testing-guide.md) -- test setup, DataCase, coverage
- [System Architecture](system-architecture.md) -- how QueryBinding generates compile-time clauses
- [Configuration Guide](configuration-guide.md) -- adapter registration
