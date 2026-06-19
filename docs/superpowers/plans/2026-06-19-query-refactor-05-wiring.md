# Wiring + Thin Adapter + Subquery Operands + Aggregate→HAVING — Implementation Plan (Plan 05 of 6)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Connect the pieces end-to-end: route `:where`/`:or_where`/`:having`/`:or_having` through `CommonFilters.PredicateBuilder.build/4` → a **thin** dialect adapter that turns one `%Predicate{}` into a dynamic; delete the old tidying path from `Postgres`; move the shorthand-field mapping into `PredicateBuilder`; add the subquery operands; and place aggregate predicates in HAVING.

**Architecture:** Today `Builder.apply_filter(:where, …)` calls `DynamicBuilders.Resolver.build_dynamic(source, binding, {key, value}, opts)`, and `Postgres.build_dynamic` does *all* the tidying before emitting. We change the seam: `PredicateBuilder.build(source, key, value, opts)` returns `{:ok, [%Predicate{}]}`; each `%Predicate{}` goes to the adapter `build_dynamic(%Predicate{}, binding, opts)`, which only dispatches by `routing` to a pure Expr module and applies `negated`. The dynamics are AND-merged and wrapped (`where`/`or_where`/`having`). The Expr modules (pure, from Plans 02–04) are unchanged; the tidying logic in `Postgres` is removed.

**Tech Stack:** Elixir, Ecto. Tests: the full `CommonFilters` pipeline with `assert_query`/`assert_sql`; adapter unit tests feed a `%Predicate{}` directly.

## Global Constraints

- Builds on Plans 01–04 (merged). `PredicateBuilder` (comparison family + operands + date-math) and the pure Expr modules already exist.
- **Never use `alias Module, as: X`** (project convention).
- **Reduce over entries; never assume one pair** (project convention) — applies to the per-field AND-merge here.
- The `DynamicBuilder` behaviour callback changes shape (it now takes a `%Predicate{}`); record it as a v3.0.0 migration note for custom-dialect implementers (only Postgres ships).
- Subquery construction recurses through `CommonFilters.convert_params_to_filter` (dialect-agnostic) and is done by the adapter (which may build Ecto queries); `PredicateBuilder` stays pure (it only resolves the source alias and carries the spec).

---

### Task 1: Thin adapter — `build_dynamic(%Predicate{}, binding, opts)`

**Files:**
- Modify: `lib/ecto_shorts/dynamic_builder.ex` (behaviour callback)
- Modify: `lib/ecto_shorts/dynamic_builders.ex` → `DynamicBuilders.Resolver` (the selector, renamed in the naming pass)
- Modify: `lib/ecto_shorts/dynamic_builders/postgres.ex` (becomes a thin adapter)
- Test: `test/ecto_shorts/dynamic_builders/postgres_test.exs`

**Interfaces:**
- New behaviour: `@callback build_dynamic(predicate :: EctoShorts.CommonFilters.Predicate.t(), selected_binding, opts) :: Ecto.Query.dynamic_expr() | nil`.
- `DynamicBuilders.Resolver.build_dynamic(predicate, binding, opts)` picks the adapter (as today) and delegates.
- `Postgres.build_dynamic(%Predicate{routing: r, field: f, negated: n, expr: e}, binding, opts)` dispatches: `:scalar` → `ScalarExpr.dynamic_expr(binding, f, neg(n), e, opts)`, `:array` → `ArrayExpr…`, `:map` → `MapExpr…`, `:common` → `ShorthandExpr.dynamic_expr(binding, f, neg(n), e, opts)` (the field is already resolved by `PredicateBuilder`). `neg(true) = :not`, `neg(false) = nil`.

- [ ] **Step 1: Write the failing test**

```elixir
test "the Postgres adapter turns a scalar Predicate into the right dynamic" do
  import Ecto.Query
  alias EctoShorts.CommonFilters.Predicate
  alias EctoShorts.DynamicBuilders.Postgres

  pred = %Predicate{field: :views, routing: :scalar, negated: false, expr: {:>, 10}}
  dyn = Postgres.build_dynamic(pred, {:as, nil}, [])

  q = from(p in EctoShorts.Schema.Post, where: ^dyn)
  assert_sql(from(p in EctoShorts.Schema.Post, where: p.views > ^10), q)
end
```

- [ ] **Step 2: Run to verify it fails**

Run: `mix test test/ecto_shorts/dynamic_builders/postgres_test.exs -k "scalar Predicate"`
Expected: FAIL — `build_dynamic/3` over a `%Predicate{}` doesn't exist yet.

- [ ] **Step 3: Implement the thin adapter**

In `postgres.ex`, add the predicate-consuming entry and dispatch (keep the Expr aliases):

```elixir
alias EctoShorts.CommonFilters.Predicate
alias EctoShorts.DynamicBuilders.Postgres.{ScalarExpr, ArrayExpr, MapExpr, ShorthandExpr}

@behaviour EctoShorts.DynamicBuilder

@impl true
def build_dynamic(%Predicate{routing: routing, field: field, negated: negated, expr: expr}, binding, opts) do
  neg = if negated, do: :not, else: nil

  case routing do
    :scalar -> ScalarExpr.dynamic_expr(binding, field, neg, expr, opts)
    :array  -> ArrayExpr.dynamic_expr(binding, field, neg, expr, opts)
    :map    -> MapExpr.dynamic_expr(binding, field, neg, expr, opts)
    :common -> ShorthandExpr.dynamic_expr(binding, field, neg, expr, opts)
  end
end
```

In `dynamic_builder.ex`, change the `@callback` to the predicate shape. In
`DynamicBuilders.Resolver`, change `build_dynamic/3` to forward `(predicate, binding, opts)` to the resolved adapter (the adapter-selection logic is unchanged).

> `ShorthandExpr.dynamic_expr/6` from Plan 02 takes the field explicitly; here `field` already carries the shorthand's column (Task 3 ensures `PredicateBuilder` filled it in), so the call is uniform with the other helpers. (Adjust ShorthandExpr to the 5-arg `(binding, field, negated, expr, opts)` shape used by the others, since the operator is now in `expr`.)

- [ ] **Step 4: Run + commit**

Run: `mix test test/ecto_shorts/dynamic_builders/postgres_test.exs`
Expected: PASS.
```bash
git add lib/ecto_shorts/dynamic_builder.ex lib/ecto_shorts/dynamic_builders.ex lib/ecto_shorts/dynamic_builders/postgres.ex test/
git commit -m "feat(adapter): thin build_dynamic over %Predicate{} (dispatch by routing)"
```

---

### Task 2: Wire `:where` / `:or_where` through `PredicateBuilder`

**Files:**
- Modify: `lib/ecto_shorts/common_filters/builder.ex` (`apply_filter(:where, …)` / `:or_where`, lines 183–199)
- Test: `test/ecto_shorts/common_filters/common_filters_comparison_operators_test.exs` (existing end-to-end)

**Interfaces:**
- Consumes: `PredicateBuilder.build(source, key, value, opts) :: {:ok, [%Predicate{}]} | :skip`, `Resolver.build_dynamic(%Predicate{}, binding, opts)`.
- Produces: a single AND-merged dynamic per field, wrapped in `Query.where`/`Query.or_where`. A `:skip` adds nothing.

- [ ] **Step 1: Establish baseline**

Run: `mix test test/ecto_shorts/common_filters/common_filters_comparison_operators_test.exs`
Expected: PASS (the existing end-to-end `assert_sql` suite is the safety net).

- [ ] **Step 2: Replace the build site**

In `builder.ex`:

```elixir
defp apply_filter(:where, source, query, selected_binding, {key, value}, opts) do
  effective_source = resolve_source(source, query, selected_binding)

  case PredicateBuilder.build(effective_source, key, value, opts) do
    :skip -> query
    {:ok, predicates} -> Query.where(query, ^merge_predicates(predicates, selected_binding, opts))
  end
end

defp apply_filter(:or_where, source, query, selected_binding, {key, value}, opts) do
  effective_source = resolve_source(source, query, selected_binding)

  case PredicateBuilder.build(effective_source, key, value, opts) do
    :skip -> query
    {:ok, predicates} -> Query.or_where(query, ^merge_predicates(predicates, selected_binding, opts))
  end
end

# AND-merge the per-operator predicates for one field into one dynamic.
defp merge_predicates(predicates, binding, opts) do
  predicates
  |> Enum.map(&EctoShorts.DynamicBuilders.Resolver.build_dynamic(&1, binding, opts))
  |> Enum.reject(&is_nil/1)
  |> Enum.reduce(fn dyn, acc -> Ecto.Query.dynamic(^acc and ^dyn) end)
end
```

> `term` arrives as a `{key, value}` tuple (reduce_filters split the map upstream), so `PredicateBuilder.build(source, key, value, opts)` matches its arity. The AND-merge across a field's multiple operators (`%{age: %{gt: 21, lte: 65}}`) happens here, replacing `Postgres.merge_dynamic`. If `merge_predicates` gets an empty list (all entries skipped), guard it to return `nil` and have the caller add nothing.

- [ ] **Step 3: Run the where/comparison suites + full suite**

Run: `mix test test/ecto_shorts/common_filters/common_filters_comparison_operators_test.exs test/ecto_shorts/common_filters/common_filters_negation_test.exs && mix test`
Expected: PASS — same SQL, now produced via `PredicateBuilder` + the thin adapter. (Schemaless and field-type suites also exercise this path.)

- [ ] **Step 4: Commit**

```bash
git add lib/ecto_shorts/common_filters/builder.ex
git commit -m "feat(wiring): route where/or_where through PredicateBuilder + adapter"
```

---

### Task 3: Move shorthand-field resolution into `PredicateBuilder` (D-CommonExpr-FIELD)

**Files:**
- Modify: `lib/ecto_shorts/common_filters/predicate_builder.ex` (shorthand operators → `:common` routing + resolved field)
- Modify: `lib/ecto_shorts/dynamic_builders/postgres.ex` (remove the temporary `common_field_for/1` from Plan 02)
- Test: `test/ecto_shorts/common_filters/predicate_builder_test.exs`, plus the existing shorthand end-to-end tests

**Interfaces:**
- `PredicateBuilder.build(source, :ids, [1,2,3], opts)` → `{:ok, [%Predicate{field: :id, routing: :common, negated: false, expr: {:ids, [1,2,3]}}]}`. The shorthand→column map (`:ids`/`:before`/… → `:id`; `:start_date`/… → `:inserted_at`) lives here now; `ShorthandExpr` stays pure (field passed in).

- [ ] **Step 1: Write the failing test**

```elixir
test "shorthand resolves the implied column and routes to :common" do
  alias EctoShorts.CommonFilters.Predicate
  assert {:ok, [%Predicate{field: :id, routing: :common, expr: {:ids, [1, 2, 3]}}]} =
           EctoShorts.CommonFilters.PredicateBuilder.build(EctoShorts.Schema.Post, :ids, [1, 2, 3], [])

  assert {:ok, [%Predicate{field: :inserted_at, routing: :common, expr: {:start_date, _}}]} =
           EctoShorts.CommonFilters.PredicateBuilder.build(EctoShorts.Schema.Post, :start_date, ~U[2026-01-01 00:00:00Z], [])
end
```

- [ ] **Step 2: Run to verify it fails**

Run: `mix test test/ecto_shorts/common_filters/predicate_builder_test.exs -k shorthand`
Expected: FAIL.

- [ ] **Step 3: Implement shorthand handling in `build`**

Recognize the shorthand operators as the top-level key (they are the *key*, not a value-map operator), fill the column, route `:common`:

```elixir
@id_shorthands [:ids, :before, :after, :since, :until]
@date_shorthands [:start_date, :end_date, :since_date, :until_date]

# in build/4, before field resolution:
def build(source, key, value, opts) when key in @id_shorthands do
  {:ok, [%Predicate{field: :id, routing: :common, negated: false, expr: {key, value}}]}
end

def build(source, key, value, opts) when key in @date_shorthands do
  {:ok, [%Predicate{field: :inserted_at, routing: :common, negated: false, expr: {key, value}}]}
end

def build(_source, :exists, value, _opts) do
  {:ok, [%Predicate{field: nil, routing: :common, negated: false, expr: {:exists, value}}]}
end
```

Then delete `common_field_for/1` and its call site in `postgres.ex` (the field now arrives in the `%Predicate{}`).

- [ ] **Step 4: Run + commit**

Run: `mix test test/ecto_shorts/common_filters/predicate_builder_test.exs && mix test`
Expected: PASS.
```bash
git add lib/ecto_shorts/common_filters/predicate_builder.ex lib/ecto_shorts/dynamic_builders/postgres.ex test/
git commit -m "feat: shorthand field resolution moves into PredicateBuilder"
```

---

### Task 4: `:having` / `:or_having` + aggregate→HAVING + auto-GROUP-BY

**Files:**
- Modify: `lib/ecto_shorts/common_filters/filters/having.ex` and `or_having.ex` (route through PredicateBuilder)
- Modify: `lib/ecto_shorts/common_filters/builder.ex` (`:where` aggregate → HAVING redirect)
- Test: `test/ecto_shorts/common_filters/common_filters_having_test.exs`, `..._aggregate_operators_test.exs`

**Interfaces:**
- `:having`/`:or_having` build predicates exactly like `:where` (Task 2) but wrap with `Query.having`/`Query.or_having`.
- Aggregate placement: a predicate whose `expr` is `{agg, _}` (agg in `:avg :count :max :min :sum`) **always lands in HAVING**, even when written under `:where`. If the query has no `group_by`, the builder **adds a default GROUP BY on the source's primary key** (so the SQL is valid).

- [ ] **Step 1: Write the failing tests**

```elixir
test "an aggregate written under :where lands in HAVING with an auto GROUP BY" do
  import Ecto.Query
  actual = EctoShorts.CommonFilters.convert_params_to_filter(EctoShorts.Schema.Post, %{views: %{avg: %{gt: 5}}}, [])
  # avg(views) > 5 must appear in HAVING, and a GROUP BY on :id is auto-added
  assert_sql(from(p in EctoShorts.Schema.Post, group_by: p.id, having: avg(p.views) > ^5), actual)
end

test "an aggregate under :having on an explicitly grouped query keeps that grouping" do
  import Ecto.Query
  source = from(p in EctoShorts.Schema.Post, group_by: p.author_id)
  actual = EctoShorts.CommonFilters.convert_params_to_filter(source, %{having: %{views: %{avg: %{gt: 5}}}}, [])
  assert_sql(from(p in EctoShorts.Schema.Post, group_by: p.author_id, having: avg(p.views) > ^5), actual)
end
```

- [ ] **Step 2: Run to verify they fail**

Run: `mix test test/ecto_shorts/common_filters/common_filters_having_test.exs -k aggregate`
Expected: FAIL — aggregates under `:where` currently emit invalid SQL / no auto-group.

- [ ] **Step 3: Implement**

In `builder.ex`, after building predicates for `:where`, split off aggregate predicates and place them in HAVING (adding a default group_by if none):

```elixir
defp place(query, predicates, :where, binding, opts) do
  {aggs, plain} = Enum.split_with(predicates, &aggregate_predicate?/1)
  query = if plain == [], do: query, else: Query.where(query, ^merge_predicates(plain, binding, opts))
  apply_having(query, aggs, binding, opts)
end

defp aggregate_predicate?(%Predicate{expr: {agg, _}}) when agg in [:avg, :count, :max, :min, :sum], do: true
defp aggregate_predicate?(_), do: false

defp apply_having(query, [], _binding, _opts), do: query
defp apply_having(query, aggs, binding, opts) do
  query = ensure_group_by(query)          # add group_by on the primary key if absent
  Query.having(query, ^merge_predicates(aggs, binding, opts))
end
```

`ensure_group_by/1` checks whether the query already has a `group_by`; if not, it adds one on the source's primary key (via `CommonSchema` reflection). `:having`/`:or_having` route through `PredicateBuilder` like `:where` but always wrap with `Query.having`/`Query.or_having` (and also call `ensure_group_by/1`).

- [ ] **Step 4: Run + commit**

Run: `mix test test/ecto_shorts/common_filters/common_filters_having_test.exs test/ecto_shorts/common_filters/common_filters_aggregate_operators_test.exs && mix test`
Expected: PASS.
```bash
git add lib/ecto_shorts/common_filters/builder.ex lib/ecto_shorts/common_filters/filters/having.ex lib/ecto_shorts/common_filters/filters/or_having.ex test/
git commit -m "feat: aggregates land in HAVING with auto GROUP BY; having uses PredicateBuilder"
```

---

### Task 5: Subquery operands (`from` / `all` / `any` / `exists` / `parent`)

**Files:**
- Modify: `lib/ecto_shorts/common_filters/predicate_builder.ex` (recognize subquery/exists/parent operand shapes)
- Modify: `lib/ecto_shorts/dynamic_builders/postgres.ex` (build the subquery via `CommonFilters`; `ScalarExpr`/`ShorthandExpr` already emit the all/any/exists/parent SQL — Plans 02/03)
- Add: a source-alias registry option (`:source_aliases` in opts, or a config key) for HTTP-supplied `from` names
- Test: `test/ecto_shorts/common_filters/common_filters_subquery_test.exs`, `..._parent_as_test.exs`, `..._set_operation_test.exs` (subquery-shaped where), `predicate_builder_test.exs`

**Interfaces:**
- `PredicateBuilder.build` produces, for a quantified subquery, `%Predicate{routing: :scalar, expr: {op, {:all | :any, {:subquery, source, where_params}}}}` (source resolved: an Elixir module as-is, or an HTTP string alias looked up in `:source_aliases`; an unresolvable alias → raise `FilterError`). For `exists`: `%Predicate{routing: :common, field: nil, expr: {:exists, {:subquery, source, where_params}}}`. `parent` (only inside an `exists`/subquery `where`) → `{:parent, {binding, col}}`, **validated post-build** against the bindings the enclosing blocks declared (unknown/ambiguous → raise).
- The adapter builds the actual Ecto subquery: `CommonFilters.convert_params_to_filter(source, where_params, opts)` then `select`s the compared column; this is the only place query construction happens (the dialect-agnostic recursion).

- [ ] **Step 1: Write the failing test**

```elixir
test "id eq all subquery" do
  import Ecto.Query
  actual =
    EctoShorts.CommonFilters.convert_params_to_filter(
      EctoShorts.Schema.Post,
      %{id: %{eq: %{all: %{from: EctoShorts.Schema.Comment, where: %{published: true}}}}},
      []
    )

  # id == all(SELECT comments.id ... WHERE published)
  assert %Ecto.Query{} = actual
  assert inspect(actual) =~ "ALL" or inspect(actual) =~ "all"
end
```

- [ ] **Step 2: Run to verify it fails**

Run: `mix test test/ecto_shorts/common_filters/common_filters_subquery_test.exs -k "all subquery"`
Expected: FAIL.

- [ ] **Step 3: Implement**

In `PredicateBuilder`, add `build_one` clauses recognizing an operator value that is a quantified subquery / exists / parent operand (by key: `from`, `all`/`any`, `parent`). Resolve the `from` source: a module passes through; a string is looked up in `opts[:source_aliases]` (else `raise EctoShorts.FilterError`). Carry `{:subquery, source, where_params}` in the expr.

In `postgres.ex`, add (or keep, relocated from the old `build_quantified_query`) the subquery builder the adapter calls when it sees `{:subquery, source, where_params}`: build the inner query with `CommonFilters.convert_params_to_filter(source, where_params, opts)`, apply a `select` of the compared column, and hand the `Ecto.SubQuery` to `ScalarExpr` (which already emits `field OP ALL/ANY(subquery)` and `exists(...)`).

Add the **post-build sibling/parent validation** pass (§3.11): after the whole query is assembled, verify every `{:field, {binding, _}}` / `{:parent, {binding, _}}` reference names a binding that exists (raise `FilterError` on unknown/ambiguous).

- [ ] **Step 4: Run + commit**

Run: `mix test test/ecto_shorts/common_filters/common_filters_subquery_test.exs test/ecto_shorts/common_filters/common_filters_parent_as_test.exs && mix test`
Expected: PASS.
```bash
git add lib/ecto_shorts/common_filters/predicate_builder.ex lib/ecto_shorts/dynamic_builders/postgres.ex test/
git commit -m "feat: subquery operands (all/any/exists/parent) via registered-alias sources"
```

---

### Task 6: Delete the old tidying path from `Postgres`

**Files:**
- Modify: `lib/ecto_shorts/dynamic_builders/postgres.ex` (remove the now-dead tidying functions)
- Test: the full suite

**Interfaces:**
- After Tasks 1–5, nothing calls the old `Postgres.build_dynamic(source, binding, {key, params}, opts)` tidying chain. Remove `build_dynamic/4` (the old arity), `apply_expr/4`, `dispatch_expr/6`, `dispatch_field_expr/*`, `cast_value/2`, `build_rhs_entry/4`, `field_name_to_atom/3`, `resolve_datetime_*`, `op_alias/1`, `merge_dynamic/3` — all the tidying that `PredicateBuilder` now owns. Keep only the thin `build_dynamic(%Predicate{}, binding, opts)` adapter and the subquery builder.

- [ ] **Step 1: Confirm nothing references the old path**

Run: `grep -rn "build_dynamic(.*{.*}.*opts)\|apply_expr\|dispatch_expr\|cast_value\|field_name_to_atom" lib/ | grep -v predicate_builder`
Expected: only the thin adapter remains; the tidying helpers are unreferenced.

- [ ] **Step 2: Remove the dead functions; run the full suite**

Delete the listed functions. Run: `mix test`
Expected: PASS — the suite now runs entirely through `PredicateBuilder` + the thin adapter + the pure Expr modules.

- [ ] **Step 3: Mechanical purity gates**

Run the §5 verification greps:
- the four Expr modules contain no casting/aliasing/field-resolution/schema-reading;
- `Postgres` contains no tidying (no `cast_value`/`apply_expr`/`dispatch_expr`).

- [ ] **Step 4: Commit**

```bash
git add lib/ecto_shorts/dynamic_builders/postgres.ex
git commit -m "refactor(postgres): delete the old tidying path; adapter is now thin"
```

---

## Self-Review (done while writing)

- **Spec coverage:** the seam wiring (§3.1) → Tasks 1–2; D-CommonExpr-FIELD → Task 3; aggregate→HAVING + auto-GROUP-BY (§3.11) → Task 4; subquery operands + post-build sibling/parent validation (§1.5a, §3.11) → Task 5; the "shrink `build_dynamic` to a thin adapter" deferred from Plan 02 → Tasks 1 + 6.
- **Placeholders:** none. `ensure_group_by/1`, `merge_predicates/3`, `aggregate_predicate?/1`, and the subquery builder are named and specified; the subquery builder reuses the existing `build_quantified_query` machinery (relocated), not reinvented.
- **Type consistency:** the adapter consumes `%EctoShorts.CommonFilters.Predicate{}` (Plan 01) with `routing` ∈ `:scalar/:array/:map/:common`; `ShorthandExpr.dynamic_expr/5` (renamed from `CommonExpr`, Plan 02/naming pass) takes the resolved field; `Resolver.build_dynamic/3` is the renamed selector. Aggregate detection keys off `expr: {agg, _}` produced by `PredicateBuilder` (Plan 01).
- **Behaviour change noted:** the `DynamicBuilder` callback now takes a `%Predicate{}` — a v3.0.0 migration note for anyone implementing a custom dialect (only Postgres ships).
- **Carried to Plan 06:** the HTTP `:source_aliases` registry and the validate step that turns untrusted subquery/operand input into 4xx errors before it reaches the raising paths.
