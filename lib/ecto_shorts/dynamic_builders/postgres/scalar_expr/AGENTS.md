# lib/ecto_shorts/dynamic_builders/postgres/scalar_expr — Scalar Expression Sub-modules

`scalar_expr.ex` in the parent directory is large. It delegates to the files in this directory to keep each concern small and focused.

## Files

| File | What it handles |
|---|---|
| `comparison.ex` | Equality and ordering operators: `==`, `!=`, `>`, `<`, `>=`, `<=`. Builds `dynamic/2` expressions like `p.field == ^value`. Also handles `is_nil` and its negation. |
| `membership.ex` | The `in` operator and its negated form `not in`. Accepts a list of values or a subquery. |
| `string.ex` | String matching: `like`, `ilike`, and their negated forms. Also handles `:starts_with`, `:ends_with`, `:contains` as shorthand patterns. |
| `string_transform.ex` | String transformation operators applied before comparison: `:lower`, `:upper`, `:trim`. These wrap the field reference in an SQL function call. |
| `aggregate.ex` | Aggregate functions: `count`, `sum`, `avg`, `min`, `max`. Used when the filter value includes an aggregate key — for example, `%{views: %{avg: %{>: 100}}}` inside a `:having` clause. |

## How the sub-modules relate to `scalar_expr.ex`

`scalar_expr.ex` receives a resolved `Predicate` struct with routing `:scalar` and dispatches to these sub-modules based on the operator in `predicate.expr`. For example:

- `{:==, value}` → `comparison.ex`
- `{:in, values}` → `membership.ex`
- `{:like, pattern}` → `string.ex`
- `{:lower, inner_expr}` → `string_transform.ex`
- `{:avg, inner_expr}` → `aggregate.ex`

## Testing

Tests for all scalar expression families live in:

```
test/ecto_shorts/dynamic_builders/postgres/scalar_expr_test.exs
```

They are organized by `describe` blocks tagged with `@describetag feature: :<name>`:
- `feature: :comparison` — equality and ordering
- `feature: :membership` — `in` / `not in`
- `feature: :string` — `like` / `ilike`
- `feature: :string_transform` — `:lower`, `:upper`, `:trim`
- `feature: :aggregate` — aggregate functions
- `feature: :negation` — negated forms of the above
