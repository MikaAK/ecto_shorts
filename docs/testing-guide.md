# EctoShorts Testing Guide

## Prerequisites

A running PostgreSQL instance is required. The test database is:

| Setting | Value |
|---|---|
| Host | `localhost` |
| Port | `5432` |
| User | `postgres` |
| Password | (none by default) |
| Database | `ecto_shorts_test` |

Create and migrate the test database:

```bash
mix ecto.setup
```

## Running Tests

```bash
# Run all tests
mix test

# Run a single test file
mix test test/ecto_shorts/common_filters/join_test.exs

# Run a single test by line number
mix test test/ecto_shorts/common_filters/join_test.exs:42

# Run all filter tests (schema-backed)
mix test test/ecto_shorts/common_filters/

# Run all schemaless filter tests
mix test test/ecto_shorts/common_filters_schemaless/
```

## EctoShorts.DataCase

All tests that touch the database use `EctoShorts.DataCase` as their base case:

```elixir
defmodule EctoShorts.SomeTest do
  use EctoShorts.DataCase

  # Each test runs inside a transaction that rolls back after the test.
  # No data persists between tests.
end
```

`DataCase` sets up `Ecto.Adapters.SQL.Sandbox` in checkout mode. Each test gets its own isolated transaction. Rollback is automatic -- no teardown is required.

For tests that spawn processes (e.g. `Task`, `GenServer`), switch to shared mode:

```elixir
setup do
  :ok = Ecto.Adapters.SQL.Sandbox.checkout(EctoShorts.Test.Repo)
  Ecto.Adapters.SQL.Sandbox.mode(EctoShorts.Test.Repo, {:shared, self()})
end
```

## EctoShorts.Testing Module

`EctoShorts.Testing` provides assertion helpers for testing query construction without executing queries against the database. Import it in query-level unit tests:

```elixir
defmodule EctoShorts.CommonFilters.MyFilterTest do
  use ExUnit.Case
  import EctoShorts.Testing

  test "builds expected where clause" do
    query = CommonFilters.convert_params_to_filter(User, %{name: "Alice"})
    assert_sql(query, "WHERE")
    assert_sql(query, ~s("name" = $1))
  end
end
```

Available assertions:

| Function | Description |
|---|---|
| `assert_query/2` | Assert a query contains an expected fragment |
| `refute_query/2` | Assert a query does not contain an unexpected fragment |
| `assert_sql/2,3` | Assert the rendered SQL contains a pattern |
| `refute_sql/2,3` | Assert the rendered SQL does not contain a pattern |
| `assert_dynamic/2` | Assert a dynamic expression matches an expected value |
| `refute_dynamic/2` | Assert a dynamic expression does not match a value |

## Test Schemas

Test schemas are defined in `test/support/schema/`. They are minimal schemas used across all tests -- do not add application logic to them.

### Post

```elixir
# has_many :comments
# belongs_to :author (User)
# field :tags, {:array, :string}   # used for array filter tests
# field :title, :string
# field :body, :string
```

### User

```elixir
# has_many :posts
# many_to_many :roles, Role
# field :name, :string
# field :age, :integer
# field :status, Ecto.Enum, values: [:active, :inactive, :pending]
```

### Comment

```elixir
# belongs_to :post
# field :body, :string
```

### Book

```elixir
# Used in bulk/batch/insert_all tests
# field :title, :string
# field :author, :string
```

### UserData (`EctoShorts.Schema.UserData`)

Used for JSONB/map filter tests:

```elixir
# field :data, :map
# field :typed_map, {:map, :string}
# field :creator_id, :integer
# belongs_to :creator, User
# table: "data_stores"
```

### PostWithLock (`EctoShorts.Schema.PostWithLock`)

Used for optimistic locking and `:lock` filter tests:

```elixir
# field :title, :string
# field :lock_version, :integer
# table: "posts_with_lock"
```

## Dual-File Test Pattern

Every filter module has two test files:

| Directory | Purpose |
|---|---|
| `test/ecto_shorts/common_filters/` | Schema-backed tests -- use schema modules (`Post`, `User`, etc.) |
| `test/ecto_shorts/common_filters_schemaless/` | Schemaless tests -- use `{"posts", Post}` tuple sources |

Both files must cover the same filter behavior. This ensures filters work correctly whether or not a compiled schema is available.

When adding a new filter, create both files:

```
test/ecto_shorts/common_filters/my_filter_test.exs
test/ecto_shorts/common_filters_schemaless/my_filter_test.exs
```

### Why Schemaless Tests Matter

For array fields, the routing differs between schema-backed and schemaless sources:

- **Schema-backed**: field type is inferred from the schema, so `%{tags: %{in: [...]}}` routes to `ArrayExpr` automatically.
- **Schemaless**: no type information is available, so `%{tags: %{in: [...]}}` routes to `ScalarExpr` (scalar `IN`). To force array routing, use the `:elements` wrapper: `%{tags: %{elements: %{in: [...]}}}`.

The schemaless test file verifies that the `:elements` wrapper works and that scalar routing is the default.

## Test Data Factories

Use `factory_ex` for creating test fixtures. Do not write raw `Repo.insert!/1` calls in test files.

```elixir
# In a test
post = build(:post, title: "Hello")
{:ok, post} = insert(:post, title: "Hello")
```

Factory definitions live alongside the schema definitions in `test/support/`.

## Code Coverage

```bash
# Console coverage report
mix coveralls

# HTML coverage report (opens in browser)
mix coveralls.html
```

Coverage output is written to `cover/`. The HTML report is at `cover/excoveralls.html`. The project targets above 90% coverage. New filter modules and their tests must maintain this threshold.

## Cross-References

- [Code Standards](code-standards.md) -- adding filter tests, naming conventions
- [Codebase Summary](codebase-summary.md) -- test directory layout
- [API Reference](api-reference.md) -- EctoShorts.Testing function signatures
