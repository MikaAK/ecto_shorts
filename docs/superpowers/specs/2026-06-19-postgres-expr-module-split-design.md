# Postgres Expression Module Split — Design

**Date:** 2026-06-19
**Status:** Approved (brainstorming)
**Scope:** `lib/ecto_shorts/dynamic_builders/postgres/*`

## Problem

Each Postgres expression module runs its own binding-generation loop:

```elixir
{target_binding_var, binding_patterns} = QueryBinding.query_binding_contracts(__MODULE__)

for {quoted_binding_head, quoted_binding_body} <- binding_patterns do
  defp field_dyn(unquote(quoted_binding_head), key) do ... end
  # ... more accessors, each emitted once per binding pattern
end
```

`binding_patterns` contains the root binding, the named binding, and one entry per
positional binding up to `max_positional_bindings` (default 10) — roughly **12 patterns**.
Every accessor function defined inside the loop is therefore generated ~12 times.

Current state:

| Module | Lines | Binding loop? | Accessor helpers in loop |
|---|---|---|---|
| `scalar_expr.ex` | 1093 | yes | ~18 (`field_dyn`, `nil_field_dyn?`, `not_nil_dyn`, `date_field_dyn`, `lower/upper/trim/ltrim/rtrim_field_dyn`, `avg/count/max/min/sum_field_dyn`, `membership_in_dyn`, `membership_not_in_dyn`) |
| `array_expr.ex` | 405 | yes | 5 (`field_dyn`, `lower/upper_exists_dyn`, `lower/upper_not_exists_dyn`) |
| `map_expr.ex` | 120 | yes | `field_dyn` + JSONB helpers |
| `common_expr.ex` | 96 | yes | `field_dyn` + cursor/date helpers |

Two compounding costs:

1. **Total generated clause count.** `scalar_expr` alone is ~18 × 12 ≈ **216 generated
   clauses** in one file. Every new operator that adds a binding-scoped accessor multiplies by ~12.
2. **Duplication.** `field_dyn/2` (plain `field(binding, ^key)`) is generated identically in
   all four modules — 4 × 12 ≈ 48 clauses for one expression.

As the operator set grows, both the per-file compile cost and the total clause count grow
multiplicatively.

## Key architectural finding

Binding scope is already isolated to a thin set of `*_field_dyn` primitives. Every operator
composes the **returned dynamic value** without re-entering binding scope:

```elixir
defp scalar_comparison(binding, key, {:==, v}) when not is_tuple(v) do
  f = field_dyn(binding, key)      # the only binding-scoped call
  dynamic([], ^f == ^v)            # composition — empty binding list, pins ^f
end

defp string_impl(binding, key, _negated, {:ilike, v}) do
  f = field_dyn(binding, key)
  dynamic([], ilike(^f, ^preserve_or_wrap_pattern(v)))
end
```

Therefore **all** `*_impl`, `scalar_comparison`, and predicate-guard functions are already
binding-agnostic — single clause per arity, not multiplied. The only ×12 code is the
field-accessor primitives.

## Goal

Both:

- **Reduce total clean-compile clause count** (dedup the binding-multiplied primitives).
- **Reduce incremental recompile cost + improve readability** (split the large logic file).

## Approach — Hybrid (A then B)

Centralize the binding-multiplied accessors into one shared generated module, **then** split
`scalar_expr`'s now-plain logic into operator-family sub-modules. Done as two independently
verifiable phases so the dedup (the risky part) lands and is test-verified before the
cosmetic split.

### Target module layout

```
postgres/
  field_accessors.ex          — the ONLY module that runs the binding loop.
                                 Generates field_dyn/2 ×12 (+ minimal generated
                                 fallbacks if Ecto cannot compose a form).
  scalar_expr.ex              — router: operators/0, dynamic_expr/5 entry,
                                 dispatch_expr + predicate guards; delegates to:
  scalar/
    comparison.ex             — scalar / operand / parent_as / quantified comparisons
    string.ex                 — like / ilike (incl. LIKE ANY)
    string_transform.ex       — lower / upper / trim / ltrim / rtrim
    membership.ex             — in / not in
    aggregate.ex              — avg / count / max / min / sum comparisons
  array_expr.ex
  map_expr.ex                 — keep dispatch logic; drop their own loops;
  common_expr.ex                call FieldAccessors instead.
```

**Invariant:** binding scope is touched in exactly one place (`FieldAccessors`). Every other
module is plain, binding-agnostic logic. New operators that are pure logic add **zero**
generated clauses.

`ScalarExpr` remains the public entry point — preserving CLAUDE.md's rule that
operator/predicate tests live in the implementing module's test file
(`scalar_expr_test.exs`), exercised through the public `common_filters.ex` entry.

## The `FieldAccessors` contract

Exposes the binding-scoped primitive — the one function generated per binding pattern:

```elixir
def field_dyn(selected_binding, key) :: %Ecto.Query.DynamicExpr{}
```

Every former accessor becomes plain composition over its returned dynamic, with no binding in scope:

| Before (generated ×12, per module) | After (single clause, composes `^f`) |
|---|---|
| `lower_field_dyn(b, k)` | `dynamic([], fragment("lower(?)", ^field_dyn(b, k)))` |
| `upper_field_dyn(b, k)` | `dynamic([], fragment("upper(?)", ^field_dyn(b, k)))` |
| `date_field_dyn(b, k)` | `dynamic([], fragment("date(?)", ^field_dyn(b, k)))` |
| `trim/ltrim/rtrim_field_dyn(b, k)` | same shape, different fragment string |
| `nil_field_dyn?(b, k)` | `dynamic([], is_nil(^field_dyn(b, k)))` |
| `not_nil_dyn(b, k)` | `dynamic([], not is_nil(^field_dyn(b, k)))` |

### Test-first fallback rule (aggressive dedup, verified)

The aim is for `field_dyn/2` to be the **only** generated primitive. Each rewrite is proven
by a test asserting the produced query equals the old one **before** the old accessor is
deleted. Forms that carry real Ecto-composition risk must be proven first; if Ecto rejects a
pinned dynamic in that position, the form stays as a generated primitive in `FieldAccessors`
(still deduped to one module, just still ×12):

- **Aggregates** — `dynamic([], avg(^field_dyn(b, k)))` and the other four. Aggregate
  functions may require the field literally in binding scope.
- **Array/JSONB fragment helpers** — `array_expr`'s `lower_exists_dyn` etc. and `map_expr`'s
  JSONB operators — same test-first treatment.

`FieldAccessors`' final surface = `field_dyn/2` **plus** whatever minimal set fails
composition. The decision per form is recorded as tests resolve it, not guessed up front.

## Sequencing

Each step must be green before the next begins.

1. **Create `FieldAccessors`** with `field_dyn/2` (move the loop + the universal primitive).
   Add `field_accessors_test.exs` covering each binding shape (root, named, positional,
   first, last).
2. **Migrate `common_expr` → `map_expr` → `array_expr`** (smallest first) onto
   `FieldAccessors`; rewrite each accessor as composition (TDD per the fallback rule); delete
   the local loop. Run that module's existing test file after each migration.
3. **Migrate `scalar_expr`'s accessors** onto `FieldAccessors` (still one file at this point).
4. **Split `scalar_expr` logic** into the `scalar/` family modules; `ScalarExpr` becomes the
   router delegating to them. Pure code-move — no behavior change.

## Testing & verification

- **Adapter contract** (`test/support/filter_contract.ex`, walked from
  `dynamic_builders/postgres/contract_test.exs`) is the behavioral oracle — green at **every** step.
- **Feature-tagged describe blocks** (`scalar_expr_test.exs`, `array_expr_test.exs`,
  `map_expr_test.exs`, `common_expr_test.exs`) already cover the operators. No test
  reorganization needed since `ScalarExpr` stays the public entry.
- **New:** `field_accessors_test.exs` mirroring the new lib file (per the test-mirror rule).
- **Before "done":** `mix test`, `mix credo`, `mix dialyzer` all clean.
- **Compile-cost evidence (optional, recorded in this spec on completion):** `mix compile
  --force` timing and generated-clause count before/after, to confirm the goal was met.

## Risks & mitigations

| Risk | Mitigation |
|---|---|
| Ecto won't compose a form (e.g. aggregates) | Falls back to a generated primitive in `FieldAccessors`. Caught by TDD, not a blocker. |
| Behavior drift during the split | Contract test + feature tests run after every step. |
| New shared module is a recompile hub | Acceptable — `field_dyn` is stable and rarely edited, which is exactly why centralizing it is safe. |

## Process notes

- Implementation is delegated to the `claude-copilot:code-implementer` agent per RULES.md.
- New filter/expr modules must call `QueryBinding.query_binding_contracts/1` at module-body
  level — but under this design only `FieldAccessors` does so, by construction.
