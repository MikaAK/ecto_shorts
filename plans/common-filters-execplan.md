# Rewrite `EctoShorts.CommonFilters` as a pattern-matched dispatcher

This ExecPlan is a living document. The sections `Progress`,
`Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective`
must be kept up to date as work proceeds.


## Purpose / Big Picture

`EctoShorts.CommonFilters` is the public query language of the
EctoShorts library. A caller hands it an `Ecto` source (a schema
module, an `{source_name, schema}` tuple, or an existing `Ecto.Query`)
and a map or keyword list of params, and the module returns an
`Ecto.Query` with the corresponding clauses applied. Today the module
is 539 lines and routes each filter entry through a seven-branch `cond`
inside `apply_filter/6`, mixing shape classification with action and
recursion. After this change the same module exposes the same public
functions and produces the same `Ecto.Query` outputs, but the dispatch
is a flat set of pattern-matched function clauses with each clause
naming exactly one filter family — and the body shrinks to roughly
one hundred and fifty to two hundred lines exclusive of the
`@moduledoc`.

A reader who currently has to trace through `apply_filter/6`'s `cond`
branches and the three predicate helpers (`assoc_key?`, `params?`,
`list_of_params?`) before understanding how a single entry reaches its
builder will, after this change, read the function clauses top-to-bottom
and see one clause per family. The user-visible behavior is unchanged.
Every passing test in `mix test` continues to pass; every failing
test stays failing for the same reason.


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

- [x] [complete] (2026-05-25 baseline) Establish baseline test counts. `mix test` reports 1410 tests, 15 doctests, 9 failures. The same 9 failures must remain after this rewrite.
- [ ] [blocked] Begin this rewrite only after `plans/postgres-execplan.md` reaches `## Status: complete` on its primary task. Reason: predicate filters in `CommonFilters` route through `Builder` and then through `Postgres.build_dynamic/4`. Stabilizing `Postgres` first means any regression observed after this rewrite is caused by this rewrite.
- [ ] [ready] Implement single-pass `sort/1` that partitions params into `{wheres, others, or_wheres, terminals}` via one `Enum.reduce`, replacing the four `Enum.filter` calls in `sort_filter_params/1`.
- [ ] [ready] Replace `apply_filter/6` cond with `dispatch/6` pattern-matched clauses, one per filter family, in the order described in `Plan of Work`.
- [ ] [ready] Inline `or_entries/6` at its single call site inside the `:or`-with-map clause.
- [ ] [ready] Delete the 30-line `# IMPLEMENTATION CONTRACT` block comment and replace it with a three-line note that meaning is assigned at `{key, value}` entry boundaries.
- [ ] [ready] Keep `convert_params_to_filter/2`, `convert_params_to_filter/3`, and `filters/0` as the public API. `filters/0` returns the same atom list and `@type filters` enumerates the same atoms.
- [ ] [ready] Keep the `@logger_prefix` value `"EctoShorts.CommonFilters"` so existing log assertions in tests continue to match.
- [ ] [ready] Keep the `@moduledoc` body. It is the user-facing documentation of the filter language and is referenced by the README and by external consumers.
- [ ] [ready] Run `mix test` after the rewrite. Failure count must stay at 9 and the same 9 tests must be the only failures.
- [ ] [ready] Run `mix credo --strict` and `mix dialyzer`. No new findings.


## Surprises & Discoveries

Discoveries during implementation are recorded here. Until work begins,
this section captures the design-time observations that shaped the
approach.

- Observation: The catch-all clause `apply_filter(filter, source, query, selected_binding, params, opts)` (the second `defp apply_filter/6` head) exists to handle one situation: a recursive call that passes a bare params container instead of a `{key, value}` tuple. It is reached only from the `:where`/`:or_where`/`:having`/`:or_having` clause and from the assoc-handling clause. The same behavior can be expressed by walking the container at the call site and re-dispatching with `{key, value}` shape, removing the need for a separate function head.
  Evidence: `lib/ecto_shorts/common_filters.ex` lines 460–462 and the call sites at lines 418–422, 481.

- Observation: `or_entries/6` is a one-line function with one call site. It exists only to name the operation but adds no abstraction.
  Evidence: `lib/ecto_shorts/common_filters.ex` lines 464–466 and the single caller at line 447.

- Observation: `sort_filter_params/1` walks the input four times. A single-pass reduce with a four-tuple accumulator produces the same partition with one walk.
  Evidence: `lib/ecto_shorts/common_filters.ex` lines 526–538.

- Observation: The 30-line `# IMPLEMENTATION CONTRACT` comment block exists to document that "meaning is assigned at the `{key, value}` entry boundary." Once the dispatch is pattern-matched on `{key, value}` tuples, that fact is visible in the function signatures and no longer needs a thirty-line prose paragraph to explain.
  Evidence: `lib/ecto_shorts/common_filters.ex` lines 310–338.

- Observation: Three predicate helpers — `params?/1`, `list_of_params?/1`, and `assoc_key?/2` — are referenced from inside the `cond` block. In the rewrite, `params?/1` and `list_of_params?/1` survive as small guards used by the `:or` and predicate-key clauses. `assoc_key?/2` survives as a guard used by the field-level catch-all clause.
  Evidence: `lib/ecto_shorts/common_filters.ex` lines 517–524.


## Decision Log

- Decision: Use the ExecPlan format from `cody:plan` rather than a TaskPlan.
  Rationale: The work edits a `.ex` source file. Per the dispatch rules, code-touching work is an ExecPlan.
  Date/Author: 2026-05-25 / refactor working session.

- Decision: Block this rewrite on completion of the Postgres rewrite plan.
  Rationale: Predicate filters route through `Builder` and then into `Postgres.build_dynamic/4`. If `Postgres` has open regressions, `CommonFilters` tests will look broken for the wrong reason. The blocking is administrative — both files could technically be rewritten in parallel, but serializing them simplifies regression diagnosis.
  Date/Author: 2026-05-25 / refactor working session.

- Decision: Keep `walk_subtree`-style recursion folded into `dispatch/6` rather than splitting it into a separate function.
  Rationale: The current code has an explicit fallback head that calls `reduce_filters`. In the new shape the same effect is achieved by pattern-matching the container shape directly in `dispatch/6` and recursing entry-by-entry. One function head per filter family is easier to read than two functions that call each other.
  Date/Author: 2026-05-25 / refactor working session.

- Decision: Preserve the assoc-shorthand recursion semantics verbatim.
  Rationale: When `key` matches a declared association on `source`, the current code emits an implicit `:join` with `[association: [source: key, as: key]]`, then recurses with the association's queryable as the new source and `{:as, key}` as the new selected binding. Tests assert exactly this join shape and binding name. The new dispatch clause must match this contract.
  Date/Author: 2026-05-25 / refactor working session.

- Decision: Keep `filters/0` public.
  Rationale: It is referenced by `test/ecto_shorts/common_filters_test.exs` and may be used by external query-builder implementations to enumerate the supported filter keys.
  Date/Author: 2026-05-25 / refactor working session.


## Outcomes & Retrospective

To be filled when implementation completes. The expected summary is:
the module shrinks from 539 lines to roughly 150–200 lines (excluding
the `@moduledoc` block), the seven-branch `cond` is replaced by a flat
set of pattern-matched clauses, and the same test surface passes with
the same failure count.


## Context and Orientation

The module under refactor lives at `lib/ecto_shorts/common_filters.ex`.
Its public entry point `convert_params_to_filter/2,3` is the
caller-facing way to build an `Ecto.Query` from a params payload. The
module is consumed by `EctoShorts.Actions` for every read path and is
the named query language in the project's public documentation.

The module routes filter entries through `EctoShorts.CommonFilters.Builder`
(at `lib/ecto_shorts/common_filters/builder.ex`), which is the
`EctoShorts.QueryBuilder` behaviour implementation for structural
filters. `Builder` has its own routing layer with one clause per
structural filter, dispatching to per-filter modules under
`lib/ecto_shorts/common_filters/` (`Distinct`, `Join`, `OrderBy`,
`Page`, `Select`, etc.). Predicate filters (`:where`, `:or_where`,
`:having`, `:or_having`) are handled in `Builder` by calling
`EctoShorts.DynamicBuilders.build_dynamic/4`, which selects an
adapter-specific implementation — today only
`EctoShorts.DynamicBuilders.Postgres`. The rewrite of `CommonFilters`
must produce the same calls into `Builder` as today.

Term-of-art glossary:

- A *filter entry* is a `{key, value}` pair from the params input. `key`
  is either a structural keyword (`:where`, `:join`, `:order_by`, etc.),
  a boolean grouping keyword (`:and`, `:or`), a binding selector
  (`:as`, `:at`), a schema-association name, or a schema-field name.
  `value` is the payload for that entry, in a shape that depends on
  `key`.
- *Sort* in the context of this module means: rearrange the entries
  of the input keyword or map so that `:where` entries come first, all
  other non-predicate filters next, `:or_where` entries after that, and
  terminal entries (`:last`, `:subquery`) last. This ordering is
  required so that `OR WHERE` clauses follow `WHERE` clauses in the
  produced SQL and terminal clauses do not capture intermediate state.
- *Walk* means: recurse into a container (a map, a keyword list, or a
  list of maps/keyword lists) and treat each child entry as a new
  filter entry to dispatch.
- *Binding selector* means a tuple `{:as, nil}`, `{:as, atom()}`, or
  `{:at, pos_integer()}` identifying which binding in the produced
  query subsequent entries should target.
- *Association shorthand* means a top-level key that is the name of a
  declared `Ecto.Schema` association on `source`. The dispatcher
  treats it as an implicit join into that association.

Supporting modules used by the refactor:

- `EctoShorts.CommonSchema` (at `lib/ecto_shorts/common_schema.ex`)
  provides `to_query/1` and `get_schema_reflection/2,3` for source
  inspection and association lookup.
- `EctoShorts.CommonQuery` (at `lib/ecto_shorts/common_query.ex`)
  provides `query_binding_count/1` for resolving `at: :last` selectors.
- `EctoShorts.Config` (at `lib/ecto_shorts/config.ex`) provides
  `max_positional_bindings/0` for the `:at` range check (default 10).
- `EctoShorts.Logger` (at `lib/ecto_shorts/logger.ex`) provides
  `warning/2` for out-of-range binding and bad-shape assoc warnings.
- `EctoShorts.CommonFilters.Builder` (at
  `lib/ecto_shorts/common_filters/builder.ex`) implements the
  `EctoShorts.QueryBuilder` behaviour and is the dispatch target for
  every filter family except the binding-retarget, boolean-group, and
  assoc-shorthand handling.


## Plan of Work

The work lands as a single replacement of
`lib/ecto_shorts/common_filters.ex`. The current
`convert_params_to_filter/3` → `reduce_filters/6` → `apply_filter/6`
chain is replaced by `convert_params_to_filter/3` → `dispatch/6` with
each filter family expressed as a pattern-matched clause of
`dispatch/6` (or a small helper). The public surface is unchanged.

`convert_params_to_filter/3` accepts `(source, params, opts)` as
today. It coerces `source` to an `Ecto.Query` via
`CommonSchema.to_query/1`, sorts `params` via `opts[:sorter]` or the
new single-pass `sort/1`, then folds the sorted entries through
`dispatch/6` with the initial predicate filter set to `:where` and
the initial binding set to `{:as, nil}`.

`sort/1` does one pass with `Enum.reduce` over the entries. The
accumulator is a four-tuple `{wheres, others, or_wheres, terminals}`
of reversed lists. After the reduce, the four lists are reversed and
concatenated in order. Entries with key `:where` go to `wheres`,
entries with key `:or_where` go to `or_wheres`, entries with key
`:last` or `:subquery` go to `terminals`, everything else goes to
`others`.

`dispatch/6` accepts `(filter, source, query, selected_binding, entry, opts)`
where `filter` is the currently-active predicate filter
(`:where` by default, `:or_where` after entering an `:or` group,
`:having`/`:or_having` after entering a `:having` group), `source` is
the queryable source, `query` is the in-progress `Ecto.Query`,
`selected_binding` is the active binding selector, `entry` is either
a `{key, value}` tuple or a bare container, and `opts` is the
keyword opts. It is implemented as a set of pattern-matched function
heads, in the following order (top to bottom matters):

1. Binding selector clause — `{key, value}` where `key in [:as, :at]`.
   The body walks `value` as a map of `{inner_key => inner_value}`
   entries. For each, it resolves the new binding via
   `retarget_binding/3` and recurses into `dispatch/6` with the new
   binding and `inner_value` as the entry.

2. Predicate keys clause — `{key, value}` where `key in [:where, :or_where, :having, :or_having]`.
   If `value` is a list of params, walk it as multiple entries with
   `key` as the new predicate filter. If `value` is a single params
   map or keyword, recurse on each entry with `key` as the predicate
   filter. Otherwise route directly to `Builder.build_query(key, source, query, selected_binding, value, opts)`.

3. `:and` clause — `{:and, value}`. Walk `value` as entries; recurse
   with the same `filter`.

4. `:or` clause — `{:or, value}`. If `value` is a list of params,
   walk as `or_where` predicate entries. Otherwise walk `value` as a
   map or keyword and route each `{inner_key, inner_value}` through
   `Builder.build_query(:or_where, source, query, selected_binding, {inner_key, inner_value}, opts)`. This is the inlined version of the current `or_entries/6` helper.

5. Association shorthand clause — `{key, value}` where `assoc?(source, key)` is true.
   If `value` is not a params map or keyword, log a warning and return
   the query unchanged. Otherwise emit an implicit join via
   `Builder.build_query(:join, source, query, {:as, nil}, [association: [source: key, as: key]], opts)`,
   look up the associated source via `CommonSchema.get_schema_reflection/3`,
   and recurse into `dispatch/6` with the new source and `{:as, key}` as
   the new binding selector and `value` as the entry.

6. Known structural filter clause — `{key, value}` where `key in @filters`.
   Direct dispatch to `Builder.build_query(key, source, query, selected_binding, value, opts)`.

7. Field-level catch-all clause — `{key, value}` for any other shape.
   Direct dispatch to `Builder.build_query(filter, source, query, selected_binding, {key, value}, opts)`.

8. Bare-container clause — `value` that is not a `{key, value)` tuple.
   This is reached only via recursion from the predicate-keys, `:and`,
   and assoc-shorthand clauses. Walk `value` as entries with the current
   `filter`.

The order is significant. The binding-selector and predicate-key
clauses must precede the assoc-shorthand and structural-filter
clauses because `:as`, `:at`, and the predicate keys are not
associations and not in `@filters`. The assoc-shorthand clause must
precede the structural-filter clause because an association name is
not in `@filters` but must take precedence over the field-level
catch-all.

`retarget_binding/3` accepts `(query, key, inner_key)` and returns
`{:ok, new_binding}` or `:error`. The body handles the four cases
explicitly: `:at` with `:first` returns `{:ok, {:at, 1}}`; `:at` with
`:last` calls `CommonQuery.query_binding_count/1` and returns
`{:ok, {:at, n}}`; `:at` with an integer checks
`Config.max_positional_bindings/0` (default 10) and returns
`{:ok, {:at, position}}` if in range, else logs and returns `:error`;
all other shapes return `{:ok, {key, inner_key}}`.

`assoc?/2` and `assoc_source/2` are small helpers that look up
`CommonSchema.get_schema_reflection(source, :associations)` and
`CommonSchema.get_schema_reflection(source, :association, key)`
respectively.

`params?/1` returns true for a non-struct map or a keyword list.
`list_of_params?/1` returns true for the empty list or a list whose
head is a `params?/1`.


## Concrete Steps

Working directory is the repository root,
`/Users/kurthogarth/Documents/GitHub/ecto_shorts`.

Step 1. Confirm baseline (the same one Postgres ExecPlan recorded):

    mix test

Expected output ends with:

    Finished in 2.2 seconds (2.2s async, 0.00s sync)
    15 doctests, 1410 tests, 9 failures

Step 2. Confirm the Postgres ExecPlan has reached its acceptance gate.
This rewrite is blocked until then. If `mix test` shows more than 9
failures or the failing test names differ from the baseline, stop and
diagnose before continuing.

Step 3. Apply the rewrite by replacing
`lib/ecto_shorts/common_filters.ex` in a single edit. The final file
body matches the topology described in `Plan of Work` and satisfies
the contract in `Interfaces and Dependencies` below.

Step 4. Run the full suite:

    mix test

Expected: `15 doctests, 1410 tests, 9 failures`. The same nine tests
must be the only failures. Any new failure invalidates the rewrite and
requires diagnosis.

Step 5. Run the focused suites for this module:

    mix test test/ecto_shorts/common_filters/
    mix test test/ecto_shorts/common_filters_schemaless/
    mix test test/ecto_shorts/common_filters_test.exs

Expected: each suite passes, with the schemaless suite carrying its
nine `:map` field-type failures unchanged.

Step 6. Run static analysis:

    mix credo --strict
    mix dialyzer

Expected: no new findings beyond baseline.


## Validation and Acceptance

The rewrite is accepted when all five of the following are observed:

1. `mix test` reports `15 doctests, 1410 tests, 9 failures` and the
   nine failing tests are exactly those carried over from baseline.
2. `mix test test/ecto_shorts/common_filters_test.exs` passes,
   including the test that calls `CommonFilters.filters()` and asserts
   the returned list contains the expected atoms.
3. `mix credo --strict` reports no new findings.
4. `mix dialyzer` reports no new warnings.
5. The file `lib/ecto_shorts/common_filters.ex` is between 250 and 350
   lines including the `@moduledoc`, and the body excluding the
   `@moduledoc` is between 100 and 200 lines.

Behavior-as-a-user check: in `iex -S mix`, the following expressions
produce the same `Ecto.Query` as today —

    iex> EctoShorts.CommonFilters.convert_params_to_filter(
    ...>   EctoShorts.Schema.Post,
    ...>   %{published: true, comments: %{approved: true}},
    ...>   []
    ...> )
    #Ecto.Query<from p0 in EctoShorts.Schema.Post, join: c1 in assoc(p0, :comments), as: :comments, where: p0.published == ^true, where: c1.approved == ^true>

    iex> EctoShorts.CommonFilters.convert_params_to_filter(
    ...>   EctoShorts.Schema.Post,
    ...>   [where: %{published: true}, or_where: %{title: "Draft"}],
    ...>   []
    ...> )
    #Ecto.Query<from p0 in EctoShorts.Schema.Post, where: p0.published == ^true, or_where: p0.title == ^"Draft">

Compare the SQL produced by `Ecto.Adapters.SQL.to_sql/3` against the
same call on the prior `main` revision. The strings must match.


## Idempotence and Recovery

The rewrite replaces a single file. If any acceptance gate fails, the
recovery procedure is
`git checkout lib/ecto_shorts/common_filters.ex` to restore the prior
version, then diagnose before re-applying.

`mix test`, `mix credo`, and `mix dialyzer` are all idempotent. No
database state is modified. No filesystem state outside the repository
is touched.


## Artifacts and Notes

Public API verification snippet (current state, must remain
unchanged):

    iex> function_exported?(EctoShorts.CommonFilters, :convert_params_to_filter, 2)
    true
    iex> function_exported?(EctoShorts.CommonFilters, :convert_params_to_filter, 3)
    true
    iex> function_exported?(EctoShorts.CommonFilters, :filters, 0)
    true

Verification artifacts:

- File path claim: `lib/ecto_shorts/common_filters.ex` exists.
  Evidence: `ls -la lib/ecto_shorts/common_filters.ex`.
- Line count claim: 539 lines at baseline.
  Evidence: `wc -l lib/ecto_shorts/common_filters.ex`.
- `@filters` constant claim: 32 atoms.
  Evidence: read `lib/ecto_shorts/common_filters.ex` lines 269–304.
- Builder dispatch claim: `Builder.build_query/6` is the routing target
  for every structural filter.
  Evidence: `grep "Builder.build_query" lib/ecto_shorts/common_filters.ex`.
- Predicate routing claim: `:where`/`:or_where` ultimately call
  `EctoShorts.DynamicBuilders.build_dynamic/4` via Builder.
  Evidence: `grep "DynamicBuilders.build_dynamic" lib/ecto_shorts/common_filters/builder.ex`.


## Interfaces and Dependencies

The rewritten module is named `EctoShorts.CommonFilters` and lives at
`lib/ecto_shorts/common_filters.ex`. After the refactor it has the
following final-state shape.

Public functions:

- `convert_params_to_filter(source, params)` — delegates to the three-argument form with `opts = []`. Returns an `Ecto.Query.t()`.
- `convert_params_to_filter(source, params, opts)` — the canonical entry point. Accepts a schema module, `{source, schema}` tuple, or `Ecto.Query` as `source`; a map or keyword list as `params`; and a keyword list of options as `opts`. Returns an `Ecto.Query.t()`.
- `filters/0` — returns the canonical list of supported structural-filter atoms (`@filters`). Marked `@doc false` but kept public.

Module attributes:

- `@filters` — the same 32-atom list as today, in the same order: `:distinct, :except, :except_all, :exclude, :first, :group_by, :having, :intersect, :intersect_all, :join, :last, :limit, :lock, :offset, :order_by, :or_having, :or_where, :page, :prepend_order_by, :preload, :put_query_prefix, :recursive_ctes, :reverse_order, :select, :select_merge, :subquery, :union, :union_all, :update, :where, :windows, :with_cte, :with_named_binding, :with_ties`.
- `@type filters` — the same union type as today, enumerating the same atoms.
- `@logger_prefix` — `"EctoShorts.CommonFilters"`. Must remain exactly this string; test assertions match on it.

Private functions and their responsibilities at the final state:

- `dispatch/6` — pattern-matched on the entry shape, one clause per filter family. Eight clauses total in the order listed in `Plan of Work`.
- `sort/1` — single-pass `Enum.reduce` partitioning into the four-tuple `{wheres, others, or_wheres, terminals}`.
- `retarget_binding/3` — resolves an `:as`/`:at` selector to a binding tuple, with the range check for positional bindings.
- `assoc?/2` and `assoc_source/2` — small lookups against `CommonSchema.get_schema_reflection/3`.
- `params?/1` and `list_of_params?/1` — small guards.

Dependencies (these modules must exist and remain importable):

- `EctoShorts.CommonQuery` — for `query_binding_count/1`.
- `EctoShorts.CommonSchema` — for `to_query/1` and `get_schema_reflection/2,3`.
- `EctoShorts.Config` — for `max_positional_bindings/0`.
- `EctoShorts.Logger` — for `warning/2`.
- `EctoShorts.CommonFilters.Builder` — the routing target for every structural and predicate filter. Implements `@behaviour EctoShorts.QueryBuilder`.

No new modules are introduced by this refactor. No existing modules
are removed. No public function signatures change. The 32-atom
`@filters` constant and the matching `@type filters` are preserved
verbatim.

Cross-reference: the predicate-filter path (`:where`, `:or_where`,
`:having`, `:or_having`) routes through `Builder` and into
`EctoShorts.DynamicBuilders.Postgres.build_dynamic/4`. The contract
that module exposes at the end of its own refactor is documented in
`plans/postgres-execplan.md`, which is this ExecPlan's upstream
dependency.
