# Plan Consistency Review — Plans 00–06

Four adversarial reviewers (cross-plan interfaces, stale-name sweep, sequencing &
scope, plans-vs-spec-decisions). Verdict: the plans **faithfully match the spec's
final decisions** (all 10 confirmed); the issues were drift from the many renames
plus one real ordering flaw. All fixed.

## Fixed

**Structural (the important one) — `PredicateBuilder` is dead code until Plan 05.**
The live path through Plans 01–04 is the old `Postgres` tidier, so Plans 03–04
could neither prove new operators end-to-end nor safely remove what the old path
feeds. Resolution (chosen: keep order, unit-test in 03–04, cut over in 05):
- Plans 03–04 now state: test new work at the **unit level** (`PredicateBuilder`
  `%Predicate{}` output + direct `Expr.dynamic_expr/5` calls); **add only, remove
  nothing** the old path feeds.
- Plan 03 Task 1 no longer removes the `ArrayExpr` `:in` clause.
- Plan 05 Task 6 now **owns** the deferred removals (`:elements`, `:in`-on-array →
  warn-skip) + their test reconciliation; new **Task 7** adds the post-wiring
  end-to-end coverage for everything Plans 03–04 unit-tested.

**Interface — `ShorthandExpr` arity (HIGH).** Plan 02 built a 6-arg form; Plan 05
called 5-arg. Unified to the **5-arg `dynamic_expr(binding, field, negated, expr,
opts)`** shape used by the other Expr modules (the shorthand operator rides inside
`expr`).

**Cosmetic drifts.** Plan 03 result assertions `%{term:}` → `%Predicate{expr:}`;
Plan 03 stale `term_resolver.ex` → `predicate_builder.ex`; Plan 02 `CommonExprTest`
→ `ShorthandExprTest` and `D-ShorthandExpr-FIELD` → `D-CommonExpr-FIELD`; Plan 05
one bare `DynamicBuilders.build_dynamic` → `DynamicBuilders.Resolver.build_dynamic`;
Plan 03 "subquery moves to Plan 04" → Plan 05.

## Confirmed consistent (no change)
- All 10 final spec decisions (D-LIST + operator-driven routing, list-returning
  `build`, D-ONE-WAY, D-OPERAND, D-ADD-SHIFT, D-NULL, D-RAISE, aggregate→HAVING,
  naming, validate-step shapes) are owned by the right plan and reflected.
- `common_field_for/1` handoff (Plan 02 caller → Plan 05 into `PredicateBuilder`),
  `known_operator?/1` (Plan 06 owns), the `Predicate` struct fields/`routing` atoms,
  and the `DynamicBuilder` behaviour-callback change (Plan 05, with migration note)
  are all internally consistent.

## Minor note left for the implementer
- Plan 01's inline transform branch should be extracted into `build_one_transform/3`
  when Plan 03 first references it (Plan 03 calls this out; no separate step needed).
