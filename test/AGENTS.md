# test — Test Suite Overview

The test suite requires a running PostgreSQL instance. All tests use the `ecto_shorts_test` database on `localhost:5432` (postgres user, no password by default).

## Running tests

```bash
mix test                                        # all tests
mix test test/path/to_file_test.exs             # one file
mix test test/path/to_file_test.exs:42          # one test by line number

# Filter by tag:
mix test --only feature:comparison              # one filter feature
mix test --only schema_mode:schemaless          # schemaless cases only
```

## Directory structure

The test directory mirrors the lib directory exactly. To find the test for a source module, replace `lib/` with `test/`, and add `_test` before `.exs`:

```
lib/ecto_shorts/common_filters/filters/join.ex
  → test/ecto_shorts/common_filters/filters/join_test.exs
```

Sub-directories with their own AGENTS.md:
- `support/` — test schemas, repo, DataCase, and filter contract. See [support/AGENTS.md](support/AGENTS.md).
- `ecto_shorts/actions/` — tests for the Actions subsystem.
- `ecto_shorts/common_filters/` — tests for the filter pipeline.
- `ecto_shorts/common_filters/filters/` — one test file per filter module.
- `ecto_shorts/dynamic_builders/` — tests for the adapter system.
- `ecto_shorts/dynamic_builders/postgres/` — tests for the Postgres adapter sub-modules.
- `ecto_shorts/dynamic_builders/contract/` — adapter-agnostic contract tests.

## Test categories

### Database-backed tests

Any test that reads or writes to the database uses `EctoShorts.DataCase` as the base case. `DataCase` wraps each test in a sandbox transaction that is rolled back after the test finishes, so tests do not affect each other.

### Query structure tests

Many tests check the structure of a query without running it against the database. These use `EctoShorts.Testing.assert_query/2` (inspect-form comparison) or `EctoShorts.Testing.assert_sql/4` (SQL string comparison). They do not require `DataCase`.

### Dynamic expression tests

Tests for the dynamic builder adapters check `DynamicExpr` values with `EctoShorts.Testing.assert_dynamic/2`. These also do not require a database.

## Test tags

Tests use two tag namespaces:

| Tag | Values | What it selects |
|---|---|---|
| `feature:` | any atom | A specific filter operator or feature |
| `schema_mode:` | `:schemaless` | Tests that use `{source, schema}` tuple sources |

Schema-backed and schemaless tests live in the same file. Schemaless tests are in `describe` blocks tagged `@describetag schema_mode: :schemaless`.

## Invalid field tests

Any test that passes a field name that does not exist on the schema **must** use `ExUnit.CaptureLog.capture_log/1`. The filter pipeline emits a `Logger.warning` for unknown fields. Without the wrapper, the warning is unverified noise in test output. With the wrapper, the test can assert on the log message.

```elixir
log = capture_log(fn ->
  actual = CommonFilters.convert_params_to_filter(Post, %{nonexistent_xyz: 5}, [])
  assert_query(expected, actual)
end)

assert log =~ "does not exist on schema"
```
