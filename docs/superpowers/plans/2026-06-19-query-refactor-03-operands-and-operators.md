# Operand Convention + New Operators — Implementation Plan (Plan 03 of 6)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the new caller-facing capabilities that don't involve subqueries: the `overlaps` operator, `trim`/`ltrim`/`rtrim` transforms, the `shift` date-math word, binary arithmetic as ordered-array operands, and the `value`/`field`/sibling-`as:` operand forms — extending `PredicateBuilder` (canonical output) and the Expr modules (SQL emission) together.

**Architecture:** Each capability is built end-to-end in one task: extend `PredicateBuilder.build/4` to produce the new canonical shape, and extend the matching Expr module to emit SQL for it. `PredicateBuilder` parts are pure unit tests; Expr parts assert generated SQL through the existing pipeline.

**Tech Stack:** Elixir, Ecto. `PredicateBuilder` unit tests: `ExUnit`. SQL-emitting tests: the existing `assert_sql`/`assert_query` style via `CommonFilters` (or direct Expr calls).

## Global Constraints

- Builds on Plan 01 (`PredicateBuilder` comparison family) and Plan 02 (pure Expr, `comparison_impl` family router). Those are merged before this plan starts.
- **Subquery operands are out of scope** — `from`/`all`/`any`/`exists`/`parent` move to Plan 04. This plan covers `value`, `field` (incl. sibling `as:`), and arithmetic operands only.
- **Never use `alias Module, as: X`** (project convention).
- Canonical shapes follow spec §1.5a/§2.2: arithmetic is `{op, {arith_sym, [operand, operand]}}` (binary, ordered); `arith_sym` ∈ `:+ :- :* :/`; operands are `{:field, atom}` / `{:field, {binding, atom}}` / `{:value, cast}`.
- D-LIST (per the latest spec): a bare list is `eq`; `overlaps` is the explicit array-overlap operator; `:in` on a list column warns-and-skips.
- D-ADD-SHIFT: the date-shift word is `shift`; `add` is arithmetic only. Renaming `add`→`shift` for date-math must not change emitted SQL (still `datetime_add(...)`).

---

### Task 1: `overlaps` operator + `:in`-on-array warns-and-skips (ArrayExpr)

**Files:**
- Modify: `lib/ecto_shorts/dynamic_builders/postgres/array_expr.ex`
- Test: `test/ecto_shorts/common_filters_schemaless_test.exs` (array section) and/or `test/ecto_shorts/common_filters/common_filters_field_types_opt_test.exs`

**Interfaces:**
- Produces: ArrayExpr handles `{:overlaps, [values]}` → `fragment("? && ?", field, ^values)`; `{:in, _}` on an array column → warn-and-skip (returns `nil`). `{:==, list}` keeps emitting array equality; `{:==, scalar}` keeps element membership.
- **Operator-driven routing:** `overlaps` (and list `count`, the array quantifiers) force `PredicateBuilder` to route the predicate to `:array` **regardless of known type** — so `%{tags: %{overlaps: [..]}}` works on a schemaless source with no `:field_types` (§3.4). Implement as the operator-override in routing (Plan 01 note): an array operator in the tidied term sets `routing: :array`. (Add a schemaless test: `overlaps` with no `:field_types` still emits `&&`.)

- [ ] **Step 1: Write the failing test**

```elixir
test "overlaps emits the && array-overlap fragment" do
  expected = from(p in "posts", where: fragment("? && ?", p.tags, ^["a", "b"]))

  actual =
    EctoShorts.CommonFilters.convert_params_to_filter(
      "posts",
      %{tags: %{overlaps: ["a", "b"]}},
      field_types: [tags: {:array, :string}]
    )

  assert_query(expected, actual)
end

test ":in on a list column warns and skips (no clause added)" do
  log =
    capture_log(fn ->
      actual =
        EctoShorts.CommonFilters.convert_params_to_filter(
          "posts",
          %{tags: %{in: ["a", "b"]}},
          field_types: [tags: {:array, :string}]
        )

      assert_query(from(p in "posts"), actual)
    end)

  assert log =~ ":in"
end
```

- [ ] **Step 2: Run to verify it fails**

Run: `mix test test/ecto_shorts/common_filters_schemaless_test.exs -k overlaps`
Expected: FAIL — no `:overlaps` clause; `:in` still emits `&&`.

- [ ] **Step 3: Implement**

In `array_expr.ex`, add the `overlaps` clause and change the `:in` clause to warn-and-skip:

```elixir
defp dispatch_expr(binding, key, {:overlaps, values}) when is_list(values) do
  field = field_dyn(binding, key)
  Query.dynamic([], fragment("? && ?", ^field, ^values))
end

# :in is a scalar-membership operator; not valid on a list column (D-LIST)
defp dispatch_expr(_binding, key, {:in, _values}) do
  EctoShorts.LogUtils.warning(
    @logger_prefix,
    ":in is not supported on array field #{inspect(key)} (use overlaps or eq), skipping"
  )

  nil
end
```

> Remove the old `defp dispatch_expr(binding, key, {:in, values}) when is_list(values)` overlap clause — `overlaps` replaces it. Keep `{:==, list}` (equality) and `{:==, scalar}` (membership) clauses unchanged.

- [ ] **Step 4: Run to verify it passes + full suite**

Run: `mix test test/ecto_shorts/common_filters_schemaless_test.exs && mix test`
Expected: the new tests PASS. Note: existing schemaless tests that used `%{tags: %{elements: %{in: [...]}}}` for overlap will now fail — those are reconciled in Task 1b below (they move to `overlaps`).

- [ ] **Step 4b: Reconcile the existing overlap tests**

The schemaless tests that asserted `&&` via `%{... elements: %{in: [...]}}` are superseded (the `:elements` wrapper and `:in`-as-overlap are both gone). Update each to the new spelling, e.g.:

```elixir
# before: %{tags: %{elements: %{in: ["elixir", "ecto"]}}}
# after:
actual = CommonFilters.convert_params_to_filter("posts", %{tags: %{overlaps: ["elixir", "ecto"]}}, field_types: [tags: {:array, :string}])
expected = from(p in "posts", where: fragment("? && ?", p.tags, ^["elixir", "ecto"]))
```

(The `:elements` wrapper removal itself lands fully in Plan 04/05; here, only the overlap-spelling tests are touched so the suite is green.)

- [ ] **Step 5: Commit**

```bash
git add lib/ecto_shorts/dynamic_builders/postgres/array_expr.ex test/ecto_shorts/common_filters_schemaless_test.exs
git commit -m "feat(array): add overlaps operator; :in on a list column warns-and-skips"
```

---

### Task 2: `trim` / `ltrim` / `rtrim` text transforms (ScalarExpr)

**Files:**
- Modify: `lib/ecto_shorts/dynamic_builders/postgres/scalar_expr.ex`
- Test: `test/ecto_shorts/common_filters/common_filters_string_transformations_test.exs`

**Interfaces:**
- Produces: ScalarExpr handles `{op, {:trim | :ltrim | :rtrim, value}}` for `op in [:==, :!=]`, emitting `fragment("trim(?)", field) OP ^value` (and `ltrim`/`rtrim`). `family_for/2` classifies these like `:lower`/`:upper` (string_transform).

- [ ] **Step 1: Write the failing test**

```elixir
test "trim transform compares the trimmed column" do
  expected = from(p in EctoShorts.Schema.Post, where: fragment("trim(?)", p.title) == ^"al")

  actual =
    EctoShorts.CommonFilters.convert_params_to_filter(
      EctoShorts.Schema.Post,
      %{title: %{eq: %{trim: "al"}}},
      []
    )

  assert_query(expected, actual)
end
```

- [ ] **Step 2: Run to verify it fails**

Run: `mix test test/ecto_shorts/common_filters/common_filters_string_transformations_test.exs -k trim`
Expected: FAIL.

- [ ] **Step 3: Implement**

Add the three generated helpers (mirroring `lower_field_dyn`) inside the `for {quoted_binding_head, quoted_binding_body} <- binding_patterns do` block:

```elixir
defp trim_field_dyn(unquote(quoted_binding_head), unquote(key_var)) do
  dynamic([unquote_splicing(quoted_binding_body)], fragment("trim(?)", field(unquote(target_binding_var), ^unquote(key_var))))
end

defp ltrim_field_dyn(unquote(quoted_binding_head), unquote(key_var)) do
  dynamic([unquote_splicing(quoted_binding_body)], fragment("ltrim(?)", field(unquote(target_binding_var), ^unquote(key_var))))
end

defp rtrim_field_dyn(unquote(quoted_binding_head), unquote(key_var)) do
  dynamic([unquote_splicing(quoted_binding_body)], fragment("rtrim(?)", field(unquote(target_binding_var), ^unquote(key_var))))
end
```

Extend `family_for/2` so the new transforms classify as `:string_transform`:

```elixir
defp family_for(op, {transform, _term})
     when op in @comparison_operators and transform in [:lower, :upper, :trim, :ltrim, :rtrim] do
  :string_transform
end
```

Extend `string_transform_impl/4` to handle the three new transforms, mapping each to its helper (follow the existing `:lower`/`:upper` clauses; e.g. `{:==, {:trim, v}} -> dynamic([], ^trim_field_dyn(binding, key) == ^v)` and the `:!=`/negated variants).

- [ ] **Step 4: Run to verify it passes + full suite**

Run: `mix test test/ecto_shorts/common_filters/common_filters_string_transformations_test.exs && mix test`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/ecto_shorts/dynamic_builders/postgres/scalar_expr.ex test/ecto_shorts/common_filters/common_filters_string_transformations_test.exs
git commit -m "feat(scalar): add trim/ltrim/rtrim text transforms"
```

---

### Task 3: `shift` date-math word (rename `add`, no SQL change)

**Files:**
- Modify: `lib/ecto_shorts/common_filters/predicate_builder.ex` (date-math canonicalization — added here, since Plan 01 deferred date-math)
- Modify: `lib/ecto_shorts/dynamic_builders/postgres/scalar_expr.ex` (`datetime_comparison`/`apply_datetime_comparison` — accept `:shift`)
- Test: `test/ecto_shorts/common_filters/common_filters_datetime_wrappers_test.exs`, `..._date_wrappers_test.exs`, and `PredicateBuilder` unit test

**Interfaces:**
- Produces: caller `%{at: %{gt: %{ago: %{count: 1, unit: "day"}}}}` and `%{at: %{gt: %{date: %{shift: %{count: 7, unit: "day"}}}}}` tidy to `{:>, {:datetime, {:ago, [count: 1, interval: "day"]}}}` and `{:>, {:date, {:shift, [count: 7, interval: "day"]}}}`. `shift` emits the same `datetime_add(...)` SQL the old `add` did. `unit` is a closed set (`second minute hour day week month year`).

- [ ] **Step 1: Write the failing tests (resolver unit + SQL)**

```elixir
# PredicateBuilder unit
test "date-math: unit map tidies to interval keyword; shift kept" do
  assert {:ok, [%Predicate{expr: {:>, {:datetime, {:ago, [count: 1, interval: "day"]}}}}]} =
           PredicateBuilder.build(Post, :inserted_at, %{gt: %{ago: %{count: 1, unit: "day"}}}, [])

  assert {:ok, [%Predicate{expr: {:>=, {:date, {:shift, [count: 7, interval: "day"]}}}}]} =
           PredicateBuilder.build(Post, :inserted_at, %{gte: %{date: %{shift: %{count: 7, unit: "day"}}}}, [])
end
```

```elixir
# SQL emission (datetime_wrappers_test)
test "shift emits datetime_add (same SQL the old add produced)" do
  expected = from(p in EctoShorts.Schema.Post, where: p.inserted_at >= datetime_add(p.published_at, ^7, "day"))

  actual =
    EctoShorts.CommonFilters.convert_params_to_filter(
      EctoShorts.Schema.Post,
      %{inserted_at: %{gte: %{datetime: %{shift: %{count: 7, unit: "day", field: :published_at}}}}},
      []
    )

  assert_query(expected, actual)
end
```

- [ ] **Step 2: Run to verify they fail**

Run: `mix test test/ecto_shorts/common_filters/common_filters_datetime_wrappers_test.exs -k shift`
Expected: FAIL — `shift` unrecognized; resolver lacks date-math.

- [ ] **Step 3: Implement the resolver date-math canonicalization**

In `predicate_builder.ex`, add a date-math clause to `build_one/3` (Plan 01's per-operator builder, which returns a **list**). The RHS of a comparison is a date wrapper `%{date | datetime: %{dt_op => %{count:, unit:, field:}}}`. **Recognize the wrapper by key access** (not a singleton `Map.to_list` match), and **reduce** over the inner map for the date op:

```elixir
@date_units ~w(second minute hour day week month year)

# date-math RHS: a wrapper map carrying exactly one of :date / :datetime.
defp build_one(op, %{date: w}, _type) when op in @comparison_ops, do: dt_term(op, :date, w)
defp build_one(op, %{datetime: w}, _type) when op in @comparison_ops, do: dt_term(op, :datetime, w)

defp dt_term(op, wrapper, w) do
  # w is %{ago | from_now | shift => params}; reduce so multiple/zero entries
  # don't crash — each recognized dt op yields one tidied term.
  Enum.reduce(w, [], fn {raw_dt_op, params}, acc ->
    case canonical_op(raw_dt_op) do
      dt_op when dt_op in [:ago, :from_now, :shift] ->
        acc ++ [{op, {wrapper, {dt_op, dt_keyword(params)}}}]

      _ ->
        (warn_skip("Unknown date-math op, skipping"); acc)
    end
  end)
end

defp dt_keyword(%{} = p) do
  unit = p[:unit] || p["unit"]
  unless to_string(unit) in @date_units, do: raise(EctoShorts.FilterError, "unknown date unit #{inspect(unit)}")
  kw = [count: p[:count] || p["count"], interval: to_string(unit)]
  case p[:field] || p["field"] do
    nil -> kw
    f -> kw ++ [field: f]
  end
end
```

> These `build_one/3` clauses sit **before** the generic transform/scalar clauses from Plan 01 (so a date wrapper isn't mistaken for a transform). `canonical_op/1` must map `"shift"`/`:shift`, `"ago"`, `"from_now"` to themselves (add them to the `@operator_atoms` set in Plan 01's compile-time map). No `Map.to_list` singleton match — the wrapper is matched by key and the inner op map is **reduced** (per the project convention: never assume a single key/value pair).

- [ ] **Step 4: Implement `shift` in ScalarExpr**

In `scalar_expr.ex`, the datetime family currently matches `:add`. Add `:shift` everywhere `:add` appears in `datetime_comparison`/`apply_datetime_comparison`, emitting the identical `datetime_add(...)` SQL. (Keep `:add` matching too for one release if desired, or remove it — per D-ADD-SHIFT the canonical word is `shift`; the resolver no longer produces `:add` for dates.) Concretely, change the guard `datetime_op in [:ago, :from_now, :add]` → `[:ago, :from_now, :shift]` and the per-clause `{:date, {:add, params}}` → `{:date, {:shift, params}}` (body unchanged — still `datetime_add`).

- [ ] **Step 5: Run to verify pass + full suite**

Run: `mix test test/ecto_shorts/common_filters/common_filters_datetime_wrappers_test.exs test/ecto_shorts/common_filters/predicate_builder_test.exs && mix test`
Expected: PASS. (The ~21 date/datetime tests are updated from `interval:`/`add` to `unit:`/`shift` as part of this task — they are the reconciliation the audit flagged for D-WIRE/D-ADD-SHIFT.)

- [ ] **Step 6: Commit**

```bash
git add lib/ecto_shorts/common_filters/predicate_builder.ex lib/ecto_shorts/dynamic_builders/postgres/scalar_expr.ex test/
git commit -m "feat(date-math): shift word + unit key; resolver canonicalizes to interval kw"
```

---

### Task 4: `value` / `field` operands + sibling `as:` (PredicateBuilder, pure)

**Files:**
- Modify: `lib/ecto_shorts/common_filters/predicate_builder.ex`
- Test: `test/ecto_shorts/common_filters/predicate_builder_test.exs`

**Interfaces:**
- Produces: the RHS of a comparison may be an **operand map**:
  - `%{value: v}` → `{:value, cast(type, v)}` (a literal; never re-read as membership)
  - `%{field: f}` → `{:field, resolved_atom}` (current binding)
  - `%{field: f, as: b}` → `{:field, {b, resolved_atom}}` (sibling binding; `b` validated later, §3.11 — resolver only records it)
  So `%{a: %{gt: %{field: :b}}}` → `{:>, {:field, :b}}` and `%{a: %{gt: %{field: :b, as: :author}}}` → `{:>, {:field, {:author, :b}}}`.

- [ ] **Step 1: Write the failing test**

```elixir
test "field operand on the current binding" do
  assert {:ok, [%Predicate{expr: {:>, {:field, :b}}}]} =
           PredicateBuilder.build(Post, :views, %{gt: %{field: :b}}, [])
end

test "field operand with a sibling binding records {binding, field}" do
  assert {:ok, [%Predicate{expr: {:>, {:field, {:author, :age}}}}]} =
           PredicateBuilder.build(Post, :views, %{gt: %{field: :age, as: :author}}, [])
end

test "value operand is always a single literal (cast), never membership" do
  assert {:ok, [%Predicate{expr: {:==, {:value, [1, 2]}}}]} =
           PredicateBuilder.build(Post, :views, %{eq: %{value: ["1", "2"]}}, [])
end
```

- [ ] **Step 2: Run to verify it fails**

Run: `mix test test/ecto_shorts/common_filters/predicate_builder_test.exs -k operand`
Expected: FAIL.

- [ ] **Step 3: Implement operand parsing as `build_one/3` clauses**

These are `build_one/3` clauses (Plan 01's per-operator builder, which returns a
**list**). Recognize the operand kind by **key access** — not a singleton match:

```elixir
defp build_one(op, %{value: v}, type) when op in @comparison_ops do
  [{op, {:value, cast(type, v)}}]
end

defp build_one(op, %{field: _} = m, _type) when op in @comparison_ops do
  [{op, {:field, field_ref(m)}}]
end

defp field_ref(%{field: f, as: b}), do: {b, f}
defp field_ref(%{field: f}), do: f
```

> Place these **before** the generic transform/scalar clauses (so an operand map isn't mistaken for a transform) and **after** the date-math clauses from Task 3 (so `%{date: …}` is matched first). String JSON keys `"field"`/`"value"`/`"as"` are normalized to atoms by the wire decoder (D-WIRE); the resolver sees atom keys. (Task 5 adds the arithmetic `build_one` clause and reuses `field_ref/1`.)

- [ ] **Step 4: Run to verify pass**

Run: `mix test test/ecto_shorts/common_filters/predicate_builder_test.exs`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/ecto_shorts/common_filters/predicate_builder.ex test/ecto_shorts/common_filters/predicate_builder_test.exs
git commit -m "feat(resolver): value/field operands + sibling-as reference (pure)"
```

---

### Task 5: Emit `field`/sibling operands + binary arithmetic (ScalarExpr)

**Files:**
- Modify: `lib/ecto_shorts/common_filters/predicate_builder.ex` (arithmetic operand)
- Modify: `lib/ecto_shorts/dynamic_builders/postgres/scalar_expr.ex` (emit field/sibling/arithmetic)
- Test: `test/ecto_shorts/common_filters/common_filters_comparison_operators_test.exs`, `..._parent_as_test.exs` (sibling), `..._arithmetic` cases

**Interfaces:**
- Consumes: the `{:field, atom}` / `{:field, {binding, atom}}` / `{:value, v}` operands from Task 4.
- Produces:
  - resolver: arithmetic `%{add: [operand, operand]}` → `{op, {:+, [op1, op2]}}` (binary; `subtract`→`:-`, `multiply`→`:*`, `divide`→`:/`; >2 operands → raise).
  - ScalarExpr: `{op, {:field, col}}` → `field OP field(col)`; `{op, {:field, {binding, col}}}` → `field OP field(as(^binding), ^col)`; `{op, {arith_sym, [a, b]}}` → `field OP (a arith_sym b)` reusing the existing `apply_dyn_comparison/4` matrix with operand dynamics built from `{:field,_}`/`{:value,_}`.

- [ ] **Step 1: Write the failing tests**

```elixir
# resolver: arithmetic ordered-array, binary only
test "binary arithmetic operand" do
  assert {:ok, [%Predicate{expr: {:>, {:+, [{:field, :base}, {:value, 5}]}}}]} =
           PredicateBuilder.build(Post, :views, %{gt: %{add: [%{field: :base}, %{value: "5"}]}}, [])
end

test "arithmetic with 3 operands raises (binary only)" do
  assert_raise EctoShorts.FilterError, fn ->
    PredicateBuilder.build(Post, :views, %{gt: %{add: [%{field: :a}, %{field: :b}, %{value: 1}]}}, [])
  end
end
```

```elixir
# SQL: column-to-column and sibling
test "compare to another column" do
  expected = from(p in EctoShorts.Schema.Post, where: p.views > p.id)
  actual = EctoShorts.CommonFilters.convert_params_to_filter(EctoShorts.Schema.Post, %{views: %{gt: %{field: :id}}}, [])
  assert_query(expected, actual)
end

test "computed-field arithmetic" do
  expected = from(p in EctoShorts.Schema.Post, where: p.views > p.id + ^5)
  actual = EctoShorts.CommonFilters.convert_params_to_filter(EctoShorts.Schema.Post, %{views: %{gt: %{add: [%{field: :id}, %{value: 5}]}}}, [])
  assert_query(expected, actual)
end
```

- [ ] **Step 2: Run to verify they fail**

Run: `mix test test/ecto_shorts/common_filters/predicate_builder_test.exs test/ecto_shorts/common_filters/common_filters_comparison_operators_test.exs -k "arithmetic"`
Expected: FAIL.

- [ ] **Step 3: Implement arithmetic in the resolver**

The RHS of a comparison may be an **operand map** (`%{value:}`/`%{field:}`/a single
arithmetic key). Match the operand kinds by **key** (not a singleton `Map.to_list`),
and reduce the arithmetic key's list. These are `build_one/3` clauses (returning a
list), placed before the generic transform/scalar clauses:

The `value`/`field` operand clauses are already added in Task 4 (and `field_ref/1`).
Here add **only** the arithmetic operand clause — recognize the single arithmetic
key by an explicit `Enum.filter` (not a singleton `Map.to_list` match), and reduce
nothing-or-one-or-many to a clear outcome:

```elixir
@arith %{add: :+, subtract: :-, multiply: :*, divide: :/}

# arithmetic operand: exactly one arith key whose value is a 2-element operand list.
# Placed AFTER the value/field/date-math build_one clauses, BEFORE the transform/scalar ones.
defp build_one(op, %{} = m, type) when op in @comparison_ops do
  case Enum.filter(Map.keys(@arith), &Map.has_key?(m, &1)) do
    [arith] ->
      case Map.fetch!(m, arith) do
        [a, b] -> [{op, {Map.fetch!(@arith, arith), [operand(a, type), operand(b, type)]}}]
        _ -> raise EctoShorts.FilterError, "arithmetic takes exactly two operands"
      end

    [] ->
      build_one_transform(op, m, type)  # transform branch (Task 2); date-math handled by its own clauses (Task 3)

    _many ->
      raise EctoShorts.FilterError, "expected a single arithmetic operator, got: #{inspect(Map.keys(m))}"
  end
end

# operand/2 reuses field_ref/1 from Task 4
defp operand(%{field: _} = m, _type), do: {:field, field_ref(m)}
defp operand(%{value: v}, type), do: {:value, cast(type, v)}
```

> No singleton `Map.to_list` match: operand kinds are recognized by key, and the
> "which arithmetic key is present" check is an explicit `Enum.filter` over the
> known arith keys (zero → fall through; one → use it; many → raise a clear error,
> not a `MatchError`). Per the project convention, we never assume a single pair.

- [ ] **Step 4: Implement emission in ScalarExpr**

In the `arithmetic_comparison`/`scalar_value_fallback` area (from Plan 02), build a dynamic for each operand and reuse `apply_dyn_comparison/4`:

```elixir
defp operand_dyn(binding, {:field, {bind, col}}), do: dynamic([], field(as(^bind), ^col))
defp operand_dyn(binding, {:field, col}), do: field_dyn(binding, col)
defp operand_dyn(_binding, {:value, v}), do: dynamic([], ^v)

# field/sibling RHS:
defp comparison_rhs(binding, {:field, _} = f), do: operand_dyn(binding, f)
# arithmetic RHS:
defp comparison_rhs(binding, {sym, [a, b]}) when sym in [:+, :-, :*, :/] do
  da = operand_dyn(binding, a)
  db = operand_dyn(binding, b)
  case sym do
    :+ -> dynamic([], ^da + ^db)
    :- -> dynamic([], ^da - ^db)
    :* -> dynamic([], ^da * ^db)
    :/ -> dynamic([], ^da / ^db)
  end
end
```

Then the family clause: `{op, rhs}` (rhs a `{:field,_}` or `{sym,[..]}`) → `apply_dyn_comparison(op, field_dyn(binding, key), comparison_rhs(binding, rhs), mode)`. (`field(as(^bind), ^col)` is the Ecto sibling-binding reference, mirroring how `parent_as` uses `field(parent_as(^pb), ^pf)`.)

- [ ] **Step 5: Run to verify pass + full suite**

Run: `mix test && mix dialyzer`
Expected: PASS. The legacy positional arithmetic shape (`{:value, {arith_op, {{:field, af}, {:value, av}}}}`) is replaced by the ordered-array shape; update any `..._comparison_operators_test.exs` arithmetic rows to the new `%{add: [..]}` spelling as part of this task.

- [ ] **Step 6: Commit**

```bash
git add lib/ecto_shorts/common_filters/predicate_builder.ex lib/ecto_shorts/dynamic_builders/postgres/scalar_expr.ex test/
git commit -m "feat: binary arithmetic operands + column/sibling field comparisons"
```

---

## Self-Review (done while writing)

- **Spec coverage:** D-LIST `overlaps` + `:in`-on-array → Task 1; D-TRIM → Task 2; D-ADD-SHIFT + D-WIRE `unit`/date-math → Task 3; D-OPERAND `value`/`field` + D-SIBLING → Task 4; D-OPERAND arithmetic (binary, ordered) + sibling emission → Task 5. **Subquery operands (`from`/`all`/`any`/`exists`/`parent`) are explicitly deferred to Plan 04** (index updated).
- **Placeholders:** none for the in-scope tasks. Every map is processed with `Enum.reduce` / key access (no singleton `Map.to_list` match); the date-math/operand/arithmetic clauses are `build_one/3` heads that return lists and fall through to `build_one_transform/3` (the Plan 01 transform branch factored into a named helper).
- **Type consistency:** operand shapes (`{:field, atom}`, `{:field, {binding, atom}}`, `{:value, v}`, `{arith_sym, [op, op]}`) are produced by `PredicateBuilder` (Tasks 4–5) and consumed by ScalarExpr `operand_dyn/2`/`comparison_rhs/2` (Task 5) with matching names; `@arith` maps words→symbols consistently with §2.2's `:+ :- :* :/`.
- **Carried to Plan 04:** sibling-`as:` *validation* (post-build, unknown/ambiguous → raise — §3.11) is recorded by the resolver here but enforced in Plan 04/05 where the full query (and its bindings) exists; subquery operands; the D-NULL/D-RAISE/D-ONE-WAY/D-PROVIDER behavior changes.
