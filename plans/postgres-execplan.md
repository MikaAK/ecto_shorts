# Rewrite `EctoShorts.DynamicBuilders.Postgres` as a three-stage pipeline

This ExecPlan is a living document. The sections `Progress`,
`Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective`
must be kept up to date as work proceeds.


## Purpose / Big Picture

`EctoShorts.DynamicBuilders.Postgres` is the module that turns a user-facing
filter entry into an `Ecto.Query.DynamicExpr` value. Today the module is 802
lines and routes every filter entry through a four-stage chain of partial
normalization that repeatedly re-walks the same containers. After this
change the same module exposes the same public functions and produces the
same `Ecto.Query.DynamicExpr` outputs, but its body is a three-stage
pipeline — **normalize term**, **cast value**, **dispatch to leaf** — and
shrinks to roughly four to five hundred lines.

A reader who currently cannot follow a single filter entry from input to
output (because each helper hands off to another with overlapping
responsibilities) will, after this change, be able to read the file
top-to-bottom and see the entry flow through three named transformations.
The user-visible behavior is unchanged: every passing test in `mix test`
continues to pass; every failing test stays failing for the same reason.


## Progress

The following statuses are used:

- `draft`: the task is being written and is not ready to work on yet.
- `backlog`: the task is valid but not selected for work.
- `ready`: the task is clear enough to start.
- `in_progress`: someone is actively working on the task.
- `blocked`: work cannot continue until a dependency is resolved.
- `pending_review`: work is done and waiting for review.
- `changes_requested`: review found required changes.
- `complete`: the task is accepted and finished.
- `cancelled`: the task will not be completed.

- [x] [complete] (2026-05-25 baseline) Establish baseline test counts. `mix test` reports 1410 tests, 15 doctests, 9 failures. All 9 failures are in the `:map` field-type routing path on the schemaless test file and are pre-existing.
- [ ] [ready] Read the four leaf modules `ScalarExpr`, `ArrayExpr`, `MapExpr`, `CommonExpr` and write a one-paragraph summary of the canonical `{op, value}` shapes each accepts into the `Interfaces and Dependencies` section below. This is the contract the new pipeline must produce.
- [ ] [ready] Implement `normalize_term/3` as a pure shape-aware function that turns a raw filter term into a list of canonical entries. Operates on the term only — no source, binding, or repo handle. Verified by direct unit tests inside `test/ecto_shorts/dynamic_builders/postgres_test.exs`.
- [ ] [ready] Implement `cast_term/3` as a pure field-type-aware function that applies `EctoShorts.Types.cast` to a canonical term, preserving the operator-specific casting rules described in `Plan of Work`. Cast runs after normalize, never before.
- [ ] [ready] Implement `dispatch/5` as a routing-only function that picks the right leaf module (`ScalarExpr`, `ArrayExpr`, `MapExpr`, `CommonExpr`) and calls its `dynamic_expr/5`. No transformation.
- [ ] [ready] Implement `build_dynamic/4` as the public entry that walks the input, calls `normalize_term`, `cast_term`, and `dispatch` in order, and combines the results with `merge/3`.
- [ ] [ready] Keep `build_quantified_query/3` public and behaviourally identical. It is exercised by direct tests in `test/ecto_shorts/dynamic_builders/postgres_test.exs`.
- [ ] [ready] Keep `field_name_to_atom/3` with its three-tier fallback (schema fields, `:allowed_keys` opt, warn-only path). Used by `build_quantified_query/3` for string `:select` and `:field` keys.
- [ ] [ready] Delete the dead duplicate `not subquery_spec?(payload)` check inside the `canonical_payload` branch. Confirmed unreachable by static reading; covered by tests if reachable.
- [ ] [ready] Run `mix test` after the rewrite. Failure count must be no higher than 9 and the same 9 tests must be the only failures.
- [ ] [ready] Run `mix credo --strict` and `mix dialyzer`. No new findings.


## Surprises & Discoveries

Discoveries during implementation are recorded here. Until work begins,
this section captures the design-time observations that shaped the
approach.

- Observation: The middle helper `apply_expr/4` redoes the same map→keyword conversion that the entry clauses of `build_dynamic/4` already did. It is a redundant stage.
  Evidence: `lib/ecto_shorts/dynamic_builders/postgres.ex` lines 136–193 vs lines 179–193.

- Observation: `build_rhs_expr/3` uses `Enum.reduce(_, nil, fn _, _acc -> ... end)`, throwing away the accumulator and returning only the last entry. For multi-entry RHS maps the result depends on undefined map iteration order. The throw-away pattern is load-bearing because every existing caller sends single-entry RHS maps.
  Evidence: `lib/ecto_shorts/dynamic_builders/postgres.ex` lines 691–697; callers at lines 452 and elsewhere always Hand single-entry maps after the `Enum.find_value` step.

- Observation: `:arithmetic` is one input key with two structurally different output shapes. The `add`/`subtract`/`multiply`/`divide` branch produces `{compare_op, {:value, {arith_op, {{:field, f}, {:value, v}}}}}`; the `ago`/`from_now` branch produces `{compare_op, {cast, {arith_key, operand_without_cast}}}` with `cast` defaulting to `:datetime`.
  Evidence: `lib/ecto_shorts/dynamic_builders/postgres.ex` lines 316–348.

- Observation: Quantifier subquery detection by the `:from` key fires at two different dispatch points — the bare `{quantifier, payload}` clause and the wrapped `{op, {quantifier, payload}}` clause. Both must remain.
  Evidence: `lib/ecto_shorts/dynamic_builders/postgres.ex` lines 215–252 and 254–277.

- Observation: `field_kind` precedence is invalid → map → array → scalar, with `nil` returned for invalid fields. `merge_dynamic` treats `nil` as identity, so invalid-field entries silently drop without raising.
  Evidence: `lib/ecto_shorts/dynamic_builders/postgres.ex` lines 469–519 and lines 798–801.

- Observation: `CommonExpr` operators (`:before`, `:after`, `:since`, `:until`, `:exists`, `:start_date`, `:end_date`, `:since_date`, `:until_date`, `:ids`) route by key alone, skipping field-kind classification. They take precedence over field-kind routing.
  Evidence: `lib/ecto_shorts/dynamic_builders/postgres.ex` lines 287–290 and `lib/ecto_shorts/dynamic_builders/postgres/common_expr.ex` lines 10–23.

- Observation: A map-typed field with a keyword-list operator value, such as `{:contains, [role: "admin", active: "true"]}`, expands into two AND-merged `MapExpr.dynamic_expr/5` calls. This expansion is specific to map fields.
  Evidence: `lib/ecto_shorts/dynamic_builders/postgres.ex` lines 482–492.

- Observation: For an array field with a plain list value, `cast_value/2` calls `Types.cast(field_type, values)` once over the whole list. For the `:in` operator on an array field, the inner type cast happens element-wise. The two are not interchangeable.
  Evidence: `lib/ecto_shorts/dynamic_builders/postgres.ex` lines 609–611 vs lines 643–645.

- Observation: Every clause that walks a container guards with `not is_struct(term)`. Date, DateTime, NaiveDateTime, and Decimal structs are maps in Elixir's type system but must not be walked as containers.
  Evidence: `lib/ecto_shorts/dynamic_builders/postgres.ex` lines 137, 181, 204, 230, 397, 450, 691, 699, 719, 737.


## Decision Log

- Decision: Use the ExecPlan format from `cody:plan` rather than a TaskPlan.
  Rationale: The work edits `.ex` source files. Per the dispatch rules, code-touching work is an ExecPlan.
  Date/Author: 2026-05-25 / refactor working session.

- Decision: Rewrite this module first, before `EctoShorts.CommonFilters`.
  Rationale: `CommonFilters` routes predicate filters through `Builder` which calls `Postgres.build_dynamic/4`. If `Postgres` has regressions, `CommonFilters` tests will look broken for the wrong reason. Stabilize the leaf of the dispatch chain first.
  Date/Author: 2026-05-25 / refactor working session.

- Decision: Normalize a term completely before casting any value.
  Rationale: If a caller passes `{op, %{value: 5}}`, the cast clause that matches `{op, {:value, value}}` only fires after normalize has collapsed the inner map into the `{:value, 5}` tuple. Reversing the order causes cast to fall through to the catch-all and return the value unchanged. This was not previously documented anywhere in the code.
  Date/Author: 2026-05-25 / refactor working session.

- Decision: Preserve the `merge(nil, _, b)` and `merge(a, _, nil)` identity rules verbatim.
  Rationale: Invalid-field entries return `nil` from their leaf and must silently drop without raising. The current code expresses this as `merge_dynamic(nil, :and, expr)`. The new code preserves the semantic but drops the `(nil, :and, ...)` syntactic noise where it served only to mean "return expr."
  Date/Author: 2026-05-25 / refactor working session.

- Decision: Preserve the `build_rhs_expr/3` throw-away accumulator semantic.
  Rationale: Tests rely on the existing single-entry RHS map contract. "Fixing" the accumulator to fold multiple entries would change behavior for any hypothetical multi-entry input. The contract is single-entry; the implementation matches the contract.
  Date/Author: 2026-05-25 / refactor working session.

- Decision: Delete the dead `not subquery_spec?(payload)` re-check inside the `canonical_payload` branch.
  Rationale: The outer `if subquery_spec?(payload)` clause has already returned by the time the `canonical_payload` branch can run. The duplicate check is unreachable. Confirmed by static reading. The test suite will validate.
  Date/Author: 2026-05-25 / refactor working session.


## Outcomes & Retrospective

To be filled when implementation completes. The expected summary is: the
module shrinks from 802 lines to roughly 400–500 lines, the four-stage
dispatch chain is replaced by a three-stage pipeline (normalize → cast →
dispatch), and the same test surface passes with the same failure count.


## Context and Orientation

The module under refactor lives at
`lib/ecto_shorts/dynamic_builders/postgres.ex`. It is the Postgres-specific
implementation of the `EctoShorts.DynamicBuilder` behaviour declared in
`lib/ecto_shorts/dynamic_builder.ex`. The behaviour is selected at runtime
by `EctoShorts.DynamicBuilders.build_dynamic/4` (in
`lib/ecto_shorts/dynamic_builders.ex`), which resolves a per-call
`:dynamic_builder` opt, then a `:dynamic_builder_module` app-config value,
then auto-detects from `repo.__adapter__/0`. Only the Postgres adapter is
currently supported.

The leaf modules that produce the actual SQL fragments live in
`lib/ecto_shorts/dynamic_builders/postgres/`:

- `scalar_expr.ex` — comparisons (`:==`, `:!=`, `:>`, `:>=`, `:<`, `:<=`), membership (`:in`, list values for `:==`/`:!=`), string operators (`:like`, `:ilike`), string transforms (`:lower`, `:upper`), aggregate comparisons (`:avg`/`:sum`/`:max`/`:min`/`:count` wrapping a comparison), datetime wrappers (`:date`/`:datetime` wrapping `:ago`/`:from_now`/`:add`), arithmetic comparisons (`:+`/`:-`/`:*`/`:/` on field references), quantifier comparisons (`{op, {:all|:any, qv}}`), parent-binding references (`:parent_as`), and value wrappers (`{op, {:value, v}}`).
- `array_expr.ex` — Postgres array operators: scalar-in-array membership, array overlap (`&&`), array containment (`<@`), array length (`:count`), array all/any (`:all`, `:any` over array element value), string transforms over array elements, and pattern matches over array elements.
- `map_expr.ex` — JSONB operators: containment `@>` (`:contains`), contained-by `<@` (`:contained_by`), key existence `jsonb_exists` (`:has_key`), any-key existence `jsonb_exists_any` (`:has_any_key`), all-keys existence `jsonb_exists_all` (`:has_all_keys`).
- `common_expr.ex` — cursor and date-range shortcuts that bind to fixed field names: `:ids`, `:before`, `:after`, `:since`, `:until` operate on `id`; `:start_date`, `:since_date`, `:end_date`, `:until_date` operate on `inserted_at`; `:exists` wraps a subquery.

Each leaf module exports `dynamic_expr/5` taking `(binding, key, negated, term, opts)` and returns either an `Ecto.Query.DynamicExpr` or `nil`. The `term` parameter is in a canonical shape: either a single tuple like `{op, value}` or a deeper tuple shape for wrapped values. Producing that canonical shape from arbitrary user input is the responsibility of `EctoShorts.DynamicBuilders.Postgres` — the module under refactor.

Supporting modules used by the refactor:

- `lib/ecto_shorts/types.ex` defines `EctoShorts.Types.cast/2` which applies Ecto type coercion to a single value or list.
- `lib/ecto_shorts/common_schema.ex` defines `EctoShorts.CommonSchema.get_schema_reflection/2` and `/3` which look up schema fields, associations, and per-field types from a source (a schema module, an `{source, schema}` tuple, or an `Ecto.Query`).
- `lib/ecto_shorts/query_binding.ex` defines `EctoShorts.QueryBinding.query_binding_contracts/1` — a compile-time macro that generates one head per binding shape (default, named via `:as`, positional via `:at`) for any module that builds dynamic expressions against multiple bindings.
- `lib/ecto_shorts/logger.ex` defines `EctoShorts.Logger.warning/2` used for the invalid-field and out-of-range-binding warnings.

Term-of-art glossary, in plain language:

- A *filter entry* is a `{key, value}` pair in the user-supplied params map. `key` is the field name (`:title`) or a structural keyword (`:where`); `value` is what the filter is supposed to match.
- A *canonical term* is the input shape the leaf modules accept: a tuple `{op, value}` where `op` is a known operator (`:==`, `:!=`, `:>`, `:like`, `:contains`, etc.) and `value` is a scalar, list, or nested tuple with specific further structure documented in the leaf modules.
- *Normalize* means: starting from arbitrary user input shapes (map values, keyword-list values, short-op aliases, transform aliases, wrapper keys like `:arithmetic`/`:aggregate`/`:elements`/`:not`), produce one or more canonical terms.
- *Cast* means: apply `EctoShorts.Types.cast/2` to the leaf of a canonical term so the value matches the schema field's declared Ecto type before it enters the SQL builder.
- *Dispatch* means: choose which leaf module receives the canonical term, based on whether the operator is a `CommonExpr` operator (key-based precedence) or, failing that, the kind of the schema field (scalar / array / map / invalid).
- A *binding selector* is a tuple `{:as, atom_or_nil}` or `{:at, positive_integer}` that names which binding in an `Ecto.Query` the leaf module should reference.


## Plan of Work

The work lands as a single replacement of `lib/ecto_shorts/dynamic_builders/postgres.ex`. The
current four-stage chain (`build_dynamic` → `apply_expr` → `dispatch_expr` →
`dispatch_field_expr`) is replaced by the following internal topology:

The public entry point `build_dynamic/4` accepts the same arguments as
today: `(source, selected_binding, args, opts)` where `args` is either an
ordinary `{key, value}` filter entry or a top-level quantified group
`{:all, params}` or `{:any, params}`. For the quantifier case,
`build_dynamic/4` walks `params` and merges each child's result with the
quantifier as the merge operator. For the ordinary case, it does three
things in sequence: it looks up the field type for `key`, calls
`normalize_term/3` to produce a list of canonical entries, casts each
entry's value with `cast_term/3`, then routes each entry through
`dispatch/5` and merges the results with `merge/3`.

`normalize_term/3` takes `(value, field_type, ctx)` where `ctx` carries
the negated flag and any structural markers (such as the `:elements`
override that forces array routing). It returns a list of
`{merge_op, term}` entries. The function handles in one pass:

- Map values: coerce to keyword list (guarded by `not is_struct(value)`),
  then walk entries with `:and` as the default merge op.
- Keyword-list values: walk entries; if an entry is `{:and, inner}` or
  `{:or, inner}` use that as the merge op; otherwise merge with `:and`.
- Scalar values: produce one canonical `{:==, value}` entry.
- Short-op aliases (`:eq`, `:ne`, `:gt`, `:gte`, `:lt`, `:lte`):
  rewrite to canonical `:==`, `:!=`, `:>`, `:>=`, `:<`, `:<=`.
- Transform aliases (`:downcase`, `:upcase`): rewrite to `:lower`,
  `:upper`.
- `:not` stripping: when an entry is `{:not, inner}`, recurse on `inner`
  with `negated: :not` in `ctx`. Leaf modules receive the negated flag
  and apply it to their output.
- `:arithmetic` wrapper expansion: read `compare:` and find the single
  arith key. If the arith key is `add`/`subtract`/`multiply`/`divide`,
  produce `{compare_op, {:value, {arith_op, {{:field, f}, {:value, v}}}}}`
  where `arith_op` is `:+`/`:-`/`:*`/`:/`. If the arith key is `ago` or
  `from_now`, read the optional `cast:` key (default `:datetime`) and
  produce `{compare_op, {cast, {arith_key, operand_without_cast}}}`.
- `:aggregate` wrapper expansion: read `fn:`, `compare:`, `value:` and
  produce `{agg_fn, {compare_op, value}}`.
- Aggregate shorthand: when `agg_fn` is one of `:avg`, `:sum`, `:max`,
  `:min`, `:count` and the payload is a single-entry map or keyword,
  produce `{agg_fn, {compare_op, value}}`.
- `:elements` wrapper: produces a canonical term but tags the entry so
  `dispatch/5` forces `ArrayExpr` regardless of field kind.
- `{op, rhs_map}` RHS construction: when the right-hand side is a map,
  walk entries and emit one of these canonical RHS shapes:
  - `{:field, name}` → field reference
  - `{:value, inner}` → value wrapper around a normalized inner expr
  - `{:+|:-|:*|:/, [left, right]}` → arithmetic on two normalized exprs
  - `{:parent_as, {pb, pf}}` → parent-binding reference
  - `{:date, {dt_op, dt_term}}` → date wrapper
  - `{:datetime, {dt_op, dt_term}}` → datetime wrapper
  The RHS-construction walk preserves the existing throw-away
  accumulator semantic: only the last entry processed is returned.
  Callers must send single-entry RHS maps.

`cast_term/3` takes `(canonical_term, field_type, opts)`. It is
operator-aware:

- `{:array, _}, {:count, {op, value}}` → cast `value` to `:integer`.
- `{:array, inner_type}, {:all, {op, value}}` for `op` in `[:>, :>=, :<, :<=]` → cast `value` to `inner_type`.
- `{:array, inner_type}, {op, value}` for `op` in `[:==, :!=, :in, :>, :>=, :<, :<=, :lower, :upper, :like, :ilike]` → cast `value` element-wise via the inner type when `value` is a list, otherwise via the inner type as scalar.
- `field_type, {op, list}` for `op` in `[:==, :!=, :in]` and `list` a list (non-array field) → element-wise cast.
- `field_type, {op, {:value, value}}` for `op` in comparison ops → cast inside the `:value` wrapper.
- `field_type, {op, value}` for `op` in comparison ops → cast `value`.
- `{:array, _}, list_value` (plain list, no operator wrapper, for `:==`/`:!=` over the whole array) → cast as one array.
- Catch-all: return the term unchanged.

`dispatch/5` takes `(source, binding, key, canonical_term, opts)`. It
applies `CommonExpr` operator precedence first: if `key` is one of the
`CommonExpr.operators()`, route to `CommonExpr.dynamic_expr/5` with the
canonical term's value as the term argument. Otherwise classify the
field via `field_kind/3` and route:

- `:invalid` → log warning via `EctoShorts.Logger.warning/2`, return `nil`.
- `:elements` marker or `:array` field kind → `ArrayExpr.dynamic_expr/5`.
- `:map` field kind → `MapExpr.dynamic_expr/5`. If the canonical term is
  `{op, keyword_list}` and `keyword_list` is non-empty, expand into N
  AND-merged calls, one per keyword pair.
- `:scalar` (default) → `ScalarExpr.dynamic_expr/5`.

`field_kind/3` returns `:invalid | :map | :array | :scalar` based on
`opts[:field_types]` first (so callers can override) then
`CommonSchema.get_schema_reflection(source, :type, key)`. Reorder is not
permitted: invalid must be checked before map and array, since invalid
returns `nil` and silently drops the entry.

`merge/3` takes `(a, merge_op, b)`. If either side is `nil`, return the
other side unchanged. Otherwise return `dynamic([], ^a and ^b)` for
`:and` and `dynamic([], ^a or ^b)` for `:or`. This is the same body as
the existing `merge_dynamic/3` minus the `(nil, :and, b)` and `(a, _, nil)`
syntactic noise at branch ends.

`field_name_to_atom/3` is unchanged. It runs three fallbacks: schema
fields path, `:allowed_keys` opt path, warn-only path. It is used by
`build_quantified_query/3` for string `:select` and `:field` keys.

`build_quantified_query/3` is unchanged in signature and behavior. It
remains public because it is directly tested in
`test/ecto_shorts/dynamic_builders/postgres_test.exs`.


## Concrete Steps

Working directory is the repository root,
`/Users/kurthogarth/Documents/GitHub/ecto_shorts`.

Step 1. Capture baseline:

    mix test

Expected output ends with:

    Finished in 2.2 seconds (2.2s async, 0.00s sync)
    15 doctests, 1410 tests, 9 failures

Note the random seed printed at the end; do not require the same seed
across runs.

Step 2. Apply the rewrite by replacing
`lib/ecto_shorts/dynamic_builders/postgres.ex` in a single edit. The
final file body matches the topology described in `Plan of Work` and
satisfies the contract in `Interfaces and Dependencies` below.

Step 3. Run the full suite again:

    mix test

Expected: `15 doctests, 1410 tests, 9 failures`. The same nine tests
must be the only failures. Any new failure invalidates the rewrite and
requires diagnosis before proceeding.

Step 4. Run the direct unit tests for the module:

    mix test test/ecto_shorts/dynamic_builders/postgres_test.exs

Expected: all tests pass. These exercise `build_dynamic/4` and
`build_quantified_query/3` directly.

Step 5. Run static analysis:

    mix credo --strict
    mix dialyzer

Expected: no new findings beyond the existing baseline. The Dialyzer
PLT is stored in `./dialyzer/`; the first run may rebuild it.


## Validation and Acceptance

The rewrite is accepted when all five of the following are observed:

1. `mix test` reports `15 doctests, 1410 tests, 9 failures` and the
   nine failing tests are exactly those in
   `test/ecto_shorts/common_filters/common_filters_field_types_opt_test.exs`
   and `test/ecto_shorts/common_filters_schemaless_test.exs` that exist
   in the baseline.
2. `mix test test/ecto_shorts/dynamic_builders/postgres_test.exs`
   passes every test, including the direct tests for
   `build_quantified_query/3` with a non-keyword payload and with a
   binary `:select` spec.
3. `mix credo --strict` reports no new findings.
4. `mix dialyzer` reports no new warnings.
5. The file `lib/ecto_shorts/dynamic_builders/postgres.ex` is between
   350 and 550 lines, exclusive of the `@moduledoc`. The public API is
   unchanged: `build_dynamic/4`, `build_quantified_query/3`, and the
   `EctoShorts.DynamicBuilder` behaviour conformance are intact.

Behavior-as-a-user check: in `iex -S mix`, the following expression
returns the same `Ecto.Query.DynamicExpr` as today —

    iex> EctoShorts.DynamicBuilders.Postgres.build_dynamic(
    ...>   EctoShorts.Schema.Post,
    ...>   {:as, nil},
    ...>   {:views, %{>: 1, <: 10}},
    ...>   []
    ...> )
    #Ecto.Query.DynamicExpr<...>

Compare against the same call on the prior `main` revision and confirm
the SQL produced by `Ecto.Adapters.SQL.to_sql/3` is identical.


## Idempotence and Recovery

The rewrite replaces a single file. If any acceptance gate fails, the
recovery procedure is `git checkout
lib/ecto_shorts/dynamic_builders/postgres.ex` to restore the prior
version, then diagnose the regression before re-applying the rewrite.

`mix test` is idempotent. `mix credo` is idempotent. `mix dialyzer`
caches its PLT in `./dialyzer/`; re-running it after the rewrite reads
the existing PLT (no rebuild) unless dependencies change.

No destructive operations are required. No database state is modified.
No filesystem state outside the repository is touched.


## Artifacts and Notes

Baseline test failure transcript, captured 2026-05-25:

    Finished in 2.2 seconds (2.2s async, 0.00s sync)
    15 doctests, 1410 tests, 9 failures

    Randomized with seed 688057

All nine failures are in tests asserting `:map` field-type routing on
the schemaless source; the produced query is the bare from-clause
rather than the expected JSONB containment fragment.

Verification artifacts:

- File path claim: `lib/ecto_shorts/dynamic_builders/postgres.ex` exists.
  Evidence: `ls -la lib/ecto_shorts/dynamic_builders/postgres.ex`.
- Line count claim: 802 lines at baseline.
  Evidence: `wc -l lib/ecto_shorts/dynamic_builders/postgres.ex`.
- Test count claim: 1410 tests, 15 doctests, 9 failures.
  Evidence: `mix test` final summary line.
- Behaviour conformance claim: implements `EctoShorts.DynamicBuilder`.
  Evidence: `grep "@behaviour EctoShorts.DynamicBuilder" lib/ecto_shorts/dynamic_builders/postgres.ex`.
- Public API claim: `build_dynamic/4`, `build_quantified_query/3`.
  Evidence: `grep -E "^\s+def\s+(build_dynamic|build_quantified_query)" lib/ecto_shorts/dynamic_builders/postgres.ex`.


## Interfaces and Dependencies

The rewritten module is named `EctoShorts.DynamicBuilders.Postgres` and
lives at `lib/ecto_shorts/dynamic_builders/postgres.ex`. After the
refactor it has the following final-state shape.

Behaviour conformance:

- `@behaviour EctoShorts.DynamicBuilder` — implements the `build_dynamic/4` callback declared in `lib/ecto_shorts/dynamic_builder.ex`.

Public functions:

- `build_dynamic(source, selected_binding, args, opts \\ [])` — the behaviour callback. Returns an `Ecto.Query.DynamicExpr` or `nil`.
- `build_quantified_query(outer_key, params, opts)` — builds the inner query for an `:all`/`:any` subquery payload that carries a `:from` key. Called from within `dispatch/5` and exposed publicly for direct test coverage.
- `field_name_to_atom(source, field_name, opts)` — resolves a string field name to an atom via schema fields, `:allowed_keys` opt, or warn-only fallback. Used by `build_quantified_query/3`.

Private pipeline functions:

- `normalize_term(value, field_type, ctx)` returns a list of `{merge_op, canonical_term}` entries.
- `cast_term(canonical_term, field_type, opts)` returns a cast canonical term.
- `dispatch(source, binding, key, canonical_term, opts)` returns a dynamic expression or `nil`.
- `merge(a, merge_op, b)` combines two dynamic expressions; `nil` on either side acts as identity.
- `field_kind(source, key, opts)` returns `:invalid | :map | :array | :scalar`.

Dependencies (these modules must exist and remain importable):

- `EctoShorts.DynamicBuilder` (the behaviour spec)
- `EctoShorts.CommonFilters` (called from `build_quantified_query/3` for recursive query construction)
- `EctoShorts.CommonFilters.Select` (called from `build_quantified_query/3` for `:select` projection of the inner query)
- `EctoShorts.CommonSchema` (field reflection)
- `EctoShorts.Types` (value casting)
- `EctoShorts.DynamicBuilders.Postgres.ScalarExpr` (leaf)
- `EctoShorts.DynamicBuilders.Postgres.ArrayExpr` (leaf)
- `EctoShorts.DynamicBuilders.Postgres.MapExpr` (leaf)
- `EctoShorts.DynamicBuilders.Postgres.CommonExpr` (leaf, also exports `operators/0` for the dispatch precedence check)
- `EctoShorts.Logger` (warnings)
- `Ecto.Query` (`dynamic/1`, `dynamic/2` macros)

The canonical input shapes that each leaf module accepts are documented
in this file's `Context and Orientation` section above. The new
pipeline's contract with each leaf is exactly that shape — no more,
no less.

No new modules are introduced by this refactor. No existing modules are
removed. No public function signatures change. The
`EctoShorts.DynamicBuilders` entry-point module (at
`lib/ecto_shorts/dynamic_builders.ex`) is unchanged.
