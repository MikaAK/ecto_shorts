# CommonFilters Behavior Inventory

## Overview

This inventory documents the complete behavior of `EctoShorts.CommonFilters`, the public query language entry layer. It covers the param coercion pipeline, sorting semantics, filter routing, and every recognized filter key with its accepted shapes and warning conditions.

---

## 1. Entry Point & Parameter Pipeline

### `convert_params_to_filter/3`

**Location:** `/Users/kurthogarth/Documents/GitHub/ecto_shorts/lib/ecto_shorts/common_filters.ex:380-390`

**Signature:**
```elixir
def convert_params_to_filter(source, params, opts \\ [])
```

**Input shapes:**
- `source`: Schema module | `{source, schema}` tuple | pre-built `Ecto.Query`
- `params`: Map (plain, not struct) | keyword list
- `opts`: Keyword list (default: `[]`)

**Pipeline:**
1. Coerce `source` to `Ecto.Query` via `CommonSchema.to_query/1`
2. Apply sorter (custom or default `sort_filter_params`)
3. Call `reduce_filters/6` starting with filter type `:where`

**Param coercion rules:**
- Maps and keyword lists are both accepted
- Keyword lists preserve duplicate keys and evaluation order
- Maps are converted to keyword lists internally for ordering
- No automatic validation—invalid keys fall through to `:where` filter routing

---

## 2. Param Sorting: `sort_filter_params/1`

**Location:** `/Users/kurthogarth/Documents/GitHub/ecto_shorts/lib/ecto_shorts/common_filters.ex:526-538`

**Rule order (evaluation sequence):**
1. `:where` filters (all entries with key `:where`)
2. All other filters except `:or_where`, `:last`, `:subquery`
3. `:or_where` filters (all entries with key `:or_where`)
4. Terminal filters (`:last`, `:subquery`)

**Example:**
```elixir
# Input
[or_where: %{x: 1}, limit: 10, where: %{y: 2}, subquery: %{...}]

# After sort
[where: %{y: 2}, limit: 10, or_where: %{x: 1}, subquery: %{...}]
```

**Custom sorter option:**
```elixir
CommonFilters.convert_params_to_filter(Post, params, sorter: fn p -> ... end)
```

---

## 3. Filter Routing & Apply Logic

### Dispatch Entry: `apply_filter/6`

**Location:** `/Users/kurthogarth/Documents/GitHub/ecto_shorts/lib/ecto_shorts/common_filters.ex:396-462`

**Routing logic (in evaluation order):**

| Condition | Action | Emit |
|-----------|--------|------|
| `key in [:as, :at]` | Resolve binding selector, recurse into nested map | `:error` or `{:ok, resolved_binding}` |
| `key in [:where, :or_where, :having, :or_having]` | List-of-params? → reduce; params? → reduce; else → dispatch to Builder | nil or dyn |
| `assoc_key?(source, key)` | Implicit join + recurse on association scope; warn if value not params | query or warning |
| `key === :and` | Reduce params without changing filter type | query |
| `key === :or` | If list-of-params → reduce as `:or_where`; else → emit each entry as `:or_where` | query |
| `key in @filters` | Dispatch to `Builder.build_query(key, ...)` | varies |
| **default** | Treat as field filter: dispatch with `{key, params}` tuple to `:where` | varies |

---

## 4. Binding Selectors: `:as` and `:at`

**Location:** `/Users/kurthogarth/Documents/GitHub/ecto_shorts/lib/ecto_shorts/common_filters.ex:398-414, 484-510`

### `:as` (Named Binding)

**Accepted shapes:**
```elixir
%{as: %{author: %{select: :first_name}}}
%{as: [author: [select: :first_name]]}
```

**Behavior:**
- Key resolves to named binding in query
- Value must be map or keyword list
- Each entry `{binding_name, filters}` in the map/list recursively applies filters scoped to that binding
- Returns `{:ok, {:as, binding_name}}` for use in nested filters

### `:at` (Positional Binding)

**Accepted shapes:**
```elixir
%{at: %{1 => %{select: :title}}}
%{at: %{first: %{...}}}
%{at: %{last: %{...}}}
%{at: %{2 => [order_by: :name]}}
```

**Behavior:**
- `:first` → `{:ok, {:at, 1}}`
- `:last` → `{:ok, {:at, CommonQuery.query_binding_count(query)}}`
- Integer >= 1 → validated against `Config.max_positional_bindings()` (default 10)
- Out-of-range position → logs warning, returns `:error`, filter skipped

---

## 5. Boolean Operators: `:and`, `:or`

### `:and`

**Location:** `/Users/kurthogarth/Documents/GitHub/ecto_shorts/lib/ecto_shorts/common_filters.ex:440-441`

**Accepted shapes:**
```elixir
%{and: %{field1: value1, field2: value2}}
%{and: [field1: value1, field2: value2]}
```

**Behavior:**
- Passes params through to reducer with same filter type (transparent grouping)
- Each entry becomes a separate WHERE predicate (AND semantics in SQL)

### `:or`

**Location:** `/Users/kurthogarth/Documents/GitHub/ecto_shorts/lib/ecto_shorts/common_filters.ex:443-450`

**Accepted shapes:**
```elixir
%{or: %{field1: value1, field2: value2}}
%{or: [field1: value1, field2: value2]}
%{or: [%{field1: value1}, %{field2: value2}]}
```

**Behavior:**
- If value is `list_of_params?` (list of maps/keyword lists) → reduce as `:or_where`
- Else → iterate entries, dispatch each as `:or_where` filter
- Results in `OR_WHERE` clauses (OR semantics in SQL)

---

## 6. Association Shorthand

**Location:** `/Users/kurthogarth/Documents/GitHub/ecto_shorts/lib/ecto_shorts/common_filters.ex:428-438, 468-482`

**Accepted shape:**
```elixir
%{comments: %{approved: true}}
%{author: [published: true, name: "Alice"]}
```

**Behavior:**
1. Check if `key` matches a declared association on the source schema
2. If match:
   - Emit implicit `:join` with `association:` source family
   - Binds association as `:as` named binding (same as key)
   - Recurse with association schema and filters
3. If value not params (map/keyword list) → log warning, skip

**Warning condition:** "Expected association filter value to be a map or keyword list, got: ..."
**File:Line:** `/Users/kurthogarth/Documents/GitHub/ecto_shorts/lib/ecto_shorts/common_filters.ex:432-438`

---

## 7. Recognized Filter Keys

All filter keys below are recognized by the main dispatcher and routed via `Builder.build_query/6`.

### Boolean & Predicate Filters

| Key | Dispatches to | Accept Shapes | Emits | Warn/Nil Cases |
|-----|---------------|---------------|-------|-----------------|
| `:where` | `Builder.apply_filter(:where, ...)` | Map / keyword / list-of-maps | WHERE dynamic | `nil` → no clause; `list_of_params` → reduce as `:where`; invalid params → warning |
| `:or_where` | `Builder.apply_filter(:or_where, ...)` | Map / keyword / list-of-maps | OR_WHERE dynamic | Same as `:where` |
| `:and` | Direct reducer (transparent grouping) | Map / keyword | Multiple WHERE clauses | N/A (always succeeds) |
| `:or` | Direct reducer as `:or_where` | Map / keyword / list-of-maps | Multiple OR_WHERE clauses | N/A |

**Files:**
- `:where`, `:or_where`: `Builder.apply_filter(:where|:or_where, ...)` at `/Users/kurthogarth/Documents/GitHub/ecto_shorts/lib/ecto_shorts/common_filters/builder.ex:183-199`
- Dynamic build: `DynamicBuilders.build_dynamic(...)` (not detailed here)

### Binding Selectors

| Key | Dispatches to | Accept Shapes | Emits | Warn/Nil Cases |
|-----|---------------|---------------|-------|-----------------|
| `:as` | Direct resolver | Map/keyword with atom binding names | Resolved binding or `:error` | Invalid binding name → `:error`, query unchanged |
| `:at` | Direct resolver | Map/keyword with integer/`:first`/`:last` keys | Resolved position or `:error` | Position out of range → warning logged, `:error`, query unchanged |

**File:Line:** `/Users/kurthogarth/Documents/GitHub/ecto_shorts/lib/ecto_shorts/common_filters.ex:484-510`

### Join & Association Filters

| Key | Module | Accept Shapes | Emits | Warn/Nil Cases |
|-----|--------|---------------|-------|-----------------|
| `:join` | `Join` | `{:association, ...}` or `{:schema, ...}` or keyword/map with `:source` key | `JOIN` clause | Unknown join type → warning; missing `:source` → warning; invalid `:on` params → warning |

**File:** `/Users/kurthogarth/Documents/GitHub/ecto_shorts/lib/ecto_shorts/common_filters/filters/join.ex`

**`:join` param structure (detailed):**
```elixir
# Shape 1: explicit source family
{join_type, join_options}
  where join_type in [:association, :schema, :table, :query, :subquery, :fragment]
  and join_options = [source: value, qualifier: :inner|:left, on: conditions, as: name, ...]

# Shape 2: implicit association shorthand
{assoc_key, join_options}
  where assoc_key matches schema association
  converts to {:association, [source: assoc_key, ...]}

# Nested list/map form
[{type1, opts1}, {type2, opts2}, ...]
```

**Join type dispatch (lines 170-235):**
- `:association` → `{:association, key}`
- `:schema` → `{:source, schema_or_{table,schema}_tuple}`
- `:table` → `{:source, table_name}`
- `:query` → `{:source, Ecto.Query{...}}`
- `:subquery` → builds from params or recursively via `convert_params_to_filter`
- `:fragment` → requires `name:` and `values:` in params, resolved via `QueryProvider`

**Warning conditions (file: `join.ex`):**
- Line 60-66: Join type not in `@join_types` and not association → "Expected join type to be one of #{inspect(@join_types)}, got: ..."
- Line 102-108: Missing `:source` key → "Expected join options to have a :source key, got: ..."
- Line 127-141: QueryProvider callback error → "Join source callback returned error for key #{inspect(source_key)}: ..."
- Line 255-273: Invalid `:on` params → "Expected :on to be a keyword list, map, or true, got: ..."

### Ordering Filters

| Key | Module | Accept Shapes | Emits | Warn/Nil Cases |
|-----|--------|---------------|-------|-----------------|
| `:order_by` | `OrderBy` | Atom field / list of atoms / list of `{direction, field}` / raw dynamic | `ORDER BY` clause | Unknown field → warning, filtered out |
| `:prepend_order_by` | `PrependOrderBy` | Same as `:order_by` | Prepended `ORDER BY` | Unknown field → warning, filtered out |
| `:reverse_order` | `ReverseOrder` | `nil` or `true` | Reverses existing `ORDER BY` | Non-true value → warning, query unchanged |

**OrderBy directions:** `:asc`, `:asc_nulls_last`, `:asc_nulls_first`, `:desc`, `:desc_nulls_last`, `:desc_nulls_first`

**Field validation (OrderBy file: `order_by.ex:68-87`):**
- Validates field exists on schema; missing field → warning: "Field \"#{field_name}\" does not exist on schema #{inspect(schema)}, skipping field reference"

**Files:**
- `OrderBy`: `/Users/kurthogarth/Documents/GitHub/ecto_shorts/lib/ecto_shorts/common_filters/filters/order_by.ex`
- `PrependOrderBy`: `/Users/kurthogarth/Documents/GitHub/ecto_shorts/lib/ecto_shorts/common_filters/filters/prepend_order_by.ex`
- `ReverseOrder`: `/Users/kurthogarth/Documents/GitHub/ecto_shorts/lib/ecto_shorts/common_filters/filters/reverse_order.ex:10-26`

### Grouping & Aggregate Filters

| Key | Module | Accept Shapes | Emits | Warn/Nil Cases |
|-----|--------|---------------|-------|-----------------|
| `:group_by` | `GroupBy` | Atom field / list of atoms / raw dynamic | `GROUP BY` clause | Unknown field → warning, filtered out |
| `:having` | `Having` | Map / keyword / raw dynamic | `HAVING` clause | `nil` → no clause |
| `:or_having` | `OrHaving` | Map / keyword / raw dynamic | `OR HAVING` clause | `nil` → no clause |

**Field validation (GroupBy: `group_by.ex:62-87`):**
- Same as OrderBy: missing field → warning, filtered out

**Files:**
- `GroupBy`: `/Users/kurthogarth/Documents/GitHub/ecto_shorts/lib/ecto_shorts/common_filters/filters/group_by.ex`
- `Having`: `/Users/kurthogarth/Documents/GitHub/ecto_shorts/lib/ecto_shorts/common_filters/filters/having.ex`
- `OrHaving`: `/Users/kurthogarth/Documents/GitHub/ecto_shorts/lib/ecto_shorts/common_filters/filters/or_having.ex`

### Uniqueness Filter

| Key | Module | Accept Shapes | Emits | Warn/Nil Cases |
|-----|--------|---------------|-------|-----------------|
| `:distinct` | `Distinct` | Boolean / atom field / list of atoms / list of `{direction, field}` | `DISTINCT` clause | Boolean cast; unknown field → warning, filtered out |

**File:** `/Users/kurthogarth/Documents/GitHub/ecto_shorts/lib/ecto_shorts/common_filters/filters/distinct.ex`

### Pagination & Cardinality Filters

| Key | Module | Accept Shapes | Emits | Warn/Nil Cases |
|-----|--------|---------------|-------|-----------------|
| `:limit` | `Limit` | Integer or string (coerced to integer) | `LIMIT` clause | Coerced via `Types.cast(:integer, expr)` |
| `:first` | `Limit` (reused) | Same as `:limit` | Same as `:limit` | Same as `:limit` |
| `:offset` | `Offset` | Integer or string (coerced to integer) | `OFFSET` clause | Coerced via `Types.cast(:integer, expr)` |
| `:page` | `Page` | Offset-based: `%{index: N, size: M}` or cursor-based: `%{after\|before: cursor, by: field, size: N}` | `LIMIT` + `OFFSET` or cursor-filtered `LIMIT` | Invalid param shape → logged as part of pattern match failure |
| `:last` | `Last` | Integer / `{sort_key, limit}` tuple / keyword/map with pairs | Nested subquery with reverse order | Invalid shape → warning: "Expected :last value to be an integer, a {sort_key, limit} tuple, or a map/keyword list of such pairs, got: ..." |

**Page shapes (file: `page.ex:13-86`):**
1. Offset: `%{index: 1, size: 10}` → offset = (index - 1) * size, limit = size
2. Cursor forward: `%{after: cursor, by: field, size: size}` → filters `field > cursor`, orders ASC, limits
3. Cursor backward: `%{before: cursor, by: field, size: size}` → filters `field < cursor`, orders DESC, limits

**Last internals (file: `last.ex:13-50`):**
- Accepts `{sort_key, limit}` tuple where sort_key is nil (uses `:id` or primary key) or an atom
- Creates subquery: order by sort_key DESC, limit, then outer order by sort_key ASC

**Files:**
- `Limit`: `/Users/kurthogarth/Documents/GitHub/ecto_shorts/lib/ecto_shorts/common_filters/filters/limit.ex`
- `Offset`: `/Users/kurthogarth/Documents/GitHub/ecto_shorts/lib/ecto_shorts/common_filters/filters/offset.ex`
- `Page`: `/Users/kurthogarth/Documents/GitHub/ecto_shorts/lib/ecto_shorts/common_filters/filters/page.ex`
- `Last`: `/Users/kurthogarth/Documents/GitHub/ecto_shorts/lib/ecto_shorts/common_filters/filters/last.ex`

### Projection Filters

| Key | Module | Accept Shapes | Emits | Warn/Nil Cases |
|-----|--------|---------------|-------|-----------------|
| `:select` | `Select` | Atom field / list of atoms / `true` / `{:map, params}` / `{:struct, fields}` / raw dynamic / map / keyword | `SELECT` clause (replaces previous) | Raw dynamic passed through; boolean coercion |
| `:select_merge` | `SelectMerge` | Same as `:select` but additive | `SELECT MERGE` clause | Same as `:select` |

**Select shapes (file: `select.ex:11-73`):**
- `:field_name` → selects single field
- `[field1, field2, ...]` → as keyword list → recursive merge, or as list → raw select
- `true` → selects entire binding
- `%{key1: field1, key2: field2}` → builds map with aliases
- `{:map, params}` → forces map projection
- `{:struct, fields}` → forces struct projection with specific fields

**SelectMerge behavior (file: `select_merge.ex:10-92`):**
- Incrementally adds fields to select
- `{field_alias, field_name}` where both atoms → maps field from source
- `{field_alias, dynamic}` → merges computed field

**Files:**
- `Select`: `/Users/kurthogarth/Documents/GitHub/ecto_shorts/lib/ecto_shorts/common_filters/filters/select.ex`
- `SelectMerge`: `/Users/kurthogarth/Documents/GitHub/ecto_shorts/lib/ecto_shorts/common_filters/filters/select_merge.ex`

### Eager Loading

| Key | Module | Accept Shapes | Emits | Warn/Nil Cases |
|-----|--------|---------------|-------|-----------------|
| `:preload` | `Preload` | Atom assoc / list of atoms / `{assoc, nested}` / map / keyword | `PRELOAD` clause | Normalized via `normalize(value)` recursively |

**Preload normalization (file: `preload.ex:64-87`):**
- Map → to_list → recursive
- Keyword list → each value recursively normalized
- Atom → wrapped as `[name]`
- Other → passed through

**Files:**
- `Preload`: `/Users/kurthogarth/Documents/GitHub/ecto_shorts/lib/ecto_shorts/common_filters/filters/preload.ex`

### Nested Queries

| Key | Module | Accept Shapes | Emits | Warn/Nil Cases |
|-----|--------|---------------|-------|-----------------|
| `:subquery` | `SubQuery` | Map / keyword of filter params | Subquery wrapping | Invalid shape → warning: "Expected :subquery value to be a keyword list or map of filter params, got: ..." |

**File:** `/Users/kurthogarth/Documents/GitHub/ecto_shorts/lib/ecto_shorts/common_filters/filters/sub_query.ex:12-26`

### Locking

| Key | Module | Accept Shapes | Emits | Warn/Nil Cases |
|-----|--------|---------------|-------|-----------------|
| `:lock` | `Lock` | Map/keyword with `:name` key (or function) | `LOCK` clause | Missing `:name` → silent no-op; invalid shape → warning: "Expected :lock value to be a map or keyword list with a :name key, got: ..." |

**Lock names (file: `lock.ex:39-46`):**
- `:for_update` → `"FOR UPDATE"`
- `:for_share` → `"FOR SHARE"`
- Custom atom → resolved via QueryProvider (if configured), else warning logged

**Files:**
- `Lock`: `/Users/kurthogarth/Documents/GitHub/ecto_shorts/lib/ecto_shorts/common_filters/filters/lock.ex`

### Clause Removal

| Key | Module | Accept Shapes | Emits | Warn/Nil Cases |
|-----|--------|---------------|-------|-----------------|
| `:exclude` | `Builder.apply_filter(:exclude, ...)` | Atom field / list of atoms | Removes clause from query | N/A (always succeeds) |

**File:** `/Users/kurthoearth/Documents/GitHub/ecto_shorts/lib/ecto_shorts/common_filters/builder.ex:147-153`

### Bulk Updates

| Key | Module | Accept Shapes | Emits | Warn/Nil Cases |
|-----|--------|---------------|-------|-----------------|
| `:update` | `Update` | Map / keyword of field → value pairs | `UPDATE` set clause | Keyword form → `UpdateExpr.build_update_expr(source, term)` |

**File:** `/Users/kurthogarth/Documents/GitHub/ecto_shorts/lib/ecto_shorts/common_filters/filters/update.ex`

### Query Prefixing

| Key | Module | Accept Shapes | Emits | Warn/Nil Cases |
|-----|--------|---------------|-------|-----------------|
| `:put_query_prefix` | `PutQueryPrefix` | Any (prefix value) | Query prefix | N/A |

**File:** `/Users/kurthogarth/Documents/GitHub/ecto_shorts/lib/ecto_shorts/common_filters/filters/put_query_prefix.ex`

### Common Table Expressions

| Key | Module | Accept Shapes | Emits | Warn/Nil Cases |
|-----|--------|---------------|-------|-----------------|
| `:recursive_ctes` | `RecursiveCtes` | Boolean or string (coerced to boolean) | Sets recursive CTE flag | Coerced via `Types.cast(:boolean, value)` |
| `:with_cte` | `WithCte` | Map / keyword with CTE name → definition pairs | `WITH` clause | Missing `:as` in definition → warning; invalid `:operation` → warning; invalid `:materialized` → warning |

**WithCte structure (file: `with_cte.ex:52-107`):**
```elixir
# Entry format: {cte_name, cte_definition}
# cte_name: atom or binary
# cte_definition: keyword/map with keys:
#   :as (required) → Ecto.Query | Ecto.SubQuery | map/keyword of filter params
#   :materialized (optional) → boolean
#   :operation (optional) → :all | :update_all | :delete_all
```

**Warning conditions (file: `with_cte.ex`):**
- Line 100-105: Missing `:as` → "Expected :with_cte params for #{inspect(cte_name)} to include an :as key"
- Line 92-97: Invalid `:as` type → "Expected CTE :as query params... to be a query, subquery, or keyword/map payload, got: ..."
- Line 139-144: Invalid `:operation` → "Expected :operation for #{inspect(cte_name)} to be one of [:all, :update_all, :delete_all], got: ..."
- Line 120-125: Invalid `:materialized` → "Expected :materialized for #{inspect(cte_name)} to be a boolean, got: ..."

**Files:**
- `RecursiveCtes`: `/Users/kurthogarth/Documents/GitHub/ecto_shorts/lib/ecto_shorts/common_filters/filters/recursive_ctes.ex`
- `WithCte`: `/Users/kurthogarth/Documents/GitHub/ecto_shorts/lib/ecto_shorts/common_filters/filters/with_cte.ex`

### Windowing

| Key | Module | Accept Shapes | Emits | Warn/Nil Cases |
|-----|--------|---------------|-------|-----------------|
| `:windows` | `Windows` | Keyword/map with window_name → definition pairs | `WINDOWS` clause | Cyclic reference detected → warning; invalid `:frame` → warning; invalid params type → warning |
| `:with_ties` | `WithTies` | Boolean or keyword with `:limit` key | `WITH TIES` modifier | Boolean cast; unknown keys → warning; invalid `:limit` → warning |

**Windows definition structure (file: `windows.ex:41-60`):**
```elixir
[window_name: [partition_by: field, order_by: [{:asc, field}], frame: dyn, window: parent_name]]
# :window → parent window name for inheritance
# :partition_by → field name or list
# :order_by → field or {direction, field}
# :frame → Ecto.Query.DynamicExpr or atom
```

**WithTies behavior (file: `with_ties.ex:19-92`):**
- Boolean `true` → applies WITH TIES with default limit 1000
- `{:limit, N}` → applies limit N then WITH TIES
- No order/limit exists → ensures both before applying WITH TIES

**Warning conditions:**
- Windows: line 42-46 cyclic reference, line 92-98 invalid frame type, line 32-39 invalid params
- WithTies: line 52-55 unknown keys, line 79-85 invalid limit type

**Files:**
- `Windows`: `/Users/kurthogarth/Documents/GitHub/ecto_shorts/lib/ecto_shorts/common_filters/filters/windows.ex`
- `WithTies`: `/Users/kurthogarth/Documents/GitHub/ecto_shorts/lib/ecto_shorts/common_filters/filters/with_ties.ex`

### Named Bindings

| Key | Module | Accept Shapes | Emits | Warn/Nil Cases |
|-----|--------|---------------|-------|-----------------|
| `:with_named_binding` | `WithNamedBinding` | Map / keyword with binding_name → filter_params pairs | Applies filters and ensures named binding is created | Binding not created after filters → warning; invalid key type → warning |

**Warning conditions (file: `with_named_binding.ex`):**
- Line 45-51: Filters did not create named binding → "Filters provided for :with_named_binding key #{inspect(key)} did not create a named binding"
- Line 55-61: Invalid key (not atom) → "Expected :with_named_binding key to be an atom, got: #{inspect(key)}"

**File:** `/Users/kurthogarth/Documents/GitHub/ecto_shorts/lib/ecto_shorts/common_filters/filters/with_named_binding.ex`

### Set Operations

| Key | Module | Accept Shapes | Emits | Warn/Nil Cases |
|-----|--------|---------------|-------|-----------------|
| `:union` | `Union` | Ecto.Query or map/keyword of filter params | `UNION` composition | `nil` param → no-op |
| `:union_all` | `UnionAll` | Same as `:union` | `UNION ALL` composition | `nil` param → no-op |
| `:except` | `Except` | Same as `:union` | `EXCEPT` composition | `nil` param → no-op |
| `:except_all` | `ExceptAll` | Same as `:union` | `EXCEPT ALL` composition | `nil` param → no-op |
| `:intersect` | `Intersect` | Same as `:union` | `INTERSECT` composition | `nil` param → no-op |
| `:intersect_all` | `IntersectAll` | Same as `:union` | `INTERSECT ALL` composition | `nil` param → no-op |

**Behavior (all set operations, file examples: `union.ex:12-25`, `except.ex:12-25`):**
- If param is Ecto.Query → use as-is
- Else if param is map/keyword → recursively call `convert_params_to_filter(source, param, opts)`
- Emit set operation combining result with current query

**Files:**
- `Union`: `/Users/kurthogarth/Documents/GitHub/ecto_shorts/lib/ecto_shorts/common_filters/filters/union.ex`
- `UnionAll`: `/Users/kurthogarth/Documents/GitHub/ecto_shorts/lib/ecto_shorts/common_filters/filters/union_all.ex`
- `Except`: `/Users/kurthogarth/Documents/GitHub/ecto_shorts/lib/ecto_shorts/common_filters/filters/except.ex`
- `ExceptAll`: `/Users/kurthogarth/Documents/GitHub/ecto_shorts/lib/ecto_shorts/common_filters/filters/except_all.ex`
- `Intersect`: `/Users/kurthogarth/Documents/GitHub/ecto_shorts/lib/ecto_shorts/common_filters/filters/intersect.ex`
- `IntersectAll`: `/Users/kurthogarth/Documents/GitHub/ecto_shorts/lib/ecto_shorts/common_filters/filters/intersect_all.ex`

---

## 8. Builder & Parser Modules

### `EctoShorts.CommonFilters.Builder`

**Location:** `/Users/kurthogarth/Documents/GitHub/ecto_shorts/lib/ecto_shorts/common_filters/builder.ex`

**Role:** Implements `EctoShorts.QueryBuilder` behavior; dispatcher for all filter keys via `build_query/6`

**Public functions:**
- `build_query(filter, source, query, selected_binding, term, opts)` → applies filter and returns updated query

**Implementation:** Pattern matches on `filter` atom and delegates to module-specific `build_query/6` for each filter type.

**Special cases:**
- `:where` and `:or_where` → routes to `DynamicBuilders.build_dynamic(...)` and wraps in `Query.where/3` or `Query.or_where/3`
- `:exclude` → inline implementation wraps param in list, reduces via `Query.exclude/2`
- `:first` → aliases to `:limit` (file: line 159-161)

### `EctoShorts.CommonFilters.Parser`

**Location:** `/Users/kurthogarth/Documents/GitHub/ecto_shorts/lib/ecto_shorts/common_filters/parser.ex`

**Role:** Utility for flattening and extracting nested map/keyword structures

**Public functions:**

| Function | Arity | Purpose | Example |
|----------|-------|---------|---------|
| `extract_entries(entries)` | 1 | Extracts `[key, value]` pairs from nested map | `Parser.extract_entries(%{"a" => 1, "b" => %{"c" => 2}})` → `[{"a", 1}, {"b", %{"c" => 2}}]` |
| `normalize(entries, predicate, acc)` | 1-3 | Flattens nested structure with predicate control; `true` → recurse, `false` → stop | `Parser.normalize(%{"a" => 1, "b" => %{"c" => 2}})` → `[{"a", 1}, {"b", {"c", 2}}]` |
| `default_predicate(key, value)` | 2 | Predicate that always returns `true` | Used as default in `normalize` |

**Normalization rules (file: `parser.ex:137-149`):**
- Map not struct → convert to list, recurse
- Keyword list → recurse over each entry
- Non-keyword list → stop, treat as value
- Tuple `{key, value}` where value is map/keyword → expand value, prepend key to results
- Other value → return as-is

---

## 9. All Warning & Logging Conditions

| Warning ID | File:Line | Message Template | Condition | Returned |
|------------|-----------|------------------|-----------|----------|
| COMMON_FILTERS_001 | common_filters.ex:432-438 | "Expected association filter value to be a map or keyword list, got: #{inspect(params)}" | Association key matched but value not params | query (unchanged) |
| COMMON_FILTERS_002 | common_filters.ex:498-506 | "Positional binding :at position #{position} is out of range (compiled max: #{max}). Filter skipped." | `:at` position not in range [1, max_positional_bindings] | :error, query unchanged |
| JOIN_001 | join.ex:60-66 | "Expected join type to be one of #{inspect(@join_types)}, got: #{inspect(key)}" | Join type not in [:association, :schema, :table, :query, :subquery, :fragment] and not association | query |
| JOIN_002 | join.ex:102-108 | "Expected join options to have a :source key, got: #{inspect(join_options)}" | `:source` not in keyword/map | query |
| JOIN_003 | join.ex:127-141 | "Join source callback returned error for key #{inspect(source_key)}: #{inspect(reason)}" | QueryProvider callback returns `{:error, reason}` | :error, query |
| JOIN_004 | join.ex:255-273 | "Expected :on to be a keyword list, map, or true, got: #{inspect(term)}" | `:on` value invalid type | :error |
| ORDER_BY_001 | order_by.ex:74-79 | "Field \"#{field_name}\" does not exist on schema #{inspect(schema)}, skipping field reference" | Field not in schema fields list | :error, field filtered out |
| GROUP_BY_001 | group_by.ex:68-74 | "Field \"#{field_name}\" does not exist on schema #{inspect(schema)}, skipping field reference" | Field not in schema fields list | :error, field filtered out |
| DISTINCT_001 | distinct.ex:100-106 | "Field \"#{field_name}\" does not exist on schema #{inspect(schema)}, skipping field reference" | Field not in schema fields list | :error, field filtered out |
| LAST_001 | last.ex:59-64 | "Expected :last value to be an integer, a {sort_key, limit} tuple, or a map/keyword list of such pairs, got: #{inspect(term)}" | `:last` value not recognized shape and not keyword/map | query |
| PAGE_001 | (implicit in pattern matching) | (none logged, pattern fails silently) | `:page` params don't match any shape | (no operation) |
| PRELOAD_001 | (none) | (none) | Preload always succeeds with normalization | N/A |
| SUB_QUERY_001 | sub_query.ex:18-21 | "Expected :subquery value to be a keyword list or map of filter params, got: #{inspect(params)}" | `:subquery` params not map/keyword | query |
| WINDOWS_001 | windows.ex:42-46 | "Detected cyclic :windows reference involving #{inspect(name)}" | Parent window references itself transitively | query, frame set to `[]` |
| WINDOWS_002 | windows.ex:92-98 | "Expected :frame for #{inspect(window_name)} to be an Ecto dynamic expression, got: #{inspect(frame)}" | `:frame` not nil, atom, or DynamicExpr | query |
| WINDOWS_003 | windows.ex:32-39 | "Expected :windows params to be a map or keyword list, got: #{inspect(value)}" | `:windows` param not map/keyword | query |
| WITH_TIES_001 | with_ties.ex:30-36 | "Expected :with_ties value to be a boolean or keyword/map payload, got: #{inspect(params)}" | `:with_ties` value not boolean/keyword/map | query |
| WITH_TIES_002 | with_ties.ex:52-55 | "Expected :with_ties params to only include :limit, got unsupported keys: #{inspect(unknown_keys)}" | Keyword has keys other than `:limit` | query |
| WITH_TIES_003 | with_ties.ex:79-85 | "Expected :with_ties :limit to be an integer or nil, got: #{inspect(other)}" | `:limit` coerced to non-integer | query |
| WITH_CTE_001 | with_cte.ex:100-105 | "Expected :with_cte params for #{inspect(cte_name)} to include an :as key" | CTE definition missing `:as` | :error, query |
| WITH_CTE_002 | with_cte.ex:92-97 | "Expected CTE :as query params for #{inspect(cte_name)} to be a query, subquery, or keyword/map payload, got: #{inspect(term)}" | `:as` value invalid type | :error, query |
| WITH_CTE_003 | with_cte.ex:139-144 | "Expected :operation for #{inspect(cte_name)} to be one of [:all, :update_all, :delete_all], got: #{inspect(operation)}" | `:operation` not in enum | :error, query |
| WITH_CTE_004 | with_cte.ex:120-125 | "Expected :materialized for #{inspect(cte_name)} to be a boolean, got: #{inspect(other)}" | `:materialized` coerced to non-boolean/nil | :error, query |
| WITH_CTE_005 | with_cte.ex:25-31 | "Expected :with_cte params to be a map or keyword list, got: #{inspect(value)}" | `:with_cte` param not map/keyword | query |
| LOCK_001 | lock.ex:21-27 | "Expected :lock value to be a map or keyword list with a :name key (e.g. %{name: :for_update}), got: #{inspect(params)}" | `:lock` param not map/keyword or missing `:name` | query |
| LOCK_002 | lock.ex:53-56 | "No query provider module configured for lock filter" | Custom lock name without configured provider | query |
| LOCK_003 | lock.ex:77-83 | "Expected lock expression callback to return an Ecto.Query, got: #{inspect(other)}" | Lock expression callback returns non-Query | query |
| LOCK_004 | lock.ex:85-89 | "Expected lock expression resolved from QueryProvider to be a 1-arity function, got: #{inspect(callback)}" | QueryProvider returns non-function | query |
| LOCK_005 | lock.ex:94-99 | "Lock expression callback returned error for #{inspect(custom_name)}: #{inspect(reason)}" | QueryProvider callback returns `{:error, reason}` | query |
| WITH_NAMED_BINDING_001 | with_named_binding.ex:45-51 | "Filters provided for :with_named_binding key #{inspect(key)} did not create a named binding" | Filters applied but binding not present after | query (unchanged) |
| WITH_NAMED_BINDING_002 | with_named_binding.ex:55-61 | "Expected :with_named_binding key to be an atom, got: #{inspect(key)}" | Binding key not atom | query |
| REVERSE_ORDER_001 | reverse_order.ex:19-24 | "Expected :reverse_order value to be true, got: #{inspect(value)}" | `:reverse_order` value not `true` or `nil` | query |
| PREPEND_ORDER_BY_001 | prepend_order_by.ex:65-71 | "Field \"#{field_name}\" does not exist on schema #{inspect(schema)}, skipping field reference" | Field not in schema | :error, field filtered out |

---

## 10. Filter Key Complete List

All keys recognized by `@filters` list (line 269-304 of `common_filters.ex`):

```
:and
:distinct
:except
:except_all
:exclude
:first
:group_by
:having
:intersect
:intersect_all
:join
:last
:limit
:lock
:offset
:or
:or_having
:or_where
:page
:prepend_order_by
:preload
:put_query_prefix
:recursive_ctes
:reverse_order
:select
:select_merge
:subquery
:union
:union_all
:update
:where
:windows
:with_cte
:with_named_binding
:with_ties
```

**Plus:**
- `:as` (binding selector, special dispatch)
- `:at` (binding selector, special dispatch)
- **Any schema association name** (implicit join + recurse)
- **Any schema field name** (treated as `:where` filter)

---

## 11. Default Dispatch Behavior

**Unknown keys (not in @filters, not associations, not fields):**
- Passed to `:where` filter routing
- Treated as field equality: `{key, value}` → `DynamicBuilders.build_dynamic(source, binding, {key, value}, opts)`
- If field doesn't exist, may generate warning during field coercion

---

## 12. Example Usage Patterns

### Basic field filtering
```elixir
CommonFilters.convert_params_to_filter(Post, %{published: true, author_id: 5}, [])
```
Routes `published` and `author_id` to `:where` dynamic builder.

### Boolean grouping
```elixir
CommonFilters.convert_params_to_filter(Post, %{and: %{published: true, views: [5, 10]}}, [])
```
Both entries expand as separate WHERE clauses (AND semantics).

### Association shorthand
```elixir
CommonFilters.convert_params_to_filter(Post, %{author: %{name: "Alice"}}, [])
```
Implicit `:join` with association, recurse on author filters.

### Binding selectors
```elixir
CommonFilters.convert_params_to_filter(Post, %{as: %{author: %{select: :first_name}}}, [])
CommonFilters.convert_params_to_filter(Post, %{at: %{1 => %{order_by: :name}}}, [])
```

### Keyword list with duplicate keys
```elixir
CommonFilters.convert_params_to_filter(Post, [where: %{a: 1}, where: %{b: 2}, order_by: :id], [])
```
Multiple `:where` entries applied in order.

### Page-based pagination
```elixir
CommonFilters.convert_params_to_filter(Post, %{page: %{index: 2, size: 10}}, [])
```
Offset-based: offset = 10, limit = 10.

### Recursive CTE with union
```elixir
CommonFilters.convert_params_to_filter(Post, %{
  recursive_ctes: true,
  with_cte: [root: [as: %{from: Root}, materialized: false]],
  union_all: %{from: Root}
}, [])
```

