# Batch D — Structural Filter Tests Audit

Audited against `2026-06-19-query-building-api-refactor-design.md` (the source of truth).

**Source of truth:** §1.4 (core/advanced tiers), §3.8 (structural filters UNCHANGED), §3.9 + §3.10 (D-RAISE / D-PROVIDER), §4 (decisions).

**Headline:** §3.8 freezes all structural-filter behavior except two moves to raising: `:reverse_order` with no prior `:order_by`, and out-of-range/invalid binding positions (D-RAISE). D-PROVIDER additionally makes a bad `:lock`/`:join` provider return raise. The bulk of these tests are KEEP.

## Tier classification (D-CORE §1.4 — documentation only, NOT a behavior change)

| Filter word | Tier | Files in this batch |
|---|---|---|
| `:join` | core | join |
| `:exclude` | core | exclude |
| `:select`, `:select_merge`, `:distinct`, `:preload` | core | select, select_merge, distinct, preload |
| `:order_by`, `:reverse_order` | core (sorting) | order_modifier |
| `:group_by`, `:having` | core (grouping) | group_by |
| `:limit`, `:offset`, `:first`, `:last`, `:page` | core (pagination) | limit, offset, first, last, page |

`:prepend_order_by` is not enumerated in §1.4; treated as part of the `:order_by` family (core). All thirteen files exercise only core-tier words — no advanced-tier (`:subquery`, `:union`, `:with_cte`, `:lock`, …) words are the subject under test here (though `:exclude` and `:join` reference some as exclusion targets / provider hooks).

---

## common_filters_order_modifier_test.exs

| test (name · line) | asserts | verdict | decision ID | required change |
|---|---|---|---|---|
| named binding prepend_order_by atom · 12 | query shape | KEEP | D-API | — |
| named binding prepend_order_by ordered kw list · 38 | query shape | KEEP | D-API | — |
| positional binding prepend_order_by atom · 64 | query shape (pos 2, valid) | KEEP | D-API | — |
| positional binding prepend_order_by ordered kw list · 89 | query shape (pos 2, valid) | KEEP | D-API | — |
| orders by list of direction-field tuples · 116 | query shape | KEEP | D-API | — |
| orders by list of bare atoms default asc · 129 | query shape | KEEP | D-API | — |
| prepend_order_by list of direction-field tuples · 144 | query shape | KEEP | D-API | — |
| prepend_order_by list of bare atoms default desc · 157 | query shape | KEEP | D-API | — |
| prepend_order_by named binding + tuple list · 170 | query shape | KEEP | D-API | — |
| prepend_order_by positional binding + tuple list · 195 | query shape (pos 2, valid) | KEEP | D-API | — |
| order_by passes DynamicExpr through in list · 216 | passthrough | KEEP | D-API | — |
| order_by non-atom non-dynamic list entry · 229 | valid query | KEEP | D-API | — |
| order_by accepts kw list of dir-field pairs · 242 | valid query | KEEP | D-API | — |
| prepend_order_by passes DynamicExpr through · 253 | passthrough | KEEP | D-API | — |
| prepend_order_by non-atom non-dynamic entry · 266 | valid query | KEEP | D-API | — |
| prepend_order_by accepts raw kw list · 279 | valid query | KEEP | D-API | — |
| accepts map input for order_by · 292 | valid query | KEEP | D-API | — |
| skips invalid schema field in order_by list, query unchanged · 304 | warn-and-skip (unknown column) | KEEP | D-WARN | — |
| accepts map input for prepend_order_by · 324 | valid query | KEEP | D-API | — |
| skips invalid field in ordered-tuple entry, unchanged · 336 | warn-and-skip (unknown column) | KEEP | D-WARN | — |
| skips invalid field in plain-atom entry, unchanged · 354 | warn-and-skip (unknown column) | KEEP | D-WARN | — |
| accepts any field on schemaless source · 377 | valid query | KEEP | D-API | — |
| reverses query order when reverse_order is nil (prior order_by present) · 390 | reverses | KEEP | D-API | — |
| logs warning + unchanged when reverse_order is not true (`false`, prior order_by present) · 406 | warn-and-skip on bad value | NEEDS-DECISION | D-RAISE? | spec D-RAISE names only "`reverse_order` with no order_by" as the new raise case; a *non-true value* is not enumerated. Borderline caller-mistake. See list below. |

Note line 304/336/354 are unknown-column skips → D-WARN ("filter does not apply"), explicitly NOT D-RAISE.

---

## common_filters_join_test.exs

Mostly KEEP. Provider-contract tests are the watch items (D-PROVIDER §3.10).

| test (name · line) | asserts | verdict | decision ID | required change |
|---|---|---|---|---|
| association join payload · 13 | query shape | KEEP | D-API | — |
| association shorthand join · 34 | query shape | KEEP | D-API | — |
| explicit assoc join via type source selector · 54 | SQL output | KEEP | D-API | — |
| schema join payload · 72 | query shape | KEEP | D-API | — |
| explicit schema join via type source selector · 98 | query shape | KEEP | D-API | — |
| table join payload · 118 | query shape | KEEP | D-API | — |
| table join with configured hints · 146 | query shape | KEEP | D-API | — |
| query join payload · 174 | query shape | KEEP | D-API | — |
| subquery join from params · 202 | query shape | KEEP | D-API | — |
| named binding association join · 230 | query shape | KEEP | D-API | — |
| fragment join via provider contract (valid) · 266 | query shape | KEEP | D-PROVIDER | — (valid `{:ok, source}` path) |
| provider returns nil → query unchanged · 296 | unchanged | KEEP | D-PROVIDER | `nil` is an allowed contract shape (§3.10) → still warn/skip-equivalent; KEEP |
| provider returns `{:error, reason}` → warn + unchanged · 322 | warn-and-skip | KEEP | D-PROVIDER | `{:error, reason}` is an in-contract shape (§3.10 lists "error" result); logging it is acceptable. KEEP — but confirm whether contract wants this surfaced louder. |
| provider returns raw source (not ok/error/nil) → warn + unchanged · 353 | warn-and-skip on out-of-contract return | CHANGE | D-PROVIDER | §3.10: a return that does NOT fit the contract must **RAISE** with a precise message. before: `capture_log` + assert unchanged + log =~ "Expected join source callback to return …"; after: `assert_raise` with that message; drop the unchanged/log assertions. |
| join type key unrecognised → warn + unchanged · 382 | warn-and-skip | KEEP | D-WARN | — |
| join options missing :source → warn + unchanged · 400 | warn-and-skip | KEEP | D-WARN | — |
| join entry not map/kwlist → warn + unchanged · 418 | warn-and-skip | KEEP | D-WARN | — |
| raises when fragment source name missing · 436 | raises ArgumentError | KEEP | D-RAISE | — (already raises) |
| raises when fragment source values missing · 446 | raises ArgumentError | KEEP | D-RAISE | — |
| raises when schema join target invalid · 456 | raises ArgumentError | KEEP | D-RAISE | — |
| schema join via {table, schema} tuple · 466 | query shape | KEEP | D-API | — |
| raises when query join source not Ecto.Query · 492 | raises ArgumentError | KEEP | D-RAISE | — |
| :on not a kw list → warn + unchanged · 502 | warn-and-skip | KEEP | D-WARN | — |
| subquery join from prebuilt Ecto.Query · 524 | query shape | KEEP | D-API | — |
| nested non-kwlist of join entries · 552 | query shape | KEEP | D-API | — |
| returns compiled hints list · 578 | list | KEEP | D-API | — |
| :on filters all produce nil dynamics → unchanged · 586 | warn-and-skip (unknown field) | KEEP | D-WARN | — |
| :on as pre-built dynamic · 615 | SQL output | KEEP | D-API | — |
| :on not valid filter shape → warn + unchanged · 645 | warn-and-skip | KEEP | D-WARN | — |
| resolves source from named binding for :on · 669 | Ecto.Query | KEEP | D-API | — |
| resolves source from positional binding for :on · 700 | Ecto.Query (pos 2, valid) | KEEP | D-API | — |
| keeps first dynamic when second on-field nil · 735 | query shape + warn | KEEP | D-WARN | — |
| merges two valid on-field dynamics with AND · 768 | Ecto.Query | KEEP | D-API | — |
| association join with configured hints · 789 | query shape | KEEP | D-API | — |
| subquery join with configured hints · 819 | query shape | KEEP | D-API | — |

---

## common_filters_exclude_test.exs

All KEEP — `:exclude` behavior is unchanged (§3.8); these only assert query shape after excluding a clause. (Tests at 110/153/181/196/281 reference advanced-tier targets `with_ctes`/`lock`/`update`/`windows` as exclusion targets — exclusion of them is unchanged.)

| test (name · line) | asserts | verdict | decision ID |
|---|---|---|---|
| excluding where · 11 | query shape | KEEP | D-API |
| excluding order_by · 25 | query shape | KEEP | D-API |
| excluding group_by · 39 | query shape | KEEP | D-API |
| excluding having · 53 | query shape | KEEP | D-API |
| excluding distinct · 67 | query shape | KEEP | D-API |
| excluding select · 81 | query shape | KEEP | D-API |
| excluding combinations · 95 | query shape | KEEP | D-API |
| excluding with_ctes · 110 | query shape | KEEP | D-API |
| excluding limit · 125 | query shape | KEEP | D-API |
| excluding offset · 139 | query shape | KEEP | D-API |
| excluding lock · 153 | query shape | KEEP | D-API |
| excluding preload · 167 | query shape | KEEP | D-API |
| excluding update · 181 | query shape | KEEP | D-API |
| excluding windows · 196 | query shape | KEEP | D-API |
| excluding multiple fields via list payload · 219 | query shape | KEEP | D-API |
| excluding joins · 237 | query shape | KEEP | D-API |
| excluding left_join · 251 | query shape | KEEP | D-API |
| excluding cross_join · 265 | query shape | KEEP | D-API |
| excluding specific windows by name · 281 | query shape | KEEP | D-API |

---

## common_filters_select_test.exs

All KEEP — `:select` unchanged (§3.8). All positional bindings use valid positions.

| test (name · line) | asserts | verdict | decision ID |
|---|---|---|---|
| root select struct projection · 11 | query shape | KEEP | D-API |
| named binding select field · 24 | query shape | KEEP | D-API |
| positional binding select map alias (pos 2) · 54 | query shape | KEEP | D-API |
| first positional binding select alias · 85 | query shape | KEEP | D-API |
| last positional binding select alias · 113 | query shape | KEEP | D-API |
| root select map + kw alias list · 145 | query shape | KEEP | D-API |
| root select map + map alias · 161 | query shape | KEEP | D-API |
| named binding select map alias · 177 | query shape | KEEP | D-API |
| named binding select kw alias list · 201 | query shape | KEEP | D-API |
| named binding select true (full) · 225 | query shape | KEEP | D-API |
| named binding select struct projection · 249 | query shape | KEEP | D-API |
| positional binding select atom field · 273 | query shape | KEEP | D-API |
| positional binding select true (full) · 297 | query shape | KEEP | D-API |
| positional binding select struct projection · 319 | query shape | KEEP | D-API |
| root select {:map, map} form · 475 | query shape | KEEP | D-API |
| root select {:map, keyword_map} form · 494 | query shape | KEEP | D-API |
| root select plain non-kw list · 510 | query shape | KEEP | D-API |
| accepts DynamicExpr as select value · 526 | query shape | KEEP | D-API |

---

## common_filters_select_merge_test.exs

All KEEP — unchanged (§3.8). The two `raises` tests assert `Ecto.QueryError` raised by Ecto itself (invalid select_merge shape), not the EctoShorts D-RAISE path; behavior is unchanged.

| test (name · line) | asserts | verdict | decision ID |
|---|---|---|---|
| root select_merge map tuple alias · 11 | query shape | KEEP | D-API |
| named binding select_merge alias · 30 | query shape | KEEP | D-API |
| positional binding select_merge alias (pos 2) · 62 | query shape | KEEP | D-API |
| DynamicExpr in kwlist select_merge · 92 | valid query | KEEP | D-API |
| non-atom non-dynamic value in kwlist · 106 | valid query | KEEP | D-API |
| raises when select_merge value is plain list · 126 | Ecto.QueryError | KEEP | D-API |
| non-atom non-dynamic value passthrough · 143 | query shape | KEEP | D-API |
| raises when select_merge value is bare DynamicExpr · 164 | Ecto.QueryError | KEEP | D-API |

---

## common_filters_group_by_test.exs

KEEP. The line-170 "skip invalid field" is an unknown-column skip (D-WARN), NOT a D-RAISE case. The line-207 raise is a malformed-value raise that already exists.

| test (name · line) | asserts | verdict | decision ID |
|---|---|---|---|
| named binding group_by atom · 11 | query shape | KEEP | D-API |
| named binding group_by list · 37 | query shape | KEEP | D-API |
| named binding group_by dynamic list · 63 | query shape | KEEP | D-API |
| positional binding group_by atom (pos 2) · 91 | query shape | KEEP | D-API |
| positional binding group_by list (pos 2) · 116 | query shape | KEEP | D-API |
| positional binding group_by dynamic list (pos 2) · 141 | query shape | KEEP | D-API |
| skips invalid schema field atom, unchanged · 170 | warn-and-skip (unknown column) | KEEP | D-WARN |
| accepts bare DynamicExpr as group_by value · 191 | query shape | KEEP | D-API |
| raises when group_by list has non-atom non-Dynamic entries · 207 | ArgumentError | KEEP | D-API |

---

## common_filters_distinct_test.exs

All KEEP. The two "skip non-existent field" tests are unknown-column D-WARN; the line-284 raise already exists.

| test (name · line) | asserts | verdict | decision ID |
|---|---|---|---|
| root boolean distinct · 11 | query shape | KEEP | D-API |
| root distinct atom · 24 | query shape | KEEP | D-API |
| root distinct ordered kw list · 37 | query shape | KEEP | D-API |
| named binding distinct atom · 50 | query shape | KEEP | D-API |
| named binding distinct ordered kw list · 76 | query shape | KEEP | D-API |
| positional binding distinct atom (pos 2) · 102 | query shape | KEEP | D-API |
| positional binding distinct ordered kw list (pos 2) · 127 | query shape | KEEP | D-API |
| root distinct bare-atom list · 154 | query shape | KEEP | D-API |
| named binding distinct bare-atom list · 167 | query shape | KEEP | D-API |
| root boolean false distinct · 187 | query shape | KEEP | D-API |
| casts string boolean distinct · 200 | query shape | KEEP | D-API |
| skips ordered-tuple entry for non-existent field, unchanged · 213 | warn-and-skip (unknown column) | KEEP | D-WARN |
| skips plain-atom entry for non-existent field, unchanged · 234 | warn-and-skip (unknown column) | KEEP | D-WARN |
| accepts DynamicExpr in distinct list · 254 | query shape | KEEP | D-API |
| applies bare DynamicExpr via fallback · 270 | query shape | KEEP | D-API |
| raises when distinct list has non-atom non-Dynamic entries · 284 | ArgumentError | KEEP | D-API |
| accepts any atom field on schemaless source · 292 | query shape | KEEP | D-API |

---

## common_filters_limit_test.exs

| test (name · line) | asserts | verdict | decision ID |
|---|---|---|---|
| fallthrough binding · 11 | applies limit with no binding when selector unrecognized | KEEP | D-API |

---

## common_filters_offset_test.exs

All KEEP.

| test (name · line) | asserts | verdict | decision ID |
|---|---|---|---|
| root integer offset · 11 | query shape | KEEP | D-API |
| named binding offset · 24 | query shape | KEEP | D-API |
| positional binding offset (pos 2) · 49 | query shape | KEEP | D-API |
| casts string integer offset · 73 | query shape | KEEP | D-API |
| applies offset via fallback when binding unrecognised · 89 | query shape | KEEP | D-API |

---

## common_filters_first_test.exs

All KEEP.

| test (name · line) | asserts | verdict | decision ID |
|---|---|---|---|
| root integer first · 11 | query shape | KEEP | D-API |
| named binding first · 24 | query shape | KEEP | D-API |
| positional binding first (pos 2) · 49 | query shape | KEEP | D-API |
| casts string integer first · 73 | query shape | KEEP | D-API |

---

## common_filters_last_test.exs

All KEEP. The subquery-with-reversed-order wrapping is explicitly documented as correct (§4, "`last` subquery shape" — document, no behavior change). The line-11 warn is a bad-value-shape skip, unchanged.

| test (name · line) | asserts | verdict | decision ID |
|---|---|---|---|
| returns unchanged when last is non-kwlist (warn "Expected :last value") · 11 | warn-and-skip | KEEP | D-WARN |
| root integer last (subquery, desc:id then asc:id) · 30 | query shape | KEEP | D-API / "last subquery shape" |
| root keyword last · 49 | query shape | KEEP | D-API |
| explicit id last · 68 | query shape | KEEP | D-API |
| explicit title last · 87 | query shape | KEEP | D-API |
| terminal last wrapping after local filters · 106 | query shape | KEEP | D-API |
| last replaces previous order_by · 126 | query shape | KEEP | D-API |
| casts string integer last · 146 | query shape | KEEP | D-API |

---

## common_filters_page_test.exs

All KEEP — `:page` (offset + keyset cursor) unchanged.

| test (name · line) | asserts | verdict | decision ID |
|---|---|---|---|
| page 1 size 5 → LIMIT 5 OFFSET 0 · 11 | query shape | KEEP | D-API |
| page 2 size 5 → OFFSET 5 · 20 | query shape | KEEP | D-API |
| page 3 size 10 → OFFSET 20 · 29 | query shape | KEEP | D-API |
| respects named binding · 38 | query shape | KEEP | D-API |
| respects positional binding · 52 | query shape | KEEP | D-API |
| casts string index and size · 68 | query shape | KEEP | D-API |
| casts string size only · 77 | query shape | KEEP | D-API |
| after cursor forward (id > cursor) · 88 | query shape | KEEP | D-API |
| after: nil (no WHERE) · 101 | query shape | KEEP | D-API |
| after cursor named binding · 114 | query shape | KEEP | D-API |
| after cursor positional binding · 133 | query shape | KEEP | D-API |
| after cursor on :views field · 154 | query shape | KEEP | D-API |
| before cursor on :views field · 167 | query shape | KEEP | D-API |
| casts string size in after-cursor · 180 | query shape | KEEP | D-API |
| before cursor backward (id < cursor) · 195 | query shape | KEEP | D-API |
| before: nil (no WHERE) · 208 | query shape | KEEP | D-API |
| before cursor named binding · 221 | query shape | KEEP | D-API |
| before cursor positional binding · 240 | query shape | KEEP | D-API |

---

## common_filters_preload_test.exs

All KEEP — `:preload` unchanged. The line-491 raise (nested value not map/list/atom) already raises.

| test (name · line) | asserts | verdict | decision ID |
|---|---|---|---|
| root preload atom · 11 | query shape | KEEP | D-API |
| nested preload kwlist · 24 | query shape | KEEP | D-API |
| named join-backed preload · 37 | query shape | KEEP | D-API |
| named nested join-backed preload tuple · 67 | query shape | KEEP | D-API |
| positional nested join-backed preload tuple · 97 | query shape | KEEP | D-API |
| join-backed preload no filter on binding · 127 | query shape | KEEP | D-API |
| join-backed preload with where on same binding · 157 | query shape | KEEP | D-API |
| two independent preload clauses, two named bindings · 194 | query shape | KEEP | D-API |
| through-association preload + root where · 233 | query shape | KEEP | D-API |
| two preload clauses, top-level + binding-scoped same assoc · 258 | query shape | KEEP | D-API |
| join-backed nested preload tuple with where · 292 | query shape | KEEP | D-API |
| positional at: binding with where + preload · 324 | query shape | KEEP | D-API |
| join-backed preload with select on same binding · 354 | query shape | KEEP | D-API |
| map input for preload under named binding · 390 | query shape | KEEP | D-API |
| bare atom preload key (nil nested) · 413 | query shape | KEEP | D-API |
| normalizes map nested preload spec · 436 | query shape | KEEP | D-API |
| double-wrapped preload tuple for non-kw nested · 461 | query shape | KEEP | D-API |
| raises when nested preload value not map/list/atom · 491 | raises | KEEP | D-API |

---

## CHANGE list (cite decision ID + before→after)

1. **join · line 353** ("provider returns a raw source") — **D-PROVIDER (§3.10).**
   before: `capture_log` + `assert_query(unchanged)` + `assert log =~ "Expected join source callback to return {:ok, source} | {:error, reason} | nil"`.
   after: `assert_raise` (with the precise contract message) — an out-of-contract provider return must raise, not warn-and-skip.

## NEW tests needed

These behaviors are now mandated by D-RAISE/D-PROVIDER but have **no existing test** in this batch:

1. **`:reverse_order` with no prior `:order_by` must RAISE** (D-RAISE §3.9, §3.8). Current file only tests `reverse_order` when an `order_by` is already present (lines 390, 406). Add a test: `convert_params_to_filter(Post, %{reverse_order: nil}, [])` on a query with no order → `assert_raise`. → file: `common_filters_order_modifier_test.exs`.
2. **Out-of-range / invalid `:at` binding position must RAISE** (D-RAISE §3.9 — "zero, negative, or higher than the number of tables, whether or not later referenced, handled the same way in every spot"). No test in this batch exercises an invalid position; every positional `:at` test uses a valid position (2, first, last). Add raising tests in each binding-aware filter file (order_modifier, select, select_merge, group_by, distinct, offset, first, join `:on`, page, preload) — at minimum representative coverage: position 0, negative, and > number of tables.
3. **`:join` provider wrong-arity function must RAISE** (D-PROVIDER §3.10 — "the function's arity is checked"). No test covers a provider supplying a function of the wrong arity. Add to `common_filters_join_test.exs`.

## NEEDS-DECISION list

1. **order_modifier · line 406** — `reverse_order: false` (a non-`true`, non-`nil` value) currently warns-and-skips. D-RAISE §3.9 enumerates the new raise case as "`:reverse_order` used when there is no `:order_by`" — it does **not** list "`:reverse_order` given a value other than true/nil." Is a malformed `:reverse_order` *value* a "caller used the API wrong → raise," or does it remain warn-and-skip? Verdict held at NEEDS-DECISION; current reading is KEEP (spec only names the no-order case). Needs a §4 row either way.

2. **join · line 322** — provider returns `{:error, reason}` → warns. §3.10 lists "a clearly-shaped … 'error' result" as an *allowed* return shape, so logging-and-skipping seems in-contract (KEEP). But §3.10 also says a return "that does not fit the contract raises." Confirm `{:error, reason}` is intended to be a quiet log (KEEP) vs. surfaced as a raise. Tentative: KEEP.

3. **`:at` raise scope** — D-RAISE says invalid positions raise "in every spot … whether or not later referenced." Confirm this applies uniformly to ALL binding-aware structural filters in this batch (order_by, select, select_merge, group_by, distinct, offset, first, page, preload, join `:on`), since each currently only tests valid positions. This is a coverage/scope decision driving the NEW-tests item #2 above.
