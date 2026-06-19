# Batch C — Array / Map / Schemaless test audit

Spec source of truth: `docs/superpowers/specs/2026-06-19-query-building-api-refactor-design.md`.
Most relevant decisions: **D-LIST** (`:elements` removed; bare list = "is one of" everywhere; list-column overlap is the explicit `overlaps` operator; list routing only from a known column type — schema or `:field_types`), **D-WIRE**, **D-RAISE**, **D-NULL**, **D-OPERAND**.

## Summary counts
- KEEP: 25
- CHANGE: 12
- NEEDS-DECISION: 4

---

## File: common_filters_map_field_test.exs

JSONB/map behavior on schema-backed `UserData`. Map routing comes from the schema type, unaffected by D-LIST. These do not touch `:elements`, lists, or the operand convention.

| test (name · line) | asserts | verdict | decision ID | required change |
|---|---|---|---|---|
| bare :map IS NULL · 11 | `%{data: nil}` → `is_nil(u.data)` | KEEP | — | — |
| JSONB containment single-key map · 18 | `%{data: %{contains: %{role: "admin"}}}` → `@>` | KEEP | — | — |
| negated JSONB containment · 34 | `%{data: %{not: %{contains: ...}}}` → `not (@>)` | KEEP | D-NULL (consistent) | — (negation = `negated` slot) |
| jsonb_exists has_key · 50 | `%{data: %{has_key: "role"}}` → jsonb_exists | KEEP | — | — |
| jsonb_exists_any has_any_key · 66 | `has_any_key` list → jsonb_exists_any | KEEP | — | — |
| jsonb_exists_all has_all_keys · 82 | `has_all_keys` list → jsonb_exists_all | KEEP | — | — |
| multi-key containment ANDed · 102 | `%{data: %{contains: [role:, active:]}}` → two ANDed `@>` | NEEDS-DECISION | — | Relies on the old Normalizer expanding a keyword-list value into multiple entries. Spec §2.2 shows `contains` taking a map (`{:contains, {:role,"admin"}}`); the keyword-list multi-pair expansion is not described. Confirm whether multi-pair containment is still supported / in what shape. |
| typed {:map,:string} containment · 122 | `typed_map` `contains` → `@>` | KEEP | D-LIST §3.4 (routing from type) | — (typed map routes to map helper, correct) |
| typed map IS NULL · 138 | `%{typed_map: nil}` → `is_nil` | KEEP | — | — |

---

## File: common_filters_field_types_opt_test.exs

`:field_types` is the supported way to declare list/map columns on schemaless sources (spec §1.6, §3.4).

| test (name · line) | asserts | verdict | decision ID | required change |
|---|---|---|---|---|
| without field_types, list value uses scalar membership · 13 | `%{tags: ["elixir","ecto"]}` on `"posts"` → `p.tags in ^[...]` | KEEP | D-LIST | matches spec exactly (bare list = membership, no type → scalar) |
| with field_types array, scalar value uses array membership · 26 | `%{tags: "elixir"}` + `field_types` → `^"elixir" in p.tags` | KEEP | D-LIST §3.4 | — (typed list column, scalar = element membership) |
| with field_types array, explicit `in:` list uses array overlap · 39 | `%{tags: %{in: [...]}}` → `&&` overlap | CHANGE | D-LIST | A bare/`in` list no longer means overlap. `in:` on a typed list column = membership (`IN`), or per spec a list value = "is one of". Overlap must use the new `overlaps` operator: `%{tags: %{overlaps: ["elixir","ecto"]}}` → `&&`. before: `in:`→`&&`; after: `overlaps:`→`&&`. |
| field_types overrides schema-backed reflection · 52 | `Post` + `field_types:[tags:{:array,:string}]`, `%{tags:"elixir"}` → `^"elixir" in p.tags` | KEEP | — | — |
| field_types :map containment · 67 | `%{data:%{contains:...}}` + `field_types:[data: :map]` → `@>` | KEEP | — | — |
| field_types {:map,:string} containment · 83 | same, `{:map,:string}` | KEEP | — | — |
| field_types :map has_key · 99 | `%{data:%{has_key:"role"}}` → jsonb_exists | KEEP | — | — |

---

## File: common_filters_association_filter_test.exs

| test (name · line) | asserts | verdict | decision ID | required change |
|---|---|---|---|---|
| map value routes through association handler · 12 | `%{author: %{age: 25}}` → join + where | KEEP | — | — |
| keyword list value routes through association handler · 30 | `[author: [age: 25]]` → join + where | KEEP | — | — |
| scalar value logs warning, returns unchanged · 48 | `%{author: "bad value"}` → query unchanged + warning log | CHANGE | D-RAISE | Association given a scalar is now a caller mistake → **raises** from Elixir (validated over HTTP). before: `capture_log` + unchanged query + "Expected association filter value..." warning; after: `assert_raise` with the precise message. |

---

## File: common_filters_schemaless_test.exs (array/map/elements/list + operator-shape focus)

### `:elements wrapper (schemaless)` describe block — all CHANGE (D-LIST removes `:elements`)

| test (name · line) | asserts | verdict | decision ID | required change |
|---|---|---|---|---|
| :in with :elements produces && · 39 | `%{tags:%{elements:%{in:[...]}}}` → `&&` | CHANGE | D-LIST | `:elements` removed. Overlap is now `%{tags:%{overlaps:[...]}}` and requires a typed list column (`field_types:[tags:{:array,:string}]`). before: elements+in→`&&` on bare schemaless; after: `overlaps` + `field_types`→`&&`. |
| :in without :elements → scalar IN · 52 | `%{tags:%{in:[...]}}` on `"posts"` → `p.tags in ^[...]` | KEEP | D-LIST | Correct under D-LIST (no type → scalar membership). Drop the "without :elements" framing in the name; keep the assertion. |
| scalar value with :elements → element membership · 65 | `%{tags:%{elements:"elixir"}}` → `^"elixir" in p.tags` | CHANGE | D-LIST | `:elements` removed. Express via `field_types:[tags:{:array,:string}]` + `%{tags:"elixir"}` (see field_types_opt line 26). |
| nil with :elements → IS NULL · 78 | `%{tags:%{elements:nil}}` → `is_nil` | CHANGE | D-LIST | `:elements` removed. `%{tags: nil}` already yields `is_nil` regardless of type; rewrite without wrapper. |
| count with :elements → array_length · 91 | `%{tags:%{elements:%{count:%{>:3}}}}` → `array_length > 3` | CHANGE | D-LIST | `:elements` removed; `count` is now a list-column operator (`%{tags:%{count:%{gt:3}}}`) requiring a typed list column via `field_types`. |
| list value with :elements → array equality · 104 | `%{tags:%{elements:["elixir","erlang"]}}` → `p.tags == ^[...]` | NEEDS-DECISION | D-LIST | `:elements` removed. Spec §1.5/§2.2 lists no array-**equality** operator (only `overlaps`, `count`). Decide whether array equality survives and under what operator, or drop this test. |

### `field_types: opt (schemaless)` describe block

| test (name · line) | asserts | verdict | decision ID | required change |
|---|---|---|---|---|
| field_types :map has_key · 123 | jsonb_exists | KEEP | — | — |
| field_types :map containment · 139 | `@>` | KEEP | — | — |
| without field_types, scalar semantics regardless of name · 155 | `%{tags:["elixir","ecto"]}` → `p.tags in ^[...]` | KEEP | D-LIST | matches spec exactly |

### Other operator-shape assertions

| test (name · line) | asserts | verdict | decision ID | required change |
|---|---|---|---|---|
| unknown key scalar = equality · 20 | `%{author_id: 1}` → `==` | KEEP | — | — |
| invalid fields kept in where/select/order_by · 174/187/200 | arbitrary field passes through on schemaless | NEEDS-DECISION | §3.3 / D-WIRE | Spec §3.3: text field on schemaless with no `:allowed_keys` → skip+warn. These tests use atom keys (`p.does_not_exist`); atom keys are "use as-is". Confirm atom-keyed unknown fields on schemaless still pass through unchanged (no `:allowed_keys` gate for atoms). |
| comparison == (atom & plain map) · 219/226 | `==` | KEEP | — | — |
| negation: not in list → `is_nil OR not in` · 235 | `%{published:%{not:%{in:[true,false]}}}` → `is_nil(p.published) or p.published not in ^[...]` | CHANGE | D-NULL | `!=`/not-in no longer matches null rows. before: `is_nil(p.published) or p.published not in ^[...]`; after: `p.published not in ^[true, false]` (plain SQL, no `is_nil` padding). |
| string like → `%hello%` · 252 | auto-`%` wrap | KEEP | D-LIKE-WRAP | — |
| lowercased compare · 261 | `lower(?) == ` | KEEP | — | — |
| aggregate avg > · 270 | `avg(p.views) > ^10` | KEEP | D-ONE-WAY | — (already the one-spelling form) |
| boolean :and / :or / :or-list · 278/286/292 | where / or_where | KEEP | — | — |
| keyword where AND · 310 | two where clauses | KEEP | — | — |
| date wrapper add 7 days · 324 | `%{>=:%{date:%{add:%{field:..,count:7,interval:"day"}}}}` | KEEP | D-OPERAND/D-WIRE (date-math) | Uses `count`/`interval` map (not tuple) — OK for date-math. Note: this is the field-relative `add` calculation, distinct from `ago`/`from_now`; consistent with operand-tree direction. Keep, verify operand shape during impl. |
| datetime wrapper add · 348 | datetime_add comparison | KEEP | D-OPERAND/D-WIRE | same as above |
| parent_as equality / negated / gt · 811/824/837 | `field(parent_as(:post), :id)` direct | NEEDS-DECISION | D-OPERAND | These assert the resulting Ecto query (parent_as), which is fine, but if they feed the old `:parent_as` **input** shape they must move to `%{parent: %{as:"post", field: :id}}` and only inside a subquery/exists. Read input params (lines ~813-849) and convert if old shape. |

(Structural-only schemaless tests — exclude, join, last, lock, page, order, group_by, having, select, select_merge, set ops, subquery, update, with_cte, with_named_binding, with_ties, windows, first/limit/offset — are outside this batch's array/map/list/operator-shape scope and are covered by the structural batch. Note: `with_ties` invalid-payload (773) and `with_cte` invalid (712) keep warn-and-skip per §3.8 unless they are caller-mistake binding cases.)

---

## NEW tests needed
1. **`overlaps` operator, typed list column** — `%{tags:%{overlaps:["a","b"]}}` with `field_types:[tags:{:array,:string}]` (and schema-backed `Post.tags`) → `fragment("? && ?", p.tags, ^[...])`. Replaces the deleted `:elements`/`:in`-overlap path.
2. **Bare list = membership on a typed list column** — `%{tags:["a","b"]}` with a list `field_types` → confirm `p.tags in ^[...]` (membership), NOT overlap; proves D-LIST applies even when the type is known.
3. **`count` list-size operator on a typed list column** — `%{tags:%{count:%{gt:3}}}` + `field_types:[tags:{:array,:string}]` → `array_length(?,1) > ^3`. Replaces the `:elements`+count test.
4. **Element membership without `:elements`** — `%{tags:"elixir"}` on a typed list column → `^"elixir" in p.tags`. (Partially covered by field_types_opt:26; add the schemaless-source variant.)
5. **`overlaps` on an untyped schemaless column warns-and-skips or treats as scalar** — define behavior when `overlaps` is used without a known list type (§3.4: array helper chosen only when type is known to be a list).
6. **Association scalar raises** — `assert_raise` companion to the converted association test (D-RAISE), plus an HTTP-validate variant returning errors as data.
7. **`!=`/not-in does NOT match nulls** — positive D-NULL coverage and the explicit `%{eq: nil}` opt-in path.

## NEEDS-DECISION list
1. **Multi-key JSONB containment via keyword list** (map_field:102) — does the keyword-list-value → multiple ANDed `@>` expansion survive, and in what spec-blessed shape? Spec §2.2 only shows single-map `contains`.
2. **Array equality operator** (schemaless:104) — `:elements` is gone; spec lists no array-equality operator (only `overlaps`/`count`). Keep array equality (under which operator) or drop?
3. **Atom-keyed unknown fields on schemaless** (schemaless:174/187/200) — §3.3 gates *text* field names behind `:allowed_keys`; confirm atom keys remain "use as-is" and pass through unchanged with no schema/allowed_keys.
4. **`parent_as` input shape** (schemaless:811/824/837) — confirm whether the test inputs use the old `:parent_as` shape (must migrate to `%{parent:%{as:,field:}}`, subquery-only per D-OPERAND) or already assert only output.
