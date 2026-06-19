# EctoShorts Test Behavior Inventory
**Generated:** 2026-06-19  
**Scope:** `/test/ecto_shorts/common_filters/` (42 files, ~399 tests) + `/test/ecto_shorts/common_filters_schemaless_test.exs` (57 tests)

---

## 1. Test Files & Operator Coverage

### Schema-Backed Tests (common_filters/)

| File | Tests | Primary Operators |
|------|-------|-------------------|
| common_filters_aggregate_operators_test.exs | 16 | `avg`, `count`, `max`, `min`, `sum` with comparison |
| common_filters_association_filter_test.exs | 3 | Association shorthand (warn on scalar value) |
| common_filters_boolean_composition_test.exs | 1 | `:or_where` with nil dynamic (no-op) |
| common_filters_comparison_operators_test.exs | 44 | `==`, `!=`, `>`, `>=`, `<`, `<=`, `in`, list rewrites, quantified (`all`/`any`) |
| common_filters_date_wrappers_test.exs | 5 | `:date` wrapper with `ago`, `from_now`, `add` |
| common_filters_datetime_wrappers_test.exs | 16 | `:datetime`/`:date` wrappers, `add`, `ago`, `from_now` |
| common_filters_distinct_test.exs | 17 | `:distinct` boolean, atom, keyword list; schemaless accepts any atom |
| common_filters_enum_casting_test.exs | 6 | Ecto.Enum cast to integers (bare & operator-wrapped) |
| common_filters_exclude_test.exs | 19 | `:exclude` for where, order_by, group_by, having, select, etc. |
| common_filters_field_types_opt_test.exs | 7 | `field_types:` opt—array element semantics, map containment |
| common_filters_first_test.exs | 4 | `:first` integer limit |
| common_filters_group_by_test.exs | 9 | `:group_by` atom/list, warn on invalid fields |
| common_filters_having_test.exs | 12 | `:having`, `:or_having` with aggregates |
| common_filters_invalid_schema_field_test.exs | 6 | Warn & skip invalid field in where, having, join, order, group, distinct |
| common_filters_join_test.exs | 35 | Join types: association, schema, table, query, subquery, fragment; with/without `:on` |
| common_filters_last_test.exs | 8 | `:last` integer + keyword (desc, replace order_by) |
| common_filters_limit_test.exs | 1 | `:limit` fallthrough |
| common_filters_lock_test.exs | 13 | `:lock` map (`:name`) or provider; warn on raw string/function |
| common_filters_map_field_test.exs | 9 | Bare `:map` field vs `{:map, :string}` typed; `has_key`, `contains` |
| common_filters_negation_test.exs | 21 | `:not` wrapper for any operator; nil checks, aggregates |
| common_filters_offset_test.exs | 5 | `:offset` integer |
| common_filters_order_modifier_test.exs | 25 | `:order_by` atom/list, `:prepend_order_by`, `:reverse_order`, `:at` binding |
| common_filters_out_of_range_binding_test.exs | 6 | Warn when `:at` binding is >=limit or <=0 |
| common_filters_page_test.exs | 18 | `:page` with `index`/`size` (offset) or `after`/`before` (keyset) |
| common_filters_parent_as_test.exs | 5 | `:parent_as` binding field reference in comparisons |
| common_filters_preload_test.exs | 18 | `:preload` atom/list; join-backed with where filters |
| common_filters_put_query_prefix_test.exs | 1 | `:put_query_prefix` |
| common_filters_recursive_ctes_test.exs | 3 | `:recursive_ctes` keyword |
| common_filters_select_merge_test.exs | 8 | `:select_merge` map/keyword list |
| common_filters_select_test.exs | 25 | `:select` atom/list/map; field/association selection |
| common_filters_set_operation_test.exs | 18 | `:union`, `:union_all`, `:except`, `:except_all`, `:intersect`, `:intersect_all` |
| common_filters_string_matching_test.exs | 10 | `:like`, `:ilike` (bare % wrapping, list patterns) |
| common_filters_string_transformations_test.exs | 6 | `:lower`, `:upper`, `:trim`, `:ltrim`, `:rtrim` |
| common_filters_subquery_test.exs | 3 | `:subquery` terminal wrapper |
| common_filters_typed_value_casting_test.exs | 23 | Type routing: string, integer, boolean, date, datetime, enum |
| common_filters_update_test.exs | 7 | `:update` with `set`, `inc` |
| common_filters_windows_test.exs | 19 | `:windows` with `partition_by`, `order_by` |
| common_filters_with_cte_test.exs | 23 | `:with_cte` (CTEs) with filtering |
| common_filters_with_named_binding_test.exs | 6 | `:with_named_binding` scoped filter groups |
| common_filters_with_ties_test.exs | 8 | `:with_ties` true/false (require limit + order) |
| parser_test.exs | 17 | `Parser.normalize/1/2/3` |
| update_expr_test.exs | 16 | Update expression builders |

**Schema-Backed Total:** ~399 tests

### Schemaless Tests

| File | Tests | Key Differences |
|------|-------|-----------------|
| common_filters_schemaless_test.exs | 57 | • Association keys treated as plain fields (no shorthand)<br>• `:elements` wrapper forces array routing<br>• `field_types:` opt required for map/array semantics<br>• Arbitrary fields always accepted (no invalid-field warn)<br>• Smoke tests for all operators on string sources |

**Schemaless Total:** 57 tests

---

## 2. Operator/Parameter Shape Reference Table

| Operator | Input Params | Expected Query/SQL | Schema | Schemaless | Warn+Nil? | Test File:Line |
|----------|--------------|-------------------|--------|------------|-----------|---|
| **Comparison** |
| `==` (scalar) | `{id: {==: 1}}` | `WHERE id == ^1` | ✓ | ✓ | | comparison_operators:13 |
| `==` (nil) | `{published_at: {==: nil}}` | `WHERE is_nil(published_at)` | ✓ | | | comparison_operators:20 |
| `!=` (nil) | `{published_at: {!=: nil}}` | `WHERE NOT is_nil(published_at)` | ✓ | | | comparison_operators:27 |
| `>` | `{views: {>: 10}}` | `WHERE views > ^10` | ✓ | | | comparison_operators:34 |
| `>=` | `{views: {>=: 10}}` | `WHERE views >= ^10` | ✓ | | | comparison_operators:41 |
| `<` | `{views: {<: 10}}` | `WHERE views < ^10` | ✓ | | | comparison_operators:48 |
| `<=` | `{views: {<=: 10}}` | `WHERE views <= ^10` | ✓ | | | comparison_operators:55 |
| `!=` (scalar) | `{views: {!=: 10}}` | `WHERE views != ^10` | ✓ | | | comparison_operators:62 |
| `in` | `{published: {in: [T,F]}}` | `WHERE published IN ^[T,F]` | ✓ | ✓ | | comparison_operators:69 |
| `==` (list) | `{published: {==: [T,F]}}` | `WHERE published IN ^[T,F]` (rewrite) | ✓ | ✓ | | comparison_operators:76 |
| `!=` (list) | `{published: {!=: [T,F]}}` | `WHERE is_nil(p) OR p NOT IN ^[T,F]` | ✓ | ✓ | | comparison_operators:83 |
| `all`/`any` | `{id: {all: {from: Comment, where: ...}}}` | `WHERE id == all(SELECT ...) / any(...)` | ✓ | | | comparison_operators:98 |
| **Aggregates** |
| `avg` | `{views: {avg: {>: 10}}}` | `WHERE avg(views) > ^10` | ✓ | ✓ | | aggregate_operators:14 |
| `count` | `{views: {count: {>: 0}}}` | `WHERE count(views) > ^0` | ✓ | ✓ | | aggregate_operators:31 |
| `max` | `{views: {max: {>=: 100}}}` | `WHERE max(views) >= ^100` | ✓ | | | aggregate_operators:38 |
| `min` | `{views: {min: {<: 5}}}` | `WHERE min(views) < ^5` | ✓ | | | aggregate_operators:45 |
| `sum` | `{views: {sum: {==: 1000}}}` | `WHERE sum(views) == ^1000` | ✓ | | | aggregate_operators:52 |
| **String Matching** |
| `like` | `{title: {like: "hello"}}` | `WHERE like(title, ^"%hello%")` (wrapped) | ✓ | ✓ | | string_matching:13 |
| `like` (pattern) | `{title: {like: "hello%"}}` | `WHERE like(title, ^"hello%")` (preserved) | ✓ | | | string_matching:23 |
| `ilike` | `{title: {ilike: "hello"}}` | `WHERE ilike(title, ^"%hello%")` | ✓ | | | string_matching:31 |
| `like` (list) | `{title: {like: ["h", "w"]}}` | `WHERE fragment("? LIKE ANY(?)", title, ^[...])` | ✓ | | | string_matching:38 |
| **String Transform** |
| `lower` | `{title: {==: {lower: "HELLO"}}}` | `WHERE lower(title) == ^"HELLO"` | ✓ | ✓ | | string_transformations:1 |
| `upper` | `{title: {==: {upper: "hello"}}}` | `WHERE upper(title) == ^"hello"` | ✓ | | | string_transformations:? |
| `trim` | `{title: {==: {trim: " x "}}}` | `WHERE trim(title) == ^" x "` | ✓ | | | string_transformations:? |
| **Date/DateTime Wrappers** |
| `ago` | `{inserted_at: {==: {ago: {1, :day}}}}` | `WHERE inserted_at == ago(^1, "day")` | ✓ | | | datetime_wrappers:? |
| `from_now` | `{published_at: {>=: {from_now: {1, :day}}}}` | `WHERE published_at >= from_now(^1, "day")` | ✓ | | | datetime_wrappers:? |
| `add` (datetime) | `{inserted_at: {>=: {datetime: {add: {...}}}}}` | `WHERE inserted_at >= datetime_add(...)` | ✓ | ✓ | | datetime_wrappers:? |
| `add` (date) | `{inserted_at: {>=: {date: {add: {...}}}}}` | `WHERE date(inserted_at) >= date(...)` | ✓ | | | date_wrappers:? |
| **Array/Elements (Schemaless-specific)** |
| `:elements` + `:in` | `{tags: {elements: {in: [..]}}}` | `WHERE fragment("? && ?", tags, ^[...])` array overlap | | ✓ | | schemaless:39 |
| `:elements` + scalar | `{tags: {elements: "elixir"}}` | `WHERE ^"elixir" IN tags` element membership | | ✓ | | schemaless:65 |
| `:elements` + list | `{tags: {elements: [...]}}` | `WHERE tags == ^[...]` array equality | | ✓ | | schemaless:104 |
| `:elements` + `:count` | `{tags: {elements: {count: {>: 3}}}}` | `WHERE array_length(tags, 1) > ^3` | | ✓ | | schemaless:91 |
| **Field Types Option** |
| `field_types: [tags: {:array, :string}]` | `{tags: "elixir"}` | `WHERE ^"elixir" IN tags` (not scalar IN) | ✓ | ✓ | | field_types_opt:26,52 |
| `field_types: [tags: {:array, :string}]` + `:in` | `{tags: {in: [..]}}` | `WHERE fragment("? && ?", ...)` array overlap | ✓ | ✓ | | field_types_opt:39 |
| `field_types: [data: :map]` | `{data: {has_key: "role"}}` | `WHERE fragment("jsonb_exists(...)")` | ✓ | ✓ | | field_types_opt:99 |
| `field_types: [data: :map]` | `{data: {contains: {role: "admin"}}}` | `WHERE fragment("? @> ?::jsonb", ...)` | ✓ | ✓ | | field_types_opt:67 |
| **Negation** |
| `:not` wrapper | `{views: {not: {==: 10}}}` | `WHERE NOT (views == ^10)` | ✓ | ✓ | | negation:? |
| `:not` + `in` (list) | `{published: {not: {in: [..]}}}` | `WHERE is_nil(p) OR p NOT IN ^[..]` | ✓ | ✓ | | comparison:83 |
| **Enum Casting** |
| Ecto.Enum atom | `{status: :active}` (enum field) | `WHERE status == ^0` (casts to integer) | ✓ | | | enum_casting:11 |
| Ecto.Enum in operator | `{status: {in: [:active, :pending]}}` | `WHERE status IN ^[0,1]` | ✓ | | | enum_casting:29 |
| **Association Filter (Schema-backed)** |
| Association map | `{author: {age: 25}}` | `JOIN author WHERE author.age == ^25` (shorthand) | ✓ | | | association_filter:12 |
| Association scalar | `{author: "bad"}` | Query unchanged, WARN logged | ✓ | | **WARN** | association_filter:48 |
| **Join** |
| Association join | `{join: [assoc: [...]]}` | `JOIN author assoc(p, :author)` | ✓ | | | join_test:? |
| Schema join | `{join: [schema: [source: User, ...]]}` | `JOIN users ON ...` | ✓ | | | join_test:? |
| Table join | `{join: [table: [source: "users", ...]]}` | `FROM "posts" JOIN "users" ...` | ✓ | ✓ | | join_test:? |
| Query join | `{join: [query: [...]]}` | `JOIN subquery ...` | ✓ | | | join_test:? |
| Fragment join | `{join: [fragment: [...]]}` | Via provider contract | ✓ | | | join_test:? |
| **Distinct** |
| Root boolean | `{distinct: true}` | `SELECT DISTINCT ...` | ✓ | | | distinct:14 |
| Root atom | `{distinct: :field}` | `SELECT DISTINCT ON (field) ...` | ✓ | | | distinct:18 |
| Root keyword list | `{distinct: [asc: :field]}` | `SELECT DISTINCT ON (...) ORDER BY ...` | ✓ | | | distinct:22 |
| Named binding | `{distinct: [at: :binding, field: :name]}` | With binding alias | ✓ | | | distinct:26 |
| Schemaless atom | `{distinct: :any_field}` | Accepts any atom (no schema check) | | ✓ | | schemaless:? |
| Invalid field | `{distinct: :does_not_exist}` | Query unchanged, WARN | ✓ | | **WARN** | invalid_schema_field:85 |
| **Group By** |
| Root atom | `{group_by: :author_id}` | `GROUP BY author_id` | ✓ | ✓ | | group_by:? |
| List | `{group_by: [:author_id, :status]}` | `GROUP BY author_id, status` | ✓ | | | group_by:? |
| Invalid field | `{group_by: :does_not_exist}` | Query unchanged, WARN | ✓ | | **WARN** | invalid_schema_field:73 |
| **Having** |
| Aggregate | `{having: {views: {avg: {>: 100}}}}` | `HAVING avg(views) > ^100` (on grouped query) | ✓ | ✓ | | having:? |
| `:or_having` | `{or_having: {views: {...}}}` | `HAVING ... OR ...` | ✓ | | | having:? |
| **Order By** |
| Root atom | `{order_by: :title}` | `ORDER BY title ASC` | ✓ | ✓ | | order_modifier:? |
| List | `{order_by: [asc: :title, desc: :id]}` | `ORDER BY title ASC, id DESC` | ✓ | | | order_modifier:? |
| `:prepend_order_by` | `{prepend_order_by: :created_at}` | Prepends to existing order | ✓ | | | order_modifier:? |
| `:reverse_order` | `{order_by: :title, reverse_order: true}` | Reverses direction | ✓ | ✓ | | order_modifier:? |
| `:reverse_order` (invalid) | `{reverse_order: "bad"}` | Query unchanged, WARN | ✓ | | **WARN** | order_modifier:406 |
| **Pagination** |
| `:page` offset | `{page: {index: 1, size: 5}}` | `LIMIT 5 OFFSET 0` | ✓ | ✓ | | page_test:? |
| `:page` keyset forward | `{page: {after: 5, by: :id, size: 10}}` | `WHERE id > ^5 ORDER BY id ASC LIMIT 10` | ✓ | ✓ | | page_test:? |
| `:page` keyset backward | `{page: {before: 5, by: :id, size: 10}}` | `WHERE id < ^5 ORDER BY id DESC LIMIT 10` | ✓ | | | page_test:? |
| **Select/Projection** |
| Single field | `{select: :title}` | `SELECT title` | ✓ | ✓ | | select_test:? |
| List | `{select: [:title, :body]}` | `SELECT title, body` | ✓ | | | select_test:? |
| Map alias | `{select: [title_text: :title, post_id: :id]}` | `SELECT %{title_text: p.title, post_id: p.id}` | ✓ | ✓ | | select_test:? |
| `:select_merge` | `{select_merge: {new_field: :value}}` | Merges into existing select map | ✓ | ✓ | | select_merge_test:? |
| Association | `{select: [:title, :author]}` (assoc field) | `SELECT title, author_struct` (preload) | ✓ | | | select_test:? |
| **Set Operations** |
| `:union` | `{union: {published: true}}` | `UNION (SELECT FROM ... WHERE published = ^true)` | ✓ | ✓ | | set_operation:? |
| `:union_all` | `{union_all: ...}` | `UNION ALL ...` | ✓ | | | set_operation:? |
| `:except` | `{except: ...}` | `EXCEPT ...` | ✓ | | | set_operation:? |
| `:except_all` | `{except_all: ...}` | `EXCEPT ALL ...` | ✓ | | | set_operation:? |
| `:intersect` | `{intersect: ...}` | `INTERSECT ...` | ✓ | | | set_operation:? |
| `:intersect_all` | `{intersect_all: ...}` | `INTERSECT ALL ...` | ✓ | | | set_operation:? |
| **Limit/Offset** |
| `:limit` | `{limit: 10}` | `LIMIT 10` | ✓ | ✓ | | limit_test:? |
| `:offset` | `{offset: 5}` | `OFFSET 5` | ✓ | ✓ | | offset_test:? |
| `:first` | `{first: 10}` | `LIMIT 10` (alias) | ✓ | ✓ | | first_test:? |
| `:last` | `{last: 10}` | Subquery with DESC + reverse order | ✓ | ✓ | | last_test:? |
| **Preload** |
| Association | `{preload: :author}` | `PRELOAD author` | ✓ | | | preload_test:? |
| List | `{preload: [:author, :comments]}` | Multiple preloads | ✓ | | | preload_test:? |
| Join-backed | `{preload: [{:author, :join: [...]}]}` | `PRELOAD ... with JOIN` | ✓ | | | preload_test:? |
| **Lock** |
| Map `:name` | `{lock: {name: :for_update}}` | `FOR UPDATE` | ✓ | ✓ | | lock_test:? |
| Provider | Via provider callback | Custom lock expression | ✓ | | | lock_test:? |
| Raw string | `{lock: "FOR SHARE"}` | Query unchanged, WARN | ✓ | ✓ | **WARN** | lock_test:88 |
| **CTE (Common Table Expression)** |
| `:with_cte` | `{with_cte: [{cte_name: [as: {published: true}]}]}` | `WITH cte_name AS (SELECT...)` | ✓ | ✓ | | with_cte:? |
| `:recursive_ctes` | `{recursive_ctes: true, with_cte: [...]}` | `WITH RECURSIVE ...` | ✓ | | | recursive_ctes:? |
| **Windows (Analytic Functions)** |
| Partition & order | `{windows: [w: [partition_by: :author_id, order_by: :id]]}` | `OVER (PARTITION BY ... ORDER BY ...)` | ✓ | ✓ | | windows_test:? |
| **Update** |
| `:update` set | `{update: [set: [title: "New"]]}` | `UPDATE ... SET title = 'New'` | ✓ | ✓ | | update_test:? |
| `:update` inc | `{update: [inc: [views: 1]]}` | `UPDATE ... SET views = views + 1` | ✓ | | | update_test:? |
| **Exclude** |
| Single key | `{exclude: :where}` | Removes where clauses from query | ✓ | ✓ | | exclude_test:? |
| List | `{exclude: [:limit, :offset]}` | Multiple exclusions | ✓ | ✓ | | exclude_test:? |
| **Binding** |
| `:at` (positional) | `{where: [{at: 1, field: :author_id}]}` | Applies to binding position 1 | ✓ | | | order_modifier:? |
| Out-of-range `:at` | `{field: {at: 99, ==: 1}}` | Query unchanged, WARN | ✓ | | **WARN** | out_of_range:16 |
| `:parent_as` | `{post_id: {parent_as: {post: :id}}}` | `WHERE post_id == field(parent_as(:post), :id)` | ✓ | ✓ | | parent_as:? |
| `:with_named_binding` | `{with_named_binding: [name: {join: [...]}]}` | Scoped filter group | ✓ | ✓ | | with_named_binding:? |
| **Meta** |
| `:put_query_prefix` | `{put_query_prefix: "schema_name"}` | `FROM "schema_name"."posts"` | ✓ | | | put_query_prefix:? |
| `:subquery` | `{subquery: {id: 2}}` | Wraps result as subquery | ✓ | ✓ | | subquery_test:? |
| `:with_ties` | `{with_ties: true, limit: 1, order_by: :id}` | `FETCH FIRST 1 ROW WITH TIES` | ✓ | ✓ | | with_ties_test:? |

---

## 3. Warn + Nil (Query Unchanged) Test Cases

These tests use `capture_log` and assert the query is returned unchanged with a warning message:

| Trigger | Input | Expected Behavior | File:Line |
|---------|-------|-------------------|-----------|
| Association scalar value | `{author: "bad_value"}` | Query unchanged, WARN "Expected association filter value to be a map or keyword list" | association_filter:48 |
| Invalid schema field (where) | `{does_not_exist: 1}` | Query unchanged, WARN "Field \"does_not_exist\" does not exist on schema EctoShorts.Schema.Post" | invalid_schema_field:13 |
| Invalid schema field (having) | `{group_by: :id, having: {does_not_exist: {avg: {>: 1}}}}` | Query unchanged, WARN (field guard) | invalid_schema_field:25 |
| Invalid schema field (join on) | `{join: [schema: [source: User, as: :user, on: {does_not_exist: 1}]]}` | Query unchanged, WARN | invalid_schema_field:43 |
| Invalid schema field (order_by) | `{order_by: :does_not_exist}` | Query unchanged, WARN | invalid_schema_field:61 |
| Invalid schema field (group_by) | `{group_by: :does_not_exist}` | Query unchanged, WARN | invalid_schema_field:73 |
| Invalid schema field (distinct) | `{distinct: :does_not_exist}` | Query unchanged, WARN | invalid_schema_field:85 |
| Out-of-range binding (field filter) | `{field: {at: 99, ==: 1}}` | Query unchanged, WARN "out-of-range ... binding position" | out_of_range_binding:16 |
| Out-of-range binding (position 0) | `{field: {at: 0, ==: 1}}` | Query unchanged, WARN | out_of_range_binding:38 |
| Out-of-range binding (negative) | `{field: {at: -1, ==: 1}}` | Query unchanged, WARN | out_of_range_binding:56 |
| Out-of-range binding (having) | `{having: {at: 99, views: {avg: {>: 1}}}}` | Query unchanged, WARN | out_of_range_binding:76 |
| Out-of-range binding (group_by) | `{group_by: {at: 99, field: :author_id}}` | Query unchanged, WARN | out_of_range_binding:94 |
| Out-of-range binding (order_by) | `{order_by: {at: 99, field: :title}}` | Query unchanged, WARN | out_of_range_binding:114 |
| Lock: no provider config | `{lock: {name: :custom}}` (no provider) | Query unchanged, WARN "no query provider module is configured" | lock_test:69 |
| Lock: raw string | `{lock: "FOR SHARE"}` | Query unchanged, WARN "Expected :lock value to be a map or keyword list with a :name key" | lock_test:88 |
| Lock: raw function | `{lock: fn q -> q end}` | Query unchanged, WARN | lock_test:93 |
| Lock: provider returns nil | `{lock: {name: :custom}}` (provider → nil) | Query unchanged, WARN | lock_test:112 |
| Lock: provider returns error | `{lock: {name: :custom}}` (provider → {:error, ...}) | Query unchanged, WARN | lock_test:326 |
| Lock: provider returns non-Query | `{lock: {name: :custom}}` (provider → string) | Query unchanged, WARN "provider callback returns a non-Ecto.Query" | lock_test:194 |
| Lock: provider returns non-function ok | `{lock: {name: :custom}}` (provider → {:ok, "raw"}) | Query unchanged, WARN | lock_test:212 |
| Join: provider returns nil | `{join: [...]}` (provider → nil) | Query unchanged, WARN | join_test:326 |
| Join: provider returns error | `{join: [...]}` (provider → {:error, ...}) | Query unchanged, WARN | join_test:357 |
| Join: provider returns raw source | `{join: [...]}` (provider → string/atom) | Query unchanged, WARN | join_test:386 |
| Join: unrecognized join type | `{join: [unknown_type: [...]]}` | Query unchanged, WARN "join type key is unrecognized" | join_test:404 |
| Join: missing source key | `{join: [table: [on: {...}]]}` | Query unchanged, WARN "has no :source key" | join_test:422 |
| Join: non-map/keyword entry | `{join: ["string_entry"]}` | Query unchanged, WARN "is not a map or keyword list" | join_test:386 |
| Order: invalid field | `{order_by: :does_not_exist}` | Query unchanged, WARN | invalid_schema_field:61 |
| Order: invalid `:at` modifier | `{order_by: {at: 99, field: :title}}` | Query unchanged, WARN | out_of_range_binding:114 |
| Order: `:reverse_order` not bool | `{reverse_order: "bad"}` | Query unchanged, WARN "Expected :reverse_order value to be boolean" | order_modifier:406 |
| Distinct: invalid field | `{distinct: :does_not_exist}` | Query unchanged, WARN | invalid_schema_field:85 |
| Group: invalid field | `{group_by: :does_not_exist}` | Query unchanged, WARN | invalid_schema_field:73 |
| Group: invalid `:at` | `{group_by: {at: 99, field: :author_id}}` | Query unchanged, WARN | out_of_range_binding:94 |
| Having: invalid field | `{having: {does_not_exist: {avg: {>: 1}}}}` | Query unchanged, WARN | invalid_schema_field:29 |
| Having: invalid `:at` | `{having: {at: 99, views: {avg: {>: 1}}}}` | Query unchanged, WARN | out_of_range_binding:76 |
| Quantified select: invalid field | `{id: {all: {from: Comment, select: {field: "does_not_exist"}}}}` | Query unchanged, falls back to default select, WARN | comparison_operators:190 |
| CTE: invalid params | `{with_cte: "invalid"}` | Query unchanged, WARN "Expected :with_cte params to be a map or keyword list" | schemaless:712 |
| With_ties: invalid payload | `{with_ties: "invalid", limit: 1, order_by: :id}` | Query unchanged, WARN "Expected :with_ties value to be a boolean or keyword/map payload" | schemaless:773 |
| Lock (schemaless): raw string | `{lock: "FOR SHARE NOWAIT"}` | Query unchanged, WARN | schemaless:489 |

**Total Warn+Nil Cases:** 37+ (intentional query no-ops with logging)

---

## 4. Coverage Gaps (Operators in lib/ with No/Minimal Tests)

| Operator | Location | Test Coverage | Notes |
|----------|----------|---|--------|
| `:limit` | lib/ | **1 test** (fallthrough only) | Should test basic limit application, binding positions |
| `:offset` | lib/ | **5 tests** | Basic coverage; lacks `:at` binding test for offset |
| `:prepend_order_by` | lib/ | Tested in order_modifier:? | Minimal; interacts with existing order |
| `:or_having` | lib/ | Tested in having:? | Works but minimal edge cases |
| `:except_all`, `:intersect_all` | lib/ | Set operation file | Limited explicit tests vs. `union`/`union_all` |
| Arithmetic expressions in comparisons | lib/ | Tested in comparison_operators:273 | Limited; needs more edge cases (nested, type mismatches) |
| Type casting edge cases | lib/ | typed_value_casting:23 tests | Good coverage but lacks union with unknown types, coercion errors |
| Association through: | lib/ | Not explicitly tested | Tested implicitly in select/preload but no dedicated test |
| Recursive CTE depth | lib/ | 3 tests | Minimal; no deep recursion or cycle test |
| Fragment joins w/ complex on | lib/ | join_test partial | Limited; most are through provider |
| Enum + negation interaction | lib/ | enum_casting:6 tests | Passes enum in negation but no dedicated test |
| Field override in select with aggregates | lib/ | select_test:25 | Exists but edge case interaction with group_by |

---

## 5. Audit Candidates (Questionable/Inconsistent Behavior)

| Issue | Evidence | Severity |
|-------|----------|----------|
| **Schemaless `:elements` requirement inconsistency** | `:elements` wrapper needed on schemaless for array semantics, but `field_types:` option makes it unnecessary. Behavior feels ad-hoc. | MEDIUM |
| **List value semantics flip** | `{field: list}` = scalar IN; `{field: {in: list}}` = array overlap (on array field). Non-obvious rewrite. | MEDIUM |
| **`!=` with list rewrites to OR + NULL check** | `{field: {!=: [a,b]}}` → `is_nil(field) OR field NOT IN [a,b]`. Why NULL? Seems defensive but undocumented. | LOW |
| **Association scalar warns instead of errors** | `{author: "scalar"}` logs warn + no-op. Could be hard error to catch API misuse. | LOW |
| **Out-of-range binding position partial enforcement** | Position 0 and negative warn, but >limit only warns if actually referenced. Asymmetric checking. | LOW |
| **Lock provider contract vague** | Returns `{:ok, fn q -> q end}` or `{:error, ...}` or nil. Inconsistent; no validation of returned function arity. | MEDIUM |
| **Join provider contract vague** | Same as lock; fragment builder returns strings/atoms that aren't validated. | MEDIUM |
| **`:reverse_order` requires prior `:order_by`** | Silent no-op if no order. Could be loud error. | LOW |
| **`last` subquery semantics** | `{last: 10}` wraps in subquery w/ DESC + reverse. Implicit; not obvious without reading code. | LOW |
| **Null handling in `!=` quantified** | `{id: {!=: {all: ...}}}` → `NOT (id != all(...))`. Double negation; semantics unclear. | LOW |
| **String pattern matching auto-wrapping** | `{title: {like: "hello"}}` wraps as `"%hello%"`. But `"hello%"` or `"%hello"` passed unchanged. Heuristic is implicit. | MEDIUM |

---

## 6. Support Schemas (Field Types Reference)

### Post (posts table)
- `id` `:integer` (primary key)
- `author_id` `:integer` (FK → User)
- `body` `:string`
- `notes` `:string` (source: :custom_string_field)
- `permalink` `:string`
- `published_at` `:utc_datetime`
- `published` `:boolean`
- `title` `:string`
- `tags` `{:array, :string}`
- `views` `:integer`
- `inserted_at`, `updated_at` `:utc_datetime` (timestamps)
- Assoc: `author` (belongs_to User), `comments` (has_many), `comments_authors` (through)

### User (users table)
- `id` `:integer` (primary key)
- `first_name` `:string`
- `last_name` `:string`
- `age` `:integer`
- `email` `:string`
- `inserted_at`, `updated_at` `:utc_datetime`
- Assoc: `posts` (many_to_many), `comments` (has_many), `books` (has_many)

### Comment (comments table)
- `id` `:integer` (primary key)
- `author_id` `:integer` (FK → User)
- `post_id` `:integer` (FK → Post)
- `body` `:string` (validated: min 3 chars)
- `published` `:boolean`
- `published_at` `:naive_datetime`
- `replies` `:integer`
- `tags` `{:array, :string}`
- `inserted_at`, `updated_at` `:utc_datetime`

### Book (books table)
- `author_id` `:integer` (FK → User, primary key part)
- `title` `:string` (primary key part; no separate id field)
- `inserted_at`, `updated_at` `:utc_datetime`

### UserData (user_data table) — used in map field tests
- `id` `:integer` (primary key)
- `data` `:map` (bare)
- `typed_map` `{:map, :string}` (typed)

---

## Summary

- **Total Tests:** ~456 (399 schema-backed + 57 schemaless)
- **Operators Covered:** ~45 (comparison, aggregate, string ops, date/datetime, array, enum, join, select, pagination, CTE, window, etc.)
- **Warn+Nil Cases:** 37+ (intentional no-ops)
- **Coverage Gaps:** 10+ (mainly edge cases: recursive CTE depth, arithmetic nesting, association through:)
- **Audit Candidates:** 10 (schemaless semantics, list rewrite consistency, provider contracts, pattern auto-wrap)
- **Key Difference (Schema vs Schemaless):** Association shorthand, `:elements` requirement, `field_types:` necessity, invalid field tolerance

