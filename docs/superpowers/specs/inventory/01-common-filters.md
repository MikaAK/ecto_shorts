# CommonFilters Behavior Inventory

## Overview

This document explains everything `EctoShorts.CommonFilters` does. Think of `CommonFilters` as a translator: you hand it some plain data (a map or a list of key/value pairs), and it turns that data into a database request (a query) you can run.

It is the main, public way you tell the library "find me the rows I want." This document covers, step by step:
- how your input is cleaned up and put in order before anything happens,
- how each piece of input is matched to the right helper,
- every key (instruction word) the library understands, what data shapes each one accepts, and
- every case where the library logs a warning instead of doing what you asked.

---

## Words used in this document

- **Ecto** — Ecto, the Elixir library for talking to a database. EctoShorts is built on top of it.
- **query** — a database request (a query). The thing you build up and eventually run to get rows back.
- **schema** — a schema: an Elixir description of a database table and its columns.
- **field** — field (a column of a table).
- **dynamic** — a query condition built up in code (Ecto calls this a "dynamic").
- **operator** — operator: a comparison word such as "equals" or "greater than."
- **operator alias** — nickname for an operator.
- **canonical** — the standard, tidied-up form.
- **term** — the filter piece / the value being matched.
- **predicate** — condition (a true/false test).
- **normalization** — tidying the input into one standard shape.
- **reduce / fold** — go through the items one by one, building up the result.
- **binding** — binding: which table in the query a condition points to.
- **pure function** — a function that only turns its inputs into an output, without looking anything up or changing anything outside itself.
- **association** — association: a link between two tables (for example, a post and its author).
- **subquery** — subquery: a query nested inside another query.
- **CTE** — CTE (common table expression): a named, temporary result you can reuse inside one query.
- **warn+nil / no-op** — logs a warning and skips that part, leaving the query unchanged.

---

## 1. Entry Point & Parameter Pipeline

This is the single function you call to start everything.

### `convert_params_to_filter/3`

**Location:** `/Users/kurthogarth/Documents/GitHub/ecto_shorts/lib/ecto_shorts/common_filters.ex:380-390`

**Signature:**
```elixir
def convert_params_to_filter(source, params, opts \\ [])
```
This shows the function name and its three inputs: where to read from, what to filter by, and extra options.

**Input shapes (what each input is allowed to be):**
- `source`: a schema (an Elixir description of a database table) module | a `{source, schema}` tuple | an already-built database request (`Ecto.Query`)
- `params`: a map (a plain map, not a struct) | a keyword list (a list of key/value pairs)
- `opts`: a keyword list (default: `[]`, meaning none)

**Pipeline (the steps it runs, in order):**
1. Turn `source` into a database request (`Ecto.Query`) using `CommonSchema.to_query/1`
2. Put the input in order using a sorter (either one you supply or the built-in `sort_filter_params`)
3. Go through the input one by one, building up the query (`reduce_filters/6`), starting with the filter type `:where`

**Rules for accepting input:**
- Both maps and keyword lists are accepted
- Keyword lists keep duplicate keys and keep their order
- Maps are turned into keyword lists internally so the order is fixed
- No automatic checking — keys the library does not recognize quietly fall through to the `:where` filter (treated as a plain condition)

---

## 2. Param Sorting: `sort_filter_params/1`

Before doing the work, the library reorders your input so that certain instructions run before others. This matters because some pieces (like adding more conditions) must happen before terminal pieces (like wrapping everything in a smaller query).

**Location:** `/Users/kurthogarth/Documents/GitHub/ecto_shorts/lib/ecto_shorts/common_filters.ex:526-538`

**Order things run in:**
1. `:where` filters (all entries whose key is `:where`)
2. All other filters except `:or_where`, `:last`, `:subquery`
3. `:or_where` filters (all entries whose key is `:or_where`)
4. Terminal filters, which must come last (`:last`, `:subquery`)

**Example (input before sorting, then the same input after sorting):**
```elixir
# Input
[or_where: %{x: 1}, limit: 10, where: %{y: 2}, subquery: %{...}]

# After sort
[where: %{y: 2}, limit: 10, or_where: %{x: 1}, subquery: %{...}]
```
This shows `:where` moving to the front and `:subquery` ending up last.

**Supplying your own sorter:**
```elixir
CommonFilters.convert_params_to_filter(Post, params, sorter: fn p -> ... end)
```
This shows passing a `sorter:` option to replace the built-in ordering.

---

## 3. Filter Routing & Apply Logic

Once the input is in order, the library looks at each key and decides which helper should handle it. That decision is "routing."

### Dispatch Entry: `apply_filter/6`

**Location:** `/Users/kurthogarth/Documents/GitHub/ecto_shorts/lib/ecto_shorts/common_filters.ex:396-462`

**Routing logic (checked top to bottom; the first match wins):**

| Condition | Action | Emit |
|-----------|--------|------|
| `key in [:as, :at]` | Pick which table the next conditions point to (the binding), then go into the nested map | `:error` or `{:ok, resolved_binding}` |
| `key in [:where, :or_where, :having, :or_having]` | A list of params? → go through them one by one; a single set of params? → go through them; otherwise → hand to the Builder | nil or a built condition (dynamic) |
| `assoc_key?(source, key)` | This key names a link to another table (an association): add an automatic join and recurse into that table; warn if the value is not params | query or warning |
| `key === :and` | Go through the params without changing the filter type | query |
| `key === :or` | If it is a list of params → go through them as `:or_where`; otherwise → send each entry as `:or_where` | query |
| `key in @filters` | Hand to `Builder.build_query(key, ...)` | varies |
| **default** | Treat as a plain field condition: send `{key, params}` to `:where` | varies |

---

## 4. Binding Selectors: `:as` and `:at`

A query can involve more than one table (for example, posts joined to their authors). A "binding" says which of those tables a condition points to. `:as` and `:at` let you aim the following conditions at a specific table.

**Location:** `/Users/kurthogarth/Documents/GitHub/ecto_shorts/lib/ecto_shorts/common_filters.ex:398-414, 484-510`

### `:as` (point at a table by name)

**Accepted shapes:**
```elixir
%{as: %{author: %{select: :first_name}}}
%{as: [author: [select: :first_name]]}
```
These both aim the inner filters at the table named `author`.

**Behavior:**
- The key names a table that was given a name in the query (a named binding)
- The value must be a map or a keyword list
- Each entry `{binding_name, filters}` runs its filters aimed at that named table
- Returns `{:ok, {:as, binding_name}}` so nested filters know which table to use

### `:at` (point at a table by position)

**Accepted shapes:**
```elixir
%{at: %{1 => %{select: :title}}}
%{at: %{first: %{...}}}
%{at: %{last: %{...}}}
%{at: %{2 => [order_by: :name]}}
```
These aim the inner filters at the table in a given position (first, last, or a number).

**Behavior:**
- `:first` → `{:ok, {:at, 1}}`
- `:last` → `{:ok, {:at, CommonQuery.query_binding_count(query)}}`
- An integer 1 or higher → checked against `Config.max_positional_bindings()` (default 10)
- A position outside that range → logs a warning, returns `:error`, and that filter is skipped

---

## 5. Boolean Operators: `:and`, `:or`

These let you group conditions. `:and` means "all of these must be true." `:or` means "any of these may be true."

### `:and`

**Location:** `/Users/kurthogarth/Documents/GitHub/ecto_shorts/lib/ecto_shorts/common_filters.ex:440-441`

**Accepted shapes:**
```elixir
%{and: %{field1: value1, field2: value2}}
%{and: [field1: value1, field2: value2]}
```
These group two conditions together with AND.

**Behavior:**
- Passes the params straight through with the same filter type (it is just a see-through wrapper)
- Each entry becomes its own WHERE condition, and several WHERE conditions are combined with AND in SQL

### `:or`

**Location:** `/Users/kurthogarth/Documents/GitHub/ecto_shorts/lib/ecto_shorts/common_filters.ex:443-450`

**Accepted shapes:**
```elixir
%{or: %{field1: value1, field2: value2}}
%{or: [field1: value1, field2: value2]}
%{or: [%{field1: value1}, %{field2: value2}]}
```
These group conditions together with OR.

**Behavior:**
- If the value is a list of param sets (`list_of_params?`, a list of maps or keyword lists) → go through them as `:or_where`
- Otherwise → go through each entry, sending each as an `:or_where` filter
- Produces `OR_WHERE` clauses (OR in SQL)

---

## 6. Association Shorthand

An association is a link between two tables (for example, a post and its author). If you use a key that names one of these links, the library automatically joins to the linked table and applies the inner filters there.

**Location:** `/Users/kurthogarth/Documents/GitHub/ecto_shorts/lib/ecto_shorts/common_filters.ex:428-438, 468-482`

**Accepted shape:**
```elixir
%{comments: %{approved: true}}
%{author: [published: true, name: "Alice"]}
```
These filter by something on a linked table (comments, author).

**Behavior:**
1. Check whether `key` names a declared link (association) on the source schema
2. If it does:
   - Add an automatic `:join` using the `association:` source family
   - Give the joined table a name (an `:as` named binding) equal to the key
   - Recurse into the linked table's schema and filters
3. If the value is not params (a map or keyword list) → log a warning and skip

**Warning condition:** "Expected association filter value to be a map or keyword list, got: ..."
**File:Line:** `/Users/kurthogarth/Documents/GitHub/ecto_shorts/lib/ecto_shorts/common_filters.ex:432-438`

---

## 7. Recognized Filter Keys

Below are all the keys the main router understands. Each one is handled through `Builder.build_query/6`.

### Boolean & Predicate Filters

These build conditions (true/false tests) on the query.

| Key | Dispatches to | Accept Shapes | Emits | Warn/Nil Cases |
|-----|---------------|---------------|-------|-----------------|
| `:where` | `Builder.apply_filter(:where, ...)` | Map / keyword / list-of-maps | WHERE dynamic | `nil` → no clause; `list_of_params` → reduce as `:where`; invalid params → warning |
| `:or_where` | `Builder.apply_filter(:or_where, ...)` | Map / keyword / list-of-maps | OR_WHERE dynamic | Same as `:where` |
| `:and` | Direct reducer (transparent grouping) | Map / keyword | Multiple WHERE clauses | N/A (always succeeds) |
| `:or` | Direct reducer as `:or_where` | Map / keyword / list-of-maps | Multiple OR_WHERE clauses | N/A |

**Files:**
- `:where`, `:or_where`: `Builder.apply_filter(:where|:or_where, ...)` at `/Users/kurthogarth/Documents/GitHub/ecto_shorts/lib/ecto_shorts/common_filters/builder.ex:183-199`
- Builds the condition (dynamic): `DynamicBuilders.build_dynamic(...)` (covered elsewhere, not here)

### Binding Selectors

These pick which table the following conditions point to. See Section 4 for details.

| Key | Dispatches to | Accept Shapes | Emits | Warn/Nil Cases |
|-----|---------------|---------------|-------|-----------------|
| `:as` | Direct resolver | Map/keyword with atom binding names | Resolved binding or `:error` | Invalid binding name → `:error`, query unchanged |
| `:at` | Direct resolver | Map/keyword with integer/`:first`/`:last` keys | Resolved position or `:error` | Position out of range → warning logged, `:error`, query unchanged |

**File:Line:** `/Users/kurthogarth/Documents/GitHub/ecto_shorts/lib/ecto_shorts/common_filters.ex:484-510`

### Join & Association Filters

A join pulls in another table so you can filter or read from it.

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
This shows the three ways to write a join: name the kind of source explicitly, lean on an association name, or pass several joins at once.

**Join type dispatch (lines 170-235), one entry per kind of source:**
- `:association` → `{:association, key}`
- `:schema` → `{:source, schema_or_{table,schema}_tuple}`
- `:table` → `{:source, table_name}`
- `:query` → `{:source, Ecto.Query{...}}`
- `:subquery` → builds from params, or recurses through `convert_params_to_filter` (a subquery: a query nested inside another query)
- `:fragment` → needs `name:` and `values:` in the params, looked up through `QueryProvider`

**Warning conditions (file: `join.ex`):**
- Line 60-66: Join type not in `@join_types` and not an association → "Expected join type to be one of #{inspect(@join_types)}, got: ..."
- Line 102-108: Missing `:source` key → "Expected join options to have a :source key, got: ..."
- Line 127-141: QueryProvider callback error → "Join source callback returned error for key #{inspect(source_key)}: ..."
- Line 255-273: Invalid `:on` params → "Expected :on to be a keyword list, map, or true, got: ..."

### Ordering Filters

These control the sort order of the results.

| Key | Module | Accept Shapes | Emits | Warn/Nil Cases |
|-----|--------|---------------|-------|-----------------|
| `:order_by` | `OrderBy` | Atom field / list of atoms / list of `{direction, field}` / raw dynamic | `ORDER BY` clause | Unknown field → warning, filtered out |
| `:prepend_order_by` | `PrependOrderBy` | Same as `:order_by` | Prepended `ORDER BY` | Unknown field → warning, filtered out |
| `:reverse_order` | `ReverseOrder` | `nil` or `true` | Reverses existing `ORDER BY` | Non-true value → warning, query unchanged |

**OrderBy directions (which way to sort, and where empty values go):** `:asc`, `:asc_nulls_last`, `:asc_nulls_first`, `:desc`, `:desc_nulls_last`, `:desc_nulls_first`

**Field validation (OrderBy file: `order_by.ex:68-87`):**
- Checks the field (column) exists on the schema; a missing field → warning: "Field \"#{field_name}\" does not exist on schema #{inspect(schema)}, skipping field reference"

**Files:**
- `OrderBy`: `/Users/kurthogarth/Documents/GitHub/ecto_shorts/lib/ecto_shorts/common_filters/filters/order_by.ex`
- `PrependOrderBy`: `/Users/kurthogarth/Documents/GitHub/ecto_shorts/lib/ecto_shorts/common_filters/filters/prepend_order_by.ex`
- `ReverseOrder`: `/Users/kurthogarth/Documents/GitHub/ecto_shorts/lib/ecto_shorts/common_filters/filters/reverse_order.ex:10-26`

### Grouping & Aggregate Filters

Grouping bundles rows together (for counts, sums, and so on); `:having` filters those groups.

| Key | Module | Accept Shapes | Emits | Warn/Nil Cases |
|-----|--------|---------------|-------|-----------------|
| `:group_by` | `GroupBy` | Atom field / list of atoms / raw dynamic | `GROUP BY` clause | Unknown field → warning, filtered out |
| `:having` | `Having` | Map / keyword / raw dynamic | `HAVING` clause | `nil` → no clause |
| `:or_having` | `OrHaving` | Map / keyword / raw dynamic | `OR HAVING` clause | `nil` → no clause |

**Field validation (GroupBy: `group_by.ex:62-87`):**
- Same as OrderBy: a missing field (column) → warning, filtered out

**Files:**
- `GroupBy`: `/Users/kurthogarth/Documents/GitHub/ecto_shorts/lib/ecto_shorts/common_filters/filters/group_by.ex`
- `Having`: `/Users/kurthogarth/Documents/GitHub/ecto_shorts/lib/ecto_shorts/common_filters/filters/having.ex`
- `OrHaving`: `/Users/kurthogarth/Documents/GitHub/ecto_shorts/lib/ecto_shorts/common_filters/filters/or_having.ex`

### Uniqueness Filter

This removes duplicate rows.

| Key | Module | Accept Shapes | Emits | Warn/Nil Cases |
|-----|--------|---------------|-------|-----------------|
| `:distinct` | `Distinct` | Boolean / atom field / list of atoms / list of `{direction, field}` | `DISTINCT` clause | Boolean cast; unknown field → warning, filtered out |

**File:** `/Users/kurthogarth/Documents/GitHub/ecto_shorts/lib/ecto_shorts/common_filters/filters/distinct.ex`

### Pagination & Cardinality Filters

These control how many rows you get back and where in the result set you start.

| Key | Module | Accept Shapes | Emits | Warn/Nil Cases |
|-----|--------|---------------|-------|-----------------|
| `:limit` | `Limit` | Integer or string (coerced to integer) | `LIMIT` clause | Coerced via `Types.cast(:integer, expr)` |
| `:first` | `Limit` (reused) | Same as `:limit` | Same as `:limit` | Same as `:limit` |
| `:offset` | `Offset` | Integer or string (coerced to integer) | `OFFSET` clause | Coerced via `Types.cast(:integer, expr)` |
| `:page` | `Page` | Offset-based: `%{index: N, size: M}` or cursor-based: `%{after\|before: cursor, by: field, size: N}` | `LIMIT` + `OFFSET` or cursor-filtered `LIMIT` | Invalid param shape → logged as part of pattern match failure |
| `:last` | `Last` | Integer / `{sort_key, limit}` tuple / keyword/map with pairs | Nested subquery with reverse order | Invalid shape → warning: "Expected :last value to be an integer, a {sort_key, limit} tuple, or a map/keyword list of such pairs, got: ..." |

**Page shapes (file: `page.ex:13-86`), the three ways to ask for a page of results:**
1. By page number: `%{index: 1, size: 10}` → offset = (index - 1) * size, limit = size
2. Forward from a marker (cursor): `%{after: cursor, by: field, size: size}` → keeps rows where `field > cursor`, sorts ascending, limits
3. Backward from a marker (cursor): `%{before: cursor, by: field, size: size}` → keeps rows where `field < cursor`, sorts descending, limits

**Last internals (file: `last.ex:13-50`):**
- Accepts a `{sort_key, limit}` tuple where `sort_key` is `nil` (uses `:id` or the primary key) or an atom
- Builds a subquery (a query nested inside another query): sort by `sort_key` descending, limit, then the outer query sorts by `sort_key` ascending

**Files:**
- `Limit`: `/Users/kurthogarth/Documents/GitHub/ecto_shorts/lib/ecto_shorts/common_filters/filters/limit.ex`
- `Offset`: `/Users/kurthogarth/Documents/GitHub/ecto_shorts/lib/ecto_shorts/common_filters/filters/offset.ex`
- `Page`: `/Users/kurthogarth/Documents/GitHub/ecto_shorts/lib/ecto_shorts/common_filters/filters/page.ex`
- `Last`: `/Users/kurthogarth/Documents/GitHub/ecto_shorts/lib/ecto_shorts/common_filters/filters/last.ex`

### Projection Filters

"Projection" means choosing which fields (columns) come back, instead of the whole row.

| Key | Module | Accept Shapes | Emits | Warn/Nil Cases |
|-----|--------|---------------|-------|-----------------|
| `:select` | `Select` | Atom field / list of atoms / `true` / `{:map, params}` / `{:struct, fields}` / raw dynamic / map / keyword | `SELECT` clause (replaces previous) | Raw dynamic passed through; boolean coercion |
| `:select_merge` | `SelectMerge` | Same as `:select` but additive | `SELECT MERGE` clause | Same as `:select` |

**Select shapes (file: `select.ex:11-73`):**
- `:field_name` → returns a single field (column)
- `[field1, field2, ...]` → if it is a keyword list → merge them one by one; if a plain list → use as a raw select
- `true` → returns the whole table for the current binding
- `%{key1: field1, key2: field2}` → builds a map, with the keys as labels
- `{:map, params}` → forces the result to be a map
- `{:struct, fields}` → forces a struct result with only those fields

**SelectMerge behavior (file: `select_merge.ex:10-92`), which adds to the select instead of replacing it:**
- Adds fields one at a time
- `{field_alias, field_name}` where both are atoms → takes the field from the source under a label
- `{field_alias, dynamic}` → adds a computed value (a condition built in code)

**Files:**
- `Select`: `/Users/kurthogarth/Documents/GitHub/ecto_shorts/lib/ecto_shorts/common_filters/filters/select.ex`
- `SelectMerge`: `/Users/kurthogarth/Documents/GitHub/ecto_shorts/lib/ecto_shorts/common_filters/filters/select_merge.ex`

### Eager Loading

This loads linked records (associations) up front so you do not fetch them one at a time later.

| Key | Module | Accept Shapes | Emits | Warn/Nil Cases |
|-----|--------|---------------|-------|-----------------|
| `:preload` | `Preload` | Atom assoc / list of atoms / `{assoc, nested}` / map / keyword | `PRELOAD` clause | Normalized via `normalize(value)` recursively |

**Preload normalization (file: `preload.ex:64-87`), tidying the input into one standard shape:**
- A map → turn into a list → recurse
- A keyword list → tidy each value
- An atom → wrap it as `[name]`
- Anything else → pass through unchanged

**Files:**
- `Preload`: `/Users/kurthogarth/Documents/GitHub/ecto_shorts/lib/ecto_shorts/common_filters/filters/preload.ex`

### Nested Queries

| Key | Module | Accept Shapes | Emits | Warn/Nil Cases |
|-----|--------|---------------|-------|-----------------|
| `:subquery` | `SubQuery` | Map / keyword of filter params | Subquery wrapping | Invalid shape → warning: "Expected :subquery value to be a keyword list or map of filter params, got: ..." |

This wraps the current query inside another query (a subquery: a query nested inside another query).

**File:** `/Users/kurthogarth/Documents/GitHub/ecto_shorts/lib/ecto_shorts/common_filters/filters/sub_query.ex:12-26`

### Locking

Locking tells the database to hold onto rows so other work cannot change them at the same time.

| Key | Module | Accept Shapes | Emits | Warn/Nil Cases |
|-----|--------|---------------|-------|-----------------|
| `:lock` | `Lock` | Map/keyword with `:name` key (or function) | `LOCK` clause | Missing `:name` → logs a warning and skips, leaving the query unchanged; invalid shape → warning: "Expected :lock value to be a map or keyword list with a :name key, got: ..." |

**Lock names (file: `lock.ex:39-46`):**
- `:for_update` → `"FOR UPDATE"`
- `:for_share` → `"FOR SHARE"`
- A custom atom → looked up through QueryProvider (if one is configured); otherwise a warning is logged

**Files:**
- `Lock`: `/Users/kurthogarth/Documents/GitHub/ecto_shorts/lib/ecto_shorts/common_filters/filters/lock.ex`

### Clause Removal

This removes a part you (or an earlier filter) already added.

| Key | Module | Accept Shapes | Emits | Warn/Nil Cases |
|-----|--------|---------------|-------|-----------------|
| `:exclude` | `Builder.apply_filter(:exclude, ...)` | Atom field / list of atoms | Removes clause from query | N/A (always succeeds) |

**File:** `/Users/kurthoearth/Documents/GitHub/ecto_shorts/lib/ecto_shorts/common_filters/builder.ex:147-153`

### Bulk Updates

This sets new values on many rows at once.

| Key | Module | Accept Shapes | Emits | Warn/Nil Cases |
|-----|--------|---------------|-------|-----------------|
| `:update` | `Update` | Map / keyword of field → value pairs | `UPDATE` set clause | Keyword form → `UpdateExpr.build_update_expr(source, term)` |

**File:** `/Users/kurthogarth/Documents/GitHub/ecto_shorts/lib/ecto_shorts/common_filters/filters/update.ex`

### Query Prefixing

A prefix usually points the query at a particular database schema (namespace).

| Key | Module | Accept Shapes | Emits | Warn/Nil Cases |
|-----|--------|---------------|-------|-----------------|
| `:put_query_prefix` | `PutQueryPrefix` | Any (prefix value) | Query prefix | N/A |

**File:** `/Users/kurthogarth/Documents/GitHub/ecto_shorts/lib/ecto_shorts/common_filters/filters/put_query_prefix.ex`

### Common Table Expressions

A CTE (common table expression) is a named, temporary result you can reuse inside one query.

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
This shows that each CTE has a name and a definition, and that the definition must include `:as` (the query it stands for) plus two optional settings.

**Warning conditions (file: `with_cte.ex`):**
- Line 100-105: Missing `:as` → "Expected :with_cte params for #{inspect(cte_name)} to include an :as key"
- Line 92-97: Invalid `:as` type → "Expected CTE :as query params... to be a query, subquery, or keyword/map payload, got: ..."
- Line 139-144: Invalid `:operation` → "Expected :operation for #{inspect(cte_name)} to be one of [:all, :update_all, :delete_all], got: ..."
- Line 120-125: Invalid `:materialized` → "Expected :materialized for #{inspect(cte_name)} to be a boolean, got: ..."

**Files:**
- `RecursiveCtes`: `/Users/kurthogarth/Documents/GitHub/ecto_shorts/lib/ecto_shorts/common_filters/filters/recursive_ctes.ex`
- `WithCte`: `/Users/kurthogarth/Documents/GitHub/ecto_shorts/lib/ecto_shorts/common_filters/filters/with_cte.ex`

### Windowing

A window lets you run calculations across a group of related rows while still returning each row.

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
This shows a window's name and its settings: which other window it builds on, how to split the rows, how to sort them, and the range it covers.

**WithTies behavior (file: `with_ties.ex:19-92`):**
- Boolean `true` → turns on WITH TIES with a default limit of 1000
- `{:limit, N}` → sets the limit to N, then turns on WITH TIES
- If there is no order or limit yet → adds both before turning on WITH TIES

**Warning conditions:**
- Windows: line 42-46 cyclic reference, line 92-98 invalid frame type, line 32-39 invalid params
- WithTies: line 52-55 unknown keys, line 79-85 invalid limit type

**Files:**
- `Windows`: `/Users/kurthogarth/Documents/GitHub/ecto_shorts/lib/ecto_shorts/common_filters/filters/windows.ex`
- `WithTies`: `/Users/kurthogarth/Documents/GitHub/ecto_shorts/lib/ecto_shorts/common_filters/filters/with_ties.ex`

### Named Bindings

This applies filters and makes sure a named table (named binding) ends up in the query.

| Key | Module | Accept Shapes | Emits | Warn/Nil Cases |
|-----|--------|---------------|-------|-----------------|
| `:with_named_binding` | `WithNamedBinding` | Map / keyword with binding_name → filter_params pairs | Applies filters and ensures named binding is created | Binding not created after filters → warning; invalid key type → warning |

**Warning conditions (file: `with_named_binding.ex`):**
- Line 45-51: Filters did not create the named binding → "Filters provided for :with_named_binding key #{inspect(key)} did not create a named binding"
- Line 55-61: Invalid key (not an atom) → "Expected :with_named_binding key to be an atom, got: #{inspect(key)}"

**File:** `/Users/kurthogarth/Documents/GitHub/ecto_shorts/lib/ecto_shorts/common_filters/filters/with_named_binding.ex`

### Set Operations

These combine the results of two queries (for example, glue them together or keep only the overlap).

| Key | Module | Accept Shapes | Emits | Warn/Nil Cases |
|-----|--------|---------------|-------|-----------------|
| `:union` | `Union` | Ecto.Query or map/keyword of filter params | `UNION` composition | `nil` param → logs nothing and changes nothing (no-op) |
| `:union_all` | `UnionAll` | Same as `:union` | `UNION ALL` composition | `nil` param → no-op |
| `:except` | `Except` | Same as `:union` | `EXCEPT` composition | `nil` param → no-op |
| `:except_all` | `ExceptAll` | Same as `:union` | `EXCEPT ALL` composition | `nil` param → no-op |
| `:intersect` | `Intersect` | Same as `:union` | `INTERSECT` composition | `nil` param → no-op |
| `:intersect_all` | `IntersectAll` | Same as `:union` | `INTERSECT ALL` composition | `nil` param → no-op |

**Behavior (all set operations, file examples: `union.ex:12-25`, `except.ex:12-25`):**
- If the param is already an `Ecto.Query` → use it as is
- Otherwise, if it is a map or keyword list → recurse with `convert_params_to_filter(source, param, opts)`
- Combine that result with the current query using the set operation

**Files:**
- `Union`: `/Users/kurthogarth/Documents/GitHub/ecto_shorts/lib/ecto_shorts/common_filters/filters/union.ex`
- `UnionAll`: `/Users/kurthogarth/Documents/GitHub/ecto_shorts/lib/ecto_shorts/common_filters/filters/union_all.ex`
- `Except`: `/Users/kurthogarth/Documents/GitHub/ecto_shorts/lib/ecto_shorts/common_filters/filters/except.ex`
- `ExceptAll`: `/Users/kurthogarth/Documents/GitHub/ecto_shorts/lib/ecto_shorts/common_filters/filters/except_all.ex`
- `Intersect`: `/Users/kurthogarth/Documents/GitHub/ecto_shorts/lib/ecto_shorts/common_filters/filters/intersect.ex`
- `IntersectAll`: `/Users/kurthogarth/Documents/GitHub/ecto_shorts/lib/ecto_shorts/common_filters/filters/intersect_all.ex`

---

## 8. Builder & Parser Modules

These are the two internal helpers behind everything above.

### `EctoShorts.CommonFilters.Builder`

**Location:** `/Users/kurthogarth/Documents/GitHub/ecto_shorts/lib/ecto_shorts/common_filters/builder.ex`

**Role:** Implements the `EctoShorts.QueryBuilder` behavior; it is the single place that routes every filter key, through `build_query/6`

**Public functions:**
- `build_query(filter, source, query, selected_binding, term, opts)` → applies the filter and returns the updated query

**Implementation:** Matches on the `filter` atom and hands off to that filter's own `build_query/6`.

**Special cases:**
- `:where` and `:or_where` → build the condition with `DynamicBuilders.build_dynamic(...)` and wrap it in `Query.where/3` or `Query.or_where/3`
- `:exclude` → handled right here: wrap the param in a list and remove it via `Query.exclude/2`
- `:first` → just another name for `:limit` (file: line 159-161)

### `EctoShorts.CommonFilters.Parser`

**Location:** `/Users/kurthogarth/Documents/GitHub/ecto_shorts/lib/ecto_shorts/common_filters/parser.ex`

**Role:** A helper for flattening and pulling apart nested maps and keyword lists

**Public functions:**

| Function | Arity | Purpose | Example |
|----------|-------|---------|---------|
| `extract_entries(entries)` | 1 | Pulls `[key, value]` pairs out of a nested map | `Parser.extract_entries(%{"a" => 1, "b" => %{"c" => 2}})` → `[{"a", 1}, {"b", %{"c" => 2}}]` |
| `normalize(entries, predicate, acc)` | 1-3 | Flattens a nested structure, with a condition (a true/false test) controlling how deep to go; `true` → keep going deeper, `false` → stop | `Parser.normalize(%{"a" => 1, "b" => %{"c" => 2}})` → `[{"a", 1}, {"b", {"c", 2}}]` |
| `default_predicate(key, value)` | 2 | A condition that always returns `true` | Used as the default in `normalize` |

**Normalization rules (file: `parser.ex:137-149`), the rules for tidying input into one standard shape:**
- A map that is not a struct → turn into a list, then recurse
- A keyword list → recurse over each entry
- A plain list (not a keyword list) → stop and treat it as a value
- A tuple `{key, value}` where the value is a map or keyword list → open up the value and put the key in front of the results
- Anything else → return it unchanged

---

## 9. All Warning & Logging Conditions

Every place the library logs a warning instead of doing what you asked. "Returned" tells you what happens to the query in each case.

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

All keys the `@filters` list recognizes (line 269-304 of `common_filters.ex`):

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

**Plus, handled separately from the list above:**
- `:as` (binding selector, special dispatch)
- `:at` (binding selector, special dispatch)
- **Any schema association name** (adds an automatic join and recurses)
- **Any schema field name** (treated as a `:where` filter)

---

## 11. Default Dispatch Behavior

What happens to a key that is not in `@filters`, is not an association, and is not a field:
- It is sent to the `:where` filter
- It is treated as "this field equals this value": `{key, value}` → `DynamicBuilders.build_dynamic(source, binding, {key, value}, opts)`
- If that field does not actually exist, a warning may be logged while the value is being prepared

---

## 12. Example Usage Patterns

Each example below shows a call and a one-line note on what it does.

### Basic field filtering
```elixir
CommonFilters.convert_params_to_filter(Post, %{published: true, author_id: 5}, [])
```
Sends `published` and `author_id` to the `:where` condition builder.

### Boolean grouping
```elixir
CommonFilters.convert_params_to_filter(Post, %{and: %{published: true, views: [5, 10]}}, [])
```
Both entries become separate WHERE conditions joined with AND.

### Association shorthand
```elixir
CommonFilters.convert_params_to_filter(Post, %{author: %{name: "Alice"}}, [])
```
Adds an automatic join to the linked `author` table and applies the author filters there.

### Binding selectors
```elixir
CommonFilters.convert_params_to_filter(Post, %{as: %{author: %{select: :first_name}}}, [])
CommonFilters.convert_params_to_filter(Post, %{at: %{1 => %{order_by: :name}}}, [])
```
The first aims filters at the table named `author`; the second aims them at the table in position 1.

### Keyword list with duplicate keys
```elixir
CommonFilters.convert_params_to_filter(Post, [where: %{a: 1}, where: %{b: 2}, order_by: :id], [])
```
Several `:where` entries are applied in order.

### Page-based pagination
```elixir
CommonFilters.convert_params_to_filter(Post, %{page: %{index: 2, size: 10}}, [])
```
By page number: offset = 10, limit = 10.

### Recursive CTE with union
```elixir
CommonFilters.convert_params_to_filter(Post, %{
  recursive_ctes: true,
  with_cte: [root: [as: %{from: Root}, materialized: false]],
  union_all: %{from: Root}
}, [])
```
Defines a reusable named result (a CTE) called `root` and combines it with the query using UNION ALL.
