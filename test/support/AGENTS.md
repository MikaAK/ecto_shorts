# test/support — Test Support Modules

This directory contains shared infrastructure used by all tests. Nothing here is part of the public library — these modules only exist to support the test suite.

## Core files

| File | What it provides |
|---|---|
| `data_case.ex` | `EctoShorts.DataCase` — the base test case for any test that hits the database. Wraps each test in an `Ecto.Adapters.SQL.Sandbox` transaction that rolls back after the test, so each test starts with a clean database state. |
| `repo.ex` | `EctoShorts.Repo` — a minimal Ecto repo module configured for the test database. Used as the `:repo` in test configuration. |
| `filter_contract.ex` | `EctoShorts.FilterContract` — an adapter-agnostic list of filter test cases. Every `DynamicBuilder` implementation must pass these cases. The contract is run by `test/ecto_shorts/dynamic_builders/contract/contract_test.exs`. |
| `test_query_provider.ex` | A `QueryProvider` implementation used in tests for joins, locks, and windows that reference named expressions. |
| `test_no_op_query_provider.ex` | A `QueryProvider` that returns `nil` for everything — used in tests that need a provider configured but should not affect the query. |
| `test_unsupported_adapter.ex` | A fake Ecto adapter module used to test the error path when no supported adapter is found. |
| `test_unsupported_repo.ex` | A fake repo that uses the unsupported adapter — used alongside `test_unsupported_adapter.ex`. |

## schema/ sub-directory

Contains lightweight Ecto schemas used across all tests. These schemas define only the fields and associations needed to exercise the filter and query building code.

| File | Schema | Purpose |
|---|---|---|
| `post.ex` | `Post` | Primary schema used in most tests. Has title, body, published, views, author_id, tags (array), inserted_at, updated_at. |
| `post_abstract.ex` | `PostAbstract` | Like `Post` but uses abstract schema prefix. |
| `post_abstract_has_schema_prefix.ex` | `PostAbstractHasSchemaPrefix` | Like `PostAbstract` but with a compile-time schema prefix. |
| `post_has_abstract_field_source.ex` | `PostHasAbstractFieldSource` | Tests field source mapping (`:source` option on fields). |
| `post_has_query_builder.ex` | `PostHasQueryBuilder` | A post schema that specifies a custom query builder module. |
| `post_has_schema_prefix.ex` | `PostHasSchemaPrefix` | Post with a static schema prefix for prefix-filter tests. |
| `post_author.ex` | `PostAuthor` | Join table between posts and authors. |
| `post_with_lock.ex` | `PostWithLock` | Post with a `lock_version` field for optimistic lock tests. |
| `user.ex` | `User` | Has a `has_many :posts`. Used for association filter tests. |
| `user_abstract.ex` | `UserAbstract` | Abstract version of `User`. |
| `user_data.ex` | `UserData` | Used for JSONB (`:map` type) field tests. |
| `comment.ex` | `Comment` | Has `belongs_to :post`. Used for join and association filter tests. |
| `comment_abstract.ex` | `CommentAbstract` | Abstract version of `Comment`. |
| `book.ex` | `Book` | Schema without timestamps — used to test timestamp-free insert paths. |
| `timestamp_free.ex` | `TimestampFree` | Schema explicitly without `:inserted_at` / `:updated_at`. |
| `enum_schema.ex` | `EnumSchema` | Has an Ecto enum field — used to test enum type casting. |
| `enum_parent.ex` | `EnumParent` | Parent schema with a `has_many` to `EnumSchema`. |
| `composite_primary_key.ex` | `CompositePrimaryKey` | Schema with a composite primary key — used to test upsert conflict resolution with multi-field primary keys. |
