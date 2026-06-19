# Pure Expr Modules + comparison_impl Decomposition — Implementation Plan (Plan 02 of 6)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the leaf Expr modules pure and break the 373-line `comparison_impl` in `ScalarExpr` into small, clearly-named family dispatchers — without changing any generated SQL.

**Architecture:** This is a **behavior-preserving refactor**, not new behavior. The existing `assert_sql` test suite is the safety net: it characterizes the SQL each filter produces today, and every task must keep it green. We (a) split `comparison_impl/4` into one function per operand family, (b) collapse the scalar leaf-generators into a single matrix, and (c) make `CommonExpr` pure by passing the target column in instead of hardcoding `:id`/`:inserted_at`.

**Tech Stack:** Elixir, Ecto. Tests via `mix test` (the existing suite); `EctoShorts.Testing.assert_sql/2` is the characterization assertion.

## Global Constraints

- **Behavior-preserving.** No generated SQL changes in this plan. The decisions that *do* change behavior (D-NULL, D-OPERAND, etc.) are Plans 03–04. If a refactor here would change SQL, it is out of scope — stop and leave it for the owning plan.
- **The existing suite is the contract for this plan.** Each task ends with `mix test` fully green. (Per spec §5, the suite is reconciled to the spec in later plans; in *this* plan we preserve current behavior so the refactor is provably safe.)
- **Never use `alias Module, as: X`** — use the plain alias and the module's last segment. (Project convention.)
- **TDD note:** because this is a refactor, the cycle is *establish green → refactor → re-verify green → commit*, not *write failing test → implement*. Where a family currently lacks a focused test, add a characterization test (real `assert_sql`) capturing today's SQL **before** moving its clauses.
- The "shrink `build_dynamic` to a thin adapter over `TermResolver` output" work is **not** here — it is Plan 05 (wiring), because it only makes sense once `TermResolver` feeds the adapter.

---

### Task 1: Baseline + extract `scalar_comparison/4`

**Files:**
- Modify: `lib/ecto_shorts/dynamic_builders/postgres/scalar_expr.ex` (`comparison_impl/4`, lines 252–624; nil + scalar clauses at 256–316)
- Test: `test/ecto_shorts/common_filters/common_filters_comparison_operators_test.exs` (existing) and `..._negation_test.exs` (existing)

**Interfaces:**
- Produces (internal): `scalar_comparison(binding, key, negated, {op, value}) :: dynamic` — handles nil checks (`{:==, nil}`/`{:!=, nil}`) and scalar comparisons (`:==`/`:!=`/`:>`/`:>=`/`:<`/`:<=` with a non-tuple value), exactly the SQL the current `comparison_impl` clauses at lines 256–316 produce.

- [ ] **Step 1: Establish the green baseline**

Run: `mix test test/ecto_shorts/common_filters/common_filters_comparison_operators_test.exs test/ecto_shorts/common_filters/common_filters_negation_test.exs`
Expected: PASS. (If not green on a clean checkout, stop — the baseline must be green before refactoring.)

- [ ] **Step 2: Add `scalar_comparison/4` and route the scalar/nil families to it**

In `scalar_expr.ex`, add a new private function and have `comparison_impl/4` delegate the nil + scalar cases to it. Move the clauses currently at lines 256–316 verbatim:

```elixir
# comparison_impl keeps the term-building, then routes by family.
defp comparison_impl(binding, key, negated, {op, value}) do
  term = if negated === :not, do: {:not, {op, value}}, else: {op, value}

  cond do
    nil_or_scalar?(term) -> scalar_comparison(binding, key, term)
    # ... the other families stay inline for now; later tasks extract them ...
    true -> comparison_impl_rest(binding, key, term)
  end
end

defp nil_or_scalar?({op, v}) when op in [:==, :!=] and (is_nil(v) or not is_tuple(v)), do: true
defp nil_or_scalar?({:not, {op, v}}) when op in [:==, :!=] and (is_nil(v) or not is_tuple(v)), do: true
defp nil_or_scalar?({op, v}) when op in [:>, :>=, :<, :<=] and not is_tuple(v), do: true
defp nil_or_scalar?({:not, {op, v}}) when op in [:>, :>=, :<, :<=] and not is_tuple(v), do: true
defp nil_or_scalar?(_), do: false

# scalar_comparison receives the already-negation-folded `term`.
defp scalar_comparison(binding, key, {:==, nil}), do: nil_field_dyn?(binding, key)
defp scalar_comparison(binding, key, {:not, {:==, nil}}), do: not_nil_dyn(binding, key)
defp scalar_comparison(binding, key, {:!=, nil}), do: not_nil_dyn(binding, key)
defp scalar_comparison(binding, key, {:not, {:!=, nil}}), do: nil_field_dyn?(binding, key)
defp scalar_comparison(binding, key, {:not, {op, v}}) when op in [:==, :!=, :>, :>=, :<, :<=] do
  apply_scalar_comparison(op, field_dyn(binding, key), v, :negated)
end
defp scalar_comparison(binding, key, {op, v}) when op in [:==, :!=, :>, :>=, :<, :<=] do
  apply_scalar_comparison(op, field_dyn(binding, key), v, :plain)
end
```

> This reuses the existing `apply_scalar_comparison/4` (lines 632–643) and the existing `field_dyn`/`nil_field_dyn?`/`not_nil_dyn` helpers — so the emitted SQL is byte-identical. `comparison_impl_rest/3` is the remaining `case` body (the clauses below line 316) moved verbatim into a sibling function; Tasks 2–4 carve families out of it.

- [ ] **Step 3: Re-verify green**

Run: `mix test test/ecto_shorts/common_filters/common_filters_comparison_operators_test.exs test/ecto_shorts/common_filters/common_filters_negation_test.exs`
Expected: PASS — identical SQL, now produced via `scalar_comparison/4`.

- [ ] **Step 4: Full suite**

Run: `mix test`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/ecto_shorts/dynamic_builders/postgres/scalar_expr.ex
git commit -m "refactor(scalar_expr): extract scalar_comparison/4 from comparison_impl (no SQL change)"
```

---

### Task 2: Extract `quantified_comparison/4`

**Files:**
- Modify: `lib/ecto_shorts/dynamic_builders/postgres/scalar_expr.ex` (quantified clauses, lines 318–413)
- Test: `test/ecto_shorts/common_filters/common_filters_comparison_operators_test.exs` (the `all`/`any` tests)

**Interfaces:**
- Produces (internal): `quantified_comparison(binding, key, term) :: dynamic` — handles `{op, {:all | :any, qv}}` (and negated) for all six comparison ops, producing today's `field OP ALL/ANY(qv)` SQL.

- [ ] **Step 1: Establish green baseline**

Run: `mix test test/ecto_shorts/common_filters/common_filters_comparison_operators_test.exs`
Expected: PASS.

- [ ] **Step 2: Move the quantified clauses into `quantified_comparison/3`**

Add a `nil_or_scalar?`-style guard `quantified?({op, {q, _}}) when q in [:all, :any]` (and negated variant), route from `comparison_impl_rest/3` to `quantified_comparison/3`, and move the clauses at lines 318–413 verbatim into it (they already only reference `field_dyn` and literal `dynamic` fragments):

```elixir
defp quantified?({_op, {q, _}}) when q in [:all, :any], do: true
defp quantified?({:not, {_op, {q, _}}}) when q in [:all, :any], do: true
defp quantified?(_), do: false

defp quantified_comparison(binding, key, {:==, {:all, qv}}) do
  f = field_dyn(binding, key)
  dynamic([], ^f == all(^qv))
end
# ... move the remaining quantified clauses (lines 327–413) here verbatim ...
```

And in `comparison_impl_rest/3`, add `quantified?(term) -> quantified_comparison(binding, key, term)` before the remaining families.

- [ ] **Step 3: Re-verify green**

Run: `mix test test/ecto_shorts/common_filters/common_filters_comparison_operators_test.exs`
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add lib/ecto_shorts/dynamic_builders/postgres/scalar_expr.ex
git commit -m "refactor(scalar_expr): extract quantified_comparison (no SQL change)"
```

---

### Task 3: Extract `aggregate_comparison/4`

**Files:**
- Modify: `lib/ecto_shorts/dynamic_builders/postgres/scalar_expr.ex` (aggregate clauses, lines 415–479)
- Test: `test/ecto_shorts/common_filters/common_filters_aggregate_operators_test.exs`, `..._having_test.exs`

**Interfaces:**
- Produces (internal): `aggregate_comparison(binding, key, term) :: dynamic` — handles `{helper, {op, value}}` for `helper in [:avg, :count, :max, :min, :sum]` (and the helper-vs-nil and negated variants), producing today's `agg(field) OP value` SQL via the generated `*_field_dyn` helpers.

- [ ] **Step 1: Establish green baseline**

Run: `mix test test/ecto_shorts/common_filters/common_filters_aggregate_operators_test.exs test/ecto_shorts/common_filters/common_filters_having_test.exs`
Expected: PASS.

- [ ] **Step 2: Move the aggregate clauses into `aggregate_comparison/3`**

Add the guard and move lines 415–479 verbatim:

```elixir
@aggregate_helpers [:avg, :count, :max, :min, :sum]  # if not already a module attr

defp aggregate?({h, {_op, _}}) when h in @aggregate_helpers, do: true
defp aggregate?({:not, {h, {_op, _}}}) when h in @aggregate_helpers, do: true
defp aggregate?(_), do: false

defp aggregate_comparison(binding, key, {h, {:==, nil}}) when h in @aggregate_helpers do
  nil_field_dyn?(agg_target(binding, key, h))  # uses existing agg_field_dyn routing
end
# ... move remaining aggregate clauses (lines 420–479) here verbatim ...
```

> Keep using the existing `agg_field_dyn`/`avg_field_dyn`/… helpers exactly as the current clauses do; only their *location* changes. Route `aggregate?(term) -> aggregate_comparison(binding, key, term)` from `comparison_impl_rest/3`.

- [ ] **Step 3: Re-verify green**

Run: `mix test test/ecto_shorts/common_filters/common_filters_aggregate_operators_test.exs test/ecto_shorts/common_filters/common_filters_having_test.exs`
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add lib/ecto_shorts/dynamic_builders/postgres/scalar_expr.ex
git commit -m "refactor(scalar_expr): extract aggregate_comparison (no SQL change)"
```

---

### Task 4: Extract the advanced families (`datetime`/`arithmetic`/`parent_as`)

**Files:**
- Modify: `lib/ecto_shorts/dynamic_builders/postgres/scalar_expr.ex` (datetime 481–569, arithmetic 571–584, parent_as 595–610, value-wrapper 586–593, fallback 612–621)
- Test: `..._datetime_wrappers_test.exs`, `..._date_wrappers_test.exs`, `..._parent_as_test.exs`

**Interfaces:**
- Produces (internal): `datetime_comparison/3`, `arithmetic_comparison/3`, `parent_as_comparison/3`, and a final `scalar_value_fallback/3` (the `{:value, v}` and generic `{op, v}` catch-alls). Each produces today's SQL.

> These families are **reworked** in Plan 03 (operand convention, `shift`, sibling `as:`). Here we only **relocate** them so `comparison_impl` becomes a clean router. Their internal `Keyword.fetch!`/`Keyword.get(:field)` impurities (lines 501–506, 731–777) are **left as-is** and fixed in Plan 03 when the operand convention supplies those values pre-resolved.

- [ ] **Step 1: Establish green baseline**

Run: `mix test test/ecto_shorts/common_filters/common_filters_datetime_wrappers_test.exs test/ecto_shorts/common_filters/common_filters_date_wrappers_test.exs test/ecto_shorts/common_filters/common_filters_parent_as_test.exs`
Expected: PASS.

- [ ] **Step 2: Relocate each family into its own function**

Move lines 481–569 → `datetime_comparison/3`; 571–584 → `arithmetic_comparison/3`; 595–610 → `parent_as_comparison/3`; 586–593 + 612–621 → `scalar_value_fallback/3`. Then `comparison_impl_rest/3` becomes a pure router:

```elixir
defp comparison_impl_rest(binding, key, term) do
  cond do
    datetime?(term)  -> datetime_comparison(binding, key, term)
    arithmetic?(term) -> arithmetic_comparison(binding, key, term)
    parent_as?(term) -> parent_as_comparison(binding, key, term)
    true -> scalar_value_fallback(binding, key, term)
  end
end
```

Add the matching `datetime?/1`, `arithmetic?/1`, `parent_as?/1` guards (shape-matching the term forms the moved clauses expect). The moved clause bodies are unchanged.

- [ ] **Step 3: Collapse `comparison_impl/4` to the family router**

`comparison_impl/4` now reads as: build `term`, then `cond` over the family predicates (`nil_or_scalar?`, `quantified?`, `aggregate?`, then `comparison_impl_rest`). Confirm it is short (≈10 lines) and every former clause lives in a named family function.

- [ ] **Step 4: Re-verify green + full suite**

Run: `mix test`
Expected: PASS — the 373-line monolith is now a router plus six small family functions, identical SQL.

- [ ] **Step 5: Commit**

```bash
git add lib/ecto_shorts/dynamic_builders/postgres/scalar_expr.ex
git commit -m "refactor(scalar_expr): comparison_impl is now a family router (no SQL change)"
```

---

### Task 5: Make `CommonExpr` pure (pass the column in)

**Files:**
- Modify: `lib/ecto_shorts/dynamic_builders/postgres/common_expr.ex` (remove hardcoded `:id`/`:inserted_at`)
- Modify: `lib/ecto_shorts/dynamic_builders/postgres.ex` (the caller that dispatches the common-expr operators — around line 287)
- Test: add `test/ecto_shorts/dynamic_builders/postgres/common_expr_test.exs` (new — CommonExpr has no isolated test today)

**Interfaces:**
- Consumes: a `field` resolved by the caller.
- Produces: `CommonExpr.dynamic_expr(selected_binding, operator, field, negated, term, opts)` — the operator's target column arrives as `field` (e.g. `:id` for `:ids`/`:before`/…, `:inserted_at` for `:start_date`/…); `CommonExpr` no longer contains any column literal. `:exists` ignores `field` (passes `nil`).
- New caller helper: `EctoShorts.DynamicBuilders.Postgres.common_field_for(operator) :: atom() | nil` — maps the operator to its column (`:id` / `:inserted_at` / `nil` for `:exists`). (In Plan 05 this mapping moves into `TermResolver`; here it lives at the caller so the behavior is unchanged.)

- [ ] **Step 1: Write the failing test (characterization, now isolatable because CommonExpr takes the field)**

```elixir
defmodule EctoShorts.DynamicBuilders.Postgres.CommonExprTest do
  use ExUnit.Case, async: true

  alias EctoShorts.DynamicBuilders.Postgres.CommonExpr

  test "ids builds an `in` over the given column" do
    dyn = CommonExpr.dynamic_expr({:as, nil}, :ids, :id, nil, [1, 2, 3], [])
    assert %Ecto.Query.DynamicExpr{} = dyn
  end

  test "start_date builds `>=` over the given column (no hardcoded inserted_at)" do
    dyn = CommonExpr.dynamic_expr({:as, nil}, :start_date, :published_at, nil, ~U[2026-01-01 00:00:00Z], [])
    assert %Ecto.Query.DynamicExpr{} = dyn
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/ecto_shorts/dynamic_builders/postgres/common_expr_test.exs`
Expected: FAIL — `dynamic_expr/6` undefined (current arity is 5, and the column is hardcoded).

- [ ] **Step 3: Make `CommonExpr` take the field**

Rewrite `common_expr.ex` so the generated entry is `dynamic_expr/6` and `dispatch_expr` uses the passed `field`:

```elixir
for {quoted_binding_head, quoted_binding_body} <- binding_patterns do
  def dynamic_expr(unquote(quoted_binding_head) = selected_binding, operator, field, negated, term, _opts) do
    selected_binding
    |> dispatch_expr(operator, field, term)
    |> maybe_negate(negated)
  end

  defp field_dyn(unquote(quoted_binding_head), field_name) do
    Query.dynamic([unquote_splicing(quoted_binding_body)], field(unquote(target_binding_var), ^field_name))
  end
end

def dynamic_expr(_selected_binding, _operator, _field, _negated, _term, _opts), do: nil

defp dispatch_expr(binding, :ids, field, term) do
  dyn = field_dyn(binding, field)
  Query.dynamic([], ^dyn in ^term)
end

defp dispatch_expr(binding, :after, field, term) do
  dyn = field_dyn(binding, field)
  Query.dynamic([], ^dyn > ^term)
end

defp dispatch_expr(binding, :before, field, term) do
  dyn = field_dyn(binding, field)
  Query.dynamic([], ^dyn < ^term)
end

defp dispatch_expr(binding, :since, field, term) do
  dyn = field_dyn(binding, field)
  Query.dynamic([], ^dyn >= ^term)
end

defp dispatch_expr(binding, :until, field, term) do
  dyn = field_dyn(binding, field)
  Query.dynamic([], ^dyn <= ^term)
end

defp dispatch_expr(binding, operator, field, term) when operator in [:start_date, :since_date] do
  dyn = field_dyn(binding, field)
  Query.dynamic([], ^dyn >= ^term)
end

defp dispatch_expr(binding, operator, field, term) when operator in [:end_date, :until_date] do
  dyn = field_dyn(binding, field)
  Query.dynamic([], ^dyn <= ^term)
end

defp dispatch_expr(_binding, :exists, _field, term) do
  Query.dynamic([], exists(term))
end

defp dispatch_expr(_binding, _operator, _field, _term), do: nil
```

- [ ] **Step 4: Update the caller in `postgres.ex` to resolve and pass the field**

Add `common_field_for/1` and pass it at the dispatch site (~line 287):

```elixir
defp common_field_for(op) when op in [:ids, :before, :after, :since, :until], do: :id
defp common_field_for(op) when op in [:start_date, :end_date, :since_date, :until_date], do: :inserted_at
defp common_field_for(:exists), do: nil

# at the common-expr dispatch site:
CommonExpr.dynamic_expr(selected_binding, key, common_field_for(key), negated, term, opts)
```

- [ ] **Step 5: Run the new test + the suite**

Run: `mix test test/ecto_shorts/dynamic_builders/postgres/common_expr_test.exs && mix test`
Expected: PASS — `CommonExpr` is now pure (no column literals); the `:ids`/`:before`/`:start_date`/etc. behavior is unchanged (same `:id`/`:inserted_at` targets, supplied by the caller).

- [ ] **Step 6: Verify purity mechanically**

Run: `grep -nE ":id\b|:inserted_at" lib/ecto_shorts/dynamic_builders/postgres/common_expr.ex`
Expected: no matches (no hardcoded column names remain).

- [ ] **Step 7: Commit**

```bash
git add lib/ecto_shorts/dynamic_builders/postgres/common_expr.ex lib/ecto_shorts/dynamic_builders/postgres.ex test/ecto_shorts/dynamic_builders/postgres/common_expr_test.exs
git commit -m "refactor(common_expr): pass the column in; remove hardcoded :id/:inserted_at"
```

---

## Self-Review (done while writing)

- **Spec coverage:** D1 (decompose `comparison_impl` + family functions) → Tasks 1–4; D-CommonExpr-FIELD / B1–B2 (pure `CommonExpr`) → Task 5. The scalar leaf-matrix stays as the existing `apply_scalar_comparison/4` (already a clean 12-clause matrix); the larger `apply_arith_comparison` (48) collapse rides with Plan 03, where arithmetic is reshaped to the operand convention — collapsing it here would risk an SQL change with no behavioral payoff.
- **Placeholders:** none. Bulk verbatim clause relocations are given as exact line ranges + the destination function and the routing predicate, which is a precise mechanical instruction (not "similar to Task N").
- **Type consistency:** `CommonExpr.dynamic_expr/6` (added `field` arg) is matched by the single caller change in `postgres.ex`; `common_field_for/1` returns the column the old hardcoded clauses used. The family-function names (`scalar_comparison`, `quantified_comparison`, `aggregate_comparison`, `datetime_comparison`, `arithmetic_comparison`, `parent_as_comparison`, `scalar_value_fallback`) are introduced once and reused by the `comparison_impl` router.
- **Carried to Plan 03:** the datetime/arithmetic/parent_as families still hold the `Keyword.fetch!`/`Keyword.get(:field)` impurities; Plan 03 removes them when `TermResolver` supplies pre-resolved operands (`shift`, sibling `as:`, ordered-array arithmetic).
- **Carried to Plan 05:** `common_field_for/1` moves into `TermResolver` (the field is filled in upstream per D-CommonExpr-FIELD); `CommonExpr` stays pure.
