# Postgres Dynamic-Builder Behavior Inventory

## Overview

This document lists every transformation in the Postgres dynamic-builder layer. The dynamic-builder is the part of the code that turns a tidied-up filter (a request you wrote as a map or keyword list) into actual query conditions — that is, into a query condition built up in code, which Ecto (the Elixir library for talking to a database) calls a "dynamic". This is the most jargon-heavy document, so each stage is explained step by step.

The code lives in:
- `lib/ecto_shorts/dynamic_builders/postgres.ex` (the main file)
- Four helper modules it hands work off to: `ScalarExpr`, `ArrayExpr`, `MapExpr`, `CommonExpr`

There is no separate "normalizer" module here. All the tidying-up happens in the main file and in the four helper modules.

### Words used in this document

- **Ecto** — the Elixir library for talking to a database.
- **query** — a database request (a query).
- **schema** — a schema: an Elixir description of a database table and its columns.
- **field** — a field (a column of a table).
- **dynamic** — a query condition built up in code (Ecto calls this a "dynamic").
- **operator** — a comparison word such as "equals" or "greater than".
- **operator alias** — a nickname for an operator (for example, `:eq` is a nickname for "equals").
- **canonical / canonicalize** — the standard tidied-up form / to put a value into that standard form.
- **term** — the filter piece, the value being matched.
- **normalization** — tidying the input into one standard shape.
- **cast / casting** — convert a value to the type the column expects (for example, the text `"5"` to the number `5`).
- **reduce / fold** — go through the items one by one, building up the result.
- **dispatch / route** — decide which helper handles this and send it there.
- **negation** — the "not" case, flipping a condition to its opposite.
- **quantifier (all/any)** — compare against every value (all) or against at least one value (any) in a set.
- **aggregate** — a function that summarizes many rows into one number, like average or count.
- **arithmetic** — math on a column, like adding or multiplying.
- **RHS** — the right-hand side of a comparison (the value or expression being compared against).
- **subquery** — a query nested inside another query.

---

## 1. `build_dynamic/4` Overload Catalog

An "overload" is one of several versions of the same function, each one matching a different shape of input. All versions take `(source, selected_binding, args, opts)` and return a query condition built up in code (`Ecto.Query.dynamic_expr()`). The table below shows, for each input shape, what the function does and what comes out.

| Input Shape | Transformation | Output Shape | File:Line |
|---|---|---|---|
| `{:all, params}` or `{:any, params}` where params is keyword list — that is, "match all" or "match any" of a set of conditions | Go through params one by one, call `build_dynamic/4` again for each entry, and join the results with the quantifier (`:and` for all, `:or` for any) | `dynamic(...)` joining all the all/any entries | `postgres.ex:125-134` |
| `{key, params}` where params is a plain map (not a struct) | Turn the map into a list using `Map.to_list/1` | `{key, list_entries}` → sent back to the keyword-list version below | `postgres.ex:136-139` |
| `{key, params}` where params is a keyword list | Convert each entry to the right type using `cast_value/2`, build a query condition for each entry, and join them with `:and` | Each keyword entry becomes a query condition (`Ecto.Query.dynamic_expr()`), all joined with `:and` | `postgres.ex:141-166` |
| `{key, params}` where params is a plain list (not a keyword list) | Convert the single value to the right type, then hand `{key, casted}` to `apply_expr/4` | A query condition for the simple comparison | `postgres.ex:141-166` |
| `{key, scalar}` (any single value that is not a map or a list) | Convert the value to the right type, then hand it to `apply_expr/4` | An "equals" query condition built by `dispatch_field_expr/5` | `postgres.ex:168-177` |

---

## 2. `apply_expr/4` Transformation Pipeline

**Signature:** `defp apply_expr(source, selected_binding, {key, term}, opts)`

This step takes one filter piece (the `term`) and decides how to handle it based on its shape.

| Input `term` Shape | Transformation | Next Stage | File:Line |
|---|---|---|---|
| A plain map (not a struct) | Turn it into a keyword list | Call this function again with the keyword-list form | `postgres.ex:179-182` |
| A keyword list | Go through the entries one by one, call `apply_expr/4` again for each inner entry, and join the results with `:and` | Several query conditions joined with `:and` | `postgres.ex:184-188` |
| Anything else | Pass it to `dispatch_expr/6` with `negated=nil` (no "not" yet) | The dispatch-driven transformation (see section 3) | `postgres.ex:190-192` |

---

## 3. `dispatch_expr/6` Clause Inventory

**Signature:** `defp dispatch_expr(source, selected_binding, key, negated, term, opts)`

This is the heart of the routing. It looks at the term and decides which helper handles it and sends it there. The "not" case is pulled out first, so every later clause works with either `:not` or `nil` already set.

### 3.1 Negation Extraction

This pulls out the "not" wrapper so the rest of the code knows the condition should be flipped to its opposite.
```
Input:  {:not, inner_term}
Output: dispatch_expr(..., key, :not, inner_term, ...)
File:   postgres.ex:195-197
```

### 3.2 Bare Map Expansion

If the term is a plain map, turn it into a list of pairs and route each pair on its own.
```
Input:  plain map (non-struct)
Transformation: Map.to_list/1, then route each pair through dispatch_expr again
Output: Go through the pairs one by one, joining results with :and
File:   postgres.ex:203-211
Example: %{avg: %{>: 10}} → dispatch {:avg, %{>: 10}}
         (a request for "average greater than 10" is split out)
```

### 3.3 Quantified Subqueries (`:all`, `:any`)

This handles "match all" / "match at least one" requests. There are two cases, decided by `subquery_spec?/1`, which checks whether the payload has a `:from` key (the marker of a subquery: a query nested inside another query).

#### 3.3.1 With subquery (has `:from`)
```
Input:  {quantifier, payload} where quantifier in [:all, :any]
        and payload has :from
Transformation:
  1. build_quantified_query(key, payload, opts) → builds the nested Ecto query
  2. Hand to dispatch_field_expr with {==, {quantifier, subquery}}
Output: A quantified condition sent to the field handler
File:   postgres.ex:215-227
```
(Plain reading: "compare this field against all/any rows that the nested query returns.")

#### 3.3.2 Without subquery (no `:from`)
```
Input:  {quantifier, payload} (not a subquery)
Transformation:
  If payload is a single-pair map: pull out {op, val}, tidy the operator to its
    standard form via op_alias
  Otherwise: keep payload as-is
Output: dispatch_field_expr with {quantifier, canonical_payload}
File:   postgres.ex:229-251
```
(Plain reading: "compare this field against every value / at least one value in a given set.")

### 3.4 Quantified with Outer Operator
```
Input:  {op, {quantifier, payload}} where quantifier in [:all, :any]
Transformation:
  If it is a subquery (subquery_spec?): build the nested query
  Otherwise: hand to the field handler with the original term
Output: Either a quantified subquery condition or a plain field condition
File:   postgres.ex:254-277
```

### 3.5 Short Operator Alias (`:eq`, `:ne`, `:gt`, `:gte`, `:lt`, `:lte`)

These are nicknames for operators. This step swaps each nickname for its standard form.
```
Input:  {short_op, term} where short_op in [:eq, :ne, :gt, :gte, :lt, :lte]
Standard form for each nickname:
  :eq  → :==
  :ne  → :!=
  :gt  → :>
  :gte → :>=
  :lt  → :<
  :lte → :<=
Transformation: Re-route using the standard operator
Output: dispatch_expr with the standard form
File:   postgres.ex:280-283
```

### 3.6 Common Expression Operators

A fixed set of special keys is handed straight to the `CommonExpr` helper.
```
Input:  key in [:ids, :before, :after, :until, :since, :exists, 
               :start_date, :end_date, :since_date, :until_date]
Output: Hand off to CommonExpr.dynamic_expr/5
File:   postgres.ex:287-290
```

### 3.7 Scalar (Non-Tuple, Non-List)

If the term is just a plain value, treat it as an "equals" check.
```
Input:  term where not is_tuple(term) and not is_list(term)
Transformation: Rewrite as an equals check {==, term}
Output: dispatch_field_expr with {==, scalar}
File:   postgres.ex:293-296
```

### 3.8 String Transform Aliasing (`:lower`, `:upper`, `:downcase`, `:upcase`)

These ask the database to lowercase or uppercase the text before comparing. `:downcase` and `:upcase` are nicknames; this step swaps them for the standard names.
```
Input:  {:transform, value} where transform in [:lower, :upper, :downcase, :upcase]
Standard name for each:
  :lower / :downcase → :lower
  :upper / :upcase   → :upper
Transformation: {canonical_op, value}
Output: dispatch_field_expr with {==, {canonical_op, value}}
File:   postgres.ex:298-302
```

### 3.9 Arithmetic (`:arithmetic` operator)

This does math on a column (like adding or multiplying, or shifting a date) before comparing.
```
Input:  {:arithmetic, params} where params is a map or keyword list
  Required keys:
    - :compare (the comparison operator)
    - One of [:add, :subtract, :multiply, :divide, :ago, :from_now]
    - An operand (a map or keyword list with :interval, and optional :cast — a
      request to convert to a type)
Transformation:
  Case 1 (interval-based — shifting a date/time):
    {compare_op, {cast, {arith_key, operand_without_cast}}}
    cast defaults to :datetime
  Case 2 (field arithmetic — math on a column):
    {compare_op, {:value, {arith_op, {{:field, field}, {:value, value}}}}}
Output: ScalarExpr.dynamic_expr
File:   postgres.ex:304-348
Example: {:arithmetic, [compare: :>, add: [interval: "1 day"]]} 
         → {>, {:datetime, {add, [count, interval]}}}
         (plain reading: "is this date/time greater than now plus one day?")
```

### 3.10 Aggregates (`:aggregate` operator)

An aggregate is a function that summarizes many rows into one number, like average or count. This compares a field's summary value.
```
Input:  {:aggregate, params} where params is a map or keyword list
  Required keys:
    - :fn (the aggregate function)
    - :compare (the comparison operator)
    - :value (the value to compare against)
Transformation:
  {agg_fn, {compare_op, value}} via dispatch_field_expr
Output: A ScalarExpr aggregate condition
File:   postgres.ex:350-369
```

### 3.11 Aggregate Shorthand

A shorter way to write the same aggregate comparison, using the function name directly as the key.
```
Input:  {agg_fn, params} where agg_fn in [:avg, :sum, :max, :min, :count]
        and params is a single-pair map or keyword list
Transformation:
  Pull out [{compare_op, value}]
  Rewrite in the full form: {agg_fn, {compare_op, value}}
Output: A dispatch_field_expr aggregate condition
File:   postgres.ex:377-394
```

### 3.12 Elements (Array Filtering)

`:elements` forces the value to be treated as an array (a list of values stored in one column) and sends it to the `ArrayExpr` helper.
```
Input:  {:elements, params} where params is a map, keyword list, nil, tuple, or plain value
Case 1 (map): go through the pairs one by one, route each operator to ArrayExpr
Case 2 (keyword list): go through the pairs one by one, route each operator to ArrayExpr
Case 3 (nil): send {:==, nil} to ArrayExpr
Case 4 (tuple): pass it straight through to ArrayExpr
Case 5 (plain value): rewrite as {:in, scalar}
Output: ArrayExpr.dynamic_expr (joined with :and if there is more than one pair)
File:   postgres.ex:396-443
Example: {:elements, [>: 5, <: 10]} → two ArrayExpr calls joined with :and
         (plain reading: "array elements greater than 5 and less than 10")
```

### 3.13 RHS Map Expansion

The RHS is the right-hand side of a comparison (the value or expression being compared against). When that side is itself a map, this step builds it up piece by piece.
```
Input:  {op, rhs_params} where rhs_params is a plain map (not a struct)
Transformation:
  1. build_rhs_entry/4 for each {rhs_key, rhs_val} pair
  2. If the result is a quantifier tuple: re-route to the quantifier clause
  3. Otherwise: dispatch_field_expr
Output: A field condition (quantified or plain)
File:   postgres.ex:449-463
Example: {:>, %{value: 5}} → build_rhs_entry → dispatch_field_expr
         (plain reading: "greater than the value 5")
```

### 3.14 Fallback to Field Dispatch

If none of the patterns above matched, send the term to the field handler as-is.
```
Input:  Any term not matching the patterns above
Output: dispatch_field_expr(source, selected_binding, key, negated, term, opts)
File:   postgres.ex:465-467
```

---

## 4. `dispatch_field_expr/5` — Schema-Aware Routing

**Signature:** `defp dispatch_field_expr(source, selected_binding, key, negated, term, opts)`

This step looks at the column's type (worked out from the schema: the Elixir description of the table and its columns) and routes the term to one of three helper modules. "Term Canonical" means the standard tidied-up shape the term is put into before being handed off.

| Condition | Target Module | Term Canonical | File:Line |
|---|---|---|---|
| The field does not exist on the schema (not in the `:fields` list) | — | Log a warning, return `nil` (skip it) | `postgres.ex:470-477` |
| The field holds a map (`:map` or `{:map, _}` type) | `MapExpr.dynamic_expr/5` | For keyword lists: expand each key/value pair as a separate `@>` (JSONB "contains") check | `postgres.ex:479-496` |
| The field holds an array (`{:array, _}` type) | `ArrayExpr.dynamic_expr/5` | Anything that is not a tuple or list becomes `{==, term}` | `postgres.ex:498-507` |
| Any other field (the default — a plain value) | `ScalarExpr.dynamic_expr/5` | Anything that is not a tuple becomes `{==, term}` | `postgres.ex:509-518` |

How a map field expands a keyword list (lines 483-489):
```
{op, [role: "admin", active: true]}
→ Two separate calls:
   MapExpr.dynamic_expr(..., {op, {role, "admin"}}, ...)
   MapExpr.dynamic_expr(..., {op, {active, true}}, ...)
→ Joined with :and
(plain reading: "the JSON column contains role=admin AND active=true")
```

---

## 5. `cast_value/2` — 18 Overloads

**Signature:** `defp cast_value(field_type, entry)`

This function converts a value to the type the column expects (for example, the text `"5"` to the number `5`). It has 18 versions, one per input shape. `Types.cast/2` is the helper that actually does the type conversion.

| Input Signature | Transformation | Output | File:Line |
|---|---|---|---|
| `(nil, entry)` | Do nothing, pass through | `entry` unchanged | `postgres.ex:592` |
| `(field_type, {short_op, entry})` where short_op is a nickname | Swap the nickname for the standard operator via `op_alias/1` | `{canonical_op, entry}` | `postgres.ex:594-596` |
| `(field_type, {:and, entry})` | Convert the inner entry, then re-wrap | `{:and, cast_value(field_type, entry)}` | `postgres.ex:598` |
| `(field_type, {:or, entry})` | Convert the inner entry, then re-wrap | `{:or, cast_value(field_type, entry)}` | `postgres.ex:599` |
| `({:array, _}, {:==, list})` when it is a list | Convert the list elements via `Types.cast/2` | `{:==, Types.cast({:array, _}, list)}` | `postgres.ex:601-603` |
| `({:array, _}, {:!=, list})` when it is a list | Convert the list elements | `{:!=, Types.cast({:array, _}, list)}` | `postgres.ex:605-607` |
| `({:array, inner}, {:in, list})` when it is a list | Convert each element using the inner (element) type | `{:in, [Types.cast(inner, el) ...]}` | `postgres.ex:609-611` |
| `({:array, _}, {:count, {op, value}})` when op is a comparison | Convert the value to an integer | `{:count, {op, Types.cast(:integer, value)}}` | `postgres.ex:613-616` |
| `({:array, inner}, {:all, {op, value}})` when op is a comparison | Convert the value using the inner type | `{:all, {op, Types.cast(inner, value)}}` | `postgres.ex:618-621` |
| `({:array, inner}, {op, value})` when op is a standard comparison or transform | Convert the value using the inner type | `{op, Types.cast(inner, value)}` | `postgres.ex:623-626` |
| `(field_type, {op, list})` when op in [:==, :!=, :in] and it is a list | Convert the list elements | `{op, [Types.cast(field_type, el) ...]}` | `postgres.ex:628-631` |
| `(field_type, {op, {:value, value}})` when op is a comparison | Convert the value inside the `:value` wrapper | `{op, {:value, Types.cast(field_type, value)}}` | `postgres.ex:633-636` |
| `(field_type, {op, value})` when op is a comparison | Convert the plain value | `{op, Types.cast(field_type, value)}` | `postgres.ex:638-641` |
| `({:array, _}, value)` when it is a list | Convert the whole list | `Types.cast({:array, _}, value)` | `postgres.ex:643-645` |
| `(field_type, value)` when it is a list | Convert each element | `[Types.cast(field_type, el) ...]` | `postgres.ex:647-649` |
| `(field_type, value)` when it is not a tuple | Convert the plain value | `Types.cast(field_type, value)` | `postgres.ex:651-653` |
| `(field_type, entry)` catch-all (tuples, and so on) | Pass through | `entry` unchanged | `postgres.ex:655` |

**Key insight:** Converting the type also unwraps and reshapes operator shapes, while still respecting the container type (list vs. plain value).

---

## 6. `build_rhs_entry/4` — RHS Parameter Assembly

**Signature:** `defp build_rhs_entry(source, rhs_key, rhs_val, opts)`

This builds up the right-hand side of a comparison (the value or expression being compared against), one key at a time.

| `rhs_key` | Input `rhs_val` | Output Shape | File:Line |
|---|---|---|---|
| `:field` | A field name as text or atom | `{:field, resolved_atom}` via `field_name_to_atom/3` | `postgres.ex:660-662` |
| `:value` | A plain value or a map | `{:value, build_rhs_expr(source, inner, opts)}` | `postgres.ex:664-666` |
| A math operator (`:+`, `:-`, `:*`, `:/`) | A `[left, right]` list | `{arith_op, {build_rhs_expr(..., left), build_rhs_expr(..., right)}}` | `postgres.ex:668-670` |
| `:parent_as` | A plain map `{binding_atom => field_atom}` | `{:parent_as, {binding, field}}` | `postgres.ex:672-676` |
| `:date` | A term (map, keyword list, or plain value) | `{:date, {dt_op, dt_term}}` via `resolve_datetime_wrapper/3` | `postgres.ex:678-681` |
| `:datetime` | A term (map, keyword list, or plain value) | `{:datetime, {dt_op, dt_term}}` via `resolve_datetime_wrapper/3` | `postgres.ex:683-686` |
| Anything else | Any value | Pass the tuple through unchanged | `postgres.ex:688` |

---

## 7. `field_name_to_atom/3` — String→Atom Resolution

**Signature:** `defp field_name_to_atom(source, field_name, opts)`

This turns a field name given as text into an Elixir atom (the form the code needs), but only if the name is a real, allowed field. If it is not, it warns and skips it (returns `nil`).

| Input `field_name` | Condition | Transformation | Output | File:Line |
|---|---|---|---|---|
| Atom | Always | Pass through | `field_name` | `postgres.ex:752` |
| Text | A schema is present and the field is in the schema's fields | `String.to_existing_atom/1` | Atom | `postgres.ex:754-769` |
| Text | A schema is present but the field is NOT in it | — | Warn, return `nil` | `postgres.ex:763-768` |
| Text | No schema, but `:allowed_keys` is in opts, and the field is in the allowed set | `String.to_atom/1` | Atom | `postgres.ex:774-779` |
| Text | No schema, `:allowed_keys` is in opts, but the field is NOT in the allowed set | — | Warn, return `nil` | `postgres.ex:780-786` |
| Text | No schema and no `:allowed_keys` | — | Warn, return `nil` | `postgres.ex:788-794` |

**The three "warn and return nil" branches:**
1. **Line 763-768:** `"Field \"#{field_name}\" does not exist on schema #{inspect(schema)}, skipping field reference"`
2. **Line 780-786:** `"Field \"#{field_name}\" is not in the :allowed_keys list, skipping field reference"`
3. **Line 788-794:** `"Field \"#{field_name}\" cannot be resolved: no schema or :allowed_keys available, skipping field reference"`

---

## 8. Datetime Wrapper Resolution

### 8.1 `resolve_datetime_wrapper/3`
```
defp resolve_datetime_wrapper(source, term, opts)

Input:  A map (turned into a keyword list) or a keyword list
        It must have exactly one pair: {datetime_op, datetime_term}
        where datetime_op in [:add, :ago, :from_now]

Output: {datetime_op, datetime_node}
        where datetime_node = resolve_datetime_node(source, datetime_term, opts)

File:   postgres.ex:699-717
Error:  Raises ArgumentError if it is not a single-pair keyword list
```

### 8.2 `resolve_datetime_node/3`
```
defp resolve_datetime_node(source, term, opts)

Input:  A keyword list with the required keys:
          - :count (a whole number)
          - :interval (text like "1 day")
        Optional key:
          - :field (a field name as text or atom)

Output: A keyword list [count: count, interval: interval, (optional) field: resolved_atom]

File:   postgres.ex:719-734
Error:  Raises ArgumentError if it is not a keyword list
```

**Example flow:**
```
Input:  {:ago, %{count: 3, interval: "days"}}
Step 1: resolve_datetime_wrapper → {:ago, resolve_datetime_node(...)}
Step 2: resolve_datetime_node([count: 3, interval: "days"])
        → [count: 3, interval: "days"]
Output: {:ago, [count: 3, interval: "days"]}
(plain reading: "3 days ago")
```

---

## 9. Operator Alias Table

Each row shows a nickname for an operator (Short Form) and the standard form it is swapped for (Canonical).

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

These are all the operators in their standard form.

**Comparison Operators (6):** `:==`, `:!=`, `:>`, `:>=`, `:<`, `:<=`

**Short Ops (6) — nicknames:** `:eq`, `:ne`, `:gt`, `:gte`, `:lt`, `:lte` → swapped for the standard form via `op_alias/1`

**Quantifier Operators (2):** `:all`, `:any` (compare against every value, or against at least one value, in a set)

**Common Expression Operators (10):** `:ids`, `:before`, `:after`, `:until`, `:since`, `:exists`, `:start_date`, `:end_date`, `:since_date`, `:until_date`

**String Operators (2):** `:like`, `:ilike`

**Array Operations (1):** `:elements`

**Aggregate Functions (5) — summarizing many rows into one number:** `:avg`, `:sum`, `:max`, `:min`, `:count`

**Special Operators:** `:arithmetic` (math on a column), `:aggregate` (a row summary), `:not` (the "not" / flip-to-opposite marker)

**Map Field Operators (for JSON columns):** `:contains`, `:contained_by`, `:has_key`, `:has_any_key`, `:has_all_keys`

---

## 11. Transformation Summary Table

This walks through the whole pipeline, phase by phase: what goes in, what comes out, and where it lives.

| Phase | Input | Output | Module | File:Line |
|---|---|---|---|---|
| **Phase 1: Entry Normalization (tidying the input)** | `{key, params}` | `{key, casted_value}` or a list of entries | `postgres.ex` | `build_dynamic:141-177` |
| **Phase 2: Map/Keyword Flattening** | A plain map or keyword list | A keyword list | `apply_expr` | `postgres.ex:179-193` |
| **Phase 3: Negation Extraction (pulling out "not")** | `{:not, term}` | `dispatch_expr(..., :not, term)` | `dispatch_expr` | `postgres.ex:195-197` |
| **Phase 4: Operator Canonicalization (standardizing operators)** | A nickname or transform | The standard form | `dispatch_expr` | `postgres.ex:280-302` |
| **Phase 5: Semantic Dispatch (route by meaning)** | A standardized term | A subquery, aggregate, datetime, arithmetic, or plain field condition | `dispatch_expr` | `postgres.ex:215-467` |
| **Phase 6: Field-Type Routing** | An `{op, value}` tuple | A `ScalarExpr` / `ArrayExpr` / `MapExpr` / `CommonExpr` query condition | `dispatch_field_expr` | `postgres.ex:469-519` |
| **Phase 7: RHS Assembly (build the right-hand side)** | RHS map entries | `{:field, atom}`, `{:value, expr}`, and so on | `build_rhs_entry` | `postgres.ex:660-688` |

---

## 12. Build Quantified Query

This builds the nested query (the subquery) used by "match all" / "match at least one" requests.

**Function:** `build_quantified_query/3`

**Inputs:**
- `outer_key`: a field name as an atom or text
- `params`: a map or keyword list with:
  - `:from` (optional, the source for the subquery)
  - `:select` (optional, the field to pull out)
  - The rest: filter params for the `where` clause
- `opts`: options passed straight through

**Transformation pipeline:**
```
1. Pull out `:from` → the source (default: [])
2. Pull out `:select` → the select spec
3. The remaining entries → the where params
4. Work out the select field via field_name_to_atom, or fall back to outer_key
5. Build the inner query via CommonFilters.convert_params_to_filter
6. Wrap it with Select.build_query(:select, ...)
```

**File:** `postgres.ex:521-558`

---

## 13. Integration with Delegation Modules

These are the four helper modules the main file hands work off to. Each takes a standard `{op, value}` tuple (its "Canonical Input") and produces a query condition built up in code.

### ScalarExpr (`scalar_expr.ex`)
- **Entry:** `dynamic_expr(selected_binding, key, negated, term, opts)` (line 24)
- **Canonical input:** `{op, value}` tuples
- **Handles:** comparisons, aggregates (row summaries), quantified subqueries, datetime, arithmetic (column math)
- **Output:** an Ecto query condition (`Ecto.Query.dynamic`)

### ArrayExpr (`array_expr.ex`)
- **Entry:** `dynamic_expr(selected_binding, key, negated, term, opts)` (line 15)
- **Canonical input:** `{op, value}` tuples for array operations
- **Handles:** "is this value in the array", array length, ANY/ALL quantifiers, case-insensitive matching
- **Output:** array query conditions built from SQL fragments

### MapExpr (`map_expr.ex`)
- **Entry:** `dynamic_expr(selected_binding, key, negated, term, opts)` (line 14)
- **Canonical input:** `{op, value}` tuples for JSONB (JSON-in-a-column) operations
- **Handles:** containment (`@>`), contained-by (`<@`), key existence
- **Output:** JSONB query conditions built from SQL fragments

### CommonExpr (`common_expr.ex`)
- **Entry:** `dynamic_expr(selected_binding, key, negated, term, opts)` (line 28)
- **Canonical input:** an operator key (`:ids`, `:before`, and so on)
- **Handles:** filtering by ID, time boundaries, existence checks
- **Output:** pre-built query conditions

---

## 14. Field Type Inference

This is how the code works out a column's type, so it knows whether to route to `ScalarExpr`, `ArrayExpr`, or `MapExpr`.

**Sources (checked in this order):**
1. `opts[:field_types]` — a type map the caller passed in explicitly
2. `CommonSchema.get_schema_reflection(source, :type, key)` — the type read from the schema

**Detection functions:**
```elixir
# Is it an array column?
array_field?(source, key, opts) → check if the type is {:array, _}

# Is it a map (JSON) column?
map_field?(source, key, opts) → check if the type is :map or {:map, _}

# Is the field even real?
invalid_schema_field?(source, key) → check if the key is NOT in the :fields list
```

**File:** `postgres.ex:570-590`

---

## 15. Negation Application Pattern

This is how the "not" case (flipping a condition to its opposite) is applied. All four helper modules follow the same pattern.

```elixir
# In dispatch_expr (written by hand, not generated)
term = if negated === :not, do: {:not, {op, value}}, else: {op, value}

case term do
  {:not, {:==, v}} → dynamic([], ^f != ^v)   # "not equal"
  {:==, v} → dynamic([], ^f == ^v)           # "equal"
  # ... more cases
end

# In the helper modules, the final step that applies the flip
defp maybe_negate(nil, _negated), do: nil
defp maybe_negate(expr, :not), do: dynamic([], not (^expr))
defp maybe_negate(expr, _negated), do: expr
```

**File:** `postgres.ex:798-801` (the main `merge_dynamic`); each helper module implements its own version in its own file.
