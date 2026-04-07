# EctoShorts Codebase Summary

## Directory Structure

```
ecto_shorts/
+-- lib/
|   +-- ecto_shorts.ex                    # Top-level module, version constant
|   +-- ecto_shorts/
|       +-- actions.ex                    # Public Actions facade
|       +-- common_filters.ex             # Public CommonFilters facade + dispatcher
|       +-- common_changes.ex             # Changeset helpers
|       +-- common_params.ex              # Param-building utilities
|       +-- config.ex                     # Config reader (repo, replica, adapters)
|       +-- testing.ex                    # Assertion helpers for query tests
|       +-- actions/
|       |   +-- crud.ex                   # get, create, update, delete, find
|       |   +-- bulk.ex                   # insert_all, update_all, delete_all
|       |   +-- batch.ex                  # batch, batch_find
|       |   +-- multi.ex                  # create_many, update_many, delete_many, find_many
|       |   +-- transaction.ex            # transaction, transact
|       |   +-- source.ex                 # source-based query helpers
|       |   +-- error.ex                  # Default error-response builder
|       +-- adapter/
|       |   +-- query_builder.ex          # @behaviour QueryBuilder (build_query/6)
|       |   +-- dynamic_builder.ex        # @behaviour DynamicBuilder (build_dynamic/4)
|       |   +-- query_provider.ex         # @behaviour QueryProvider
|       +-- common_filters/
|       |   +-- builder.ex                # Reduce loop + apply_filters dispatch
|       |   +-- sorter.ex                 # Param sort (where -> others -> or_where -> terminal)
|       |   +-- query_binding.ex          # Compile-time clause generation macro
|       |   +-- join.ex                   # :join filter
|       |   +-- order_by.ex               # :order_by filter
|       |   +-- group_by.ex               # :group_by filter
|       |   +-- having.ex                 # :having filter
|       |   +-- select.ex                 # :select filter
|       |   +-- with_cte.ex               # :with_cte filter
|       |   +-- subquery.ex               # :subquery terminal filter
|       |   +-- preload.ex                # :preload filter
|       |   +-- limit.ex                  # :first / :last filters
|       |   +-- lock.ex                   # :lock filter
|       |   +-- distinct.ex               # :distinct filter
|       |   +-- offset.ex                 # :offset filter
|       |   +-- where.ex                  # :where predicate filter
|       |   +-- or_where.ex               # :or_where predicate filter
|       |   +-- search.ex                 # :search delegation filter
|       |   +-- ids.ex                    # :ids shorthand filter
|       |   +-- before.ex                 # :before cursor filter
|       |   +-- after.ex                  # :after cursor filter
|       |   +-- start_date.ex             # :start_date filter
|       |   +-- end_date.ex               # :end_date filter
|       |   +-- and_filter.ex             # :and boolean group filter
|       |   +-- or_filter.ex              # :or boolean group filter
|       +-- dynamic_builders/
|           +-- postgres.ex               # DynamicBuilders.Postgres dispatcher
|           +-- postgres/
|               +-- scalar_expr.ex        # Comparisons, equality, in, like, ilike, negation
|               +-- array_expr.ex         # Postgres array operators (&&, @>, <@, etc.)
|               +-- common_expr.ex        # Arithmetic, aggregate, date/datetime, string functions
|               +-- map_expr.ex           # JSONB / map field expressions
|               +-- normalizer.ex         # Normalize raw filter values before expression build
+-- test/
|   +-- ecto_shorts/
|   |   +-- common_filters/               # Schema-backed filter tests (30 files)
|   |   +-- common_filters_schemaless/    # Schemaless filter tests (30 files)
|   |   +-- dynamic_builders/             # Expression builder unit tests
|   |   +-- actions/                      # Actions integration tests
|   +-- support/
|       +-- data_case.ex                  # EctoShorts.DataCase base case
|       +-- repo.ex                       # Test repo module
|       +-- schema/
|           +-- post.ex                   # Post schema (has_many :comments, tags array)
|           +-- user.ex                   # User schema (has_many :posts, many_to_many :roles)
|           +-- comment.ex                # Comment schema (belongs_to :post)
|           +-- book.ex                   # Book schema (used in bulk/batch tests)
+-- priv/
|   +-- repo/migrations/                  # Test DB migrations
+-- docs/                                 # This documentation directory
+-- mix.exs
+-- .credo.exs
```

## Key Files and Their Roles

| File | Role |
|---|---|
| `lib/ecto_shorts/actions.ex` | Public facade. Delegates to CRUD, Bulk, Batch, Multi, Transaction sub-modules. All public functions live here or are re-exported here. |
| `lib/ecto_shorts/common_filters.ex` | Public facade for query building. Entry point is `convert_params_to_filter/3`. Owns the `@sorting_filters`, `@all_filters` attributes and `do_build_query` dispatch. |
| `lib/ecto_shorts/common_filters/builder.ex` | The reduce loop. Iterates sorted params, calls `apply_filters/6`, threads the accumulating `Ecto.Query`. |
| `lib/ecto_shorts/query_binding.ex` | Macro that generates compile-time function clauses for root, named (`:as`), and positional (`:at`) binding shapes. |
| `lib/ecto_shorts/config.ex` | Reads application config. Provides `repo!/1`, `replica!/1`, `dynamic_builder_module/0`, `query_builder_module/0`. |
| `lib/ecto_shorts/dynamic_builders/postgres.ex` | Routes to `ScalarExpr`, `ArrayExpr`, `CommonExpr`, or `MapExpr` based on field type and operator wrapper. |
| `lib/ecto_shorts/adapter/query_builder.ex` | Behaviour definition. One callback: `build_query/6`. |
| `lib/ecto_shorts/adapter/dynamic_builder.ex` | Behaviour definition. One callback: `build_dynamic/4`. |
| `test/support/data_case.ex` | `EctoShorts.DataCase` -- extends `ExUnit.Case`, sets up `Ecto.Adapters.SQL.Sandbox` transactions. |

## Key Dependencies

| Package | Version | Type | Purpose |
|---|---|---|---|
| `ecto` | `>= 3.0.0` | runtime | ORM abstraction layer |
| `ecto_sql` | `>= 3.0.0` | runtime | SQL adapters for Ecto |
| `postgrex` | optional | optional | PostgreSQL driver |
| `error_message` | latest | runtime | Error response normalization |
| `ex_doc` | latest | dev | Documentation generation |
| `credo` | latest | dev | Static analysis linter |
| `blitz_credo_checks` | latest | dev | Custom Credo check extensions |
| `dialyxir` | latest | dev | Type checking via Dialyzer |
| `excoveralls` | latest | dev | Code coverage reporting |
| `factory_ex` | latest | dev/test | Test data factory generation |

## Cross-References

- [System Architecture](system-architecture.md) -- component diagrams, filter pipeline flow, adapter extension points
- [API Reference](api-reference.md) -- complete function signatures for all public modules
- [Testing Guide](testing-guide.md) -- test setup, DataCase, dual-file pattern, coverage
- [Code Standards](code-standards.md) -- naming conventions, adding filters, Credo, Dialyzer
