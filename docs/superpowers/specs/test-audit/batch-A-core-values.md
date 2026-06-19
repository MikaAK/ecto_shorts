# Test Audit — Batch A: Core Values

**Spec:** `2026-06-19-query-building-api-refactor-design.md` (source of truth).
**Scope:** five `test/ecto_shorts/common_filters/` files — comparison operators, negation, typed value casting, enum casting, boolean composition.

Key spec levers applied below:
- **D-NULL** (§3.5/§4): `!=` / not-in no longer pad with `is_nil OR …`. Only `== nil` / `!= nil` consider nulls. Any test asserting `is_nil(x) or x not in …` (or its negated `not is_nil … and … in …` mirror) for a non-nil comparison must change to plain SQL.
- **D-LIST** (§0.4/§3.4): a bare list is always membership (`:in`); list overlap is the explicit `overlaps` operator.
- **D-OPERAND** (§1.5a): RHS is a literal / `field` / `from` / `parent`, arithmetic uses ordered-list math words wrapped under `value`. The tests already use this shape.
- **D-WIRE** (§1.7): string/atom operator keys via a closed safe list; no tuples on the wire.

---

## common_filters_comparison_operators_test.exs

| test (name · line) | what it asserts | verdict | decision ID | required change |
|---|---|---|---|---|
| equals via == · 13 | `%{id: %{==: 1}}` → `id == ^1` | KEEP | — | — |
| is nil via == nil · 20 | `%{published_at: %{==: nil}}` → `is_nil` | KEEP | D-NULL | nil path retained |
| not nil via != nil · 27 | `%{published_at: %{!=: nil}}` → `not is_nil` | KEEP | D-NULL | nil path retained |
| greater than · 34 | `%{views: %{>: 10}}` → `> ^10` | KEEP | — | — |
| gte · 41 | `>= ^10` | KEEP | — | — |
| less than · 48 | `< ^10` | KEEP | — | — |
| lte · 55 | `<= ^10` | KEEP | — | — |
| not equal via != · 62 | `%{views: %{!=: 10}}` → `views != ^10` | KEEP | — | scalar `!=`, no null padding — already correct |
| in list · 69 | `%{published: %{in: [..]}}` → `in ^[..]` | KEEP | — | — |
| list with == as IN · 76 | `%{published: %{==: [..]}}` → `in ^[..]` | KEEP | D-LIST | list under `==` = membership — consistent |
| **list with != as NOT IN · 83** | `%{published: %{!=: [..]}}` → **`is_nil(p.published) or p.published not in ^[..]`** | **CHANGE** | **D-NULL** | asserts null padding; must become `p.published not in ^[true, false]` (plain `not in`, no `is_nil … or`) |
| struct DateTime preserved · 90 | `>= ^dt` | KEEP | — | — |
| quantified default equality (all) · 98 | `%{id: %{all: subq}}` → `id == all(subq)` | KEEP | D-OPERAND | `from: Comment` (module) — see NEEDS-DECISION 1 |
| quantified any default · 121 | `id == any(subq)` | KEEP | D-OPERAND | as above |
| quantified select override · 144 | `select: %{field: "post_id"}` → `select c.post_id` | KEEP | D-OPERAND | module source caveat |
| quantified any select override · 167 | any + select override | KEEP | D-OPERAND | module source caveat |
| invalid select override falls back · 190 | bad field warns + falls back to `id` | KEEP | D-WARN | warn-and-skip preserved |
| quantified > all · 227 | `%{id: %{>: %{all: subq}}}` → `id > all(subq)` | KEEP | D-OPERAND | — |
| quantified > any · 250 | `id > any(subq)` | KEEP | D-OPERAND | — |
| explicit value wrapper arithmetic · 273 | `%{views: %{>: %{value: %{+: [%{field: "views"}, %{value: 10}]}}}}` → `views > views + ^10` | KEEP | D-OPERAND | matches §1.5a ordered-list math |
| raises for unsupported nil operator · 286 | `%{published_at: %{>: nil}}` raises `ArgumentError` | NEEDS-DECISION | D-RAISE | see NEEDS-DECISION 2 |
| negated arithmetic comparison · 294 | `not (views == views + ^10)` | KEEP | D-OPERAND | — |
| negated value-wrapped == · 309 | `%{not: %{==: %{value: 10}}}` → `views != ^10` | KEEP | — | negated `==` collapses to `!=` (scalar, no null) |
| negated value-wrapped > · 322 | `not (views > ^5)` | KEEP | — | — |
| generic scalar != fallback · 337 | `%{!=: %{value: 5}}` → `views != ^5` | KEEP | — | — |
| negated scalar >= fallback · 344 | `not (views >= ^5)` | KEEP | — | — |
| datetime ago == with date cast · 353 | `%{==: %{date: %{ago: [count: 1, interval: "month"]}}}` → `date(?) == date(ago(^1,"month"))` | NEEDS-DECISION | D-WIRE | see NEEDS-DECISION 3 |
| negated datetime ago · 369 | `!=` mirror of above | NEEDS-DECISION | D-WIRE | see NEEDS-DECISION 3 |
| arithmetic + variants (==,!=,>,>=,<,<=, 4 negated) · 387–515 | `views OP views + ^10` and negated | KEEP | D-OPERAND | ordered-list `+` — all match §1.5a |
| arithmetic - variants · 519, 532 | `views == views - ^5`, negated | KEEP | D-OPERAND | — |
| arithmetic * variants · 547, 560 | `views == views * ^2`, negated | KEEP | D-OPERAND | — |
| arithmetic / variants · 575, 588 | `views == views / ^2`, negated | KEEP | D-OPERAND | — |

Note: none of the arithmetic-variant tests assert null padding (RHS is non-nil), so D-NULL leaves them untouched.

---

## common_filters_negation_test.exs

| test (name · line) | what it asserts | verdict | decision ID | required change |
|---|---|---|---|---|
| **not in list · 12** | `%{not: %{in: [..]}}` → **`is_nil(p.published) or p.published not in ^[..]`** | **CHANGE** | **D-NULL** | must become `p.published not in ^[true, false]` (no `is_nil … or`) |
| **not (== list) · 25** | `%{not: %{==: [..]}}` → **`is_nil(..) or .. not in ^[..]`** | **CHANGE** | **D-NULL** | must become plain `not in ^[..]` |
| **not (!= list) · 38** | `%{not: %{!=: [..]}}` → **`not is_nil(..) and .. in ^[..]`** | **CHANGE** | **D-NULL** | double negation of a non-nil `!=`; must become plain `in ^[true, false]` (no `not is_nil … and`) |
| excludes > value · 51 | `not (views > ^10)` | KEEP | — | — |
| excludes == value · 58 | `%{not: %{==: 10}}` → `views != ^10` | KEEP | — | scalar, no null |
| negated quantified equality (all) · 65 | `not (id == all(subq))` | KEEP | D-OPERAND | module source caveat |
| negated quantified any · 88 | `not (id == any(subq))` | KEEP | D-OPERAND | module source caveat |
| double negation != · 111 | `%{not: %{!=: 10}}` → `views == ^10` | KEEP | — | scalar |
| negated ne alias · 118 | `%{not: %{ne: 10}}` → `views == ^10` | KEEP | D-WIRE | `ne` alias preserved |
| negated gt alias · 125 | `%{not: %{gt: 10}}` → `not (views > ^10)` | KEEP | D-WIRE | `gt` alias preserved |
| negated lower + not != · 134 | `%{not: %{!=: %{lower: "hello"}}}` → `lower(title) == ^"hello"` | KEEP | — | `lower` operand; scalar |
| excludes nil not == · 149 | `not is_nil(published_at)` | KEEP | D-NULL | nil path retained |
| includes nil not != · 156 | `is_nil(published_at)` | KEEP | D-NULL | nil path retained |
| negated != all · 165 | `not (id != all(subq))` | KEEP | D-OPERAND | module source caveat |
| negated > any · 188 | `not (id > any(subq))` | KEEP | D-OPERAND | module source caveat |
| not avg == nil · 213 | `not is_nil(avg(views))` | KEEP | D-NULL | aggregate nil path retained |
| not avg != nil · 222 | `is_nil(avg(views))` | KEEP | D-NULL | — |
| sum == nil · 231 | `is_nil(sum(views))` | KEEP | D-ONE-WAY/D-NULL | single aggregate spelling, nil retained |
| sum != nil · 238 | `not is_nil(sum(views))` | KEEP | — | — |
| negated avg <= · 245 | `not (avg(views) <= ^10)` | KEEP | — | — |
| negated avg != → == · 254 | `avg(views) == ^50` | KEEP | — | scalar, no null |

---

## common_filters_typed_value_casting_test.exs

| test (name · line) | what it asserts | verdict | decision ID | required change |
|---|---|---|---|---|
| string int on root field · 11 | `%{id: "1"}` → `id == ^1` | KEEP | D-WIRE | text cast by schema |
| string int named binding · 24 | `%{as: %{author: %{age: "42"}}}` → `u.age == ^42` | KEEP | D-WIRE | — |
| string int positional binding · 43 | `%{at: %{2 => %{age: "42"}}}` | KEEP | D-WIRE | binding 2 valid (assoc joined) |
| cast string int with > · 63 | `> ^10` | KEEP | D-WIRE | — |
| cast with >= · 71 | `>= ^10` | KEEP | — | — |
| cast with < · 79 | `< ^10` | KEEP | — | — |
| cast with <= · 87 | `<= ^10` | KEEP | — | — |
| cast with gt alias · 95 | `> ^10` | KEEP | D-WIRE | alias preserved |
| cast with gte alias · 103 | `>= ^10` | KEEP | D-WIRE | — |
| cast with lt alias · 111 | `< ^10` | KEEP | D-WIRE | — |
| cast with lte alias · 119 | `<= ^10` | KEEP | D-WIRE | — |
| cast with != · 127 | `views != ^10` | KEEP | — | scalar |
| cast with ne alias · 135 | `views != ^10` | KEEP | D-WIRE | — |
| cast with eq alias · 143 | `views == ^10` | KEEP | D-WIRE | — |
| list of string ints == · 153 | `%{==: ["10","20"]}` → `in ^[10,20]` | KEEP | D-LIST | list = membership |
| **list of string ints != · 161** | `%{!=: ["10","20"]}` → **`is_nil(p.views) or p.views not in ^[10,20]`** | **CHANGE** | **D-NULL** | must become `p.views not in ^[10, 20]` |
| list of string ints in · 169 | `in ^[10,20]` | KEEP | — | — |
| bare list membership · 177 | `%{views: ["10","20"]}` → `in ^[10,20]` | KEEP | D-LIST | — |
| array field equality · 187 | `%{tags: %{==: [..]}}` → `tags == ^[..]` | NEEDS-DECISION | D-LIST | see NEEDS-DECISION (list) |
| array field inequality · 196 | `%{tags: %{!=: [..]}}` → `tags != ^[..]` | NEEDS-DECISION | D-LIST/D-NULL | see NEEDS-DECISION (list) |
| array field `in` (bare list) · 205 | `%{tags: ["elixir"]}` → `tags == ^["elixir"]` | CHANGE | D-LIST | bare list must be membership `tags in ^["elixir"]`, not equality (§3.4: array helper only via type, but bare list = "is one of") — see NEEDS-DECISION (list) |
| value wrapper tuple · 215 | `%{views: %{>: {:value, "10"}}}` → `> ^10` | NEEDS-DECISION | D-WIRE | tuple operand; see NEEDS-DECISION 4 |
| string boolean · 230 | `%{published: "true"}` → `published == ^true` | KEEP | D-WIRE | — |

---

## common_filters_enum_casting_test.exs

| test (name · line) | what it asserts | verdict | decision ID | required change |
|---|---|---|---|---|
| bare enum atom cast · 12 | `%{status: :published}` → `status == ^1` | KEEP | — | — |
| operator-wrapped enum != · 19 | `%{status: %{!=: :archived}}` → `status != ^2` | KEEP | — | scalar, no null |
| list of enum atoms membership · 26 | `%{status: [..]}` → `in ^[1,2]` | KEEP | D-LIST | bare list = membership |
| non-enum passthrough · 35 | `%{views: 42}` → `views == ^42` | KEEP | — | — |
| nil passthrough · 42 | `%{status: nil}` → `is_nil(status)` | KEEP | D-NULL | bare `nil` = is_nil (see NEEDS-DECISION 5) |
| enum through association · 51 | `%{enum_schema: %{status: :published}}` → join + `status == ^1` | KEEP | — | — |

---

## common_filters_boolean_composition_test.exs

| test (name · line) | what it asserts | verdict | decision ID | required change |
|---|---|---|---|---|
| or_where unknown field → unchanged + warn · 13 | `%{or_where: %{nonexistent…: 42}}` warns "does not exist on schema", query unchanged | KEEP | D-WARN | unknown column = warn-and-skip (not raise); matches §3.9 |

---

## NEW tests needed

1. **String operator keys end-to-end.** Tests use atom keys (`%{==: 1}`, `%{gt: …}`) but the spec headline (D-WIRE, §1.7) is that **string** keys round-trip (`%{"gt" => 21}` / `{"age":{"gt":21}}`). No test exercises a string operator key. Add core cases: `%{views: %{"gt" => 10}}`, `%{views: %{"ne" => 10}}`.
2. **Rejected/unsafe operator string.** A string not on the closed safe list must be rejected without `String.to_atom` (D-WIRE, §2.3). Add a test that an unknown operator string warns/rejects and never creates an atom.
3. **Bare list overlap requires explicit `overlaps` (D-LIST).** No test covers `%{tags: %{overlaps: ["a","b"]}}` → array `&&`. Add it (the old `:elements` path is gone). Pairs with the array-field ambiguity below.
4. **Date-math as a map, not a keyword/tuple (D-WIRE).** Spec form is `%{ago: %{count: 1, unit: "day"}}`; current tests only use the keyword-list `[count: 1, interval: "month"]`. Add the map-form date-math test (the canonical HTTP shape).
5. **`!= [list]` produces plain `not in` (D-NULL).** After the three CHANGE rows land, add an explicit positive test that the *only* way to include nulls is `%{or: [%{views: %{eq: nil}}, %{views: %{not: %{in: […]}}}]}` — locking in that null padding is gone.
6. **Correlated `parent` operand (§1.5a).** No test in this batch covers `%{parent: %{as: "post", field: :id}}` inside an `exists`/subquery. (May belong to another batch, but flagged.)

---

## NEEDS-DECISION list

1. **Subquery source as a raw module vs. registered string alias.** Every quantified test passes `from: Comment` (an Elixir module). D-WIRE (§1.5a/§1.7) says client-supplied subquery sources must be a **registered string name, never a raw module**. From Elixir a module may still be allowed, but the spec doesn't explicitly say module-sources stay valid for the in-process API — it only guarantees the registered-name path. Need a decision: do the Elixir-facing tests keep `from: Comment`, or must they move to `from: "comments"`? Affects ~8 tests across comparison + negation files.
2. **`%{field: %{>: nil}}` raising (comparison test, line 286).** The test asserts `ArgumentError` for `%{published_at: %{>: nil}}`. §3.9/D-RAISE enumerates the cases that raise (scalar association, bad binding, `:reverse_order`, bad provider) — a non-nil-supporting operator given `nil` is **not** in that list. The spec's default for a meaningless operator/value combo is warn-and-skip (D-WARN). So this test may be wrong (should warn-and-skip, not raise), or this is an unlisted raise case that needs a new §4 row. Genuinely ambiguous.
3. **Date-math operand keyword-list form (`[count: 1, interval: "month"]`).** Tests at lines 353/369 pass date-math as a keyword list with key `interval`; the spec's canonical/tidied form is `[count: 1, interval: "day"]` internally but the **caller** form is the map `%{count:, unit:}` with key `unit` (D-WIRE, §1.5/§1.7). The tests use the internal tidied shape as *input*, which the spec says is not the documented caller form. Decision: are these tests asserting an accepted (legacy/Elixir-only) input shape, or must the input switch to `%{ago: %{count: 1, unit: "month"}}`?
4. **`{:value, "10"}` tuple operand (casting test, line 215).** Tenet 7 / D-WIRE say "nothing on the wire is a tuple"; the operand convention uses `%{value: …}` maps. This tuple is Elixir-only sugar. Decision: keep the tuple as an accepted Elixir convenience (spec §1.7 keeps the date-math tuple "from Elixir for convenience"), or replace with `%{value: "10"}`? Lean: keep but add the map-form test; needs confirmation.

*(Also folded into above: the three array-field tests at lines 187/196/205 — whether `%{tags: %{==: [..]}}` is list equality vs. membership, and whether a bare list on a known list column is membership (`in`) per §3.4 "bare list always means is one of" even though the array helper is type-routed. The line-205 test asserting `tags == ^["elixir"]` for a bare list contradicts D-LIST's "bare list = is one of" and is marked CHANGE; the `==`/`!=`-with-explicit-list-on-an-array-column cases (187/196) are the genuine ambiguity — does an explicit `==` list on a list column mean array equality or membership? Spec §3.4 routes by type to the array helper but §1.5/D-LIST only defines *bare* list semantics. Needs a §4 clarification.)*

5. **Bare `nil` value (enum test, line 42, and elsewhere).** `%{status: nil}` → `is_nil`. The spec's core value table only shows nil under an operator (`%{eq: nil}`); it doesn't state that a *bare* `nil` (no operator) means `== nil`. Behavior is sensible and likely KEEP, but the spec is silent on bare-nil, so it's flagged for an explicit confirmation/§4 note.
