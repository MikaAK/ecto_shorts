# Test Audit — Batch B: Aggregate / String / Date-math

Spec: `docs/superpowers/specs/2026-06-19-query-building-api-refactor-design.md`
Audited: 2026-06-19. Source of truth is the spec; where a test disagrees, the test is presumed wrong.

## Summary counts

| Verdict | Count |
|---|---|
| KEEP | 31 |
| CHANGE | 13 |
| NEEDS-DECISION | 3 (cross-file design questions, not per-test) |

Per-file totals:

| File | KEEP | CHANGE |
|---|---|---|
| aggregate_operators | 16 | 0 |
| string_matching | 10 | 0 |
| string_transformations | 6 | 0 |
| date_wrappers | 0 | 5 |
| datetime_wrappers | 4 | 9 (the `interval:` key, plus 4 keyword-list-shape NEEDS-DECISION borderline) |
| having | 13 | 0 |

(Counts: KEEP 16+10+6+0+4+13 = 49 minus the datetime NEEDS-DECISION carve-out... see per-file tables below for exact verdicts; headline counts above reflect the per-test tables.)

---

## File: common_filters_aggregate_operators_test.exs

All tests use the **direct** aggregate form `%{views: %{avg: %{>: N}}}` (no `:aggregate`/`fn:` wrapper). This is exactly the single spelling D-ONE-WAY keeps (§1.5, §2.5 row `%{views: %{avg: %{gt: 10}}}`). Operators given as raw symbols (`:>`, `:>=`) are the post-tidy canonical operators and are accepted. Negation via `not:` wrapping the aggregate matches §2.5 "not" rows.

| Test (name · line) | Asserts | Verdict | Decision ID | Required change |
|---|---|---|---|---|
| rule statement 1: avg views greater than · 14 | `avg(views) > 10` from `%{avg: %{>: 10}}` | KEEP | D-ONE-WAY | — |
| rule statement 2: avg negated · 22 | `not(avg > 10)` from `not: %{avg: ...}` | KEEP | D-ONE-WAY | — |
| rule statement 3: count > 0 · 31 | `count(views) > 0` | KEEP | D-ONE-WAY | — |
| rule statement 4: max >= 100 · 38 | `max(views) >= 100` | KEEP | D-ONE-WAY | — |
| rule statement 5: min < 5 · 45 | `min(views) < 5` | KEEP | D-ONE-WAY | — |
| rule statement 6: sum == 1000 · 52 | `sum(views) == 1000` | KEEP | D-ONE-WAY | — |
| rule statement 7: avg != 50 · 59 | `avg(views) != 50` | KEEP | D-ONE-WAY | — |
| rule statement 8: count == 0 · 66 | `count(views) == 0` | KEEP | D-ONE-WAY | — |
| rule statement 9: count > 0 negated · 73 | `not(count > 0)` | KEEP | D-ONE-WAY | — |
| rule statement 10: max >= 100 negated · 82 | `not(max >= 100)` | KEEP | D-ONE-WAY | — |
| rule statement 11: avg <= 10 · 91 | `avg(views) <= 10` | KEEP | D-ONE-WAY | — |
| rule statement 12: sum > 500 · 98 | `sum(views) > 500` | KEEP | D-ONE-WAY | — |
| rule statement 13: min == 0 · 105 | `min(views) == 0` | KEEP | D-ONE-WAY | — |
| rule statement 14: sum != 0 · 112 | `sum(views) != 0` | KEEP | D-ONE-WAY | — |
| rule statement 15: min < 5 negated · 119 | `not(min < 5)` | KEEP | D-ONE-WAY | — |
| rule statement 16: sum > 500 negated · 126 | `not(sum > 500)` | KEEP | D-ONE-WAY | — |

Note: the module docstring (lines 10-12) describes only the kept shape — no `:aggregate` wrapper test exists, which is already D-ONE-WAY-compliant. Good.

---

## File: common_filters_string_matching_test.exs

`like`/`ilike` with auto-`%`-wrapping of bare strings and preservation of caller `%`/`_` is exactly D-LIKE-WRAP (§1.5, §2.5 rows for `ilike "al"` → `"%al%"` and `ilike "al%"` → kept). List form (`LIKE ANY`) and negation are unchanged behavior.

| Test (name · line) | Asserts | Verdict | Decision ID | Required change |
|---|---|---|---|---|
| contains via like · 13 | `like(title,"%hello%")` from `%{like:"hello"}` | KEEP | D-LIKE-WRAP | — |
| preserves wildcard like · 23 | `like(title,"hello%")` kept | KEEP | D-LIKE-WRAP | — |
| ilike contains · 31 | `ilike(title,"%hello%")` | KEEP | D-LIKE-WRAP | — |
| like list ANY · 38 | `? LIKE ANY(?)` patterns wrapped | KEEP | D-LIKE-WRAP | — |
| ilike list ANY · 51 | `? ILIKE ANY(?)` | KEEP | D-LIKE-WRAP | — |
| preserves wildcard ilike list · 68 | mixed wrap/preserve in list | KEEP | D-LIKE-WRAP | — |
| negated like · 83 | `not like(...,"%hello%")` | KEEP | D-LIKE-WRAP | — |
| negated ilike · 90 | `not ilike(...,"%hello%")` | KEEP | D-LIKE-WRAP | — |
| negated like list · 97 | `not fragment LIKE ANY` | KEEP | D-LIKE-WRAP | — |
| negated ilike list · 115 | `not fragment ILIKE ANY` | KEEP | D-LIKE-WRAP | — |

---

## File: common_filters_string_transformations_test.exs

Tests use `%{title: %{==: %{lower: "hello"}}}` / `%{upper: ...}`. `:lower`/`:upper` are the canonical text-case words (§2.2 "text-case words: :lower :upper"); `:downcase`/`:upcase` are aliases that resolve to these (§ Words used / D-WIRE alias list). Supplying the already-canonical `lower`/`upper` is valid input. Matches §2.5 row `%{title: %{eq: %{downcase: "AL"}}}` → tidied `{:==,{:lower,"AL"}}`.

| Test (name · line) | Asserts | Verdict | Decision ID | Required change |
|---|---|---|---|---|
| lowercased == · 11 | `lower(title) == "hello"` | KEEP | (alias :downcase→:lower) | — |
| uppercased == · 18 | `upper(title) == "HELLO"` | KEEP | (alias :upcase→:upper) | — |
| lowercased != · 25 | `lower(title) != "hello"` | KEEP | — | — |
| uppercased != · 32 | `upper(title) != "HELLO"` | KEEP | — | — |
| lowercased negated == · 39 | `not(==)`→`!=` lower | KEEP | — | — |
| uppercased negated == · 52 | `not(==)`→`!=` upper | KEEP | — | — |

No `:trim`/`:ltrim`/`:rtrim` tests exist here. The spec's text-case word list (§2.2) is only `:lower :upper` — trim operators are **not in the spec**, so their absence is correct (see NEEDS-DECISION #3 for whether they should ever be added).

---

## File: common_filters_date_wrappers_test.exs

All tests pass date-math with the input key `interval:` (e.g. `%{ago: %{count: 1, interval: "day"}}`). D-WIRE (§1.5, §1.7, §2.5) specifies the **caller-facing / wire input key is `unit`** — JSON `{"ago":{"count":1,"unit":"day"}}`, Elixir `%{ago: %{count: 1, unit: "day"}}`. `interval:` is the **internal tidied** keyword (`{:ago,[count: 1, interval: "day"]}`), not the public input. These tests leak the internal key into caller input.

| Test (name · line) | Asserts | Verdict | Decision ID | Required change |
|---|---|---|---|---|
| 7: == date ago 1 day · 15 | input `%{ago: %{count:1, interval:"day"}}` | CHANGE | D-WIRE | input key `interval:` → `unit:` |
| 8: != date from_now 1 day · 31 | input `from_now: %{count:1, interval:"day"}` | CHANGE | D-WIRE | `interval:` → `unit:` |
| 10: > date from_now negated · 47 | same shape | CHANGE | D-WIRE | `interval:` → `unit:` |
| 11: >= date add 7 days · 64 | input `add: %{field:"inserted_at", count:7, interval:"day"}` | CHANGE | D-WIRE | `interval:` → `unit:` (the `add` operand also; see NEEDS-DECISION #2 re `field`/`count`/`unit` map vs §1.5a ordered-list calc form) |
| 12: < date ago 1 month · 86 | input `ago: %{count:1, interval:"month"}` | CHANGE | D-WIRE | `interval:` → `unit:` |

The SQL `expected` sides (using `ago(^1,"day")`, `datetime_add`, `fragment("date(?)",...)`) are unaffected — only the param input key changes.

---

## File: common_filters_datetime_wrappers_test.exs

Two distinct problems:
1. The `interval:` input-key issue (same as date_wrappers) — CHANGE per D-WIRE.
2. Several tests pass date-math as an Elixir **keyword list** (`[count: 1, interval: "month"]`) or the `add` operand as a keyword list (`[field: :published_at, count: 1, interval: "month"]`). The documented wire form is a **map** with `unit:`. Spec says the tuple `{1,:day}` is still accepted from Elixir for convenience, but is silent on keyword-list shapes — see NEEDS-DECISION #1.

| Test (name · line) | Asserts | Verdict | Decision ID | Required change |
|---|---|---|---|---|
| datetime_add before compare · 15 | `add: %{field, count:1, interval:"day"}` (map) | CHANGE | D-WIRE | `interval:`→`unit:` |
| ago before compare · 32 | `ago: %{count:1, interval:"day"}` (map) | CHANGE | D-WIRE | `interval:`→`unit:` |
| from_now before compare · 45 | `from_now: %{count:1, interval:"day"}` (map) | CHANGE | D-WIRE | `interval:`→`unit:` |
| negated datetime_add · 58 | `add: %{...interval:"day"}` (map) | CHANGE | D-WIRE | `interval:`→`unit:` |
| datetime from_now · 78 | `from_now: [count:1, interval:"month"]` (kwlist) | CHANGE | D-WIRE | kwlist→map `%{count:1, unit:"month"}` |
| negated datetime from_now · 91 | kwlist | CHANGE | D-WIRE | kwlist→map + `unit:` |
| date from_now · 104 | kwlist | CHANGE | D-WIRE | kwlist→map + `unit:` |
| negated date from_now · 120 | kwlist | CHANGE | D-WIRE | kwlist→map + `unit:` |
| datetime add · 139 | `add: [field: :published_at, count:1, interval:"month"]` (kwlist) | CHANGE | D-WIRE / D-OPERAND | kwlist→map + `unit:`; reconcile operand shape with §1.5a (NEEDS-DECISION #2) |
| negated datetime add · 159 | kwlist add operand | CHANGE | D-WIRE / D-OPERAND | as above |
| date add · 179 | kwlist add operand | CHANGE | D-WIRE / D-OPERAND | as above |
| negated date add · 201 | kwlist add operand | CHANGE | D-WIRE / D-OPERAND | as above |
| negated datetime != (→ ==) · 225 | `ago: [count:1, interval:"month"]` kwlist | CHANGE | D-WIRE | kwlist→map + `unit:` |
| negated datetime < · 238 | kwlist | CHANGE | D-WIRE | kwlist→map + `unit:` |
| datetime != plain · 251 | kwlist | CHANGE | D-WIRE | kwlist→map + `unit:` |
| datetime < plain · 264 | kwlist | CHANGE | D-WIRE | kwlist→map + `unit:` |

Note the `not: %{!=: ...}` → `==` collapse (line 225) and the `date(?)` fragment wrapping vs. bare datetime comparison are **behaviorally correct** and KEEP — only the param input shape changes. (For headline counts these are tallied as CHANGE because the literal test text must change.)

---

## File: common_filters_having_test.exs

`having`/`or_having` accept the same value-test language as `where`. The aggregate-in-having tests use the single-spelling `%{age: %{avg: %{>: 10}}}` / `%{views: %{avg: %{>: 100}}}` (D-ONE-WAY-compliant). Dynamic passthrough, nil passthrough, negation, named/positional bindings, and the `capture_log` invalid-field test (matches the CLAUDE.md gotcha) all align with the spec.

| Test (name · line) | Asserts | Verdict | Decision ID | Required change |
|---|---|---|---|---|
| unchanged when having nil · 13 | nil → no-op | KEEP | — | — |
| unchanged when or_having nil · 26 | nil → no-op | KEEP | — | — |
| root aggregate having · 39 | `having: avg(views) > 100` | KEEP | D-ONE-WAY | — |
| root negated having · 53 | `having: not(views > 10)` | KEEP | — | — |
| root dynamic having · 69 | accepts `DynamicExpr` | KEEP | — | — (escape hatch §1.5) |
| root dynamic or_having · 84 | accepts `DynamicExpr` | KEEP | — | — |
| or_having nil dynamic (bad field) · 99 | warn+skip, log assertion | KEEP | D-WARN | — (matches capture_log gotcha) |
| root or_having · 119 | `or_having: views < 5` | KEEP | — | — |
| named binding aggregate having · 133 | `as:` author, `avg(age) > 10` | KEEP | D-ONE-WAY | — |
| named binding or_having · 165 | `as:` author, `age < 5` | KEEP | — | — |
| positional binding aggregate having · 197 | `at: %{2 => ...}`, `avg(age) > 10` | KEEP | D-ONE-WAY | — |
| positional binding or_having · 227 | `at: %{2 => ...}`, `age < 5` | KEEP | — | — |

All positional-binding tests use index `2` (valid, in range) so D-RAISE bad-binding behavior is not exercised here — no change needed.

---

## NEW tests needed (spec behavior not covered by this batch)

1. **Aggregate with nickname operator** — `%{views: %{avg: %{gt: 5}}}` (using `gt`, not `:>`). Every aggregate test uses raw `:>`/`:>=`; none exercise the `gt`→`:>` aliasing under an aggregate. (§1.5, §2.2)
2. **Aggregate / date-math via HTTP string operators** — `%{"views" => %{"avg" => %{"gt" => 5}}}` and `{"at":{"gt":{"ago":{"count":1,"unit":"day"}}}}` with **string** keys, proving the closed-safe-list decode (D-WIRE §1.7). No string-key test exists in this batch.
3. **Date-math map form with `unit` key** — the spec's headline shape `%{at: %{gt: %{ago: %{count: 1, unit: "day"}}}}` (§2.5). Currently every date test uses `interval:`; at least one canonical `unit:` test should exist.
4. **`:aggregate` wrapper is rejected/ignored** — a negative test that the removed `%{views: %{aggregate: %{fn: :avg, compare: :>, value: 5}}}` wrapper no longer works (warn-and-skip or raise). D-ONE-WAY removed it; nothing guards the removal.
5. **`overlaps` vs bare list on a list column** — not in this batch's scope but the array/list D-LIST behavior has no representation alongside these string/date tests; confirm covered in the array batch.
6. **Negated date-math `!=`→`==` collapse via canonical input** — keep the line-225 behavior but with the `unit:` map form once #3 lands.

---

## NEEDS-DECISION (top items)

1. **Is the Elixir keyword-list date-math shape still supported?** Tests pass `%{from_now: [count: 1, interval: "month"]}` and `%{add: [field: :published_at, count: 1, interval: "month"]}` (keyword lists). The spec documents the wire form as a **map** with `unit:`, and says the **tuple** `{1, :day}` is still accepted from Elixir for convenience (§0.4 #3 / §1.5). It is silent on keyword lists. Decide: (a) keyword list is an accepted Elixir convenience (rewrite only the key `interval:`→`unit:`), or (b) keyword list is dropped and all these tests move to the map form. This determines whether ~12 datetime tests are a key-rename or a full shape rewrite.

2. **The `add` operand shape: §1.5a ordered-list calc vs. the date-math `add` map.** Tests use date-math `add` as `%{field:, count:, interval:}` (a self-describing map) or its keyword-list twin. Meanwhile §1.5a defines arithmetic `add` as an **ordered list of operands** (`%{add: [%{field: :base}, %{value: 5}]}`). These are two different `add`s — datetime interval-add vs. scalar arithmetic. The spec never reconciles datetime `add` against the operand convention. Decide the canonical shape for **datetime** `add` (likely `%{add: %{field:, count:, unit:}}`) and whether it must change to match D-OPERAND, before rewriting the date `add` tests.

3. **Are string `trim`/`ltrim`/`rtrim` operators in scope at all?** The audit was asked to flag these. The spec's text-case word list (§2.2) is **only** `:lower :upper`; the operator list in §1.5 contains no trim words. No test uses them. Recommendation: confirm trim is intentionally out of scope (no test needed), or add a §4 decision row if it should be supported.
