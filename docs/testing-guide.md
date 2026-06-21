# Testing Your EctoShorts Code

When you build queries with `EctoShorts.CommonFilters` (or call `EctoShorts.Actions`),
you often want a test that proves a given set of params produces the query you
expect — *before* it ever hits the database. `EctoShorts.Testing` gives you
assertion helpers to do exactly that.

This guide shows how to use those helpers in **your own** application's test
suite. It assumes you already have EctoShorts installed and configured (see
[Getting Started](getting-started.md)).

## Why these helpers

A filter call like `convert_params_to_filter(Post, %{age: %{gte: 18}})` returns
an `Ecto.Query`. You *could* test it by converting to a string and matching
substrings, but that is brittle. `EctoShorts.Testing` compares queries
structurally at three levels, so your tests stay readable and break only when
behaviour actually changes:

| Helper | Compares | Needs a repo? | Runs the query? |
|---|---|---|---|
| `assert_query/2` | the two `Ecto.Query` structs (inspect form) | No | No |
| `assert_sql/3,4` | the SQL string each query compiles to | Yes | No |
| `assert_dynamic/2` | two `Ecto.Query.dynamic/2` expressions (AST) | No | No |

Each has a `refute_*` counterpart that asserts the two inputs **differ**.

None of these execute the query, so most of your filter tests need no database
connection at all — only `assert_sql` needs a repo (to compile SQL), and even
then it never runs the statement.

## Setup

Add `use EctoShorts.Testing, repo: MyApp.Repo` to your test module. This imports
the assertion helpers and binds your repo at compile time, so the `assert_sql` /
`refute_sql` helpers don't need a repo argument on every call:

```elixir
defmodule MyApp.PostQueryTest do
  use ExUnit.Case
  use EctoShorts.Testing, repo: MyApp.Repo

  import Ecto.Query

  alias EctoShorts.CommonFilters
  alias MyApp.Post

  test "age filter builds a >= predicate" do
    expected = from p in Post, where: p.age >= ^18
    actual = CommonFilters.convert_params_to_filter(Post, %{age: %{gte: 18}})

    assert_query(expected, actual)
  end
end
```

You write the query you *expect* by hand with `Ecto.Query`, build the `actual`
query through EctoShorts, and assert they match.

## Strategy 1 — check query structure (`assert_query/2`)

The fastest check, and no database required. Use it when you care about how the
query is *built* — predicates, limits, joins, ordering:

```elixir
test "ilike filter wraps the value in % automatically" do
  expected = from p in Post, where: ilike(p.title, ^"%hello%")
  actual = CommonFilters.convert_params_to_filter(Post, %{title: %{ilike: "hello"}})

  assert_query(expected, actual)
end

test "page params set limit and offset" do
  expected = from p in Post, limit: ^20, offset: ^20
  actual = CommonFilters.convert_params_to_filter(Post, %{page: %{index: 2, size: 20}})

  assert_query(expected, actual)
end
```

## Strategy 2 — check SQL output (`assert_sql/3,4`)

Use this when you want to verify the *generated SQL*, e.g. for PostgreSQL-specific
features (array operators, JSONB). It compiles both queries to SQL through your
repo but does **not** execute them.

With `use EctoShorts.Testing, repo: MyApp.Repo`, call the two-argument form:

```elixir
test "in filter produces a SQL IN clause" do
  expected = from p in Post, where: p.status in ^[:active, :pending]
  actual = CommonFilters.convert_params_to_filter(Post, %{status: %{in: [:active, :pending]}})

  assert_sql(expected, actual)
end
```

For non-`SELECT` statements, pass the SQL kind as a third argument
(`:all` (default), `:update_all`, or `:delete_all`):

```elixir
test "update params compile to the right UPDATE" do
  expected =
    from p in Post, where: p.published == ^false, update: [set: [published: true]]

  actual =
    CommonFilters.convert_params_to_filter(Post, %{
      published: false,
      update: [set: [published: true]]
    })

  assert_sql(expected, actual, :update_all)
end
```

## Strategy 3 — check dynamic expressions (`assert_dynamic/2`)

Use this when you build `Ecto.Query.dynamic/2` fragments directly — most often
when writing a custom `EctoShorts.DynamicBuilder` (see the
[Extending guide](guides/extending.md)). It compares the two expressions by
their AST, so no repo or database is involved:

```elixir
defmodule MyApp.DynamicTest do
  use ExUnit.Case

  import Ecto.Query

  test "two equal dynamic expressions match" do
    a = dynamic([p], p.published == ^true)
    b = dynamic([p], p.published == ^true)

    EctoShorts.Testing.assert_dynamic(a, b)
  end

  test "different dynamic expressions are refuted" do
    a = dynamic([p], p.published == ^true)
    b = dynamic([p], p.published == ^false)

    EctoShorts.Testing.refute_dynamic(a, b)
  end
end
```

## Choosing the right assertion

| If you want to… | Use |
|---|---|
| Verify query construction quickly, no DB | `assert_query/2` |
| Verify the exact SQL (e.g. array/JSONB operators) | `assert_sql/3,4` |
| Verify a hand-built or custom-adapter dynamic expression | `assert_dynamic/2` |
| Prove two queries / SQL / expressions are **not** the same | the matching `refute_*` |

## Calling without `use`

If you can't add `use EctoShorts.Testing` to a module, call the functions
directly and pass the repo explicitly as the first argument to `assert_sql` /
`refute_sql`:

```elixir
defmodule MyApp.PlainTest do
  use ExUnit.Case

  import Ecto.Query

  alias EctoShorts.CommonFilters
  alias MyApp.Post

  test "filter generates the expected SQL" do
    expected = from p in Post, where: p.title == ^"Hello"
    actual = CommonFilters.convert_params_to_filter(Post, %{title: "Hello"})

    EctoShorts.Testing.assert_sql(MyApp.Repo, expected, actual)
  end
end
```

`assert_query/2` and `assert_dynamic/2` never take a repo, so they are identical
with or without `use`.

## Function reference

| Function | Arguments | Asserts |
|---|---|---|
| `assert_query/2` | `(query_a, query_b)` | same query structure |
| `refute_query/2` | `(query_a, query_b)` | queries differ |
| `assert_sql/3` | `(repo, query_a, query_b)` | same SQL (kind `:all`) |
| `assert_sql/4` | `(repo, query_a, query_b, kind)` | same SQL for `kind` (`:all`/`:update_all`/`:delete_all`) |
| `refute_sql/3,4` | `(repo, query_a, query_b[, kind])` | SQL differs |
| `assert_dynamic/2` | `(expr_a, expr_b)` | same dynamic AST |
| `refute_dynamic/2` | `(expr_a, expr_b)` | dynamic expressions differ |

With `use EctoShorts.Testing, repo: MyApp.Repo`, the repo-bound forms drop the
first argument: `assert_sql(query_a, query_b)` and
`assert_sql(query_a, query_b, kind)`.

## Cross-References

- [Getting Started](getting-started.md) — install and configure EctoShorts
- [Filtering Guide](guides/filtering.md) — the filter params these tests assert on
- [Extending Guide](guides/extending.md) — writing the custom builders `assert_dynamic/2` helps test
- `EctoShorts.Testing` — full function docs
