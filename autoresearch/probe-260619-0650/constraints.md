# Probe Constraints — Plan for Reworking the Query-Building Code

This file lists the firm rules and decisions agreed during planning. Each rule
has an ID (A1, B1, and so on). The rules tell the team what the rework must and
must not do.

## Words used here

- Ecto: the Elixir library for talking to a database.
- Query building: turning a caller's filter parameters into a database request.
- Normalization / normalization pass: a separate step that rewrites all the
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
- Canonical term / grammar: the standard tidied form of a filter, and the full
  list of allowed shapes for it.
- Operator alias: a nickname for a comparison word (for example, "eq" for
  "equals").
- Cast / casting: convert a value to the type the column expects.
- Warn+nil: log a warning and skip that filter, leaving the query unchanged.
- Public contract / internal contract: the promises the code makes to outside
  callers / the promises its internal parts make to each other.
- Spec: the specification document — the agreed description of how things should
  behave.
- Test audit: going through the existing tests one by one to check them against
  the spec.

---

## Topic

Rework the query-building code so that jobs stop overlapping between
`EctoShorts.CommonFilters` and `EctoShorts.DynamicBuilders.Postgres`. Make the
`*Expr` modules pure. Get rid of the normalization pass. Bring back the
one-by-one reduce/fold style. Cut out over-cautious code and repeated functions.

Mode: interactive · Personas rotated: Skeptic, Domain Expert, Contradiction
Finder, Edge-Case Hunter, Scope Guardian, Ops Engineer · Rounds: 4 · Status: SATURATED

---

## Category A — Which pattern to use (the core decision)

- **A1 (HIGH)** Drop the "normalize first, then dispatch" pattern. There must be
  **no separate normalization pass** that walks the whole parameter structure and
  rewrites it before building.
  _Evidence: user — "I don't think it's even needed. I don't like the normalization pattern."_
- **A2 (HIGH)** Use this instead: **one reduce over the params, tidying each
  piece at the moment it is handled (transform-at-leaf)**. Each entry becomes a
  database condition right where it is processed, not rewritten ahead of time.
- **A3 (HIGH)** Keep the operator nicknames (`:eq`→`:==`, `:downcase`→`:lower`,
  and so on), but handle them as **ordinary branches in the reduce/dispatch layer
  above the Expr modules** — never as a separate pass, and never inside the Expr
  modules.
- **A4 (MED)** The wrapper operators (`:arithmetic`, `:aggregate`, `:elements`)
  and the datetime wrappers (`:ago`/`:from_now`/`:date`) follow the **same
  transform-at-leaf rule**, so the Expr modules always get one uniform tidied
  shape.

## Category B — The purity promise for the Expr modules

- **B1 (HIGH)** `ScalarExpr`/`ArrayExpr`/`MapExpr` are **not allowed** to do any
  of these: swap operator nicknames, cast values, turn field-name strings into
  atoms, or inspect the schema.
- **B2 (HIGH)** The Expr modules get **only canonical terms** (the standard tidied
  form), and their one job is to **produce the final database condition**.

## Category C — Where the removed work goes (the resolver)

- **C1 (HIGH)** Casting, field-name resolution, and turning nicknames into their
  standard form all live in a **small, dedicated resolver module** that the reduce
  calls just before it hands a piece off to be built.
- **C2 (HIGH)** The resolver is **dialect-agnostic** — it is shared code that is
  not specific to any one database. The database-specific modules (the Postgres
  Expr modules) only produce the final condition. This keeps the Expr modules as
  pure as possible and lets them be reused across databases under the
  `DynamicBuilder` behaviour.

## Category D — What to break apart and turn into reduces

- **D1 (HIGH)** Split `comparison_impl` (about 370 lines, 100+ branches) **by the
  kind of operand** (scalar / quantified / aggregate / datetime / arithmetic /
  parent_as), **and** fold the 42 `apply_*_comparison` condition-builders into a
  **single matrix function**.
- **D2 (HIGH)** `sort_filter_params`: replace the **four `Enum.filter` passes with
  one reduce** that sorts the entries into groups in a single pass.
- **D3 (HIGH)** The param→condition building (`build_dynamic`/`apply_expr`/
  `dispatch_expr`): collapse the recursive container-rewrite into a **fold**.
- **D4 (MED)** Map→keyword conversion plus container flattening: **fold directly**,
  without creating throwaway keyword lists along the way.
- **D5 (HIGH)** `cast_value` (18 versions) currently recurses and **also unwraps
  operators**. Separate the two jobs: casting must be kept apart from operator
  unwrapping.

## Category E — Behavior and the public interface

- **E1 (HIGH)** Keep exactly the same behavior for unsupported combinations:
  **warn and skip the filter (warn+nil)**, do not crash. No visible change to logs
  or to callers — _measured against the behavior the spec defines_ (see G3 and
  conflict T2).
- **E2 (HIGH)** **No breaking changes to the public interface** (the parameter
  forms used with Actions and CommonFilters). **Internal module boundaries,
  function names, and arities may change freely.**

## Category F — Scope

- **F1 (HIGH)** Scope = **the whole query-building pipeline**: CommonFilters +
  Builder + the Postgres builder + all Expr modules.

## Category G — Spec-first process (how the work will be checked)

- **G1 (HIGH)** The existing tests are **not** the source of truth — they may lock
  in wrong behavior. **Write a specification document for
  `convert_params_to_filter/3` first.**
- **G2 (HIGH)** The spec must define a **closed canonical-term grammar**: the exact
  tidied shape the Expr modules receive (for example, `{field_atom, {canonical_op,
  cast_value}}`, with the negation / quantifier / wrapper variants all listed
  out), **plus** the operator families and the resolver's contract. It must be
  complete.
- **G3 (HIGH)** The spec must write down **every PUBLIC CONTRACT and INTERNAL
  CONTRACT**, must be **fully self-contained**, and must **describe how the parts
  behave where they meet**.
- **G4 (MED)** Reconcile the test audit **one case at a time during design**: when
  the spec and a test disagree, assume the test is wrong, but settle each clash on
  purpose, not by rewriting tests automatically.
- **G5 (HIGH)** Order of work: **Spec → test audit → writing-plans → implement.**
  No code until the spec is approved.

---

## The five most important constraints

1. **G1/G5** — Spec first; no code until it is approved. This sets the whole
   workflow.
2. **A1/A2/A3** — Kill the normalization pass; use one reduce plus
   transform-at-leaf, with nicknames handled as dispatch branches. This is the
   central design change.
3. **B1/B2 + C1/C2** — Pure Expr modules; a dialect-agnostic resolver owns
   casting, field-resolution, and turning input into the standard form.
4. **G2/G3** — A complete, closed canonical-term grammar plus public and internal
   contracts written down across boundaries.
5. **D1** — Break the ~370-line `comparison_impl` into per-family dispatchers plus
   one collapsed matrix.
