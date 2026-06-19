# Probe Summary — Plan for Reworking the Query-Building Code

This file gives the short version of the plan: what the user wants, the order of
work, and a config block saved for a later automated pass.

## Words used here

- Ecto: the Elixir library for talking to a database.
- Query building: turning a caller's filter parameters into a database request.
- Normalization / normalization pattern: a separate step that rewrites all the
  input into one standard shape before building the query. The team wants to
  avoid this.
- Transform-at-leaf: tidy each filter piece at the moment it is handled, instead
  of rewriting everything up front.
- Reduce / fold: go through the items one by one, building up the result.
- Resolver: the step that translates a caller's input into the standard form.
- Dialect-agnostic: not tied to one database brand; works the same regardless of
  which database is used.
- Expr modules / pure: the small helper modules that build the final query
  conditions. "Pure" means they only turn input into output without looking
  things up or changing anything else.
- Operator alias: a nickname for a comparison word (for example, "eq" for
  "equals").
- Cast / casting: convert a value to the type the column expects.
- Public contract / internal contract: the promises the code makes to outside
  callers / the promises its internal parts make to each other.
- Spec: the specification document — the agreed description of how things should
  behave.
- Test audit: going through the existing tests one by one to check them against
  the spec.

---

- **Rounds:** 4 · **Constraints:** 20 across 7 categories · **Status:** SATURATED
- **Net-new trend:** R1 ~6 → R2 ~6 → R3 ~5 → R4 ~3 (refinements only) → saturated.
- **Open seams (see conflicts.md):** what to match behavior against (T2), and the
  line between "no normalization pass" and "canonical grammar" (T3).

## What the user actually wants (one paragraph)

Not "move normalization into one layer" — **get rid of the normalization pattern
completely.** Replace the multi-pass rewrite (`build_dynamic` → `apply_expr` →
`dispatch_expr` → `cast_value`) with a **single reduce that folds the params into
one combined database condition**, tidying each entry into its standard form **at
the leaf** (with nicknames handled as dispatch branches), and with casting,
field-resolution, and turning input into the standard form pulled out into a
**dialect-agnostic thin resolver**. The `*Expr` modules become **pure builders of
the final condition** that only ever see canonical terms. And before any of this:
a **self-contained specification** of `convert_params_to_filter/3` — the closed
canonical-term grammar, all public and internal contracts, and the behavior where
the parts meet — because the **tests cannot be trusted as the source of truth.**

## Order of deliverables (agreed — G5)

1. **Specification document** for `convert_params_to_filter/3` (this is the
   brainstorming "design doc"; it must be approved before any code).
2. **Test audit** — reconcile the tests against the spec, one case at a time.
3. **writing-plans** — build the implementation plan from the approved spec.
4. **Implement** (handed off to `claude-copilot:code-implementer` per RULES.md).

## Derived config block (for a later autoresearch:fix/ship pass — NOT now)

```yaml
goal: >
  Refactor EctoShorts query building to a single reduce with transform-at-leaf,
  pure dialect-specific Expr modules, and a dialect-agnostic resolver — matching
  the approved convert_params_to_filter/3 specification exactly.
scope:
  - lib/ecto_shorts/common_filters.ex
  - lib/ecto_shorts/common_filters/**
  - lib/ecto_shorts/dynamic_builders/**
metric: >
  All tests reconciled to the spec pass; ScalarExpr/ArrayExpr/MapExpr contain
  zero aliasing/casting/field-resolution/schema-reflection; comparison_impl
  decomposed; sort_filter_params single-pass; public API unchanged.
verify:
  - mix test
  - mix credo
  - mix dialyzer
  - grep -nE "cast|to_existing_atom|op_alias|get_schema_reflection" lib/ecto_shorts/dynamic_builders/postgres/{scalar,array,map}_expr.ex  # must be empty
direction: minimize_complexity_preserve_public_behavior
```
