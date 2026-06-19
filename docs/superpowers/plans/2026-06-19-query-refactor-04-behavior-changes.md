# Behavior Changes (D-NULL / D-RAISE / D-ONE-WAY / D-PROVIDER / single-pass sort) — Implementation Plan (Plan 04 of 6)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Apply the deliberate v3.0.0 behavior changes that are concrete edits to the existing pipeline: single-pass param sorting, the null-semantics change, removing the `:aggregate` wrapper, raising on caller mistakes, and the checked provider contract.

**Architecture:** Each is a focused edit to a current module, paired with the test reconciliation the audit flagged for that decision. Most flip an existing warn-and-skip test to an `assert_raise` (or assert the new SQL). A small `EctoShorts.FilterError` exception is introduced for the raises.

**Tech Stack:** Elixir, Ecto. Tests via the existing pipeline (`CommonFilters.convert_params_to_filter`), `assert_query`/`assert_sql`, `ExUnit.CaptureLog`, and `assert_raise`.

## Global Constraints

- Builds on Plans 01–03 (merged first).
- **Subquery operands (`from`/`all`/`any`/`exists`/`parent`) and aggregate→HAVING placement are NOT here** — they need the resolver wiring and move to Plan 05.
- **Never use `alias Module, as: X`** (project convention).
- The decisions and their exact rules are in spec §3.9 (D-RAISE), §3.10 (D-PROVIDER), §3.5/§3.11 (D-NULL), §3.2 (D2 sort), §0.4 (D-ONE-WAY). The per-test verdicts are in `docs/superpowers/specs/test-audit.md`.
- Raising uses `EctoShorts.FilterError` (Task 4 creates it). `{:error, reason}` *in-contract* provider returns still warn-and-skip (D-PROVIDER).

---

### Task 1: Single-pass `sort_filter_params/1` (D2)

**Files:**
- Modify: `lib/ecto_shorts/common_filters.ex:526-538`
- Test: `test/ecto_shorts/common_filters/common_filters_sorting_test.exs` (new — a focused unit test for the ordering)

**Interfaces:**
- Produces: `sort_filter_params(params)` orders entries `:where` → others → `:or_where` → terminal (`:last`, `:subquery`) — identical to today — in **one** pass instead of four `Enum.filter` scans.

- [ ] **Step 1: Write the failing test (characterize the order, one pass)**

```elixir
defmodule EctoShorts.CommonFilters.SortingTest do
  use ExUnit.Case, async: true

  test "orders where -> others -> or_where -> terminal, preserving within-group order" do
    params = [or_where: %{x: 1}, limit: 10, where: %{a: 1}, subquery: %{}, where: %{b: 2}, last: 5]
    # The private function is exercised through the public entry; assert the applied order
    # via a deterministic sorter hook is overkill — instead test the helper directly by
    # temporarily making it public OR assert behavior through convert_params_to_filter order.
    assert EctoShorts.CommonFilters.sort_filter_params(params) ==
             [where: %{a: 1}, where: %{b: 2}, limit: 10, or_where: %{x: 1}, last: 5, subquery: %{}]
  end
end
```

> Make `sort_filter_params/1` public (`def`) for this test, or add a `@doc false` test-only delegate. (It is internal — exposing it `@doc false` is acceptable and lets us characterize the ordering directly.)

- [ ] **Step 2: Run to verify it fails (or passes against current impl, establishing the baseline order)**

Run: `mix test test/ecto_shorts/common_filters/common_filters_sorting_test.exs`
Expected: PASS against the current 4-pass implementation (this pins the exact order before refactoring). If it fails, fix the expected order to match current behavior first.

- [ ] **Step 3: Replace with a single reduce**

```elixir
@doc false
def sort_filter_params(params) do
  {where, ors, terminal, other} =
    Enum.reduce(params, {[], [], [], []}, fn {key, _} = entry, {w, o, t, rest} ->
      case key do
        :where -> {[entry | w], o, t, rest}
        :or_where -> {w, [entry | o], t, rest}
        k when k in [:last, :subquery] -> {w, o, [entry | t], rest}
        _ -> {w, o, t, [entry | rest]}
      end
    end)

  Enum.reverse(where) ++ Enum.reverse(other) ++ Enum.reverse(ors) ++ Enum.reverse(terminal)
end
```

- [ ] **Step 4: Re-verify + full suite**

Run: `mix test test/ecto_shorts/common_filters/common_filters_sorting_test.exs && mix test`
Expected: PASS — same order, one pass.

- [ ] **Step 5: Verify single-pass mechanically**

Run: `grep -c "Enum.filter" lib/ecto_shorts/common_filters.ex` near the sorter (expect the four sorter filters gone).

- [ ] **Step 6: Commit**

```bash
git add lib/ecto_shorts/common_filters.ex test/ecto_shorts/common_filters/common_filters_sorting_test.exs
git commit -m "refactor(sort): single-pass sort_filter_params (D2, order unchanged)"
```

---

### Task 2: Plain-SQL null semantics (D-NULL)

**Files:**
- Modify: `lib/ecto_shorts/dynamic_builders/postgres/scalar_expr.ex:113-127` (`membership_not_in_dyn/3`, `membership_nil_aware_in_dyn/3`)
- Test: `test/ecto_shorts/common_filters/common_filters_comparison_operators_test.exs`, `..._negation_test.exs`

**Interfaces:**
- Produces: `{:!=, list}` / `{:not, {:in, list}}` emit plain `field NOT IN values` (no `is_nil(...) OR`); `{:not, {:!=, list}}` emits plain `field IN values` (no `not is_nil(...) AND`). Null rows are excluded by SQL three-valued logic (§3.5). Only `eq nil`/`ne nil` consider nulls (unchanged).

- [ ] **Step 1: Write the failing test**

```elixir
test "not-in over a list is plain SQL (no is_nil padding) — D-NULL" do
  expected = from(p in EctoShorts.Schema.Post, where: p.title not in ^["a", "b"])

  actual =
    EctoShorts.CommonFilters.convert_params_to_filter(
      EctoShorts.Schema.Post,
      %{title: %{ne: ["a", "b"]}},
      []
    )

  assert_query(expected, actual)
end
```

- [ ] **Step 2: Run to verify it fails**

Run: `mix test test/ecto_shorts/common_filters/common_filters_comparison_operators_test.exs -k "not-in"`
Expected: FAIL — current SQL has `is_nil(p.title) or p.title not in ...`.

- [ ] **Step 3: Implement — drop the null padding**

```elixir
defp membership_not_in_dyn(unquote(quoted_binding_head), unquote(key_var), values) do
  dynamic(
    [unquote_splicing(quoted_binding_body)],
    field(unquote(target_binding_var), ^unquote(key_var)) not in ^values
  )
end

defp membership_nil_aware_in_dyn(unquote(quoted_binding_head), unquote(key_var), values) do
  dynamic(
    [unquote_splicing(quoted_binding_body)],
    field(unquote(target_binding_var), ^unquote(key_var)) in ^values
  )
end
```

> Rename `membership_nil_aware_in_dyn` → it is now identical to `membership_in_dyn`; collapse the call site in `membership_impl/4` to use `membership_in_dyn`/`membership_not_in_dyn` and delete the redundant helper. (Behavior: `{:not, {:!=, list}}` now = plain `IN`.)

- [ ] **Step 4: Reconcile the D-NULL tests + run**

Update the ~6 audit-flagged tests (negation `:12 :25 :38`, comparison `:83`, casting `:161`) that asserted the `is_nil OR …` padding to the plain-SQL form. Run:
`mix test test/ecto_shorts/common_filters/common_filters_comparison_operators_test.exs test/ecto_shorts/common_filters/common_filters_negation_test.exs && mix test`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/ecto_shorts/dynamic_builders/postgres/scalar_expr.ex test/
git commit -m "feat(null): plain-SQL not-in (drop is_nil padding) — D-NULL"
```

---

### Task 3: Remove the `:aggregate` wrapper (D-ONE-WAY)

**Files:**
- Modify: `lib/ecto_shorts/dynamic_builders/postgres.ex:350-369` (remove both `{:aggregate, params}` clauses)
- Test: `test/ecto_shorts/common_filters/common_filters_aggregate_operators_test.exs`

**Interfaces:**
- Produces: the only aggregate spelling is `%{views: %{avg: %{gt: 5}}}`. `%{views: %{aggregate: %{fn: :avg, …}}}` is no longer recognized (the wrapper clauses are deleted); an `:aggregate` key is then treated like any unknown operator → warn-and-skip.

- [ ] **Step 1: Write the failing test**

```elixir
test "the short aggregate spelling works" do
  expected = from(p in EctoShorts.Schema.Post, having: avg(p.views) > ^5)
  source = from(p in EctoShorts.Schema.Post, group_by: p.author_id)

  actual = EctoShorts.CommonFilters.convert_params_to_filter(source, %{having: %{views: %{avg: %{gt: 5}}}}, [])
  assert_query(from(p in EctoShorts.Schema.Post, group_by: p.author_id, having: avg(p.views) > ^5), actual)
end

test "the :aggregate wrapper is no longer supported (warns and skips)" do
  log =
    capture_log(fn ->
      actual = EctoShorts.CommonFilters.convert_params_to_filter(EctoShorts.Schema.Post, %{views: %{aggregate: %{fn: :avg, compare: :>, value: 5}}}, [])
      assert_query(from(p in EctoShorts.Schema.Post), actual)
    end)

  assert log =~ "aggregate" or log =~ "operator"
end
```

- [ ] **Step 2: Run to verify it fails**

Run: `mix test test/ecto_shorts/common_filters/common_filters_aggregate_operators_test.exs -k "wrapper"`
Expected: FAIL — the wrapper is still expanded today.

- [ ] **Step 3: Delete the wrapper clauses**

Remove the two `defp dispatch_expr(_, _, _, _, {:aggregate, params}, _)` clauses (postgres.ex:350-369). No replacement — an `:aggregate` key now falls through to the unknown-operator path (warn-and-skip).

- [ ] **Step 4: Run + full suite**

Run: `mix test`
Expected: PASS. (Per the audit, no current test uses the wrapper, so only the new tests are affected.)

- [ ] **Step 5: Commit**

```bash
git add lib/ecto_shorts/dynamic_builders/postgres.ex test/ecto_shorts/common_filters/common_filters_aggregate_operators_test.exs
git commit -m "feat(aggregate): one spelling; remove the :aggregate wrapper (D-ONE-WAY)"
```

---

### Task 4: Raise on caller mistakes (D-RAISE)

**Files:**
- Create: `lib/ecto_shorts/filter_error.ex` (the exception)
- Modify: `lib/ecto_shorts/common_filters.ex` (assoc-scalar ~428-438; out-of-range `:at` ~492-506)
- Modify: `lib/ecto_shorts/common_filters/filters/reverse_order.ex:10-26`
- Modify: `lib/ecto_shorts/common_filters/filters/lock.ex` (malformed value shape — value not `%{name: …}`)
- Modify: `lib/ecto_shorts/dynamic_builders/postgres/scalar_expr.ex` (ordering operator vs `nil`)
- Test: `..._invalid_schema_field_test.exs` (assoc), `..._out_of_range_binding_test.exs`, `..._order_modifier_test.exs`, `..._lock_test.exs`, `..._comparison_operators_test.exs`

**Interfaces:**
- Produces: `EctoShorts.FilterError` (an `Exception`). These raise it: association given a non-map/keyword value; out-of-range/invalid `:at` position; `:reverse_order` given anything other than `true`/absent; a `:lock` value that isn't `%{name: …}`; an ordering operator (`gt`/`gte`/`lt`/`lte`) given `nil`. Filters that merely don't apply (unknown column, unsupported combo) still warn-and-skip.

- [ ] **Step 1: Create the exception + write failing tests**

```elixir
# lib/ecto_shorts/filter_error.ex
defmodule EctoShorts.FilterError do
  @moduledoc "Raised when a filter is used incorrectly (a caller mistake, not a non-applicable filter)."
  defexception [:message]
end
```

```elixir
# test (one per site; example for assoc-scalar)
test "an association given a scalar raises (D-RAISE)" do
  assert_raise EctoShorts.FilterError, ~r/association/, fn ->
    EctoShorts.CommonFilters.convert_params_to_filter(EctoShorts.Schema.Post, %{author: "x"}, [])
  end
end

test "an out-of-range :at binding raises" do
  base = from(p in EctoShorts.Schema.Post, join: c in assoc(p, :comments))
  assert_raise EctoShorts.FilterError, ~r/out of range/, fn ->
    EctoShorts.CommonFilters.convert_params_to_filter(base, %{at: %{99 => %{title: "x"}}}, [])
  end
end

test "reverse_order with a non-true value raises" do
  assert_raise EctoShorts.FilterError, fn ->
    EctoShorts.CommonFilters.convert_params_to_filter(EctoShorts.Schema.Post, %{reverse_order: "bad"}, [])
  end
end

test "an ordering operator given nil raises" do
  assert_raise EctoShorts.FilterError, fn ->
    EctoShorts.CommonFilters.convert_params_to_filter(EctoShorts.Schema.Post, %{views: %{gt: nil}}, [])
  end
end
```

- [ ] **Step 2: Run to verify they fail**

Run the four test files with `-k` on the new test names. Expected: FAIL (they warn-and-skip today).

- [ ] **Step 3: Convert each warn site to a raise**

- `common_filters.ex` assoc-scalar branch: replace the `LogUtils.warning(...) ; query` with
  `raise EctoShorts.FilterError, "association filter #{inspect(key)} expects a map or keyword list, got: #{inspect(params)}"`.
- `common_filters.ex` out-of-range `:at`: replace the warning+`:error` with
  `raise EctoShorts.FilterError, "binding position #{position} is out of range (max #{max})"`.
- `reverse_order.ex` the `_ ->` branch: `raise EctoShorts.FilterError, "reverse_order expects true, got: #{inspect(value)}"`.
- `lock.ex` the malformed-value branch (value not `%{name: …}`): raise `EctoShorts.FilterError` (keep the *provider-return* handling as-is — Task 5).
- `scalar_expr.ex`: add an early clause in the comparison family — `{op, nil}` with `op in [:>, :>=, :<, :<=]` → `raise EctoShorts.FilterError, "#{op} cannot be compared to nil"` (only `:==`/`:!=` accept nil).

- [ ] **Step 4: Reconcile the warn-and-skip tests + run**

Flip the ~7 audit-flagged tests in `out_of_range_binding`, `order_modifier:406`, `invalid_schema_field` (assoc), and `lock` from `capture_log`/`assert_query unchanged` to `assert_raise EctoShorts.FilterError`. **Keep** the genuine does-not-apply tests (unknown column, unsupported combo) as warn-and-skip. Run `mix test`.
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/ecto_shorts/filter_error.ex lib/ecto_shorts/common_filters.ex lib/ecto_shorts/common_filters/filters/reverse_order.ex lib/ecto_shorts/common_filters/filters/lock.ex lib/ecto_shorts/dynamic_builders/postgres/scalar_expr.ex test/
git commit -m "feat(raise): caller mistakes raise FilterError (D-RAISE)"
```

---

### Task 5: Checked provider contract (D-PROVIDER)

**Files:**
- Modify: `lib/ecto_shorts/common_filters/filters/lock.ex:48-109` and the matching provider call site in `join.ex`
- Test: `..._lock_test.exs`, `..._join_test.exs`

**Interfaces:**
- Produces: an **out-of-contract** provider return (not `{:ok, fun/1}` / `{:error, _}` / `nil`, or a callback of the wrong arity, or a callback returning a non-`Ecto.Query`) **raises** `EctoShorts.FilterError`. An **in-contract** `{:error, reason}` and `nil` still **warn-and-skip** (unchanged).

- [ ] **Step 1: Write the failing tests**

```elixir
test "a provider returning a non-function raises (out of contract)" do
  assert_raise EctoShorts.FilterError, fn ->
    EctoShorts.CommonFilters.convert_params_to_filter(EctoShorts.Schema.Post, %{lock: %{name: :bad_shape}}, query_provider_module: EctoShorts.TestQueryProvider)
  end
end

test "a provider {:error, reason} still warns and skips (in contract)" do
  log = capture_log(fn ->
    actual = EctoShorts.CommonFilters.convert_params_to_filter(EctoShorts.Schema.Post, %{lock: %{name: :returns_error}}, query_provider_module: EctoShorts.TestQueryProvider)
    assert_query(from(p in EctoShorts.Schema.Post), actual)
  end)
  assert log =~ "error"
end
```

> Add `:bad_shape` (returns e.g. `{:ok, "not a function"}`) and `:returns_error` (returns `{:error, :nope}`) to `EctoShorts.TestQueryProvider` (test support).

- [ ] **Step 2: Run to verify they fail**

Run: `mix test test/ecto_shorts/common_filters/common_filters_lock_test.exs -k provider`
Expected: the non-function case FAILs (today it warns, not raises).

- [ ] **Step 3: Convert out-of-contract branches to raise**

In `lock.ex` (and the equivalent in `join.ex`): the branches that currently warn for *out-of-contract* shapes — callback not 1-arity, callback returns non-`Ecto.Query`, and the final `other ->` catch-all — become `raise EctoShorts.FilterError, "<precise message>"`. Leave `nil ->` and `{:error, reason} ->` as warn-and-skip.

- [ ] **Step 4: Reconcile tests + run**

Flip the audit-flagged lock/join provider-return tests (the wrong-shape ones, e.g. lock `:194`, `:212`; join `:386`) to `assert_raise`; keep the `{:error,_}`/nil ones as warn. Run `mix test`.
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/ecto_shorts/common_filters/filters/lock.ex lib/ecto_shorts/common_filters/filters/join.ex test/
git commit -m "feat(provider): out-of-contract returns raise; {:error,_} warns (D-PROVIDER)"
```

---

## Self-Review (done while writing)

- **Spec coverage:** D2 → Task 1; D-NULL → Task 2; D-ONE-WAY → Task 3; D-RAISE → Task 4; D-PROVIDER → Task 5. **Aggregate→HAVING + auto-GROUP-BY and the subquery operands moved to Plan 05** (index updated) — they depend on the resolver wiring (subqueries recurse through `CommonFilters`; aggregate placement is a builder routing decision).
- **Placeholders:** none. Test reconciliations cite the exact audit line numbers from `test-audit.md`.
- **Type consistency:** `EctoShorts.FilterError` is created in Task 4 and reused in Task 5; the lock provider's in-contract `{:error,_}`/`nil` warn behavior (kept) is consistent between Task 4 (malformed *value*) and Task 5 (provider *return*) — different branches, both clearly delimited.
- **Carried to Plan 05:** aggregate→HAVING + auto-GROUP-BY; subquery operands; moving `common_field_for/1` (Plan 02) into `TermResolver`; the end-to-end wiring of `TermResolver` → thin adapter.
