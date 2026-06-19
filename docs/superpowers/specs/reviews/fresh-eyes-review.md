# Fresh-Eyes Review — Query-Building API Design

Five independent agents: three **blind** designers (given only the problem +
the HTTP requirement, not our spec) and two **reviews** of our actual spec
(adversarial design critique + HTTP round-trip stress test).

## The good news: our core shape is the industry consensus

All three blind designers — and the prior-art survey across Mongo, Prisma,
Hasura, Ash, Ransack, JSON:API — independently landed on the shape we already
have:

- **field-keyed, operator-nested:** `%{field: %{op: value}}`
- **bare value = equality:** `%{status: "active"}`
- **implicit AND across keys; explicit `or`/`and` as a list of sub-maps**
- **a small, closed operator set**
- **a dumb decoder + schema-driven casting** (values stay strings off the wire;
  the schema decides types) — exactly what our `TermResolver` does
- **an allowlist of filterable fields** for safety (we have `:allowed_keys`)
- **JSON body as the primary transport; query-string brackets for the simple
  flat-AND subset**

So the foundational decisions are sound and well-validated. The criticism is not
about the core — it is about **how much we bolted onto it** and **HTTP details we
left unspecified.**

## The divergences (where outsiders would build differently)

### 1. The surface is too big to call "minimal" (both reviews agree)
Our §2.2 freezes ~22 value shapes and §1.4 freezes ~40 structural keys. The blind
designers built far smaller languages and **refused** several things we keep:
arithmetic comparisons, `parent_as`, quantified `all`/`any` subqueries, `:exists`,
CTEs, windows, set operations. The critic's words: *"you cannot claim minimalism
and freeze a 40-key structural vocabulary plus a 22-shape value grammar — pick one
story."* These advanced shapes are ~70 generated clauses in `ScalarExpr` alone
(arithmetic 48 + parent_as 24).

**Recommended:** split the grammar into a **wire-safe core** and an
**Elixir-only advanced tier**, and push the advanced shapes behind a raw-`dynamic`
escape hatch (already supported). Loses no capability; shrinks §2.2 by a third and
deletes ~70 clauses.

### 2. HTTP decoding is unspecified — the biggest hole, and a security gap
- **Operators are atoms; JSON carries only strings.** Nearly every non-plain
  filter uses an operator key, so JSON sends `"gt"`, not `:gt`. We never specified
  how `"gt"` becomes `:>`. Must be a **closed allow-list lookup**, never
  `String.to_atom` on client input (atom-exhaustion DoS).
- **Date-math tuples `{1, :day}` have NO JSON or query-string form.** This is the
  single worst offender and it's an everyday filter ("last 7 days"). Fix: the map
  form `%{count: 1, unit: "day"}` — which our tidied output *already* produces
  internally and which `add` already accepts.
- **Subquery `from: Comment` is a module reference** — no JSON form, and
  re-atomizing client strings into modules is a remote-code/atom hazard. Must use
  server-registered **string aliases**, not raw module names.
- **Times must be ISO8601 strings** over the wire (no `DateTime` structs).

### 3. D-ELEMENTS introduced a regression (both reviews flagged it)
Removing `:elements` and unifying list forms makes a bare list **type-dependent**:
membership on a scalar column, overlap on an array column — *same syntax, different
meaning.* And it removes the only **wire-side** trigger for array filtering on
schemaless sources. Recommended: **bare list = membership everywhere**; require an
explicit operator (e.g. `%{tags: %{overlaps: [...]}}`) for array overlap.

### 4. Smaller intuitiveness issues
- **Operator-vs-field-name collisions** at the top level: columns named `count`,
  `before`, `after`, `data`, `all` collide with operator/shorthand words. Need a
  stated precedence rule. (The nested `%{field: %{op: ...}}` shape avoids this for
  operators; our top-level shorthands and structural keys do not.)
- **Two spellings for aggregates** — `%{views: %{avg: %{gt: 5}}}` and
  `%{views: %{aggregate: %{fn: :avg, ...}}}` both exist. Drop one.
- **D-RAISE over HTTP:** raising on `%{author: "x"}` (a malformed *request*)
  becomes a 500 unless wrapped. Reconsider whether request-shaped mistakes should
  raise or return a validation error.
- **§2.5 tables show only Elixir-atom syntax** — for an HTTP-first design they
  should show the JSON/query-string the map decodes *from*. Adding that column
  would have surfaced the tuple/atom gaps on its own.

## Net assessment
Roughly two-thirds of our shapes round-trip *structurally* in JSON today; they
fail only on the atom-vs-string-key policy, which one decision fixes globally. The
genuinely HTTP-natural subset (scalar compares, in-lists, like/ilike, JSON key
checks, the `ids`/`before`/`start_date` shorthands) is solid. The breakage is
concentrated in: tuples, the atom-vs-string gap, raw module references, and the
inherently-non-query-string features (OR, subqueries, arithmetic) — which should
be **declared JSON-body-only or Elixir-only**, not forced into the wire.

## The strategic question for the user
Do we **keep the full surface** (a faithful internal rewrite of a large API) or
use the unreleased v3.0.0 to **cut to a minimal, HTTP-natural core + escape hatch**
for the rest? Every independent designer built the smaller thing. This is the one
decision that reframes the spec.
