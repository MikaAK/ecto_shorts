# Expr Modules Behavior Inventory

## Overview
Exhaustive catalog of canonical term shapes → SQL/dynamic fragments for EctoShorts leaf Expr modules. Each module emits pure SQL; all field name handling, schema lookups, and binding resolution occur via QueryBinding contracts (macro-generated per binding).

---

## 1. ScalarExpr (`scalar_expr.ex`)

### Declared Operators
- `@operators`: `[:membership, :comparison, :string_transform, :string]`
- `@comparison_operators`: `[:>, :>=, :<, :<=, :==, :!=]`
- `@equality_operators`: `[:==, :!=]`
- `@string_operators`: `[:like, :ilike]`
- `@aggregate_helpers`: `[:avg, :count, :max, :min, :sum]`

### Dispatch Architecture
Entry point: `dispatch_expr(binding, key, negated, {op, value})` → `family_for(op, value)` routes to:
- `:membership` → `membership_impl`
- `:string_transform` → `string_transform_impl`
- `:string` → `string_impl`
- `:comparison` → `comparison_impl`

### Membership Implementation (lines 141–166)
Handles `:in`, `:==`, `:!=` with list values; produces in/not-in SQL.

| Canonical Term | Negated Variant | Emitted Dynamic | File:Line |
|---|---|---|---|
| `{:in, [values]}` | `{:not, {:in, [values]}}` | `field IN (values)` / `NOT (field IN values)` | 145-146, 149 |
| `{:==, [values]}` | `{:not, {:==, [values]}}` | `field IN (values)` / `NOT (field IN values)` | 148-149, 151-152 |
| `{:!=, [values]}` | `{:not, {:!=, [values]}}` | `NOT IN (values)` / `NIL-AWARE IN` | 157-158, 160-161 |

Details:
- `:in` + list → `membership_in_dyn`: `field(K) in ^values` (106–111)
- `NOT :in` → `membership_not_in_dyn`: `is_nil(field) OR field NOT IN values` (113–119)
- `:==` + list → same as `:in` (154–155)
- `NOT :==` → same as `NOT :in` (151–152)
- `:!=` + list → `membership_not_in_dyn` (160–161)
- `NOT :!=` → `membership_nil_aware_in_dyn`: `NOT is_nil(field) AND field IN values` (157–158)

### String Transform Implementation (lines 168–207)
Matches `{:==|:!=, {:lower|:upper, v}}`; emits `lower(field) = v` or `upper(field) = v`.

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

SQL fragments (from `lower_field_dyn`/`upper_field_dyn`, lines 57–69):
- `lower_field_dyn`: `fragment("lower(?)", field(...))`
- `upper_field_dyn`: `fragment("upper(?)", field(...))`

### String Implementation (lines 209–249)
Matches `:like|:ilike` with scalar or list patterns; produces LIKE/ILIKE ANY or scalar LIKE.

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

Pattern wrapping (`preserve_or_wrap_pattern`, lines 822–832): adds `%` prefix/suffix unless pattern contains `%` or `_`.

### Comparison Implementation Core (lines 252–624)

**Nil Checks (lines 256–267):**
| Canonical Term | Emitted Dynamic | File:Line |
|---|---|---|
| `{:==, nil}` | `is_nil(field)` | 257–258 |
| `{:!=, nil}` | `NOT is_nil(field)` | 263–264 |
| `{:not, {:==, nil}}` | `NOT is_nil(field)` | 260–261 |
| `{:not, {:!=, nil}}` | `is_nil(field)` | 266–267 |

**Scalar Comparisons (lines 270–316):**
Matches `{op, scalar}` where `not is_tuple(scalar)`.

| Operator | Plain | Negated | File:Line |
|---|---|---|---|
| `:==` | `field == value` | `field != value` | 270–276 |
| `:!=` | `field != value` | `field == value` | 278–284 |
| `:>` | `field > value` | `NOT (field > value)` | 286–292 |
| `:>=` | `field >= value` | `NOT (field >= value)` | 294–300 |
| `:<` | `field < value` | `NOT (field < value)` | 302–308 |
| `:<=` | `field <= value` | `NOT (field <= value)` | 310–316 |

**Quantified Comparisons (lines 319–413):**
Matches `{op, {:all\|:any, qv}}`; emits `field OP ALL/ANY(qv)`.

| Canonical Term | Plain | Negated | File:Line |
|---|---|---|---|
| `{:==, {:all, qv}}` | `field == all(qv)` | `NOT (field == all(qv))` | 319–325 |
| `{:!=, {:all, qv}}` | `field != all(qv)` | `NOT (field != all(qv))` | 335–341 |
| `:>, :>=, :<, :<=` + `:all` | 6 more pairs (lines 351–413) | ... | ... |
| `{:==, {:any, qv}}` | `field == any(qv)` | `NOT (field == any(qv))` | 327–333 |
| `:!=, :>, :>=, :<, :<=` + `:any` | 5 more pairs | ... | 343–413 |

**Aggregate Comparisons (lines 416–479):**
Matches `{helper, {op, value}}` where `helper in @aggregate_helpers` (avg/count/max/min/sum).

Nil checks (lines 416–430):
| Canonical Term | Emitted Dynamic | File:Line |
|---|---|---|
| `{:avg\|:count\|:max\|:min\|:sum, {:==, nil}}` | `is_nil(agg_field)` | 417–418 |
| `{helper, {:!=, nil}}` | `NOT is_nil(agg_field)` | 425–426 |
| `{:not, {helper, {:==, nil}}}` | `NOT is_nil(agg_field)` | 420–422 |
| `{:not, {helper, {:!=, nil}}}` | `is_nil(agg_field)` | 428–430 |

Value comparisons (lines 433–479): 6 operators × 5 aggregates × 2 negation modes = 60 clause pairs.

Example (lines 433–439):
- `{:avg, {:==, v}}` → `avg_field_dyn(binding, key) == v` (434–435)
- `{:not, {:avg, {:==, v}}}` → `avg_field_dyn(binding, key) != v` (437–439)

Aggregates dispatched via `agg_field_dyn` (lines 626–630) to:
- `:avg` → `avg_field_dyn` → `fragment("avg(?)", field)` + `avg(field(...))` (71–76, line 75)
- `:count` → `count_field_dyn` → `count(field(...))` (78–83, line 81)
- `:max` → `max_field_dyn` → `max(field(...))` (85–90, line 88)
- `:min` → `min_field_dyn` → `min(field(...))` (92–97, line 95)
- `:sum` → `sum_field_dyn` → `sum(field(...))` (99–104, line 102)

**Datetime Comparisons (lines 482–569):**
Matches `{op, {wrapper, {datetime_op, params}}}` where:
- `op in @comparison_operators`
- `wrapper in [:datetime, :date]`
- `datetime_op in [:ago, :from_now, :add]`

Keyword args extracted from `params`: `:count`, `:interval`, `:field` (for `:add`).

Sample clause (lines 482–486):
```elixir
{:==, {:date, {:ago, params}}} ->
  count = Keyword.fetch!(params, :count)
  interval = Keyword.fetch!(params, :interval)
  f = date_field_dyn(binding, key)
  dynamic([], ^f == fragment("date(?)", ago(^count, ^interval)))
```

Date extraction (lines 50–55): `date_field_dyn` → `fragment("date(?)", field(...))`

Datetime add (lines 500–506, 508–514, 516–522): extracts `:field` name from params, calls `field_dyn(binding, field_name)`, emits `datetime_add(field2, count, interval)`.

Generic fallback (lines 561–569): matches any valid combo, delegates to `apply_datetime_comparison(binding, key, op, wrapper, datetime_op, params, mode)` (lines 730–782) which constructs lhs/rhs dynamics and calls `apply_dyn_comparison`.

**Arithmetic Comparisons (lines 572–584):**
Matches `{op, {:value, {arith_op, {{:field, af}, {:value, av}}}}}` where arith_op in [:+, :-, :*, :/].

Example (lines 575–577):
```elixir
f = field_dyn(binding, key)
f2 = field_dyn(binding, af)
apply_arith_comparison(op, f, f2, arith_op, av, :plain)
```

Negated variant (lines 579–584) uses `:negated` mode.

**Value Wrapper (lines 587–593):**
Matches `{op, {:value, v}}` for scalars; unwraps to `{op, v}` via `apply_scalar_comparison`.

**Parent_as Comparisons (lines 595–610):**
Matches `{:parent_as, {pb, pf}}` (parent binding, parent field); emits `field == field(parent_as(pb), pf)`.

Example (lines 596–598):
```elixir
f = field_dyn(binding, key)
dynamic([], ^f == field(parent_as(^pb), ^pf))
```

6 operators × 2 negation modes = 12 clauses (lines 596–610); dispatches to `apply_parent_as_comparison` (lines 645–679).

**Scalar Fallback (lines 613–619):**
Generic catch-all for remaining `{op, v}` where op in @comparison_operators; calls `apply_scalar_comparison(op, f, v, negation_mode)`.

### Scalar Comparison Overloads (lines 632–643)
**apply_scalar_comparison** matrix: 6 operators × 2 modes = 12 clauses.

| Operator | Plain Mode | Negated Mode | File:Line |
|---|---|---|---|
| `:==` | `field == value` | `field != value` | 632–633 |
| `:!=` | `field != value` | `field == value` | 634–635 |
| `:>` | `field > value` | `NOT (field > value)` | 636–637 |
| `:>=` | `field >= value` | `NOT (field >= value)` | 638–639 |
| `:<` | `field < value` | `NOT (field < value)` | 640–641 |
| `:<=` | `field <= value` | `NOT (field <= value)` | 642–643 |

### Parent_as Comparison Overloads (lines 645–679)
**apply_parent_as_comparison**: 6 operators × 2 modes = 12 clauses.
All emit `field(parent_as(pb), pf)` on RHS; negation flips operator.

| Operator | Plain Mode | Negated Mode |
|---|---|---|
| `:==` | `field == parent_as_field` | `field != parent_as_field` |
| `:!=` | `field != parent_as_field` | `field == parent_as_field` |
| `:>` | `field > parent_as_field` | `NOT (field > parent_as_field)` |
| `:>=` | `field >= parent_as_field` | `NOT (field >= parent_as_field)` |
| `:<` | `field < parent_as_field` | `NOT (field < parent_as_field)` |
| `:<=` | `field <= parent_as_field` | `NOT (field <= parent_as_field)` |

### Arithmetic Comparison Overloads (lines 681–728)
**apply_arith_comparison**: 6 operators × 4 arithmetic ops [:+, :-, :*, :/] × 2 modes = 48 clauses.

Pattern: `field OP (field2 ARITH_OP value)`.

| Operator | + Plain | + Negated | - Plain | - Negated | * Plain | * Negated | / Plain | / Negated |
|---|---|---|---|---|---|---|---|---|
| `:==` | `f == f2 + v` | `NOT (f == f2 + v)` | `f == f2 - v` | `NOT (...)` | `f == f2 * v` | `NOT (...)` | `f == f2 / v` | `NOT (...)` |
| `:!=` | `f != f2 + v` | `NOT (f != f2 + v)` | `f != f2 - v` | `NOT (...)` | `f != f2 * v` | `NOT (...)` | `f != f2 / v` | `NOT (...)` |
| `:>` | `f > f2 + v` | `NOT (f > f2 + v)` | ... | ... | ... | ... | ... | ... |
| `:>=, :<, :<=` | (similar, 3 more) | ... | ... | ... | ... | ... | ... | ... |

(Lines 681–728 detailed)

### Dynamic Comparison Helpers (lines 784–795)
**apply_dyn_comparison**: 6 operators × 2 modes = 12 clauses; both lhs and rhs are dynamics.

| Operator | Plain Mode | Negated Mode |
|---|---|---|
| `:==` | `lhs == rhs` | `lhs != rhs` |
| `:!=` | `lhs != rhs` | `lhs == rhs` |
| `:>` | `lhs > rhs` | `NOT (lhs > rhs)` |
| `:>=` | `lhs >= rhs` | `NOT (lhs >= rhs)` |
| `:<` | `lhs < rhs` | `NOT (lhs < rhs)` |
| `:<=` | `lhs <= rhs` | `NOT (lhs <= rhs)` |

### Datetime Comparison Dispatchers (lines 730–782)
Four helpers: `apply_datetime_comparison(binding, key, op, wrapper, datetime_op, params, mode)`.

Each binds `count, interval` from params; for `:add`, also binds `:field` and constructs `f2 = field_dyn(binding, field_name)`.

- **:datetime, :ago** (lines 730–737): `ago(count, interval)` as RHS
- **:datetime, :from_now** (lines 739–746): `from_now(count, interval)` as RHS
- **:datetime, :add** (lines 748–756): `datetime_add(f2, count, interval)` as RHS; passes to `apply_dyn_comparison`
- **:date, :ago** (lines 758–764): wraps RHS in `fragment("date(?)", ago(...))`, calls `apply_dyn_comparison` with `date_field_dyn`
- **:date, :from_now** (lines 766–772): wraps RHS in `fragment("date(?)", from_now(...))`
- **:date, :add** (lines 774–782): wraps RHS in `fragment("date(?)", datetime_add(...))`

### Purity Violations
1. **Field name extraction** (line 501, 509, 517, 749, 753, 775, 779): `Keyword.get(params, :field)` — schema/metadata lookup from params, not pure SQL emission.
2. **Keyword parameter parsing** (lines 483–484, 489–490, etc.): `Keyword.fetch!` — introduces runtime fallibility and side effects (exceptions).

---

## 2. ArrayExpr (`array_expr.ex`)

### Dispatch Architecture
Entry point: `dynamic_expr(binding, key, negated, term, _opts)` → `dispatch_expr(binding, key, term)` → `maybe_negate(result, negated)`.

No `@operators` declared; operators inferred from dispatch clause patterns.

### Supported Operators
- `:==`, `:!=` (nil checks, list comparison, membership)
- `:in` (array overlap, membership)
- `:count` (array_length checks)
- `:all` (ALL quantifier)
- `:>`, `:>=`, `:<`, `:<=` (comparison operators)
- `:lower`, `:upper` (case transforms with EXISTS)
- `:like`, `:ilike` (pattern matching with EXISTS)
- `:parent_as` (parent field comparison)
- `:any` (rejected with warning)
- `:avg, :sum, :max, :min` (rejected with warning)
- `:datetime, :date` (rejected with warning)

### Nil & Equality Checks (lines 82–101)

| Canonical Term | Emitted Dynamic | File:Line |
|---|---|---|
| `{:==, nil}` | `is_nil(field)` | 82–84 |
| `{:!=, nil}` | `NOT is_nil(field)` | 86–89 |
| `{:==, [values]}` (list) | `field == values` | 91–95 |
| `{:!=, [values]}` (list) | `field != values` | 97–101 |

### Case Transforms (lines 103–117)

| Canonical Term | Emitted Dynamic | File:Line |
|---|---|---|
| `{:==, {:lower, v}}` | `fragment("EXISTS (SELECT 1 FROM unnest(?) AS t WHERE lower(t) = ?)", field, v)` | 103–105 |
| `{:==, {:upper, v}}` | `fragment("EXISTS (SELECT 1 FROM unnest(?) AS t WHERE upper(t) = ?)", field, v)` | 107–109 |
| `{:!=, {:lower, v}}` | `fragment("NOT EXISTS (SELECT 1 FROM unnest(?) AS t WHERE lower(t) = ?)", field, v)` | 111–113 |
| `{:!=, {:upper, v}}` | `fragment("NOT EXISTS (SELECT 1 FROM unnest(?) AS t WHERE upper(t) = ?)", field, v)` | 115–117 |

Macros: `lower_exists_dyn` (35–44), `upper_exists_dyn` (46–55), `lower_not_exists_dyn` (57–66), `upper_not_exists_dyn` (68–77).

### Unwrapped Value Wrapper (lines 119–131)

| Canonical Term | Emitted Dynamic | File:Line |
|---|---|---|
| `{op, {:value, {arith_op, _}}}` where op in [:==, :!=, :>, :>=, :<, :<=] and arith_op in [:+, :-, :*, :/] | **Warning** (line 121–124): `"arithmetic comparison (#{arith_op}) is not supported on array field #{inspect(key)}, skipping"` → returns `nil` | 119–127 |
| `{op, {:value, v}}` (other) | Recursive: `dispatch_expr(binding, key, {op, v})` | 129–131 |

### Quantified Comparisons (lines 133–161)

**:any quantifier** (lines 133–161):
| Canonical Term | Emitted Dynamic | File:Line |
|---|---|---|
| `{:==, {:any, qv}}` | `field == any(qv)` | 133–136 |
| `{:!=, {:any, qv}}` | `field != any(qv)` | 138–141 |
| `{:>, {:any, qv}}` | `field > any(qv)` | 143–146 |
| `{:>=, {:any, qv}}` | `field >= any(qv)` | 148–151 |
| `{:<, {:any, qv}}` | `field < any(qv)` | 153–156 |
| `{:<=, {:any, qv}}` | `field <= any(qv)` | 158–161 |

**:all quantifier** (lines 256–289):
Invert operator semantics: `{:all, {:>, v}}` → `? < ALL(?)` (inverses).

| Canonical Term | Emitted Dynamic | SQL | File:Line |
|---|---|---|---|
| `{:all, {:==, v}}` | `fragment("? = ALL(?)", v, field)` | `value = ALL(array)` | 256–259 |
| `{:all, {:!=, v}}` | `fragment("? != ALL(?)", v, field)` | `value != ALL(array)` | 261–264 |
| `{:all, {:>, v}}` | `fragment("? < ALL(?)", v, field)` | `value < ALL(array)` | 266–269 |
| `{:all, {:>=, v}}` | `fragment("? <= ALL(?)", v, field)` | `value <= ALL(array)` | 271–274 |
| `{:all, {:<, v}}` | `fragment("? > ALL(?)", v, field)` | `value > ALL(array)` | 276–279 |
| `{:all, {:<=, v}}` | `fragment("? >= ALL(?)", v, field)` | `value >= ALL(array)` | 281–284 |
| `{:all, {:in, [values]}}` (list) | `fragment("? <@ ?", field, values)` | `array <@ container` (subset) | 286–289 |

### Membership / Containment (lines 198–216)

| Canonical Term | Emitted Dynamic | SQL | File:Line |
|---|---|---|---|
| `{:==, value}` (scalar) | `fragment("value IN field")` via `value in field` | `value IN array` | 198–201 |
| `{:!=, value}` (scalar) | `fragment("value NOT IN field")` | `value NOT IN array` | 203–206 |
| `{:in, [values]}` (list) | `fragment("? && ?", field, values)` | `array && values` (overlap) | 208–211 |
| `{:in, value}` (scalar) | `fragment("value IN field")` | `value IN array` | 213–216 |

### Count Operator (lines 218–254)

| Canonical Term | Emitted Dynamic | File:Line |
|---|---|---|
| `{:count, {:==, 0}}` | `fragment("coalesce(array_length(?, 1), 0)", field) == 0` | 218–222 |
| `{:count, {:==, v}}` (v ≠ 0) | `fragment("array_length(?, 1)", field) == v` | 224–228 |
| `{:count, {:!=, v}}` | `fragment("array_length(?, 1)", field) != v` | 230–234 |
| `{:count, {:>, v}}` | `fragment("array_length(?, 1)", field) > v` | 236–239 |
| `{:count, {:>=, v}}` | `fragment("array_length(?, 1)", field) >= v` | 241–244 |
| `{:count, {:<, v}}` | `fragment("array_length(?, 1)", field) < v` | 246–249 |
| `{:count, {:<=, v}}` | `fragment("array_length(?, 1)", field) <= v` | 251–254 |

Note: Special case for `count = 0` wraps in `coalesce(array_length(...), 0)` to handle NULL arrays (line 221).

### Parent_as Comparisons (lines 163–196)

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

| Canonical Term | Emitted Dynamic | File:Line |
|---|---|---|
| `{:like, value\|[values]}` | `fragment("EXISTS (SELECT 1 FROM unnest(?) AS t WHERE t LIKE ANY (?))", field, patterns)` | 319–327 |
| `{:ilike, value\|[values]}` | `fragment("EXISTS (SELECT 1 FROM unnest(?) AS t WHERE t ILIKE ANY (?))", field, patterns)` | 329–337 |

Pattern wrapping: `wrap_patterns` (381–387) → `preserve_or_wrap_pattern` (389–399) (same as ScalarExpr).

### Unsupported Operators (with warnings)

| Operator | Message | File:Line |
|---|---|---|
| `:avg, :sum, :max, :min` | `"#{op} aggregate is not supported on array field #{inspect(key)}, skipping"` | 339–346 |
| `:any` (bare, not with quantifier) | `":any subquery quantifier is not supported on array field #{inspect(key)}, skipping"` | 348–355 |
| `:datetime, :date` | `"#{wrapper} comparison is not supported on array field #{inspect(key)}, skipping"` | 357–364 |
| `:parent_as` (malformed) | `":parent_as requires a {binding, field} payload, got unexpected form for field #{inspect(key)}, skipping"` | 366–373 |

### Negation Handler (lines 377–379)
```elixir
defp maybe_negate(nil, _negated), do: nil
defp maybe_negate(expr, :not), do: Query.dynamic([], not (^expr))
defp maybe_negate(expr, _negated), do: expr
```

### Purity Violations
None. All operations are pure SQL emissions. No field lookups or metadata access beyond field name passing.

---

## 3. MapExpr (`map_expr.ex`)

### Dispatch Architecture
Entry point: `dynamic_expr(binding, key, negated, term, _opts)` → `dispatch_expr(binding, key, term)` → `maybe_negate(result, negated)`.

No `@operators` declared; operators inferred from dispatch clause patterns.

### Nil & Equality Checks (lines 38–58)

| Canonical Term | Emitted Dynamic | File:Line |
|---|---|---|
| `{:==, nil}` | `is_nil(field)` | 38–40 |
| `{:!=, nil}` | `NOT is_nil(field)` | 42–45 |
| `{:==, value}` (scalar) | `field == value` | 48–52 |
| `{:!=, value}` (scalar) | `field != value` | 54–58 |

### JSONB Containment (lines 60–78)
**Operator: `:contains`** → SQL: `@>` (JSONB contains).

Three value forms:

| Canonical Term | Emitted Dynamic | File:Line |
|---|---|---|
| `{:contains, {k, v}}` (tuple, normalized from map) | `fragment("? @> ?::jsonb", field, %{k => v})` | 63–66 |
| `{:contains, value}` (binary, raw JSON string) | `fragment("? @> ?::jsonb", field, value)` | 69–72 |
| `{:contains, value}` (list, JSON array) | `fragment("? @> ?::jsonb", field, value)` | 75–78 |

### JSONB Contained-By (lines 80–94)
**Operator: `:contained_by`** → SQL: `<@` (JSONB contained by).

Three value forms (mirror of `:contains`):

| Canonical Term | Emitted Dynamic | File:Line |
|---|---|---|
| `{:contained_by, {k, v}}` (tuple) | `fragment("? <@ ?::jsonb", field, %{k => v})` | 81–84 |
| `{:contained_by, value}` (binary) | `fragment("? <@ ?::jsonb", field, value)` | 86–89 |
| `{:contained_by, value}` (list) | `fragment("? <@ ?::jsonb", field, value)` | 91–94 |

### JSONB Key Existence (lines 96–113)

| Operator | Canonical Term | Emitted Dynamic | File:Line |
|---|---|---|---|
| `:has_key` | `{:has_key, value}` (scalar key) | `fragment("jsonb_exists(?, ?)", field, value)` | 98–101 |
| `:has_any_key` | `{:has_any_key, [values]}` (list of keys) | `fragment("jsonb_exists_any(?, ?)", field, values)` | 104–107 |
| `:has_all_keys` | `{:has_all_keys, [values]}` (list of keys) | `fragment("jsonb_exists_all(?, ?)", field, values)` | 110–113 |

### Negation Handler (lines 117–119)
```elixir
defp maybe_negate(nil, _negated), do: nil
defp maybe_negate(expr, :not), do: Query.dynamic([], not (^expr))
defp maybe_negate(expr, _negated), do: expr
```

### Purity Violations
None. All operations are pure SQL emissions. No field name or metadata manipulation.

---

## 4. CommonExpr (`common_expr.ex`)

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
Entry point: `dynamic_expr(binding, operator, negated, term, _opts)` → `dispatch_expr(binding, operator, term)` → `maybe_negate(result, negated)`.

### ID Operators (lines 50–73)

| Operator | Canonical Term | Emitted Dynamic | File:Line |
|---|---|---|---|
| `:ids` | `[id_values]` (list) | `id in [...]` | 50–53 |
| `:after` | `id_value` (scalar) | `id > value` | 55–58 |
| `:before` | `id_value` (scalar) | `id < value` | 60–63 |
| `:since` | `id_value` (scalar) | `id >= value` | 65–68 |
| `:until` | `id_value` (scalar) | `id <= value` | 70–73 |

All operations target the hardcoded `:id` field via `field_dyn(binding, :id)` (line 51, 56, 61, 66, 71).

### Date Operators (lines 75–83)

| Operator | Canonical Term | Emitted Dynamic | File:Line |
|---|---|---|---|
| `:start_date`, `:since_date` | `timestamp` | `inserted_at >= timestamp` | 75–78 |
| `:end_date`, `:until_date` | `timestamp` | `inserted_at <= timestamp` | 80–83 |

Both pairs target hardcoded `:inserted_at` field (lines 76, 81).

### Exists Operator (lines 85–87)

| Operator | Canonical Term | Emitted Dynamic | File:Line |
|---|---|---|---|
| `:exists` | `term` (subquery) | `exists(term)` | 85–87 |

No field binding; passes `term` directly to `Ecto.Query.exists/1`.

### Negation Handler (lines 91–93)
```elixir
defp maybe_negate(nil, _negated), do: nil
defp maybe_negate(expr, :not), do: Query.dynamic([], not (^expr))
defp maybe_negate(expr, _negated), do: expr
```

### Purity Violations
1. **Hardcoded field names** (lines 51, 56, 61, 66, 71, 76, 81): `:id`, `:inserted_at` — violates purity by embedding schema assumptions.
   - Prevents reuse for schemas without these fields.
   - Couples operator semantics to EctoShorts convention (assumes all records have `id` and `inserted_at`).

---

## Summary: Purity Assessment

### Pure Modules
- **MapExpr**: No violations. All operations are parametric JSONB fragment emissions.
- **ArrayExpr**: No violations. All operations are parametric array fragment emissions.

### Modules with Violations
- **ScalarExpr**:
  - **Line 501, 509, 517, 749, 753, 775, 779**: Field name extraction from keyword params (`Keyword.get(params, :field)`) — introduces schema-dependent runtime lookup.
  - **Lines 483–490, 500–506, etc.**: `Keyword.fetch!` exceptions for missing `:count`, `:interval` — fallibility outside SQL domain.

- **CommonExpr**:
  - **Lines 50–87**: Hardcoded `:id` and `:inserted_at` field names — violates parametricity and domain purity.

---

## Full Dispatch Tables

### ScalarExpr dispatch_expr Entry Points

**Primary routing** (line 133–138):
```
family_for(op, value) →
  :membership       → membership_impl
  :string_transform → string_transform_impl
  :string           → string_impl
  :comparison       → comparison_impl
```

**family_for classification** (lines 799–820):
- `:in` → `:membership`
- `[:==, :!=] + list` → `:membership`
- `[:>, :>=, :<, :<=, :==, :!=] + {:lower|:upper, _}` → `:string_transform`
- `[:like, :ilike] + {:lower|:upper, _}` → `:string_transform`
- `[:like, :ilike]` → `:string`
- default → `:comparison`

