# EctoShorts Test Scenario Inventory

Version: 2026-04-07  
Baseline coverage: 87.0% (1479 tests, 0 failures)

Coverage classification key:
- (A) Already covered — at least one test proves this behavior
- (B) Partially covered — some branches covered, gap noted
- (C) Not covered — zero tests exercise this path

---

## EctoShorts.QueryBuilders

- (C) `build_query/6` uses the default adapter (`CommonFilters.Builder`) when no opts or config override is set
- (C) `build_query/6` uses the `opts[:query_builder_module]` override at runtime over config
- (C) `build_query/6` logs a warning and returns the query unchanged when the resolved module does not export `build_query/6`
- (C) `build_query/6` raises `ArgumentError` when `opts[:query_builder_module]` is not a module atom (e.g. a string or integer)
- (C) `build_query/6` uses the `Config.query_builder_module()` config value when no runtime opt is given

---

## EctoShorts.DynamicBuilders

- (A) `build_dynamic/4` delegates to `DynamicBuilders.Postgres` when the repo adapter is `Ecto.Adapters.Postgres`
- (A) `build_dynamic/4` uses the `:dynamic_builder` opt at call time to override adapter resolution
- (C) `build_dynamic/4` raises with "Adapter not yet implemented" for `Ecto.Adapters.MyXQL`
- (C) `build_dynamic/4` raises with "Adapter not yet implemented" for `Ecto.Adapters.SQL`
- (C) `build_dynamic/4` raises with "Adapter not yet implemented" for `Ecto.Adapters.Tds`
- (C) `build_dynamic/4` raises with unsupported adapter message for an unknown adapter
- (B) `build_dynamic/4` uses `Config.repo!/1` fallback when neither `:repo` nor `:replica` is in opts (config path not directly unit tested)

---

## EctoShorts.Utils

- (A) `atomize_keys/1` returns string-keyed map unchanged (unknown atom key stays string)
- (A) `atomize_keys/1` returns atom-keyed map unchanged
- (A) `atomize_keys/1` recursively transforms nested maps
- (C) `atomize_keys/1` converts a string key to an atom when the atom already exists
- (C) `atomize_keys/1` on a keyword list (list of `{key, value}` tuples)
- (C) `atomize_keys/1` on a bare tuple `{key, value}`
- (C) `atomize_keys/1` on a flat non-keyword list (passthrough of scalar elements)

---

## EctoShorts.Config

- (A) `repo!/1` raises when no repo is configured (via doctest)
- (A) `replica!/1` raises when no replica or repo is configured (via doctest)
- (A) `error_module/0` returns `EctoShorts.Actions.Error` by default (via doctest)
- (A) `dynamic_builder_module/0` returns nil by default (via doctest)
- (A) `query_builder_module/0` returns nil by default (via doctest)
- (A) `query_provider_module/0` returns nil by default (via doctest)
- (A) `max_positional_bindings/0` returns nil by default (via doctest)
- (C) `repo!/1` returns the value from `opts[:repo]` when given at runtime
- (C) `replica!/1` falls back to `opts[:repo]` when no replica is set
- (C) `replica!/1` returns the value from `opts[:replica]` when given at runtime

---

## EctoShorts.Testing

- (A) `assert_dynamic/2` returns `:ok` when two dynamic expressions are structurally identical (via doctests)
- (A) `assert_query/2` returns `:ok` when two queries have equal inspect output (via doctests)
- (A) `assert_sql/4` returns `:ok` when two queries produce the same SQL (via doctests)
- (A) `refute_dynamic/2` returns `:ok` when expressions differ
- (A) `refute_sql/4` returns `:ok` when queries produce different SQL
- (A) `refute_query/2` returns `:ok` when queries differ
- (C) `assert_dynamic/2` calls `flunk/1` when expressions differ (failure path)
- (C) `assert_query/2` calls `flunk/1` when queries differ (failure path)
- (C) `assert_sql/4` calls `flunk/1` when SQL differs (failure path)
- (C) `refute_dynamic/2` calls `flunk/1` when expressions are identical (failure path)
- (C) `refute_sql/4` calls `flunk/1` when SQL is identical (failure path)
- (C) `refute_query/2` calls `flunk/1` when queries are identical (failure path)
- (C) `use EctoShorts.Testing` with explicit `:repo` injects `assert_sql/2` bound to that repo
- (C) `use EctoShorts.Testing` without `:repo` binds to `Config.repo()`

---

## EctoShorts.CommonFilters.UpdateExpr

- (A) `build_update_operations/3` converts a map of params to a set operation list
- (A) `build_update_operations/3` converts a keyword list of params to a set operation list
- (C) `build_update_operations/3` logs warning and returns `[]` when params is not a map or list
- (C) `build_update_expr/2` returns a `DynamicExpr` unchanged when given a `DynamicExpr` directly
- (A) `build_update_expr/2` converts map-form `[set: [...]]` keyword to typed update expr
- (A) `build_update_expr/2` converts `[inc: [...]]` with integer casting
- (C) `build_update_expr/2` logs warning and returns params unchanged when given a non-map, non-list value
- (C) `reduce_update/4` raises `ArgumentError` for `:push` on a non-array field
- (C) `reduce_update/4` raises `ArgumentError` for `:pull` on a non-array field
- (C) `reduce_update/4` raises `ArgumentError` for `:inc` on a non-integer field
- (C) `reduce_update/4` raises `ArgumentError` for `:inc` with a non-integer-castable value
- (B) `build_update_operations/3` with `nil` source (schemaless) skips field filtering

---

## EctoShorts.CommonFilters.OrHaving

- (B) `:or_having` with a scalar term builds `OR HAVING` clause on root binding
- (C) `:or_having` with `nil` value returns query unchanged
- (C) `:or_having` with a pre-built `DynamicExpr` appends it directly without re-building
- (C) `:or_having` with a named binding resolves source from query and applies named binding
- (C) `:or_having` with a positional binding resolves source from query and applies positional binding

---

## EctoShorts.CommonFilters.Page

- (A) `:page` with `%{index: N, size: M}` applies correct offset and limit (offset-based)
- (A) `:page` with `%{after: cursor, by: field, size: N}` applies WHERE field > cursor + ORDER BY ASC + LIMIT
- (A) `:page` with `%{after: nil, by: field, size: N}` applies ORDER BY ASC + LIMIT without WHERE
- (A) `:page` with `%{before: cursor, by: field, size: N}` applies WHERE field < cursor + ORDER BY DESC + LIMIT
- (C) `:page` with `%{before: nil, by: field, size: N}` applies ORDER BY DESC + LIMIT without WHERE
- (C) `:page` with string index/size values (casts to integer via `Types.cast/2`)

---

## EctoShorts.CommonFilters.Preload

- (A) `:preload` with an atom on root binding adds simple preload
- (A) `:preload` with a list of atoms adds multiple preloads
- (B) `:preload` with a named binding applies preload scoped to that binding
- (C) `:preload` with a map-form nested value (converts map to keyword list before preloading)
- (C) `:preload` with a non-atom scalar (passthrough of un-normalizable preload term)

---

## EctoShorts.CommonFilters (routing and structural)

- (A) `convert_params_to_filter/3` accepts a schema module as source
- (A) `convert_params_to_filter/3` accepts a schemaless string source
- (A) `convert_params_to_filter/3` accepts a `{source, schema}` tuple
- (A) `convert_params_to_filter/3` accepts an existing `Ecto.Query` as source
- (A) `convert_params_to_filter/3` sorts `:where` before other keys before `:or_where` before `:last`/`:subquery`
- (A) `convert_params_to_filter/3` handles unknown field names without error (logged and skipped)
- (B) `convert_params_to_filter/3` routes through custom `query_builder_module` when configured

---

## Schema/Schemaless routing divergence (requires both suites)

- (A) Array field with `:in` on schema-backed source routes to array overlap (`&&`)
- (A) Array field with `:in` on schemaless source without `:elements` routes to scalar IN
- (A) Array field with `:in` on schemaless source with `:elements` routes to array overlap
- (A) Ecto.Enum field: atom value is cast to integer mapping on schema-backed source
- (B) Ecto.Enum field: no special casting on schemaless source (passes through as-is)
- (A) `field_types:` opt on schemaless source overrides type-inference for array routing

---

## Adapter and extension point behaviors

- (C) Custom `DynamicBuilder` adapter passed via `:dynamic_builder` opt is invoked
- (C) Custom `QueryBuilder` adapter passed via `:query_builder_module` opt receives all filter keys
- (C) Custom `QueryProvider` module provides named query fragments for `:lock` filter

---

## Operator alias coverage (normalizer unit tests sufficient; schema tests can be pruned)

- (A) `:eq` alias normalizes to `:==`
- (A) `:ne` alias normalizes to `:!=`
- (A) `:gt` alias normalizes to `:>`
- (A) `:gte` alias normalizes to `:>=`
- (A) `:lt` alias normalizes to `:<`
- (A) `:lte` alias normalizes to `:<=`
- (A) `:downcase` / `:lower` alias apply SQL LOWER() function
- (A) `:upcase` / `:upper` alias apply SQL UPPER() function

---

## Summary

| Classification | Count |
|----------------|-------|
| (A) Already covered | 43 |
| (B) Partially covered | 9 |
| (C) Not covered | 34 |
| **Total** | **86** |

### Top fill targets (by module priority from rubric)

1. `QueryBuilders` — 5 uncovered paths, 0% module coverage
2. `DynamicBuilders` — 5 uncovered adapter-raise paths, 50% module coverage
3. `UpdateExpr` — 5 uncovered error/warning paths, 65% module coverage
4. `Testing` — 6 uncovered failure-path assertions, 72% module coverage
5. `Utils` — 4 uncovered transform paths (keyword list, tuple, scalar), 66.6% module coverage
6. `OrHaving` — 4 uncovered binding/nil paths, 61.5% module coverage
7. `Config` — 3 uncovered runtime-opt paths, 83.3% module coverage
