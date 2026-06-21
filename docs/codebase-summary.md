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
|       |   +-- error.ex                  # Default error-response builder (@behaviour EctoShorts.Actions.Error)
|       +-- common_params/
|       |   +-- timestamps.ex             # Timestamp injection for insert params
|       |   +-- placeholders.ex           # Placeholder param helpers
|       +-- query_builder.ex              # @behaviour QueryBuilder (build_query/6)
|       +-- dynamic_builder.ex            # @behaviour DynamicBuilder (build_dynamic/4)
|       +-- query_provider.ex             # @behaviour QueryProvider (query_expression/4)
|       +-- query_builders.ex             # QueryBuilders dispatch adapter
|       +-- query_binding.ex              # Compile-time clause generation macro
|       +-- common_query.ex               # Shared query utilities
|       +-- common_schema.ex              # Schema reflection helpers
|       +-- schema_helpers.ex             # Schema introspection utilities
|       +-- utils.ex                      # General utility functions
|       +-- log_utils.ex                  # Structured logging helpers
|       +-- types.ex                      # Custom Ecto types
|       +-- common_filters/
|       |   +-- builder.ex                # Reduce loop + apply_filters dispatch
|       |   +-- filters/
|       |       +-- distinct.ex               # :distinct filter
|       |       +-- except.ex                 # :except set operation
|       |       +-- except_all.ex             # :except_all set operation
|       |       +-- group_by.ex               # :group_by filter
|       |       +-- having.ex                 # :having filter
|       |       +-- intersect.ex              # :intersect set operation
|       |       +-- intersect_all.ex          # :intersect_all set operation
|       |       +-- join.ex                   # :join filter
|       |       +-- last.ex                   # :last terminal filter
|       |       +-- limit.ex                  # :limit (and :first alias) filter
|       |       +-- lock.ex                   # :lock filter
|       |       +-- offset.ex                 # :offset filter
|       |       +-- or_having.ex              # :or_having filter
|       |       +-- order_by.ex               # :order_by filter
|       |       +-- page.ex                   # :page filter
|       |       +-- preload.ex                # :preload filter
|       |       +-- prepend_order_by.ex       # :prepend_order_by filter
|       |       +-- put_query_prefix.ex       # :put_query_prefix filter
|       |       +-- recursive_ctes.ex         # :recursive_ctes filter
|       |       +-- reverse_order.ex          # :reverse_order filter
|       |       +-- select.ex                 # :select filter
|       |       +-- select_merge.ex           # :select_merge filter
|       |       +-- sub_query.ex              # :subquery terminal filter
|       |       +-- union.ex                  # :union set operation
|       |       +-- union_all.ex              # :union_all set operation
|       |       +-- update.ex                 # :update filter
|       |       +-- update_expr.ex            # :update_expr filter
|       |       +-- windows.ex                # :windows filter
|       |       +-- with_cte.ex               # :with_cte filter
|       |       +-- with_named_binding.ex     # :with_named_binding filter
|       |       +-- with_ties.ex              # :with_ties filter
|       +-- dynamic_builders/
|           +-- postgres.ex               # DynamicBuilders.Postgres dispatcher
|           +-- postgres/
|               +-- scalar_expr.ex        # Comparisons, equality, in, like, ilike, negation
|               +-- array_expr.ex         # Postgres array operators (&&, @>, <@, etc.)
|               +-- common_expr.ex        # Arithmetic, aggregate, date/datetime, string functions
|               +-- map_expr.ex           # JSONB / map field expressions
|               +-- scalar_expr/          # Sub-modules for scalar expression types
|                   +-- aggregate.ex      # Aggregate function expressions
|                   +-- comparison.ex     # Comparison operators
|                   +-- membership.ex     # IN / NOT IN membership checks
|                   +-- string.ex         # String predicates (LIKE, ILIKE)
|                   +-- string_transform.ex # String transformation helpers
+-- test/
|   +-- ecto_shorts/
|   |   +-- common_filters/               # Schema-backed filter tests (41 files)
|   |   +-- common_filters_schemaless/    # Schemaless filter tests (39 files)
|   |   +-- dynamic_builders/             # Expression builder unit tests
|   |   |   +-- postgres/                 # Postgres-specific expression tests
|   |   +-- actions/                      # Actions integration tests (7 files)
|   +-- support/
|       +-- data_case.ex                  # EctoShorts.DataCase base case
|       +-- repo.ex                       # Test repo module
|       +-- schema/
|           +-- post.ex                   # Post schema (has_many :comments, many_to_many :authors, tags array)
|           +-- user.ex                   # User schema (has_many :posts, :comments, :books; many_to_many :posts via PostAuthor)
|           +-- comment.ex                # Comment schema (belongs_to :post, :author; tags array)
|           +-- book.ex                   # Book schema (belongs_to :author; no :id primary key)
|           +-- post_author.ex            # Join-through schema for many_to_many Post/User
|           +-- composite_primary_key.ex  # Composite PK on comment_id + post_id
|           +-- enum_schema.ex            # Ecto.Enum field tests
|           +-- post_with_lock.ex         # Post variant for :lock filter tests
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
| `lib/ecto_shorts/query_builder.ex` | Behaviour definition. One callback: `build_query/6`. |
| `lib/ecto_shorts/dynamic_builder.ex` | Behaviour definition. One callback: `build_dynamic/4`. |
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

- [System Architecture](explanation/architecture.md) -- component diagrams, filter pipeline flow, adapter extension points
- [API Reference](reference/api-reference.md) -- complete function signatures for all public modules
- [Testing Guide](testing-guide.md) -- test setup, DataCase, dual-file pattern, coverage
- [Code Standards](https://github.com/MikaAK/ecto_shorts/blob/main/docs/code-standards.md) -- naming conventions, adding filters, Credo, Dialyzer
