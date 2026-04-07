# Testing DynamicBuilders.Postgres sub-modules

**Tests for expression builders go through `Postgres.build_dynamic/4`, not
through `*Expr.dynamic_expr/5` directly.**

The internal normalized tuple forms (e.g. `{:contains, {:key, "value"}}`,
`{:>, 10}`, `{:count, {:==, 0}}`) are outputs of the `Normalizer` — they are
implementation details that can change without changing public behavior. Tests
must not construct or pass these tuples directly. Doing so:

- Couples the test to internal representation rather than public contract.
- Bypasses the Normalizer, leaving an untested gap between the external API
  and the expression builder.
- Makes tests fragile to any refactor of the normalization pipeline.

## Correct pattern — test via `Postgres.build_dynamic/4`

```elixir
alias EctoShorts.DynamicBuilders.Postgres
alias EctoShorts.Schema.Post

import Ecto.Query

# Scalar operator — use external map form
test "builds greater-than expression" do
  expected = dynamic([q], field(q, :views) > ^10)
  actual = Postgres.build_dynamic(Post, {:as, nil}, {:views, %{>: 10}}, [])
  assert_dynamic(expected, actual)
end

# Array operator — schema-backed source routes automatically
test "builds array overlap expression" do
  expected = dynamic([q], fragment("? && ?", field(q, :tags), ^["a", "b"]))
  actual = Postgres.build_dynamic(Post, {:as, nil}, {:tags, %{in: ["a", "b"]}}, [])
  assert_dynamic(expected, actual)
end

# Schemaless map/array — use field_types: opt to supply type metadata
test "builds JSONB containment for schemaless source" do
  expected = dynamic([q], fragment("? @> ?::jsonb", field(q, :data), ^%{key: "value"}))
  actual = Postgres.build_dynamic("stores", {:as, nil}, {:data, %{contains: %{key: "value"}}},
    field_types: [data: :map])
  assert_dynamic(expected, actual)
end
```

When the test covers behavior that requires a full `Ecto.Query` (named or
positional bindings, `assert_sql` verification), use a query source:

```elixir
test "builds greater-than expression on a named binding" do
  source = from(p in Post, as: :post)
  expected = from(p in Post, as: :post, where: p.views > ^10)

  actual_dyn = Postgres.build_dynamic(source, {:as, :post}, {:views, %{>: 10}}, [])
  actual = from(p in source, where: ^actual_dyn)

  assert_sql(expected, actual)
end
```
