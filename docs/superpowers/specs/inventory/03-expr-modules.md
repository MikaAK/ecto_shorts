# Expr Modules Behavior Inventory

## Overview

This document describes four small helper modules in EctoShorts. Each one takes a tidied-up piece of a filter and turns it into a piece of a database request.

A quick picture of what these helpers do:

```
a tidied filter piece   →   [ Expr helper ]   →   a piece of SQL
("the price equals 5")                          ("price = 5")
```

The four helpers are `ScalarExpr`, `ArrayExpr`, `MapExpr`, and `CommonExpr`. They are called "leaf" modules because they sit at the very end of the chain — they do the final translation and call nothing deeper.

The key idea: each helper is *supposed* to be a simple translator. It receives a canonical term (the tidied-up, standard form of a filter piece that these helpers receive) and it emits (produces — builds and returns) a piece of SQL. It should not look anything up and should not have side effects. Where a helper breaks that rule, this document flags it as a "purity violation."

All of the work of figuring out field names (a field is a column of a table), looking things up in the database schema, and deciding which table a condition points to happens elsewhere, through "QueryBinding contracts" (code generated automatically for each binding shape — a binding is which table in the query a condition points to). These helpers just receive that information ready-made.

### Words used in this document

- **Ecto** — Ecto, the Elixir library for talking to a database.
- **query** — a database request (a query).
- **field** — a field (a column of a table).
- **dynamic** — a query condition built up in code (Ecto calls this a "dynamic").
- **fragment** — a snippet of raw SQL embedded in the query.
- **operator** — a comparison word such as "equals" or "greater than".
- **canonical term** — the tidied-up, standard form of a filter piece that these helpers receive.
- **emit / emits** — produces (builds and returns).
- **pure function / purity** — a function that only turns its inputs into an output: no looking things up, no side effects. A "purity violation" is where a function breaks that rule.
- **negation / negated** — the "not" case: the opposite condition.
- **nil** — nil: the absence of a value (an empty/NULL column).
- **aggregate** — aggregate: a function that summarizes many rows into one number, like average or count.
- **quantifier (all / any)** — compare against every value (all) or at least one value (any) in a set.
- **JSONB** — JSONB: a PostgreSQL column type that stores JSON data.
- **array field** — a column that holds a list of values.
- **binding** — binding: which table in the query a condition points to.
- **parent_as** — a reference to a column in an outer query from inside a subquery.

---

## 1. ScalarExpr (`scalar_expr.ex`)

This helper handles plain single-value fields (numbers, text, dates) — as opposed to lists or JSON.

### Declared Operators

These are the operators (comparison words) the module knows about, grouped by kind:

- `@operators`: `[:membership, :comparison, :string_transform, :string]`
- `@comparison_operators`: `[:>, :>=, :<, :<=, :==, :!=]`
- `@equality_operators`: `[:==, :!=]`
- `@string_operators`: `[:like, :ilike]`
- `@aggregate_helpers`: `[:avg, :count, :max, :min, :sum]`

### Dispatch Architecture

"Dispatch" just means: deciding which inner function should handle a given filter piece.

The starting point is `dispatch_expr(binding, key, negated, {op, value})`. It calls `family_for(op, value)` to sort the request into one of four families, then sends it to the matching handler:

- `:membership` → `membership_impl`
- `:string_transform` → `string_transform_impl`
- `:string` → `string_impl`
- `:comparison` → `comparison_impl`

### Membership Implementation (lines 141–166)

This part handles "is the value one of these?" checks — the `:in`, `:==`, and `:!=` operators when given a list. It produces `IN` / `NOT IN` SQL (checking whether a value is, or is not, in a list).

| Canonical Term | Negated Variant | Emitted Dynamic | File:Line |
|---|---|---|---|
| `{:in, [values]}` | `{:not, {:in, [values]}}` | `field IN (values)` / `NOT (field IN values)` | 145-146, 149 |
| `{:==, [values]}` | `{:not, {:==, [values]}}` | `field IN (values)` / `NOT (field IN values)` | 148-149, 151-152 |
| `{:!=, [values]}` | `{:not, {:!=, [values]}}` | `NOT IN (values)` / `NIL-AWARE IN` | 157-158, 160-161 |

Details (what each rule does and which inner function builds it):

- `:in` + list → `membership_in_dyn`: `field(K) in ^values` (106–111) — "the field is one of these values"
- `NOT :in` → `membership_not_in_dyn`: `is_nil(field) OR field NOT IN values` (113–119) — "the field is empty, or not one of these values"
- `:==` + list → same as `:in` (154–155)
- `NOT :==` → same as `NOT :in` (151–152)
- `:!=` + list → `membership_not_in_dyn` (160–161)
- `NOT :!=` → `membership_nil_aware_in_dyn`: `NOT is_nil(field) AND field IN values` (157–158) — "the field is not empty and is one of these values"

### String Transform Implementation (lines 168–207)

This handles text comparisons where the text is first forced to lower-case or upper-case. It matches `{:==|:!=, {:lower|:upper, v}}` and emits `lower(field) = v` or `upper(field) = v` (compare the field, in lower/upper case, to a value).

| Canonical Term | Emitted Dynamic | File:Line |
|---|---|---|
| `{:==, {:lower, v}}` | `lower_field_dyn(binding, key) == ^v` | 176–178 |
| `{:!=, {:lower, v}}` | `lower_field_dyn(binding, key) != ^v` | 184–186 |
| `{:not, {:==, {:lower, v}}}` | `lower_field_dyn(binding, key) != ^v` | 172–174 |
| `{:not, {:!=, {:lower, v}}}` | `lower_field_dyn(binding, key) == ^v` | 180–182 |
| `{:==, {:upper, v}}` | `upper_field_dyn(binding, key) == ^v` | 192–194 |
| `{:!=, {:upper, v}}` | `upper_field_dyn(binding, key) != ^v` | 200–202 |
| `{:not, {:==, {:upper, v}}}` | `upper_field_dyn(binding, key) != ^v` | 188–190 |
| `{:not, {:!=, {:upper, v}}}` | `upper_field_dyn(binding, key) == ^v` | 196–198 |

The actual SQL fragments (snippets of raw SQL) come from `lower_field_dyn` / `upper_field_dyn`, lines 57–69:

- `lower_field_dyn`: `fragment("lower(?)", field(...))` — converts the field text to lower-case.
- `upper_field_dyn`: `fragment("upper(?)", field(...))` — converts the field text to upper-case.

### String Implementation (lines 209–249)

This handles `:like` and `:ilike` — pattern matching on text. (`LIKE` matches a text pattern; `ILIKE` is the case-insensitive version.) It works with a single pattern or a list of patterns, producing `LIKE ANY` / `ILIKE ANY` (match any of several patterns) or a plain single-pattern `LIKE`.

| Canonical Term | Emitted Dynamic | File:Line |
|---|---|---|
| `{:like, [values]}` | `fragment("? LIKE ANY(?)", field, patterns)` | 218–221 |
| `{:not, {:like, [values]}}` | `NOT fragment("? LIKE ANY(?)", field, patterns)` | 213–216 |
| `{:ilike, [values]}` | `fragment("? ILIKE ANY(?)", field, patterns)` | 228–231 |
| `{:not, {:ilike, [values]}}` | `NOT fragment("? ILIKE ANY(?)", field, patterns)` | 223–226 |
| `{:like, v}` (scalar) | `like(field, pattern)` | 237–239 |
| `{:not, {:like, v}}` | `NOT like(field, pattern)` | 233–235 |
| `{:ilike, v}` (scalar) | `ilike(field, pattern)` | 245–247 |
| `{:not, {:ilike, v}}` | `NOT ilike(field, pattern)` | 241–243 |

Pattern wrapping (`preserve_or_wrap_pattern`, lines 822–832): adds a `%` to the start and end of the pattern (so it matches anywhere in the text) unless the pattern already contains `%` or `_`.

### Comparison Implementation Core (lines 252–624)

This is the largest part. It handles all the ordinary comparisons.

**Nil Checks (lines 256–267):** checking whether a field is empty (nil — the absence of a value, an empty/NULL column).

| Canonical Term | Emitted Dynamic | File:Line |
|---|---|---|
| `{:==, nil}` | `is_nil(field)` | 257–258 |
| `{:!=, nil}` | `NOT is_nil(field)` | 263–264 |
| `{:not, {:==, nil}}` | `NOT is_nil(field)` | 260–261 |
| `{:not, {:!=, nil}}` | `is_nil(field)` | 266–267 |

`is_nil(field)` checks the column has no value; `NOT is_nil(field)` checks it has a value.

**Scalar Comparisons (lines 270–316):** comparing the field to a single plain value. Matches `{op, scalar}` where the value is not a tuple.

| Operator | Plain | Negated | File:Line |
|---|---|---|---|
| `:==` | `field == value` | `field != value` | 270–276 |
| `:!=` | `field != value` | `field == value` | 278–284 |
| `:>` | `field > value` | `NOT (field > value)` | 286–292 |
| `:>=` | `field >= value` | `NOT (field >= value)` | 294–300 |
| `:<` | `field < value` | `NOT (field < value)` | 302–308 |
| `:<=` | `field <= value` | `NOT (field <= value)` | 310–316 |

**Quantified Comparisons (lines 319–413):** comparing the field against a whole set of values, where you require the comparison to hold for *every* value (all) or for *at least one* value (any). Matches `{op, {:all|:any, qv}}` and emits `field OP ALL/ANY(qv)`.

| Canonical Term | Plain | Negated | File:Line |
|---|---|---|---|
| `{:==, {:all, qv}}` | `field == all(qv)` | `NOT (field == all(qv))` | 319–325 |
| `{:!=, {:all, qv}}` | `field != all(qv)` | `NOT (field != all(qv))` | 335–341 |
| `:>, :>=, :<, :<=` + `:all` | 6 more pairs (lines 351–413) | ... | ... |
| `{:==, {:any, qv}}` | `field == any(qv)` | `NOT (field == any(qv))` | 327–333 |
| `:!=, :>, :>=, :<, :<=` + `:any` | 5 more pairs | ... | 343–413 |

**Aggregate Comparisons (lines 416–479):** comparing against an aggregate — a function that summarizes many rows into one number, like average or count. Matches `{helper, {op, value}}` where `helper in @aggregate_helpers` (avg/count/max/min/sum).

Nil checks (lines 416–430) — checking whether the summarized value is empty:

| Canonical Term | Emitted Dynamic | File:Line |
|---|---|---|
| `{:avg\|:count\|:max\|:min\|:sum, {:==, nil}}` | `is_nil(agg_field)` | 417–418 |
| `{helper, {:!=, nil}}` | `NOT is_nil(agg_field)` | 425–426 |
| `{:not, {helper, {:==, nil}}}` | `NOT is_nil(agg_field)` | 420–422 |
| `{:not, {helper, {:!=, nil}}}` | `is_nil(agg_field)` | 428–430 |

Value comparisons (lines 433–479): 6 operators × 5 aggregates × 2 negation modes = 60 clause pairs (one for the plain case and one for the negated "not" case).

Example (lines 433–439):

- `{:avg, {:==, v}}` → `avg_field_dyn(binding, key) == v` (434–435)
- `{:not, {:avg, {:==, v}}}` → `avg_field_dyn(binding, key) != v` (437–439)

Aggregates are dispatched via `agg_field_dyn` (lines 626–630) to:

- `:avg` → `avg_field_dyn` → `fragment("avg(?)", field)` + `avg(field(...))` (71–76, line 75)
- `:count` → `count_field_dyn` → `count(field(...))` (78–83, line 81)
- `:max` → `max_field_dyn` → `max(field(...))` (85–90, line 88)
- `:min` → `min_field_dyn` → `min(field(...))` (92–97, line 95)
- `:sum` → `sum_field_dyn` → `sum(field(...))` (99–104, line 102)

**Datetime Comparisons (lines 482–569):** comparing a date/time field against a computed time (such as "three days ago"). Matches `{op, {wrapper, {datetime_op, params}}}` where:

- `op in @comparison_operators`
- `wrapper in [:datetime, :date]`
- `datetime_op in [:ago, :from_now, :add]`

Three named arguments are pulled out of `params`: `:count`, `:interval`, and `:field` (the last only for `:add`).

Sample clause (lines 482–486):

```elixir
{:==, {:date, {:ago, params}}} ->
  count = Keyword.fetch!(params, :count)
  interval = Keyword.fetch!(params, :interval)
  f = date_field_dyn(binding, key)
  dynamic([], ^f == fragment("date(?)", ago(^count, ^interval)))
```

Date extraction (lines 50–55): `date_field_dyn` → `fragment("date(?)", field(...))` — takes just the date part of a date/time field.

Datetime add (lines 500–506, 508–514, 516–522): pulls the `:field` name out of `params`, calls `field_dyn(binding, field_name)`, and emits `datetime_add(field2, count, interval)` (adds a span of time to a field).

Generic fallback (lines 561–569): matches any other valid combination and hands off to `apply_datetime_comparison(binding, key, op, wrapper, datetime_op, params, mode)` (lines 730–782), which builds the left-hand and right-hand conditions and calls `apply_dyn_comparison`.

**Arithmetic Comparisons (lines 572–584):** comparing a field against a small calculation on another field. Matches `{op, {:value, {arith_op, {{:field, af}, {:value, av}}}}}` where arith_op in `[:+, :-, :*, :/]`.

Example (lines 575–577):

```elixir
f = field_dyn(binding, key)
f2 = field_dyn(binding, af)
apply_arith_comparison(op, f, f2, arith_op, av, :plain)
```

The negated variant (lines 579–584) uses `:negated` mode (the "not" case).

**Value Wrapper (lines 587–593):** matches `{op, {:value, v}}` for plain values; unwraps it to `{op, v}` via `apply_scalar_comparison`.

**Parent_as Comparisons (lines 595–610):** comparing the field against a column in an outer query from inside a subquery (this outer reference is called parent_as). Matches `{:parent_as, {pb, pf}}` (pb = parent binding, pf = parent field) and emits `field == field(parent_as(pb), pf)`.

Example (lines 596–598):

```elixir
f = field_dyn(binding, key)
dynamic([], ^f == field(parent_as(^pb), ^pf))
```

6 operators × 2 negation modes = 12 clauses (lines 596–610); these are dispatched to `apply_parent_as_comparison` (lines 645–679).

**Scalar Fallback (lines 613–619):** a generic catch-all for any remaining `{op, v}` where op in `@comparison_operators`; it calls `apply_scalar_comparison(op, f, v, negation_mode)`.

### Scalar Comparison Overloads (lines 632–643)

**apply_scalar_comparison** — a table of 6 operators × 2 modes (plain and negated) = 12 clauses.

| Operator | Plain Mode | Negated Mode | File:Line |
|---|---|---|---|
| `:==` | `field == value` | `field != value` | 632–633 |
| `:!=` | `field != value` | `field == value` | 634–635 |
| `:>` | `field > value` | `NOT (field > value)` | 636–637 |
| `:>=` | `field >= value` | `NOT (field >= value)` | 638–639 |
| `:<` | `field < value` | `NOT (field < value)` | 640–641 |
| `:<=` | `field <= value` | `NOT (field <= value)` | 642–643 |

### Parent_as Comparison Overloads (lines 645–679)

**apply_parent_as_comparison**: 6 operators × 2 modes = 12 clauses. All put the outer-query column reference (parent_as) `field(parent_as(pb), pf)` on the right-hand side; the negated case flips the operator to its opposite.

| Operator | Plain Mode | Negated Mode |
|---|---|---|
| `:==` | `field == parent_as_field` | `field != parent_as_field` |
| `:!=` | `field != parent_as_field` | `field == parent_as_field` |
| `:>` | `field > parent_as_field` | `NOT (field > parent_as_field)` |
| `:>=` | `field >= parent_as_field` | `NOT (field >= parent_as_field)` |
| `:<` | `field < parent_as_field` | `NOT (field < parent_as_field)` |
| `:<=` | `field <= parent_as_field` | `NOT (field <= parent_as_field)` |

### Arithmetic Comparison Overloads (lines 681–728)

**apply_arith_comparison**: 6 operators × 4 arithmetic ops `[:+, :-, :*, :/]` × 2 modes = 48 clauses.

The shape is always `field OP (field2 ARITH_OP value)` — compare one field to another field after a small calculation.

| Operator | + Plain | + Negated | - Plain | - Negated | * Plain | * Negated | / Plain | / Negated |
|---|---|---|---|---|---|---|---|---|
| `:==` | `f == f2 + v` | `NOT (f == f2 + v)` | `f == f2 - v` | `NOT (...)` | `f == f2 * v` | `NOT (...)` | `f == f2 / v` | `NOT (...)` |
| `:!=` | `f != f2 + v` | `NOT (f != f2 + v)` | `f != f2 - v` | `NOT (...)` | `f != f2 * v` | `NOT (...)` | `f != f2 / v` | `NOT (...)` |
| `:>` | `f > f2 + v` | `NOT (f > f2 + v)` | ... | ... | ... | ... | ... | ... |
| `:>=, :<, :<=` | (similar, 3 more) | ... | ... | ... | ... | ... | ... | ... |

(Lines 681–728 detailed)

### Dynamic Comparison Helpers (lines 784–795)

**apply_dyn_comparison**: 6 operators × 2 modes = 12 clauses. Here both sides of the comparison are conditions built up in code (dynamics) — `lhs` is the left side and `rhs` is the right side.

| Operator | Plain Mode | Negated Mode |
|---|---|---|
| `:==` | `lhs == rhs` | `lhs != rhs` |
| `:!=` | `lhs != rhs` | `lhs == rhs` |
| `:>` | `lhs > rhs` | `NOT (lhs > rhs)` |
| `:>=` | `lhs >= rhs` | `NOT (lhs >= rhs)` |
| `:<` | `lhs < rhs` | `NOT (lhs < rhs)` |
| `:<=` | `lhs <= rhs` | `NOT (lhs <= rhs)` |

### Datetime Comparison Dispatchers (lines 730–782)

Four helpers named `apply_datetime_comparison(binding, key, op, wrapper, datetime_op, params, mode)`.

Each one pulls `count` and `interval` out of `params`; for `:add` it also pulls out `:field` and builds `f2 = field_dyn(binding, field_name)`.

- **:datetime, :ago** (lines 730–737): uses `ago(count, interval)` as the right-hand side (a point in the past).
- **:datetime, :from_now** (lines 739–746): uses `from_now(count, interval)` as the right-hand side (a point in the future).
- **:datetime, :add** (lines 748–756): uses `datetime_add(f2, count, interval)` as the right-hand side; passes it to `apply_dyn_comparison`.
- **:date, :ago** (lines 758–764): wraps the right-hand side in `fragment("date(?)", ago(...))` (just the date part of a past point) and calls `apply_dyn_comparison` with `date_field_dyn`.
- **:date, :from_now** (lines 766–772): wraps the right-hand side in `fragment("date(?)", from_now(...))`.
- **:date, :add** (lines 774–782): wraps the right-hand side in `fragment("date(?)", datetime_add(...))`.

### Purity Violations

(Recall: a purity violation is where a function does more than just turn its inputs into SQL — for example, it looks something up or can throw an error.)

1. **Field name extraction** (line 501, 509, 517, 749, 753, 775, 779): `Keyword.get(params, :field)` — this reads a field name out of the parameters, which is a schema/metadata lookup, not pure SQL production.
2. **Keyword parameter parsing** (lines 483–484, 489–490, etc.): `Keyword.fetch!` — this can fail at run time (it raises an error if `:count` or `:interval` is missing), which is a side effect outside the job of producing SQL.

---

## 2. ArrayExpr (`array_expr.ex`)

This helper handles array fields — columns that hold a list of values.

### Dispatch Architecture

The starting point is `dynamic_expr(binding, key, negated, term, _opts)`. It calls `dispatch_expr(binding, key, term)` to build the condition, then `maybe_negate(result, negated)` to flip it to the "not" case if needed.

There is no `@operators` list declared here; the operators are inferred from the patterns in the dispatch clauses.

### Supported Operators

- `:==`, `:!=` (empty-value checks, list comparison, membership)
- `:in` (array overlap, membership)
- `:count` (length checks)
- `:all` (the "every value" quantifier)
- `:>`, `:>=`, `:<`, `:<=` (comparison operators)
- `:lower`, `:upper` (case conversion, using EXISTS)
- `:like`, `:ilike` (pattern matching, using EXISTS)
- `:parent_as` (compare against an outer-query column)
- `:any` (rejected with a warning)
- `:avg, :sum, :max, :min` (rejected with a warning)
- `:datetime, :date` (rejected with a warning)

### Nil & Equality Checks (lines 82–101)

| Canonical Term | Emitted Dynamic | File:Line |
|---|---|---|
| `{:==, nil}` | `is_nil(field)` | 82–84 |
| `{:!=, nil}` | `NOT is_nil(field)` | 86–89 |
| `{:==, [values]}` (list) | `field == values` | 91–95 |
| `{:!=, [values]}` (list) | `field != values` | 97–101 |

`is_nil(field)` checks the column has no value; comparing to a list checks the whole list matches (or does not match).

### Case Transforms (lines 103–117)

These check whether the list contains an item that matches when both are made lower-case or upper-case. They use a SQL trick: `unnest` spreads the array into rows, and `EXISTS` checks if any matching row is found.

| Canonical Term | Emitted Dynamic | File:Line |
|---|---|---|
| `{:==, {:lower, v}}` | `fragment("EXISTS (SELECT 1 FROM unnest(?) AS t WHERE lower(t) = ?)", field, v)` | 103–105 |
| `{:==, {:upper, v}}` | `fragment("EXISTS (SELECT 1 FROM unnest(?) AS t WHERE upper(t) = ?)", field, v)` | 107–109 |
| `{:!=, {:lower, v}}` | `fragment("NOT EXISTS (SELECT 1 FROM unnest(?) AS t WHERE lower(t) = ?)", field, v)` | 111–113 |
| `{:!=, {:upper, v}}` | `fragment("NOT EXISTS (SELECT 1 FROM unnest(?) AS t WHERE upper(t) = ?)", field, v)` | 115–117 |

Plain glosses for the fragments above:
- lower `==`: "true if some list item, in lower-case, equals the value."
- upper `==`: "true if some list item, in upper-case, equals the value."
- lower `!=`: "true if no list item, in lower-case, equals the value."
- upper `!=`: "true if no list item, in upper-case, equals the value."

Macros: `lower_exists_dyn` (35–44), `upper_exists_dyn` (46–55), `lower_not_exists_dyn` (57–66), `upper_not_exists_dyn` (68–77).

### Unwrapped Value Wrapper (lines 119–131)

| Canonical Term | Emitted Dynamic | File:Line |
|---|---|---|
| `{op, {:value, {arith_op, _}}}` where op in `[:==, :!=, :>, :>=, :<, :<=]` and arith_op in `[:+, :-, :*, :/]` | **Warning** (line 121–124): `"arithmetic comparison (#{arith_op}) is not supported on array field #{inspect(key)}, skipping"` → returns `nil` | 119–127 |
| `{op, {:value, v}}` (other) | Recursive: `dispatch_expr(binding, key, {op, v})` | 129–131 |

The first row means: calculations on an array field are not allowed, so the helper logs a warning and produces nothing. The second row simply unwraps the value and tries again.

### Quantified Comparisons (lines 133–161)

A quantifier asks: should the comparison hold for at least one value (any) or for every value (all)?

**:any quantifier** (at least one value, lines 133–161):

| Canonical Term | Emitted Dynamic | File:Line |
|---|---|---|
| `{:==, {:any, qv}}` | `field == any(qv)` | 133–136 |
| `{:!=, {:any, qv}}` | `field != any(qv)` | 138–141 |
| `{:>, {:any, qv}}` | `field > any(qv)` | 143–146 |
| `{:>=, {:any, qv}}` | `field >= any(qv)` | 148–151 |
| `{:<, {:any, qv}}` | `field < any(qv)` | 153–156 |
| `{:<=, {:any, qv}}` | `field <= any(qv)` | 158–161 |

**:all quantifier** (every value, lines 256–289): note that the operator is flipped — for example `{:all, {:>, v}}` becomes `? < ALL(?)` (the value must be less than every array element).

| Canonical Term | Emitted Dynamic | SQL | File:Line |
|---|---|---|---|
| `{:all, {:==, v}}` | `fragment("? = ALL(?)", v, field)` | `value = ALL(array)` | 256–259 |
| `{:all, {:!=, v}}` | `fragment("? != ALL(?)", v, field)` | `value != ALL(array)` | 261–264 |
| `{:all, {:>, v}}` | `fragment("? < ALL(?)", v, field)` | `value < ALL(array)` | 266–269 |
| `{:all, {:>=, v}}` | `fragment("? <= ALL(?)", v, field)` | `value <= ALL(array)` | 271–274 |
| `{:all, {:<, v}}` | `fragment("? > ALL(?)", v, field)` | `value > ALL(array)` | 276–279 |
| `{:all, {:<=, v}}` | `fragment("? >= ALL(?)", v, field)` | `value >= ALL(array)` | 281–284 |
| `{:all, {:in, [values]}}` (list) | `fragment("? <@ ?", field, values)` | `array <@ container` (subset) | 286–289 |

Plain gloss for these: each checks that the value compares as stated against every element of the array; the last row checks the array is a subset of the given list.

### Membership / Containment (lines 198–216)

These check whether a value is in the array, or whether two arrays overlap.

| Canonical Term | Emitted Dynamic | SQL | File:Line |
|---|---|---|---|
| `{:==, value}` (scalar) | `fragment("value IN field")` via `value in field` | `value IN array` | 198–201 |
| `{:!=, value}` (scalar) | `fragment("value NOT IN field")` | `value NOT IN array` | 203–206 |
| `{:in, [values]}` (list) | `fragment("? && ?", field, values)` | `array && values` (overlap) | 208–211 |
| `{:in, value}` (scalar) | `fragment("value IN field")` | `value IN array` | 213–216 |

Plain gloss: `value IN array` checks the value appears in the list; `array && values` checks the two lists share at least one common element.

### Count Operator (lines 218–254)

These check how many items the array holds. `array_length(?, 1)` counts the elements.

| Canonical Term | Emitted Dynamic | File:Line |
|---|---|---|
| `{:count, {:==, 0}}` | `fragment("coalesce(array_length(?, 1), 0)", field) == 0` | 218–222 |
| `{:count, {:==, v}}` (v ≠ 0) | `fragment("array_length(?, 1)", field) == v` | 224–228 |
| `{:count, {:!=, v}}` | `fragment("array_length(?, 1)", field) != v` | 230–234 |
| `{:count, {:>, v}}` | `fragment("array_length(?, 1)", field) > v` | 236–239 |
| `{:count, {:>=, v}}` | `fragment("array_length(?, 1)", field) >= v` | 241–244 |
| `{:count, {:<, v}}` | `fragment("array_length(?, 1)", field) < v` | 246–249 |
| `{:count, {:<=, v}}` | `fragment("array_length(?, 1)", field) <= v` | 251–254 |

Plain gloss: each checks the number of items in the array against `v`. The first row checks the array is empty (length 0).

Note: the special case for `count = 0` wraps the length in `coalesce(array_length(...), 0)` so that an empty/NULL array counts as length 0 (line 221).

### Parent_as Comparisons (lines 163–196)

These compare the array field against a column in an outer query, from inside a subquery (the outer reference is parent_as). `pb` is the parent binding, `pf` is the parent field.

| Canonical Term | Emitted Dynamic | File:Line |
|---|---|---|
| `{:parent_as, {pb, pf}}` (bare) | `field == field(parent_as(pb), pf)` | 163–166 |
| `{:==, {:parent_as, {pb, pf}}}` | `field == field(parent_as(pb), pf)` | 168–171 |
| `{:!=, {:parent_as, {pb, pf}}}` | `field != field(parent_as(pb), pf)` | 173–176 |
| `{:>, {:parent_as, {pb, pf}}}` | `field > field(parent_as(pb), pf)` | 178–181 |
| `{:>=, {:parent_as, {pb, pf}}}` | `field >= field(parent_as(pb), pf)` | 183–186 |
| `{:<, {:parent_as, {pb, pf}}}` | `field < field(parent_as(pb), pf)` | 188–191 |
| `{:<=, {:parent_as, {pb, pf}}}` | `field <= field(parent_as(pb), pf)` | 193–196 |

### String Matching (lines 319–337)

These check whether any item in the array matches a text pattern. They use the `unnest` + `EXISTS` trick again. (`LIKE` matches a pattern; `ILIKE` is the case-insensitive version.)

| Canonical Term | Emitted Dynamic | File:Line |
|---|---|---|
| `{:like, value\|[values]}` | `fragment("EXISTS (SELECT 1 FROM unnest(?) AS t WHERE t LIKE ANY (?))", field, patterns)` | 319–327 |
| `{:ilike, value\|[values]}` | `fragment("EXISTS (SELECT 1 FROM unnest(?) AS t WHERE t ILIKE ANY (?))", field, patterns)` | 329–337 |

Plain gloss: true if at least one list item matches any of the given text patterns (case-sensitive for `LIKE`, case-insensitive for `ILIKE`).

Pattern wrapping: `wrap_patterns` (381–387) → `preserve_or_wrap_pattern` (389–399) (same behavior as in ScalarExpr).

### Unsupported Operators (with warnings)

When an operator does not make sense for an array field, the helper logs a warning and skips it.

| Operator | Message | File:Line |
|---|---|---|
| `:avg, :sum, :max, :min` | `"#{op} aggregate is not supported on array field #{inspect(key)}, skipping"` | 339–346 |
| `:any` (bare, not with quantifier) | `":any subquery quantifier is not supported on array field #{inspect(key)}, skipping"` | 348–355 |
| `:datetime, :date` | `"#{wrapper} comparison is not supported on array field #{inspect(key)}, skipping"` | 357–364 |
| `:parent_as` (malformed) | `":parent_as requires a {binding, field} payload, got unexpected form for field #{inspect(key)}, skipping"` | 366–373 |

### Negation Handler (lines 377–379)

This wraps the condition in a "not" when the negated case is requested.

```elixir
defp maybe_negate(nil, _negated), do: nil
defp maybe_negate(expr, :not), do: Query.dynamic([], not (^expr))
defp maybe_negate(expr, _negated), do: expr
```

### Purity Violations

None. Every operation here just produces SQL. There are no field lookups or metadata access beyond passing the field name through.

---

## 3. MapExpr (`map_expr.ex`)

This helper handles JSONB fields — JSONB is a PostgreSQL column type that stores JSON data.

### Dispatch Architecture

The starting point is `dynamic_expr(binding, key, negated, term, _opts)`. It calls `dispatch_expr(binding, key, term)` to build the condition, then `maybe_negate(result, negated)` to apply the "not" case if needed.

There is no `@operators` list declared here; the operators are inferred from the dispatch clause patterns.

### Nil & Equality Checks (lines 38–58)

| Canonical Term | Emitted Dynamic | File:Line |
|---|---|---|
| `{:==, nil}` | `is_nil(field)` | 38–40 |
| `{:!=, nil}` | `NOT is_nil(field)` | 42–45 |
| `{:==, value}` (scalar) | `field == value` | 48–52 |
| `{:!=, value}` (scalar) | `field != value` | 54–58 |

`is_nil(field)` checks the column has no value; the scalar rows compare the field directly to a value.

### JSONB Containment (lines 60–78)

**Operator: `:contains`** → SQL: `@>` (the JSONB "contains" operator: does the left JSON include the right JSON?).

There are three forms of value it accepts:

| Canonical Term | Emitted Dynamic | File:Line |
|---|---|---|
| `{:contains, {k, v}}` (tuple, normalized from a map) | `fragment("? @> ?::jsonb", field, %{k => v})` | 63–66 |
| `{:contains, value}` (binary, a raw JSON text string) | `fragment("? @> ?::jsonb", field, value)` | 69–72 |
| `{:contains, value}` (list, a JSON array) | `fragment("? @> ?::jsonb", field, value)` | 75–78 |

Plain gloss: each checks that the JSONB field contains the given JSON.

### JSONB Contained-By (lines 80–94)

**Operator: `:contained_by`** → SQL: `<@` (the JSONB "contained by" operator: is the left JSON included within the right JSON?).

There are three forms of value (mirroring `:contains`):

| Canonical Term | Emitted Dynamic | File:Line |
|---|---|---|
| `{:contained_by, {k, v}}` (tuple) | `fragment("? <@ ?::jsonb", field, %{k => v})` | 81–84 |
| `{:contained_by, value}` (binary) | `fragment("? <@ ?::jsonb", field, value)` | 86–89 |
| `{:contained_by, value}` (list) | `fragment("? <@ ?::jsonb", field, value)` | 91–94 |

Plain gloss: each checks that the JSONB field is contained within the given JSON.

### JSONB Key Existence (lines 96–113)

These check whether a JSON object has certain keys.

| Operator | Canonical Term | Emitted Dynamic | File:Line |
|---|---|---|---|
| `:has_key` | `{:has_key, value}` (scalar key) | `fragment("jsonb_exists(?, ?)", field, value)` | 98–101 |
| `:has_any_key` | `{:has_any_key, [values]}` (list of keys) | `fragment("jsonb_exists_any(?, ?)", field, values)` | 104–107 |
| `:has_all_keys` | `{:has_all_keys, [values]}` (list of keys) | `fragment("jsonb_exists_all(?, ?)", field, values)` | 110–113 |

Plain gloss: `jsonb_exists` checks the JSON has the given key; `jsonb_exists_any` checks it has at least one of the listed keys; `jsonb_exists_all` checks it has all of them.

### Negation Handler (lines 117–119)

```elixir
defp maybe_negate(nil, _negated), do: nil
defp maybe_negate(expr, :not), do: Query.dynamic([], not (^expr))
defp maybe_negate(expr, _negated), do: expr
```

### Purity Violations

None. Every operation here just produces SQL. There is no field-name or metadata manipulation.

---

## 4. CommonExpr (`common_expr.ex`)

This helper handles a set of common, convenience operators (such as ID ranges and date ranges).

### Declared Operators

```elixir
@operators [
  :ids,
  :before,
  :after,
  :until,
  :since,
  :exists,
  :start_date,
  :end_date,
  :since_date,
  :until_date
]
```

### Dispatch Architecture

The starting point is `dynamic_expr(binding, operator, negated, term, _opts)`. It calls `dispatch_expr(binding, operator, term)` to build the condition, then `maybe_negate(result, negated)` to apply the "not" case if needed.

### ID Operators (lines 50–73)

These filter records by their `id` value.

| Operator | Canonical Term | Emitted Dynamic | File:Line |
|---|---|---|---|
| `:ids` | `[id_values]` (list) | `id in [...]` | 50–53 |
| `:after` | `id_value` (scalar) | `id > value` | 55–58 |
| `:before` | `id_value` (scalar) | `id < value` | 60–63 |
| `:since` | `id_value` (scalar) | `id >= value` | 65–68 |
| `:until` | `id_value` (scalar) | `id <= value` | 70–73 |

Plain gloss: `:ids` keeps records whose id is one of the listed values; the others keep records whose id is greater than / less than / at-least / at-most the given value.

All of these target the hardcoded `:id` field via `field_dyn(binding, :id)` (lines 51, 56, 61, 66, 71).

### Date Operators (lines 75–83)

These filter records by their creation timestamp.

| Operator | Canonical Term | Emitted Dynamic | File:Line |
|---|---|---|---|
| `:start_date`, `:since_date` | `timestamp` | `inserted_at >= timestamp` | 75–78 |
| `:end_date`, `:until_date` | `timestamp` | `inserted_at <= timestamp` | 80–83 |

Plain gloss: keep records created on or after (first row) / on or before (second row) the given time.

Both pairs target the hardcoded `:inserted_at` field (lines 76, 81).

### Exists Operator (lines 85–87)

This checks whether a subquery returns any rows.

| Operator | Canonical Term | Emitted Dynamic | File:Line |
|---|---|---|---|
| `:exists` | `term` (subquery) | `exists(term)` | 85–87 |

There is no field binding here; it passes `term` straight to `Ecto.Query.exists/1`.

### Negation Handler (lines 91–93)

```elixir
defp maybe_negate(nil, _negated), do: nil
defp maybe_negate(expr, :not), do: Query.dynamic([], not (^expr))
defp maybe_negate(expr, _negated), do: expr
```

### Purity Violations

1. **Hardcoded field names** (lines 51, 56, 61, 66, 71, 76, 81): `:id`, `:inserted_at` — the helper assumes these field names exist, instead of receiving the field name as an input. That breaks purity.
   - It prevents reuse for tables that do not have these fields.
   - It ties the meaning of these operators to an EctoShorts convention (it assumes every record has an `id` and an `inserted_at`).

---

## Summary: Purity Assessment

(Reminder: a "pure" module only turns its inputs into SQL — no lookups, no side effects. A violation is where it does more than that.)

### Pure Modules

- **MapExpr**: No violations. Every operation is a JSONB fragment built only from its inputs.
- **ArrayExpr**: No violations. Every operation is an array fragment built only from its inputs.

### Modules with Violations

- **ScalarExpr**:
  - **Line 501, 509, 517, 749, 753, 775, 779**: reads a field name out of keyword params (`Keyword.get(params, :field)`) — this is a schema-dependent run-time lookup.
  - **Lines 483–490, 500–506, etc.**: `Keyword.fetch!` can raise an error if `:count` or `:interval` is missing — a failure outside the job of producing SQL.

- **CommonExpr**:
  - **Lines 50–87**: hardcoded `:id` and `:inserted_at` field names — these should be inputs, not assumptions, so this breaks purity.

---

## Full Dispatch Tables

### ScalarExpr dispatch_expr Entry Points

**Primary routing** (line 133–138) — how a request is sorted into one of the four families:

```
family_for(op, value) →
  :membership       → membership_impl
  :string_transform → string_transform_impl
  :string           → string_impl
  :comparison       → comparison_impl
```

**family_for classification** (lines 799–820) — the rules used to pick a family:

- `:in` → `:membership`
- `[:==, :!=] + list` → `:membership`
- `[:>, :>=, :<, :<=, :==, :!=] + {:lower|:upper, _}` → `:string_transform`
- `[:like, :ilike] + {:lower|:upper, _}` → `:string_transform`
- `[:like, :ilike]` → `:string`
- default → `:comparison`
