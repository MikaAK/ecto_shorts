# EctoShorts Configuration Guide

## Configuration Keys

All keys are set under the `:ecto_shorts` application namespace:

```elixir
config :ecto_shorts,
  key: value
```

| Key | Type | Default | Description |
|---|---|---|---|
| `:repo` | module | `nil` | Primary repo for all write operations |
| `:replica` | module | `nil` | Read replica repo; falls back to `:repo` if not set |
| `:dynamic_builder_module` | module | auto-detected | `DynamicBuilder` implementation; auto-detected from repo adapter when not set |
| `:query_builder_module` | module | `nil` | `QueryBuilder` implementation; overrides default dispatch in `EctoShorts.QueryBuilders` |
| `:query_provider_module` | module | `nil` | Named query-fragment provider for locks and structural filters |
| `:error_module` | module | `EctoShorts.Actions.Error` | Error-response builder used by `Actions` |
| `:max_positional_bindings` | integer | `10` | Upper bound for `:at` positional bindings; increasing this increases compile time |

## Basic Setup

```elixir
# config/config.exs
config :ecto_shorts,
  repo: MyApp.Repo
```

With a read replica:

```elixir
# config/config.exs
config :ecto_shorts,
  repo: MyApp.Repo,
  replica: MyApp.Repo.Replica
```

With environment-specific overrides:

```elixir
# config/test.exs
config :ecto_shorts,
  repo: MyApp.Repo,
  replica: MyApp.Repo  # use primary for both in test
```

## Replica and Primary Routing

`EctoShorts.Actions` routes based on the operation type:

- **Reads** (`all`, `get`, `find`, `exists?`, `stream`, `aggregate`, `preload`, `find_many`) use `Config.replica!/1`, which returns the replica if configured or falls back to the primary.
- **Writes** (`create`, `update`, `delete`, `insert_all`, `update_all`, `delete_all`, and all `find_and_*` / `find_or_*` variants) use `Config.repo!/1`, which always returns the primary.

Compound operations such as `find_or_create` use the replica for the read phase and the primary for the write phase within the same call. No additional configuration is needed.

## Runtime Option Overrides

`:dynamic_builder` (without `_module`) can be passed as a per-call runtime option to override the adapter for that call only. `:query_builder_module` overrides the `QueryBuilders` adapter per-call:

```elixir
EctoShorts.Actions.all(User, %{name: "Alice"}, dynamic_builder: MyApp.CustomDynamicBuilder)

EctoShorts.QueryBuilders.build_query(:where, User, query, binding, term, query_builder_module: MyApp.CustomQueryBuilder)
```

This is useful for testing adapters in isolation or for per-request customization.

## Custom Error Module

The default error module is `EctoShorts.Actions.Error`. To replace the error-response format:

```elixir
defmodule MyApp.ActionsError do
  @behaviour EctoShorts.Actions.Error

  def call(error_type, message, details \\ []) do
    {:error, %{type: error_type, message: message, details: details}}
  end
end
```

Register it:

```elixir
config :ecto_shorts, error_module: MyApp.ActionsError
```

## Custom DynamicBuilder

Implement `EctoShorts.Adapter.DynamicBuilder` to replace dynamic expression compilation:

```elixir
defmodule MyApp.CustomDynamicBuilder do
  @behaviour EctoShorts.Adapter.DynamicBuilder

  @impl true
  def build_dynamic(field, value, binding, opts) do
    # Build and return an Ecto.Query.dynamic/1 expression.
    # binding is either :root, {:named, atom}, or {:positional, integer}.
    dynamic([{^binding, x}], field(x, ^field) == ^value)
  end
end
```

Register globally:

```elixir
config :ecto_shorts, dynamic_builder_module: MyApp.CustomDynamicBuilder
```

Or pass at call time via the `:dynamic_builder` runtime option (note: no `_module` suffix for the runtime key):

```elixir
EctoShorts.Actions.all(User, params, dynamic_builder: MyApp.CustomDynamicBuilder)
```

When neither is set, `EctoShorts.DynamicBuilders` auto-detects from the repo's `__adapter__/0`. Currently only `Ecto.Adapters.Postgres` is supported; others raise at runtime.

## Custom QueryBuilder

Implement `EctoShorts.Adapter.QueryBuilder` to replace how a filter key is applied to the query:

```elixir
defmodule MyApp.CustomQueryBuilder do
  @behaviour EctoShorts.Adapter.QueryBuilder

  @impl true
  def build_query(query, binding, key, value, source, opts) do
    # Modify and return the query, or return {:error, reason}.
    {:ok, query}
  end
end
```

Register globally:

```elixir
config :ecto_shorts, query_builder_module: MyApp.CustomQueryBuilder
```

When set, `EctoShorts.QueryBuilders` calls your module for every filter key. Return the updated query to short-circuit the default, or call `EctoShorts.CommonFilters.Builder.build_query/6` to delegate to the default dispatch.

## Custom QueryProvider

Implement `EctoShorts.Adapter.QueryProvider` to supply named query fragments used by structural filters such as `:lock`:

```elixir
defmodule MyApp.QueryProvider do
  @behaviour EctoShorts.Adapter.QueryProvider

  @impl true
  def query_for(:for_update), do: "FOR UPDATE"
  def query_for(:for_share), do: "FOR SHARE"
  def query_for(name), do: raise "Unknown query fragment: #{inspect(name)}"
end
```

Register globally:

```elixir
config :ecto_shorts, query_provider_module: MyApp.QueryProvider
```

## Important: :hints is Compile-Time Only

The `:hints` config key (index hint strings passed to joins) is read with `Application.compile_env/2` inside `CommonFilters.Join`. Changes to `:hints` in runtime config have no effect -- recompilation is required after any change.

```elixir
# config/config.exs -- changes here require recompilation
config :ecto_shorts, hints: ["USE INDEX (idx_user_name)"]
```

Do not set `:hints` in `runtime.exs` or via `Application.put_env/3` at runtime.

## Cross-References

- [System Architecture](system-architecture.md) -- adapter extension point diagrams, replica routing diagram
- [API Reference](api-reference.md) -- per-call option overrides in function signatures
- [Code Standards](code-standards.md) -- implementing custom adapters step by step
