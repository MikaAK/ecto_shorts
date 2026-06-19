## Changelog

#### V3.0.0

##### Breaking changes

- **`:start_date` and `:end_date` filter keys removed** — use `:since_date` (`inserted_at >= value`) and `:until_date` (`inserted_at <= value`) respectively; the removed keys were identical aliases with no behavioural difference

- **`EctoShorts.SchemaHelpers.any_created?/1` renamed to `any_persisted?/1`** — better aligns with the `*_schema_struct?/1` family and Ecto's persisted-record idiom
- **`EctoShorts.CommonChanges` predicate renames** — four predicate functions have been renamed for value-vs-change clarity: `changeset_field_nil?/2` → `field_nil?/2`, `changeset_field_empty?/2` → `field_empty?/2`, `has_nil_change?/2` → `change_nil?/2`, `has_empty_change?/2` → `change_empty?/2`
- **Minimum Elixir version** raised from `~> 1.13` to `~> 1.15`
- **`EctoShorts.CommonFilters` re-architected** — `EctoShorts.QueryBuilder`, `EctoShorts.QueryBuilder.Common`, and `EctoShorts.QueryBuilder.Schema` have been removed and replaced by a new dispatch system built on `EctoShorts.QueryBuilder` and dedicated per-filter builder modules under `EctoShorts.CommonFilters.*`
- **`EctoShorts.CommonChanges.put_when/3` renamed to `EctoShorts.CommonChanges.apply_when/3`** — `apply_when/3` also raises `ArgumentError` if the change function does not return a changeset
- **`EctoShorts.SchemaHelpers` function renames** — `schema?/1` -> `schema_struct?/1`, `all_schemas?/1` -> `all_schema_struct?/1`
- **`EctoShorts.Actions.find_or_create_many/3` rewritten** — now uses `Ecto.Multi` internally and returns `{:ok, list}` | `{:error, reason}` instead of merging found/created records by index
- **Runtime opt for query provider renamed** — the runtime opt key for supplying a `QueryProvider` to `CommonFilters` (and `Actions`) calls changed from `:query_provider_module` to `:query_provider`; the app-config key `:query_provider_module` is unchanged
- **`EctoShorts.Actions.delete/2` no longer accepts `(queryable, id)`** — id-based delete now requires the 3-arity form `delete(queryable, id, opts)`; `delete/2` unambiguously means `delete(struct_or_changeset_or_list, opts)`
- **`EctoShorts.Actions.batch/5` replaced by `batch/3`** — `batch_keys` and `cardinality` are now passed as opts keys (`:batch_keys`, default `:id`; `:cardinality`, default `:many`) instead of positional arguments
- **`EctoShorts.Actions.aggregate/5` replaced by `aggregate/3`** — the aggregate function and field key are now passed as opts keys (`:aggregate`, default `:count`; `:key`, default `:id`) instead of positional arguments
- **`EctoShorts.Actions.all/2` no longer accepts a keyword list** — the second argument must be a params map; to pass runtime options (`:repo`, `:replica`, `:preload`, etc.) use `all/3`

##### New modules

- **`EctoShorts.CommonParams`** — prepares data for `Ecto.Repo.insert_all/3` and `Ecto.Repo.update_all/3` bulk operations, including changeset validation, timestamp generation, placeholder management, and conflict resolution options
- **`EctoShorts.CommonQuery`** — runtime query introspection (source extraction, binding counts, binding source lookup)
- **`EctoShorts.DynamicBuilders`** — database-adapter-aware entry point for building `Ecto.Query.DynamicExpr` values; ships with a Postgres adapter and supports custom adapters via `EctoShorts.DynamicBuilder`
- **`EctoShorts.Testing`** — assertion helpers (`assert_query/2`, `assert_sql/3`, `assert_dynamic/2`, and their `refute_*` counterparts) for testing query construction
- **`EctoShorts.Actions.Source`** — key-value lookup struct that can be passed as a queryable to `EctoShorts.Actions` read helpers
- **`EctoShorts.Actions.Batch`** — batch grouping and lookup internals behind `EctoShorts.Actions.batch/3` and `EctoShorts.Actions.batch_find/4`
- **`EctoShorts.Actions.Bulk`** — bulk operation internals behind `EctoShorts.Actions.insert_all/3`, `EctoShorts.Actions.update_all/4`, and `EctoShorts.Actions.delete_all/3`
- **`EctoShorts.Actions.Multi`** — multi-record transaction internals behind `EctoShorts.Actions.create_many/3`, `EctoShorts.Actions.find_many/3`, `EctoShorts.Actions.update_many/3`, `EctoShorts.Actions.delete_many/3`, `EctoShorts.Actions.find_or_create_many/3`, and `EctoShorts.Actions.find_and_upsert_many/3`
- **`EctoShorts.Actions.Transaction`** — transaction wrappers behind `EctoShorts.Actions.transaction/2` and `EctoShorts.Actions.transact/2`
- **`EctoShorts.Actions.CRUD`** — single-record CRUD internals
- **`EctoShorts.Logger`** — internal logging wrapper
- **`EctoShorts.Utils`** — shared utility functions
- **`EctoShorts.QueryBuilder`** — behaviour for custom query builders
- **`EctoShorts.QueryProvider`** — behaviour for named query expression providers
- **`EctoShorts.DynamicBuilder`** — behaviour for custom dynamic expression builders
- **`EctoShorts.CommonFilters.*`** — dedicated builder modules for each filter family: `Distinct`, `GroupBy`, `Having`, `Join`, `Last`, `Limit`, `Lock`, `Offset`, `OrderBy`, `Preload`, `Select`, `SetOperation`, `SubQuery`, `Update`, `Windows`, `WithCte`, `WithNamedBinding`, `WithTies`

##### New EctoShorts.Actions API functions

- **`EctoShorts.Actions.preload/3`** — delegates to `Ecto.Repo.preload/3`
- **`EctoShorts.Actions.exists?/3`** — delegates to `Ecto.Repo.exists?/2` with filter support
- **`EctoShorts.Actions.find_and_create/4`** — finds by one set of params, creates with a different set if not found
- **`EctoShorts.Actions.find_and_delete/3`** — finds a record and deletes it
- **`EctoShorts.Actions.insert_all/3`** — bulk insert via `Ecto.Repo.insert_all/3` with changeset validation, timestamps, and conflict resolution
- **`EctoShorts.Actions.update_all/4`** — bulk update with `:set`, `:inc`, `:push`, and `:pull` operations
- **`EctoShorts.Actions.delete_all/3`** — bulk delete matching a filter
- **`EctoShorts.Actions.create_many/3`** — transactional multi-record insert
- **`EctoShorts.Actions.find_many/3`** — transactional multi-record lookup
- **`EctoShorts.Actions.update_many/3`** — transactional multi-record update
- **`EctoShorts.Actions.delete_many/3`** — transactional multi-record delete
- **`EctoShorts.Actions.find_and_upsert_many/3`** — transactional multi-record find-and-upsert
- **`EctoShorts.Actions.batch/5`** — groups records by key(s) and cardinality (`:one` | `:many`), supports single and composite batch keys
- **`EctoShorts.Actions.batch_find/4`** — batch-fetches records and zips them into original entries
- **`EctoShorts.Actions.transaction/2`** — lower-level transaction wrapper
- **`EctoShorts.Actions.transact/2`** — higher-level transaction wrapper with result normalization and `:strict` rollback mode

##### New EctoShorts.CommonChanges functions

- **`EctoShorts.CommonChanges.change_nil?/2`** — returns `true` when a field (or all fields in a list) have no pending change
- **`EctoShorts.CommonChanges.change_empty?/2`** — returns `true` when a field change is `[]` or `%{}`
- **`EctoShorts.CommonChanges.field_nil?/2`** — returns `true` when a field's current value (data or changes) is `nil`
- **`EctoShorts.CommonChanges.field_empty?/2`** — returns `true` when a field's current value (data or changes) is `[]`
- **`EctoShorts.CommonChanges.validate_not_unset/2`** — prevents a field from being set to `nil` when it already has a persisted value
- **`EctoShorts.CommonChanges.truncate_datetime_change/3`** — truncates datetime changes to a given precision (`:second`, `:millisecond`, `:microsecond`)
- **`EctoShorts.CommonChanges.trim_string_change/2`** — trims whitespace from string changes
- **`EctoShorts.CommonChanges.put_new_change/3`** — puts a change only when the field has no pending change; supports literal values and function callbacks
- **`EctoShorts.CommonChanges.put_new_value/3`** — puts a change only when the field's current value (data or changes) is `nil`

##### New EctoShorts.CommonFilters features

- **Keyword list params** — `EctoShorts.CommonFilters.convert_params_to_filter/3` now accepts keyword lists, preserving duplicate keys and evaluation order for repeated `:where`, `:or_where`, `:join`, or `:with_cte` entries
- **Binding selectors** — top-level `:as` and `:at` keys retarget filters to named or positional bindings (`%{as: %{author: %{select: :first_name}}}`, `%{at: %{2 => %{...}}}`)
- **Boolean groups** — `:and`, `:or`, `:where`, and `:or_where` as transparent grouping operators for predicate logic
- **Explicit joins** — `:join` filter key with source-family selectors (`:association`, `:schema`, `:table`, `:query`, `:subquery`, `:fragment`) and `type:`/`qualifier:` payload keys
- **Set operations** — `:union`, `:union_all`, `:except`, `:except_all`, `:intersect`, `:intersect_all`
- **Windowing** — `:windows` and `:with_ties`
- **Common table expressions** — `:recursive_ctes` and `:with_cte`
- **Projection** — `:select` and `:select_merge`
- **Grouping and aggregates** — `:group_by`, `:having`, `:or_having`
- **Uniqueness** — `:distinct`
- **Sorting** — `:prepend_order_by` and `:reverse_order` alongside existing `:order_by`
- **Locking** — `:lock` with map/keyword `name:` payloads, raw string lock clauses, and unary function payloads
- **Clause removal** — `:exclude`
- **Bulk updates** — `:update` for `update_all` expressions
- **Query prefix** — `:put_query_prefix`
- **Named bindings** — `:with_named_binding`
- **Subqueries** — `:subquery`
- **Wildcard preservation** — `like`/`ilike` filters preserve caller-supplied `%` and `_` wildcards instead of always wrapping with `%...%`
- **Custom query builder support** — `:query_builder` option or config key delegates filter dispatch to a user-provided `EctoShorts.QueryBuilder` implementation
- **Custom query provider support** — `:query_provider` option or config key for named query expressions used by joins and locks

##### New configuration options

- **`:dynamic_builder`** — configures which `EctoShorts.DynamicBuilder` to use (auto-detected from the repo adapter when not set)
- **`:query_builder`** — configures a custom `EctoShorts.QueryBuilder` for filter dispatch
- **`:query_provider`** — configures a custom `EctoShorts.QueryProvider` for named query expressions
- **`:error_module`** — configures the error module used by `EctoShorts.Actions` (defaults to `EctoShorts.Actions.Error`)
- **`:max_positional_bindings`** — configures the maximum positional bindings allowed

##### Improvements

- **`EctoShorts.Actions.update/4` supports optimistic locking** — via `:optimistic_lock` option or a schema-defined `optimistic_lock/0` callback; stale entries return `{:error, %ErrorMessage{code: :stale}}`
- **`:preload` option on `EctoShorts.Actions` helpers** — `all/3`, `find/3`, `create/3`, `update/4`, `get/3`, and multi/batch helpers apply preloads after the main operation
- **`:group_by` option on `EctoShorts.Actions.all/3` and `EctoShorts.Actions.find/3`** — merged into params before query building
- **`EctoShorts.Actions` internal architecture split** — the monolithic `EctoShorts.Actions` module is now a thin delegation layer over `EctoShorts.Actions.CRUD`, `EctoShorts.Actions.Bulk`, `EctoShorts.Actions.Multi`, `EctoShorts.Actions.Batch`, and `EctoShorts.Actions.Transaction`
- **`EctoShorts.Actions.aggregate/5` default arguments** — now defaults to `:count` aggregate on `:id` field, allowing `EctoShorts.Actions.aggregate(Post, %{published: true})` as shorthand
- **`EctoShorts.CommonFilters.convert_params_to_filter/3` accepts an optional `opts` keyword list** — the public entry point in `EctoShorts.CommonFilters` adds a third argument (defaults to `[]`) for passing options like `:sorter`, `:query_builder`, and `:query_provider`

#### V2.4.0
- add recursive relational filtering
- add `%{field: %{!=: [1, 2, 3]}}` to allow `NOT IN ANY` queries
- fix intermittent failure from `function_exported?(schema, :create_changeset, 1)`

#### V2.3.0
- add ability to optionally require a id or a cast/put assoc
- type spec fixes

#### V2.2.3
- More typespec fixes

#### V2.2.2
- More typespec fixes

#### V2.2.1
- Use a backup error module if set to nil

#### V2.2.0
- no longer require `create_changeset`, it is now optional
- Fix dialyzer issues

#### V2.1.2
- fix typings a bit
- add lower/upper filters

#### V2.1.1
- fix update returning wrong error format

#### V2.1.0
- Make responses for Errors return as ErrorMessage

#### V2.0.0
- refactor: change find_and_update to find_and_upsert and make find_and_update not do a create
- fix: make sure we can do partial updates or create with associations

#### V1.1.5
- Add support for querying arrays and using filters around those
- Add ability to set `repo` option in `CommonChanges.preload_change_assoc` to set which repo to preload from

#### V1.1.4
- fix change to dropping associations from find instead of taking fields so other filters pass through

#### V1.1.3
- Fix relational filtering on `find_*`

#### V1.1.2
- Remove relational filtering on `find_*` functions

#### V1.1.2
- Add support for not equals filtering

#### V1.1.1
- Fix support for order_by filtering

#### V1.1.0
- Added support for querying by relation
- Remove order_by from `convert_params_to_filter` arguments and implement as a parameter

#### V1.0.0
- Multi-repo & Replica support
- Add `find_and_update`
- Add `find_or_create_many`
- Add `stream`
- Passing nil as a param results in an error (BREAKING)
- find now returns an `Ecto.MultipleResultsError` if more than one result is being returned from the query (BREAKING)

#### V0.1.5
- Add `find_or_create` for Actions

#### V0.1.4
- Update schema
- Add better specs
- Bug fixes for update

#### V0.1.3
- Add `like` filter param
- Add more documentation

#### V0.1.2
- Add more documentation

#### V0.1.1
- Add some documentation fixes

#### V0.1.0
- Initial Release
