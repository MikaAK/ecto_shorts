# Advanced Filter Shapes — HTTP Encoding Review

Verdict: **none of the advanced shapes are Elixir-only.** All encode as a JSON
body. Only `parent_as` (correlated reference) is context-dependent — it must sit
inside an `exists`/subquery block — which is semantics, not an encoding limit.

## The unifying insight: one operand convention everywhere
A value being compared against is always one of four kinds, told apart by a single
reserved key:

| Kind | JSON | Meaning |
|---|---|---|
| Literal | `{"value": x}` (bare scalar is sugar) | a value, cast by the schema |
| Column | `{"field": "name"}` | another column on the current table |
| Subquery | `{"from": "<alias>", "where": {...}}` | a registered source + nested filter |
| Correlated | `{"parent": {"as": "post", "field": "id"}}` | an outer query's column |

This collapses core and advanced into one mental model: `%{column: %{op: operand}}`,
where `operand` is any of the four kinds (or a nested expression for math).

## Per-shape JSON (verified)
- **Column-to-column** (cleanest; query-string-encodable too):
  `{"a": {"gt": {"field": "b"}}}`
- **Arithmetic** (drop the `:arithmetic`/`compare` wrapper; operands as ordered
  arrays so non-commutative `sub`/`div` are unambiguous and no tuples appear):
  `{"score": {"gt": {"add": [{"field": "base"}, {"value": 5}]}}}`
- **Quantified subquery** (registered source alias, not a module):
  `{"id": {"eq": {"all": {"from": "published_posts", "where": {"published": true}}}}}`
- **Exists**: `{"exists": {"from": "comments", "where": {"approved": true}}}`
- **Correlated parent** (only inside exists/subquery; binding name server-validated):
  `{"exists": {"from": "comments", "where": {"post_id": {"eq": {"parent": {"as": "post", "field": "id"}}}}}}`

## Three recommendations
1. Adopt the single operand convention (`value`/`field`/`from`/`parent`) across the
   whole language — decoder becomes a closed match, never `String.to_atom`.
2. Represent arithmetic as nested JSON arrays, not two-key maps — removes the
   tuple-on-wire problem and operand-order ambiguity; mirrors core comparison.
3. Make correlation binding names explicit: a `from` may declare `"as": "post"`;
   descendants reference it via `{"parent": {...}}`; validate against ancestor-
   declared names in the same request.
