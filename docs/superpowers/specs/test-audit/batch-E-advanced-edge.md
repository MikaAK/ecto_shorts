# Test Audit — Batch E (advanced / edge)

Source of truth: `docs/superpowers/specs/2026-06-19-query-building-api-refactor-design.md`.
Verdict legend: **KEEP** (agrees with spec) · **CHANGE** (must update; cite decision) ·
**NEEDS-DECISION** (spec is silent or ambiguous).

---

## common_filters_parent_as_test.exs

Every test here uses the old `%{parent_as: %{binding: field}}` shape. Per **D-OPERAND** (§1.5a, §2.2)
the correlated reference becomes `%{parent: %{as: "binding", field: :field}}` and is **only valid
inside a subquery / `exists`**. None of these tests wrap the `parent` reference in a subquery — they
apply it directly to a top-level `where` against `Comment` / `Post`. So both the operand shape *and*
the surrounding context must change.

| test (name · line) | asserts | verdict | decision | required change |
|---|---|---|---|---|
| root binding equality · 12 | `%{post_id: %{parent_as: %{post: :id}}}` → `c.post_id == field(parent_as(:post), :id)` | CHANGE | D-OPERAND | shape `%{post_id: %{eq: %{parent: %{as: "post", field: :id}}}}`, nested inside an `exists`/subquery whose `from` declares `as: "post"` (binding must be declared in-request, §1.5a) |
| negated root binding equality · 25 | `%{post_id: %{not: %{parent_as: ...}}}` → `!=` | CHANGE | D-OPERAND | `%{post_id: %{not: %{eq: %{parent: %{as: "post", field: :id}}}}}`, inside a subquery |
| greater-than comparison · 40 | `%{views: %{>: %{parent_as: %{post: :views}}}}` | CHANGE | D-OPERAND | `%{views: %{gt: %{parent: %{as: "post", field: :views}}}}`, inside a subquery (also prefer string op `gt`; bare `:>` still tidies to `:>`) |
| negated greater-than · 53 | `not (p.views > parent_as.views)` | CHANGE | D-OPERAND | `%{views: %{not: %{gt: %{parent: %{as: "post", field: :views}}}}}`, inside a subquery |
| named binding equality · 68 | `%{as: %{post_join: %{id: %{parent_as: %{post: :id}}}}}` | CHANGE | D-OPERAND | operand → `%{parent: %{as: "post", field: :id}}`; still must sit inside a subquery so the `parent` reference is legal |

All 5 → CHANGE.

---

## common_filters_subquery_test.exs

These exercise the `:subquery` **structural filter** (wrap-the-whole-query, §1.4 advanced), which is
unchanged. The subquery is built from the *same outer source schema* (`Post`) — no client-supplied
module-as-source, so D-WIRE does not bite. The operand-form subquery (`%{all: %{from: "alias", ...}}`)
is a different feature not exercised here.

| test (name · line) | asserts | verdict | decision | required change |
|---|---|---|---|---|
| root subquery map payload · 11 | `%{subquery: %{id: 2}}` → wrapped | KEEP | D-API | — |
| root subquery keyword payload · 27 | `%{subquery: [id: 2, title: "Hello"]}` | KEEP | D-API | — |
| terminal wrapping after local filters · 46 | `%{order_by: …, subquery: %{id: 2}}` | KEEP | D-API/§3.2 | — (ordering unchanged) |

All 3 → KEEP.

---

## common_filters_set_operation_test.exs

`:union`/etc. take filter-params (built from the outer source schema) or a prebuilt `%Ecto.Query{}`.
No module-as-source from a client; structural filters are UNCHANGED (§3.8). nil → no-op is warn-and-skip
style passthrough, still valid.

| test (name · line) | verdict | decision |
|---|---|---|
| union w/ filter params · 14 | KEEP | D-API |
| union w/ prebuilt query · 28 | KEEP | D-API |
| union_all filter params · 42 / prebuilt · 56 | KEEP | D-API |
| intersect filter params · 70 / prebuilt · 84 | KEEP | D-API |
| intersect_all filter params · 98 / prebuilt · 112 | KEEP | D-API |
| except filter params · 126 / prebuilt · 140 | KEEP | D-API |
| except_all filter params · 154 / prebuilt · 168 | KEEP | D-API |
| union nil · 182 | KEEP | D-API |
| union_all nil · 188 / intersect nil · 194 / intersect_all nil · 200 / except nil · 206 / except_all nil · 212 | KEEP | D-API |

All 18 → KEEP.

---

## common_filters_with_cte_test.exs

`:with_cte` structural filter, UNCHANGED (§3.8). The invalid-payload tests assert **warn-and-skip**.
Per §3.8/§3.9 only two structural cases move to raising (`:reverse_order`-without-order; bad binding);
malformed `:with_cte` payloads are not in that list, so they remain warn-and-skip (D-WARN).

| test (name · line) | verdict | decision | note |
|---|---|---|---|
| map payload · 12 | KEEP | D-API | |
| prebuilt query · 26 | KEEP | D-API | |
| prebuilt subquery · 40 | KEEP | D-API | |
| map CTE filter params · 58 | KEEP | D-API | |
| filter params default source · 72 | KEEP | D-API | |
| explicit `from:` source · 88 | KEEP | D-API | `from:` is a literal source here, not a registered alias |
| materialized false · 103 | KEEP | D-API | |
| update_all operation · 117 | KEEP | D-API | |
| recursive_ctes before with_cte · 138 | KEEP | D-API | |
| with_cte before recursive_ctes · 152 | KEEP | D-API | |
| nested under named binding · 166 | KEEP | D-API | |
| nested under positional binding · 192 | KEEP | D-API | |
| ordered keyword-list CTE deps · 219 | KEEP | D-API | |
| invalid with_cte params (warn) · 243 | KEEP | D-WARN | bad payload, not a §3.9 raise case |
| invalid :as payload (warn) · 261 | KEEP | D-WARN | |
| invalid :operation (warn) · 280 | KEEP | D-WARN | |
| string-keyed map list entry · 302 | KEEP | D-API | |
| materialized + operation · 320 | KEEP | D-API | |
| entry not a pair (warn) · 348 | KEEP | D-WARN | |
| invalid name (passthrough) · 366 | KEEP | D-WARN | |
| missing :as key (warn) · 380 | KEEP | D-WARN | |
| invalid :materialized (warn) · 398 | KEEP | D-WARN | |
| string boolean :materialized cast · 417 | KEEP | D-API | |

All → KEEP.

---

## common_filters_recursive_ctes_test.exs

| test (name · line) | verdict | decision |
|---|---|---|
| recursive_ctes true · 11 | KEEP | D-API |
| recursive_ctes false · 24 | KEEP | D-API |
| string boolean cast · 37 | KEEP | D-API |

All 3 → KEEP.

---

## common_filters_windows_test.exs

`:windows` structural filter, UNCHANGED. Field args go through the shared column-name helper (§3.3)
but the recognized fields are valid; window-cycle and bad-`:frame` cases are warn-and-skip and are
not in §3.9's raise list.

| test (name · line) | verdict | decision |
|---|---|---|
| partition_by atom · 12 | KEEP | D-API |
| partition_by list + order_by · 28 | KEEP | D-API |
| frame dynamic expr · 54 | KEEP | D-API |
| nested named binding · 70 | KEEP | D-API |
| nested positional binding · 105 | KEEP | D-API |
| multiple windows · 139 | KEEP | D-API |
| window ref by name · 171 | KEEP | D-API |
| window ref local overrides · 198 | KEEP | D-API |
| chained refs · 229 | KEEP | D-API |
| refs nested named binding · 268 | KEEP | D-API |
| refs nested positional binding · 309 | KEEP | D-API |
| ref cycle (warn) · 351 | KEEP | D-WARN |
| self-ref cycle (warn) · 374 | KEEP | D-WARN |
| frame not dynamic (warn) · 393 | KEEP | D-WARN |
| order_by keyword list · 417 | KEEP | D-API |
| partition_by nil · 438 | KEEP | D-API |
| map input · 461 | KEEP | D-API |
| non-map/non-kw value (warn) · 474 | KEEP | D-WARN |
| plain atom order_by · 493 | KEEP | D-API |

All → KEEP.

---

## common_filters_with_ties_test.exs

`:with_ties` structural filter, UNCHANGED. Invalid-limit / unsupported-keys are warn-and-skip
(not §3.9 raise cases).

| test (name · line) | verdict | decision |
|---|---|---|
| default pk ordering · 12 | KEEP | D-API |
| named binding · 29 | KEEP | D-API |
| positional binding · 55 | KEEP | D-API |
| invalid limit (warn) · 81 | KEEP | D-WARN |
| unsupported keys (warn) · 99 | KEEP | D-WARN |
| string cast for ties + limit · 117 | KEEP | D-API |
| no :limit key uses default · 154 | KEEP | D-API |
| with_ties false no-op · 171 | KEEP | D-API |

All 8 → KEEP.

---

## common_filters_with_named_binding_test.exs

`:with_named_binding` structural filter, UNCHANGED. Bad-payload paths warn-and-skip. Note: the "did
not create a named binding" case (line 106) is arguably a caller mistake, but §3.9 only enumerates
bad-binding-*position* as a raise case; a join callback that fails to create the binding is not
listed → stays warn (flag below).

| test (name · line) | verdict | decision | note |
|---|---|---|---|
| documented workflow · 12 | KEEP | D-API | |
| idempotent no-op on existing binding · 31 | KEEP | D-API | |
| not a map/kw (warn) · 52 | KEEP | D-WARN | |
| non-tuple element (warn) · 70 | KEEP | D-WARN | |
| key not an atom (warn) · 88 | KEEP | D-WARN | |
| callback did not create binding (warn) · 106 | NEEDS-DECISION | D-RAISE? | §3.9 does not list this; presumed KEEP/warn, but confirm it is not a "called wrong" raise |

7 → 6 KEEP, 1 NEEDS-DECISION.

---

## common_filters_lock_test.exs

`:lock` provider hook gains a **checked contract** (D-PROVIDER, §3.10): a return that does not fit the
contract now **raises** (from Elixir) instead of warning. The tests assert warn-and-skip for bad
provider returns — those must flip to `assert_raise`. Bad provider returns covered: error tuple,
raw expression (not `{:ok,_}|{:error,_}|nil`), non-Ecto.Query callback result, non-function ok tuple.

§3.10 defines the contract returns as "a built query, or a clearly-shaped use/​nothing/​error result".
`{:error, reason}` and `nil` are *valid* contract returns → those stay warn/no-op, not raise.
The malformed-shape returns are what raise.

| test (name · line) | asserts | verdict | decision | required change |
|---|---|---|---|---|
| for_update alias · 15 | built-in alias | KEEP | D-API | — |
| for_share alias · 28 | built-in alias | KEEP | D-API | — |
| provider-backed lock · 43 | `{:ok, fn}` | KEEP | D-PROVIDER | valid contract return |
| provider lock w/ values · 56 | `{:ok, fn}` | KEEP | D-PROVIDER | — |
| no provider configured (warn) · 69 | warn + no-op | NEEDS-DECISION | D-PROVIDER/D-WARN | spec silent: is "name needs provider, none configured" a does-not-apply (warn) or caller-mistake (raise)? presumed KEEP/warn |
| raw string lock (warn) · 89 | warn + no-op | NEEDS-DECISION | D-RAISE? | malformed `:lock` value (not map/kw w/ :name). Could be a caller mistake → raise. §3.9 lists provider-return, not value-shape. flag |
| raw function lock (warn) · 107 | warn + no-op | NEEDS-DECISION | D-RAISE? | same as above |
| provider returns nil (no-op) · 126 | no-op | KEEP | D-PROVIDER | `nil` is a valid contract return |
| provider returns error (warn) · 139 | warn `…returned error…` | KEEP | D-PROVIDER | `{:error, reason}` is a valid contract return → not a raise |
| provider returns raw expr (warn) · 160 | warn "Expected … {:ok,function}\|{:error,reason}\|nil" | CHANGE | D-PROVIDER/D-RAISE | now **raises** — replace `capture_log` + `assert log =~` with `assert_raise` (precise message per §3.10) |
| no :name key (no-op) · 181 | no-op | NEEDS-DECISION | D-RAISE? | malformed `:lock` value shape; same question as raw-string |
| callback non-Ecto.Query return (warn) · 194 | warn "Expected lock expression callback to return an Ecto.Query" | CHANGE | D-PROVIDER/D-RAISE | now **raises** |
| non-function ok tuple (warn) · 212 | warn "…to be a 1-arity function" | CHANGE | D-PROVIDER/D-RAISE | now **raises** (arity/shape checked) |

3 CHANGE, 6 KEEP, 4 NEEDS-DECISION.

---

## common_filters_update_test.exs

`:update` structural filter, UNCHANGED (§3.8). The `:subquery` tests reuse the wrap feature (KEEP).
The `:not_a_keyword_list` test already asserts `assert_raise ArgumentError` (line 111) — consistent
with D-RAISE direction, KEEP.

| test (name · line) | verdict | decision | note |
|---|---|---|---|
| subquery map wrap · 11 | KEEP | D-API | |
| subquery invalid value (warn) · 22 | KEEP | D-WARN | |
| named binding update · 43 | KEEP | D-API | |
| positional binding update · 69 | KEEP | D-API | |
| cast string values · 94 | KEEP | D-API | |
| non-kw non-map term raises · 110 | KEEP | D-RAISE | already raises |
| map term · 118 | KEEP | D-API | |

7 → KEEP.

---

## common_filters_put_query_prefix_test.exs

| test (name · line) | verdict | decision |
|---|---|---|
| root string prefix · 11 | KEEP | D-API |

1 → KEEP.

---

## common_filters_invalid_schema_field_test.exs

Unknown-field → warn-and-skip is exactly **D-WARN** (§3.3 "does not exist on schema") and is preserved.
All KEEP.

| test (name · line) | verdict | decision |
|---|---|---|
| where invalid field · 13 | KEEP | D-WARN |
| having invalid field · 25 | KEEP | D-WARN |
| join on invalid field · 43 | KEEP | D-WARN |
| order_by invalid field · 61 | KEEP | D-WARN |
| group_by invalid field · 73 | KEEP | D-WARN |
| distinct invalid field · 85 | KEEP | D-WARN |

6 → KEEP. (Note: the `having` test at line 33 uses `%{avg: %{>: 1}}` — one-spelling aggregate form,
already D-ONE-WAY-compliant.)

---

## common_filters_out_of_range_binding_test.exs

Out-of-range / zero / negative `:at` positions are explicitly called out in §3.9/§3.8 as moving from
**warn-and-skip to raise** (D-RAISE). Every test here asserts warn-and-skip → all CHANGE.

| test (name · line) | asserts | verdict | decision | required change |
|---|---|---|---|---|
| field filter at OOR position (warn) · 16 | `log =~ "out of range"` | CHANGE | D-RAISE | `assert_raise` with out-of-range message; position 11 |
| position zero (warn) · 38 | warn | CHANGE | D-RAISE | `assert_raise` |
| negative position (warn) · 56 | warn | CHANGE | D-RAISE | `assert_raise` |
| having at OOR (warn) · 76 | warn | CHANGE | D-RAISE | `assert_raise` |
| order_by at OOR (warn) · 99 | warn | CHANGE | D-RAISE | `assert_raise` |
| in-range position applies · 123 | normal apply | KEEP | D-API | — |

5 CHANGE, 1 KEEP.

---

## parser_test.exs  (D-INTERNAL)

Tests `EctoShorts.CommonFilters.Parser.normalize/1,2,3` — an internal tidying helper. §0.1/§2.3 say
the multi-pass "tidy everything first" Parser is being **removed**: tidying moves into the per-filter
`TermResolver.canonicalize`, and §6 lists no `Parser` module in the post-refactor module set. These
tests couple directly to `Parser`'s internal name and its pair-list/fan-out output shape, which is
exactly the "depend only on public contract" violation. `Parser` is internal (**D-INTERNAL** —
"`build_dynamic`, `apply_expr`, … free to change"). The doctest (line 6) will also vanish with the module.

Verdict for the whole file: **CHANGE (likely DELETE)** per D-INTERNAL — the module these tests target
is slated to disappear. If a normalize-equivalent survives under a new name, rewrite against that;
otherwise drop the file. Individual cases are not worth per-line verdicts since none assert a public
promise.

15 tests → CHANGE (file-level; internal-shape coupling).

---

## update_expr_test.exs  (D-INTERNAL)

Tests `EctoShorts.CommonFilters.UpdateExpr.build_update_operations/2,3` and `build_update_expr/2`
directly, asserting internal return shapes (`[{:inc, :views, 1}]`, keyword passthrough, etc.) and
referencing implementation line numbers in comments. `:update` is a structural filter that is
behaviorally UNCHANGED (§3.8), but these are **white-box unit tests of internal functions**
(D-INTERNAL — internal names/shapes "free to change"). They are not pinned by §1's public contract.

- The behavior they cover (warn-and-skip on non-map/list params, dynamic passthrough, value casting,
  schemaless push/inc) is still valid behavior, so these are NOT spec-conflicts.
- But they couple to internal function names and tuple shapes that the refactor may rename/restructure.

Verdict for the whole file: **NEEDS-DECISION / CHANGE-on-rename.** KEEP the *behaviors*, but the tests
must be re-pointed if `UpdateExpr`'s internal API changes during the rewrite. Flag: decide whether
update-internals are exercised through `convert_params_to_filter` (public) instead of calling
`UpdateExpr` directly. No spec row forces a behavior change here.

15 tests → NEEDS-DECISION (internal coupling; behavior itself KEEP).

---

## Counts

| Verdict | Count |
|---|---|
| KEEP | 78 |
| CHANGE | 28 |
| NEEDS-DECISION | 20 |

Breakdown of CHANGE: parent_as 5 (D-OPERAND); lock 3 (D-PROVIDER/D-RAISE); out_of_range_binding 5
(D-RAISE); parser_test 15 (D-INTERNAL, file-level delete).
Breakdown of NEEDS-DECISION: update_expr 15 (D-INTERNAL re-point); lock 4; with_named_binding 1.

---

## NEW tests needed

- **Correlated `parent` inside a subquery/`exists`** (replaces parent_as): a positive test where the
  `parent` operand resolves an outer binding declared by an enclosing `from … as:` in the same request,
  and a negative test where `parent` appears *outside* any subquery → must error (§1.5a "valid only
  inside a subquery").
- **`parent` referencing an undeclared binding name** → rejected (a client cannot invent a binding).
- **Operand-form subquery comparison** (`%{id: %{eq: %{all: %{from: "comments", where: …}}}}` and
  `any`/`exists`) using a **registered source alias** (D-WIRE), plus a negative test that a raw module
  source from untrusted input is rejected.
- **Lock provider contract raises** — explicit `assert_raise` tests for: malformed-shape return,
  non-Ecto.Query callback result, wrong-arity / non-function ok tuple (D-PROVIDER/§3.10).
- **Out-of-range binding raises** — `assert_raise` companions for positions 0, negative, and > table
  count (D-RAISE), keeping the in-range positive test.
- **HTTP string-operator form** for these advanced filters where applicable (e.g. `"gt"`, `"eq"`),
  confirming closed-safe-list decoding (D-WIRE) — currently untested in this batch.

---

## NEEDS-DECISION (full list)

1. **update_expr_test.exs (entire file)** — `UpdateExpr` is internal (D-INTERNAL). Behaviors are valid
   but tests are white-box. Decide: re-point to the public `convert_params_to_filter` path, or keep
   direct unit tests and accept they may need renaming as internals shift.
2. **lock_test "raw string lock" (89) / "raw function lock" (107) / "no :name key" (181)** — a
   malformed `:lock` *value shape* (not map/kw with `:name`). §3.9 enumerates *provider-return* as a
   raise case but not value-shape. Decide whether a bad `:lock` value is "doesn't apply" (warn, keep)
   or "called it wrong" (raise) — needs a §4 row either way.
3. **lock_test "no provider configured" (69)** — naming a non-built-in lock with no provider: warn-and-
   skip today. Is an unresolvable lock name a does-not-apply (warn) or a caller mistake (raise)? Spec
   silent; presumed warn but should be confirmed.

Additional flag: **with_named_binding "callback did not create a named binding" (106)** — borderline
caller-mistake; §3.9 lists bad binding *position* but not "callback produced no binding." Presumed
warn (KEEP) pending confirmation.
