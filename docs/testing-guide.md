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

`EctoShorts.Testing` provides assertion helpers for verifying query
construction without executing queries against a live database. It operates
at three levels:

- **Query structure** (`assert_query/2`) — compares two `Ecto.Query` structs
  by their inspect output. No database connection required.
- **SQL text** (`assert_sql/3,4`) — compiles two queries to SQL via
  `Ecto.Adapters.SQL.to_sql/3` and compares the SQL strings. Requires a repo
  but does not execute the query.
- **Dynamic expressions** (`assert_dynamic/2`) — compares two
  `Ecto.Query.dynamic/2` expressions by their AST string via
  `Macro.to_string/1`. No database connection required.

### Setup

Add `use EctoShorts.Testing, repo: MyApp.Repo` to bind the repo at compile
time. This injects two-argument forms of `assert_sql/2,3` and
`refute_sql/2,3` that forward to the full `assert_sql/4` / `refute_sql/4`
with the bound repo.

```elixir
defmodule MyApp.QueryTest do
  use ExUnit.Case
  use EctoShorts.Testing, repo: MyApp.Repo

  alias EctoShorts.CommonFilters
  alias EctoShorts.Schema.Post

  import Ecto.Query

  test "age filter builds a gte predicate" do
    expected = from p in Post, where: p.age >= ^18
    actual = CommonFilters.convert_params_to_filter(Post, %{age: %{gte: 18}})
    assert_query(expected, actual)
  end

  test "age filter generates correct SQL" do
    expected = from p in Post, where: p.age >= ^18
    actual = CommonFilters.convert_params_to_filter(Post, %{age: %{gte: 18}})
    assert_sql(expected, actual)
  end
end
```

### Available assertions

| Function | Arguments | Description |
|---|---|---|
| `assert_query/2` | `(query_a, query_b)` | Assert two queries have the same inspect output |
| `refute_query/2` | `(query_a, query_b)` | Assert two queries differ |
| `assert_sql/3` | `(repo, query_a, query_b)` | Assert both queries produce the same SQL string |
| `assert_sql/4` | `(repo, query_a, query_b, kind)` | Same, with explicit SQL kind (`:all`, `:update_all`, `:delete_all`) |
| `refute_sql/3` | `(repo, query_a, query_b)` | Assert both queries produce different SQL |
| `refute_sql/4` | `(repo, query_a, query_b, kind)` | Same, with explicit kind |
| `assert_dynamic/2` | `(expr_a, expr_b)` | Assert two dynamic expressions have the same AST string |
| `refute_dynamic/2` | `(expr_a, expr_b)` | Assert two dynamic expressions differ |

When using `use EctoShorts.Testing, repo: MyRepo`, the injected helpers
accept `(query_a, query_b)` for `assert_sql` / `refute_sql` — the repo
argument is filled in from the compile-time binding.

### Runnable examples

#### assert_query/2 — structure check without database

```elixir
defmodule MyApp.StructureTest do
  use ExUnit.Case
  use EctoShorts.Testing, repo: MyApp.Repo

  alias EctoShorts.CommonFilters
  alias EctoShorts.Schema.Post

  import Ecto.Query

  test "ilike filter wraps value in % automatically" do
    expected = from p in Post, where: ilike(p.title, ^"%hello%")
    actual = CommonFilters.convert_params_to_filter(Post, %{title: %{ilike: "hello"}})
    assert_query(expected, actual)
  end

  test "pagination sets correct limit and offset" do
    expected = from p in Post, limit: ^20, offset: ^20
    actual = CommonFilters.convert_params_to_filter(Post, %{page: %{index: 2, size: 20}})
    assert_query(expected, actual)
  end
end
```

#### assert_sql/3 — SQL text comparison

```elixir
defmodule MyApp.SqlTest do
  use ExUnit.Case
  use EctoShorts.Testing, repo: MyApp.Repo

  alias EctoShorts.CommonFilters
  alias EctoShorts.Schema.Post

  import Ecto.Query

  test "in filter generates SQL IN clause" do
    expected = from p in Post, where: p.status in ^[:active, :pending]
    actual = CommonFilters.convert_params_to_filter(Post, %{status: %{in: [:active, :pending]}})
    assert_sql(expected, actual)
  end

  test "update_all SQL is correct" do
    expected = from p in Post, where: p.published == ^false, update: [set: [published: true]]
    actual = CommonFilters.convert_params_to_filter(Post, %{published: false,
      update: [set: [published: true]]})
    assert_sql(expected, actual, :update_all)
  end
end
```

#### assert_dynamic/2 — dynamic expression builder test

```elixir
defmodule MyApp.DynamicTest do
  use ExUnit.Case

  import Ecto.Query

  test "dynamic expressions are structurally equal" do
    expr_a = dynamic([p], p.published == ^true)
    expr_b = dynamic([p], p.published == ^true)
    EctoShorts.Testing.assert_dynamic(expr_a, expr_b)
  end

  test "different dynamic expressions are not equal" do
    expr_a = dynamic([p], p.published == ^true)
    expr_b = dynamic([p], p.published == ^false)
    EctoShorts.Testing.refute_dynamic(expr_a, expr_b)
  end
end
```

#### Without use — passing repo explicitly

When you cannot use the `use` macro (e.g. in library tests), pass the repo
as the first argument:

```elixir
defmodule EctoShorts.CommonFilters.MyTest do
  use ExUnit.Case

  alias EctoShorts.CommonFilters
  alias EctoShorts.Schema.Post

  import Ecto.Query

  test "filter generates expected SQL" do
    expected = from p in Post, where: p.title == ^"Hello"
    actual = CommonFilters.convert_params_to_filter(Post, %{title: "Hello"})
    EctoShorts.Testing.assert_sql(EctoShorts.Test.Repo, expected, actual)
  end
end
```

## Test Schemas

Test schemas are defined in `test/support/schema/`. They are minimal schemas used across all tests -- do not add application logic to them.

### Post

```elixir
# belongs_to :author (User)
# many_to_many :authors, User (via PostAuthor join table)
# has_many :comments
# has_many :composite_primary_keys
# field :title, :string
# field :body, :string
# field :notes, :string          # source: :custom_string_field (custom column name)
# field :permalink, :string
# field :published_at, :utc_datetime
# field :published, :boolean
# field :tags, {:array, :string} # used for array filter tests
# field :views, :integer
```

### User

```elixir
# has_many :posts
# has_many :comments
# has_many :books
# many_to_many :posts, Post (via PostAuthor join table)
# field :first_name, :string
# field :last_name, :string
# field :age, :integer
# field :email, :string
```

### Comment

```elixir
# belongs_to :author (User)
# belongs_to :post
# field :body, :string
# field :published, :boolean
# field :published_at, :utc_datetime
# field :replies, :integer
# field :tags, {:array, :string}
```

### Book

```elixir
# belongs_to :author (User)
# No :id primary key
# field :title, :string
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
- **Schemaless**: no type information is available, so `%{tags: %{in: [...]}}` routes to `ScalarExpr` (scalar `IN`). To force array routing, use the `:array` wrapper: `%{tags: %{array: %{in: [...]}}}`.

The schemaless test file verifies that the `:array` wrapper works and that scalar routing is the default.

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
- [API Reference](reference/api-reference.md) -- EctoShorts.Testing function signatures
