# Postgres Dynamic-Builder Behavior Inventory

## Overview

This document exhaustively catalogs transformations in the Postgres dynamic-builder layer:
- `lib/ecto_shorts/dynamic_builders/postgres.ex` (primary)
- Four delegation modules: `ScalarExpr`, `ArrayExpr`, `MapExpr`, `CommonExpr`

No normalizer module exists; all transformations occur in the main module and delegation targets.

---

## 1. `build_dynamic/4` Overload Catalog

All overloads accept `(source, selected_binding, args, opts)` and return `Ecto.Query.dynamic_expr()`.

| Input Shape | Transformation | Output Shape | File:Line |
|---|---|---|---|
| `{:all, params}` or `{:any, params}` where params is keyword list | Reduce over params, recursively call `build_dynamic/4` for each entry, merge results with quantifier (`:and` or `:or`) | `dynamic(...)` merged with all/any entries | `postgres.ex:125-134` |
| `{key, params}` where params is plain map (non-struct) | Convert map to list via `Map.to_list/1` | `{key, list_entries}` → re-dispatch to keyword clause | `postgres.ex:136-139` |
| `{key, params}` where params is keyword list | Cast each entry via `cast_value/2`, build dynamic per entry, merge with `:and` | Keyword entries each become `Ecto.Query.dynamic_expr()` merged `:and` | `postgres.ex:141-166` |
| `{key, params}` where params is bare list (non-keyword) | Cast single value, dispatch to `apply_expr/4` with `{key, casted}` | `Ecto.Query.dynamic_expr()` for the scalar comparison | `postgres.ex:141-166` |
| `{key, scalar}` (any non-map, non-list value) | Cast scalar, dispatch to `apply_expr/4` | Equality dynamic via `dispatch_field_expr/5` | `postgres.ex:168-177` |

---

## 2. `apply_expr/4` Transformation Pipeline

**Signature:** `defp apply_expr(source, selected_binding, {key, term}, opts)`

| Input `term` Shape | Transformation | Next Stage | File:Line |
|---|---|---|---|
| Plain map (non-struct) | Convert to keyword list | Recursive call with keyword form | `postgres.ex:179-182` |
| Keyword list | Reduce over entries, recursively call `apply_expr/4` for each inner entry, merge `:and` | Multiple dynamic exprs merged `:and` | `postgres.ex:184-188` |
| Any other term | Pass to `dispatch_expr/6` with `negated=nil` | Dispatch-driven transformation (see section 3) | `postgres.ex:190-192` |

---

## 3. `dispatch_expr/6` Clause Inventory

**Signature:** `defp dispatch_expr(source, selected_binding, key, negated, term, opts)`

Negation extraction happens first; all subsequent clauses work with `:not` or `nil`.

### 3.1 Negation Extraction
```
Input:  {:not, inner_term}
Output: dispatch_expr(..., key, :not, inner_term, ...)
File:   postgres.ex:195-197
```

### 3.2 Bare Map Expansion
```
Input:  plain map (non-struct)
Transformation: Map.to_list/1, map each to dispatch_expr recursively
Output: Reduce merged with :and
File:   postgres.ex:203-211
Example: %{avg: %{>: 10}} → dispatch {:avg, %{>: 10}}
```

### 3.3 Quantified Subqueries (`:all`, `:any`)
Two subcases based on `subquery_spec?/1` (checks for `:from` key):

#### 3.3.1 With subquery (has `:from`)
```
Input:  {quantifier, payload} where quantifier in [:all, :any]
        and payload has :from
Transformation:
  1. build_quantified_query(key, payload, opts) → Ecto subquery
  2. Dispatch to dispatch_field_expr with {==, {quantifier, subquery}}
Output: Quantified expression routed to field handler
File:   postgres.ex:215-227
```

#### 3.3.2 Without subquery (no `:from`)
```
Input:  {quantifier, payload} (non-subquery)
Transformation:
  If payload is single-entry map: extract {op, val}, canonicalize op via op_alias
  Otherwise: keep payload as-is
Output: dispatch_field_expr with {quantifier, canonical_payload}
File:   postgres.ex:229-251
```

### 3.4 Quantified with Outer Operator
```
Input:  {op, {quantifier, payload}} where quantifier in [:all, :any]
Transformation:
  If subquery_spec?: build subquery
  Else: dispatch to field handler with original term
Output: Either quantified subquery expr or field expr
File:   postgres.ex:254-277
```

### 3.5 Short Operator Alias (`:eq`, `:ne`, `:gt`, `:gte`, `:lt`, `:lte`)
```
Input:  {short_op, term} where short_op in [:eq, :ne, :gt, :gte, :lt, :lte]
Canonical Map:
  :eq  → :==
  :ne  → :!=
  :gt  → :>
  :gte → :>=
  :lt  → :<
  :lte → :<=
Transformation: Re-dispatch with canonical operator
Output: dispatch_expr with canonical form
File:   postgres.ex:280-283
```

### 3.6 Common Expression Operators
```
Input:  key in [:ids, :before, :after, :until, :since, :exists, 
               :start_date, :end_date, :since_date, :until_date]
Output: Delegate to CommonExpr.dynamic_expr/5
File:   postgres.ex:287-290
```

### 3.7 Scalar (Non-Tuple, Non-List)
```
Input:  term where not is_tuple(term) and not is_list(term)
Transformation: Rewrite as equality {==, term}
Output: dispatch_field_expr with {==, scalar}
File:   postgres.ex:293-296
```

### 3.8 String Transform Aliasing (`:lower`, `:upper`, `:downcase`, `:upcase`)
```
Input:  {:transform, value} where transform in [:lower, :upper, :downcase, :upcase]
Canonical Map:
  :lower / :downcase → :lower
  :upper / :upcase   → :upper
Transformation: {canonical_op, value}
Output: dispatch_field_expr with {==, {canonical_op, value}}
File:   postgres.ex:298-302
```

### 3.9 Arithmetic (`:arithmetic` operator)
```
Input:  {:arithmetic, params} where params is map or keyword
  Required keys:
    - :compare (comparison operator)
    - One of [:add, :subtract, :multiply, :divide, :ago, :from_now]
    - Operand (map or keyword with :interval, optional :cast)
Transformation:
  Case 1 (interval-based):
    {compare_op, {cast, {arith_key, operand_without_cast}}}
    cast defaults to :datetime
  Case 2 (field arithmetic):
    {compare_op, {:value, {arith_op, {{:field, field}, {:value, value}}}}}
Output: ScalarExpr.dynamic_expr
File:   postgres.ex:304-348
Example: {:arithmetic, [compare: :>, add: [interval: "1 day"]]} 
         → {>, {:datetime, {add, [count, interval]}}}
```

### 3.10 Aggregates (`:aggregate` operator)
```
Input:  {:aggregate, params} where params is map or keyword
  Required keys:
    - :fn (aggregate function)
    - :compare (comparison operator)
    - :value (scalar value)
Transformation:
  {agg_fn, {compare_op, value}} via dispatch_field_expr
Output: ScalarExpr aggregation expr
File:   postgres.ex:350-369
```

### 3.11 Aggregate Shorthand
```
Input:  {agg_fn, params} where agg_fn in [:avg, :sum, :max, :min, :count]
        params is single-entry map or keyword
Transformation:
  Extract [{compare_op, value}]
  Convert to full form: {agg_fn, {compare_op, value}}
Output: dispatch_field_expr aggregation
File:   postgres.ex:377-394
```

### 3.12 Elements (Array Filtering)
```
Input:  {:elements, params} where params is map, keyword, nil, tuple, or scalar
Case 1 (map): Reduce over entries, dispatch ArrayExpr per op
Case 2 (keyword): Reduce over entries, dispatch ArrayExpr per op
Case 3 (nil): {:==, nil} to ArrayExpr
Case 4 (tuple): Pass through as-is to ArrayExpr
Case 5 (scalar): Convert to {:in, scalar}
Output: ArrayExpr.dynamic_expr (merged :and if multiple entries)
File:   postgres.ex:396-443
Example: {:elements, [>: 5, <: 10]} → two ArrayExpr calls merged :and
```

### 3.13 RHS Map Expansion
```
Input:  {op, rhs_params} where rhs_params is plain map (non-struct)
Transformation:
  1. build_rhs_entry/4 for each {rhs_key, rhs_val}
  2. If result is quantifier tuple: re-dispatch for quantifier clause
  3. Else: dispatch_field_expr
Output: Field expr (quantified or scalar)
File:   postgres.ex:449-463
Example: {:>, %{value: 5}} → build_rhs_entry → dispatch_field_expr
```

### 3.14 Fallback to Field Dispatch
```
Input:  Any term not matching above patterns
Output: dispatch_field_expr(source, selected_binding, key, negated, term, opts)
File:   postgres.ex:465-467
```

---

## 4. `dispatch_field_expr/5` — Schema-Aware Routing

**Signature:** `defp dispatch_field_expr(source, selected_binding, key, negated, term, opts)`

Routes to one of three expression modules based on field type inference:

| Condition | Target Module | Term Canonical | File:Line |
|---|---|---|---|
| Invalid schema field (not in `:fields` reflection) | — | Log warning, return `nil` | `postgres.ex:470-477` |
| Map field (`:map` or `{:map, _}` type) | `MapExpr.dynamic_expr/5` | For keywords: expand each kv pair as separate `@>` | `postgres.ex:479-496` |
| Array field (`{:array, _}` type) | `ArrayExpr.dynamic_expr/5` | Canonicalize non-tuple/list → `{==, term}` | `postgres.ex:498-507` |
| Scalar field (default) | `ScalarExpr.dynamic_expr/5` | Canonicalize non-tuple → `{==, term}` | `postgres.ex:509-518` |

Map field keyword-list expansion (lines 483-489):
```
{op, [role: "admin", active: true]}
→ Two separate calls:
   MapExpr.dynamic_expr(..., {op, {role, "admin"}}, ...)
   MapExpr.dynamic_expr(..., {op, {active, true}}, ...)
→ Merged :and
```

---

## 5. `cast_value/2` — 18 Overloads

**Signature:** `defp cast_value(field_type, entry)`

| Input Signature | Transformation | Output | File:Line |
|---|---|---|---|
| `(nil, entry)` | No-op passthrough | `entry` unchanged | `postgres.ex:592` |
| `(field_type, {short_op, entry})` where short_op in short-ops | Normalize operator via `op_alias/1` | `{canonical_op, entry}` | `postgres.ex:594-596` |
| `(field_type, {:and, entry})` | Recursively cast inner entry | `{:and, cast_value(field_type, entry)}` | `postgres.ex:598` |
| `(field_type, {:or, entry})` | Recursively cast inner entry | `{:or, cast_value(field_type, entry)}` | `postgres.ex:599` |
| `({:array, _}, {:==, list})` when is_list | Cast list elements via `Types.cast/2` | `{:==, Types.cast({:array, _}, list)}` | `postgres.ex:601-603` |
| `({:array, _}, {:!=, list})` when is_list | Cast list elements | `{:!=, Types.cast({:array, _}, list)}` | `postgres.ex:605-607` |
| `({:array, inner}, {:in, list})` when is_list | Cast each element via inner type | `{:in, [Types.cast(inner, el) ...]}` | `postgres.ex:609-611` |
| `({:array, _}, {:count, {op, value}})` when op in comparisons | Cast value to integer | `{:count, {op, Types.cast(:integer, value)}}` | `postgres.ex:613-616` |
| `({:array, inner}, {:all, {op, value}})` when op in comparisons | Cast value via inner type | `{:all, {op, Types.cast(inner, value)}}` | `postgres.ex:618-621` |
| `({:array, inner}, {op, value})` when op in std comparison/transform ops | Cast value via inner type | `{op, Types.cast(inner, value)}` | `postgres.ex:623-626` |
| `(field_type, {op, list})` when op in [:==, :!=, :in] and is_list | Cast list elements | `{op, [Types.cast(field_type, el) ...]}` | `postgres.ex:628-631` |
| `(field_type, {op, {:value, value}})` when op in comparisons | Cast value within wrapper | `{op, {:value, Types.cast(field_type, value)}}` | `postgres.ex:633-636` |
| `(field_type, {op, value})` when op in comparisons | Cast scalar value | `{op, Types.cast(field_type, value)}` | `postgres.ex:638-641` |
| `({:array, _}, value)` when is_list | Cast entire list | `Types.cast({:array, _}, value)` | `postgres.ex:643-645` |
| `(field_type, value)` when is_list | Cast each element | `[Types.cast(field_type, el) ...]` | `postgres.ex:647-649` |
| `(field_type, value)` when not is_tuple | Cast scalar | `Types.cast(field_type, value)` | `postgres.ex:651-653` |
| `(field_type, entry)` catch-all (tuples, etc.) | Passthrough | `entry` unchanged | `postgres.ex:655` |

**Key Insight:** Casting unwraps and transforms operator shapes while respecting container types.

---

## 6. `build_rhs_entry/4` — RHS Parameter Assembly

**Signature:** `defp build_rhs_entry(source, rhs_key, rhs_val, opts)`

| `rhs_key` | Input `rhs_val` | Output Shape | File:Line |
|---|---|---|---|
| `:field` | String or atom field name | `{:field, resolved_atom}` via `field_name_to_atom/3` | `postgres.ex:660-662` |
| `:value` | Scalar or map | `{:value, build_rhs_expr(source, inner, opts)}` | `postgres.ex:664-666` |
| Arithmetic op (`:+`, `:-`, `:*`, `:/`) | `[left, right]` list | `{arith_op, {build_rhs_expr(..., left), build_rhs_expr(..., right)}}` | `postgres.ex:668-670` |
| `:parent_as` | Plain map `{binding_atom => field_atom}` | `{:parent_as, {binding, field}}` | `postgres.ex:672-676` |
| `:date` | Term (map, keyword, scalar) | `{:date, {dt_op, dt_term}}` via `resolve_datetime_wrapper/3` | `postgres.ex:678-681` |
| `:datetime` | Term (map, keyword, scalar) | `{:datetime, {dt_op, dt_term}}` via `resolve_datetime_wrapper/3` | `postgres.ex:683-686` |
| Other | Any value | Passthrough tuple | `postgres.ex:688` |

---

## 7. `field_name_to_atom/3` — String→Atom Resolution

**Signature:** `defp field_name_to_atom(source, field_name, opts)`

| Input `field_name` | Condition | Transformation | Output | File:Line |
|---|---|---|---|---|
| Atom | Always | Passthrough | `field_name` | `postgres.ex:752` |
| String | Schema present & field in schema fields | `String.to_existing_atom/1` | Atom | `postgres.ex:754-769` |
| String | Schema present & field NOT in schema | — | Warn, return `nil` | `postgres.ex:763-768` |
| String | No schema, `:allowed_keys` in opts | Field in allowed_set | `String.to_atom/1` | `postgres.ex:774-779` |
| String | No schema, `:allowed_keys` in opts | Field NOT in allowed_set | Warn, return `nil` | `postgres.ex:780-786` |
| String | No schema, no `:allowed_keys` | — | Warn, return `nil` | `postgres.ex:788-794` |

**Three Warning+Nil Branches:**
1. **Line 763-768:** `"Field \"#{field_name}\" does not exist on schema #{inspect(schema)}, skipping field reference"`
2. **Line 780-786:** `"Field \"#{field_name}\" is not in the :allowed_keys list, skipping field reference"`
3. **Line 788-794:** `"Field \"#{field_name}\" cannot be resolved: no schema or :allowed_keys available, skipping field reference"`

---

## 8. Datetime Wrapper Resolution

### 8.1 `resolve_datetime_wrapper/3`
```
defp resolve_datetime_wrapper(source, term, opts)

Input:  Map (converted to keyword) or keyword list
        Must be single-entry: {datetime_op, datetime_term}
        where datetime_op in [:add, :ago, :from_now]

Output: {datetime_op, datetime_node}
        where datetime_node = resolve_datetime_node(source, datetime_term, opts)

File:   postgres.ex:699-717
Error:  Raises ArgumentError if not single-entry keyword
```

### 8.2 `resolve_datetime_node/3`
```
defp resolve_datetime_node(source, term, opts)

Input:  Keyword list with required keys:
          - :count (integer)
          - :interval (string like "1 day")
        Optional key:
          - :field (string/atom field name)

Output: Keyword list [count: count, interval: interval, (optional) field: resolved_atom]

File:   postgres.ex:719-734
Error:  Raises ArgumentError if not keyword list
```

**Example Flow:**
```
Input:  {:ago, %{count: 3, interval: "days"}}
Step 1: resolve_datetime_wrapper → {:ago, resolve_datetime_node(...)}
Step 2: resolve_datetime_node([count: 3, interval: "days"])
        → [count: 3, interval: "days"]
Output: {:ago, [count: 3, interval: "days"]}
```

---

## 9. Operator Alias Table

| Short Form | Canonical | Category | File:Line |
|---|---|---|---|
| `:eq` | `:==` | Comparison | `postgres.ex:745` |
| `:ne` | `:!=` | Comparison | `postgres.ex:746` |
| `:gt` | `:>` | Comparison | `postgres.ex:747` |
| `:gte` | `:>=` | Comparison | `postgres.ex:748` |
| `:lt` | `:<` | Comparison | `postgres.ex:749` |
| `:lte` | `:<=` | Comparison | `postgres.ex:750` |
| `:lower`, `:downcase` | `:lower` | String transform | `postgres.ex:299-300` |
| `:upcase`, `:upper` | `:upper` | String transform | `postgres.ex:300` |

---

## 10. Canonical Operator Set

**Comparison Operators (6):** `:==`, `:!=`, `:>`, `:>=`, `:<`, `:<=`

**Short Ops (6):** `:eq`, `:ne`, `:gt`, `:gte`, `:lt`, `:lte` → canonicalize via `op_alias/1`

**Quantifier Operators (2):** `:all`, `:any`

**Common Expression Operators (10):** `:ids`, `:before`, `:after`, `:until`, `:since`, `:exists`, `:start_date`, `:end_date`, `:since_date`, `:until_date`

**String Operators (2):** `:like`, `:ilike`

**Array Operations (1):** `:elements`

**Aggregate Functions (5):** `:avg`, `:sum`, `:max`, `:min`, `:count`

**Special Operators:** `:arithmetic`, `:aggregate`, `:not` (negation marker)

**Map Field Operators:** `:contains`, `:contained_by`, `:has_key`, `:has_any_key`, `:has_all_keys`

---

## 11. Transformation Summary Table

| Phase | Input | Output | Module | File:Line |
|---|---|---|---|---|
| **Phase 1: Entry Normalization** | `{key, params}` | `{key, casted_value}` or list of entries | `postgres.ex` | `build_dynamic:141-177` |
| **Phase 2: Map/Keyword Flattening** | Plain map or keyword | Keyword list | `apply_expr` | `postgres.ex:179-193` |
| **Phase 3: Negation Extraction** | `{:not, term}` | `dispatch_expr(..., :not, term)` | `dispatch_expr` | `postgres.ex:195-197` |
| **Phase 4: Operator Canonicalization** | Short op or transform | Canonical form | `dispatch_expr` | `postgres.ex:280-302` |
| **Phase 5: Semantic Dispatch** | Canonical term | Subquery, aggregate, datetime, arithmetic, or field expr | `dispatch_expr` | `postgres.ex:215-467` |
| **Phase 6: Field-Type Routing** | `{op, value}` tuple | `ScalarExpr` / `ArrayExpr` / `MapExpr` / `CommonExpr` dynamic | `dispatch_field_expr` | `postgres.ex:469-519` |
| **Phase 7: RHS Assembly** | RHS map entries | `{:field, atom}`, `{:value, expr}`, etc. | `build_rhs_entry` | `postgres.ex:660-688` |

---

## 12. Build Quantified Query

**Function:** `build_quantified_query/3`

**Inputs:**
- `outer_key`: Atom or string field name
- `params`: Map or keyword with:
  - `:from` (optional, source for subquery)
  - `:select` (optional, field to select)
  - Remaining: filter params for `where` clause
- `opts`: Pass-through options

**Transformation Pipeline:**
```
1. Extract `:from` → source (default: [])
2. Extract `:select` → select_spec
3. Remaining entries → where_params
4. Resolve select field via field_name_to_atom or use outer_key
5. Build inner query via CommonFilters.convert_params_to_filter
6. Wrap with Select.build_query(:select, ...)
```

**File:** `postgres.ex:521-558`

---

## 13. Integration with Delegation Modules

### ScalarExpr (`scalar_expr.ex`)
- **Entry:** `dynamic_expr(selected_binding, key, negated, term, opts)` (line 24)
- **Canonical Input:** `{op, value}` tuples
- **Handles:** Comparisons, aggregates, quantified subqueries, datetime, arithmetic
- **Output:** Ecto.Query.dynamic expression

### ArrayExpr (`array_expr.ex`)
- **Entry:** `dynamic_expr(selected_binding, key, negated, term, opts)` (line 15)
- **Canonical Input:** `{op, value}` tuples for array operations
- **Handles:** Element membership, array length, ANY/ALL quantifiers, case-insensitive matching
- **Output:** Fragment-based array dynamic expressions

### MapExpr (`map_expr.ex`)
- **Entry:** `dynamic_expr(selected_binding, key, negated, term, opts)` (line 14)
- **Canonical Input:** `{op, value}` tuples for JSONB operations
- **Handles:** Containment (`@>`), contained-by (`<@`), key existence
- **Output:** Fragment-based JSONB dynamic expressions

### CommonExpr (`common_expr.ex`)
- **Entry:** `dynamic_expr(selected_binding, key, negated, term, opts)` (line 28)
- **Canonical Input:** Operator key (`:ids`, `:before`, etc.)
- **Handles:** ID-based filtering, temporal boundaries, existence checks
- **Output:** Pre-built dynamic expressions

---

## 14. Field Type Inference

**Sources (in priority order):**
1. `opts[:field_types]` — explicit caller-provided type map
2. `CommonSchema.get_schema_reflection(source, :type, key)` — schema reflection

**Detection Functions:**
```elixir
# Array detection
array_field?(source, key, opts) → check if type is {:array, _}

# Map detection  
map_field?(source, key, opts) → check if type is :map or {:map, _}

# Invalid field detection
invalid_schema_field?(source, key) → check if key not in :fields list
```

**File:** `postgres.ex:570-590`

---

## 15. Negation Application Pattern

All delegation modules follow the same pattern:

```elixir
# In dispatch_expr (non-generated)
term = if negated === :not, do: {:not, {op, value}}, else: {op, value}

case term do
  {:not, {:==, v}} → dynamic([], ^f != ^v)
  {:==, v} → dynamic([], ^f == ^v)
  # ... more cases
end

# In delegate modules, final application
defp maybe_negate(nil, _negated), do: nil
defp maybe_negate(expr, :not), do: dynamic([], not (^expr))
defp maybe_negate(expr, _negated), do: expr
```

**File:** `postgres.ex:798-801` (main merge_dynamic), delegates implement in their respective files.

