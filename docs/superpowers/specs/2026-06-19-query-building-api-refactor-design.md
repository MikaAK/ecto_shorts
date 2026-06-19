# Specification — `convert_params_to_filter/3` and the Query-Building Pipeline

**Status:** Draft for review · **Date:** 2026-06-19 · **Branch:** v3.0.0

This document is the **single source of truth** for the behavior of the EctoShorts
query-building pipeline and the target architecture of its refactor. It is
self-contained: every public contract, every internal contract, the canonical
data structure that crosses each boundary, and the behavior at each boundary is
defined here. Where current behavior is contested, the **Behavior Decisions**
(§4) record the ruling — the spec overrides both code and tests.

Grounded in the behavior inventory at `./inventory/` (4 files, alongside this
spec) and the probe constraints at
`autoresearch/probe-260619-0650/constraints.md`.

---

## 0. Goal, Non-Goals, and Governing Principles

### 0.1 Goal
Restructure the pipeline so that:
1. **Normalization-as-a-pass is eliminated.** No stage walks the param tree and
   rewrites it into a normalized tree before building. Canonicalization happens
   **at the leaf, inside a single reduce**, per entry, at dispatch time.
2. **The leaf `*Expr` modules are pure.** `ScalarExpr`, `ArrayExpr`, `MapExpr`,
   `CommonExpr` receive a fully-canonical term plus a resolved field atom and
   binding, and do exactly one thing: emit an `Ecto.Query.dynamic`. They never
   alias operators, cast values, resolve field names, reflect on schemas, or
   hardcode field names.
3. **One dialect-agnostic resolver** owns operator canonicalization, value
   casting, field-name resolution, field-type routing, and wrapper expansion.
4. **Reduce patterns replace recursive rewrite chains** at every point they were
   masquerading as something else (`sort_filter_params`, `build_dynamic`,
   `apply_expr`, `cast_value`).
5. **`comparison_impl` is decomposed** into per-family dispatchers plus one
   collapsed comparison matrix.

### 0.2 Non-Goals
- No change to the **public param language** callers use today (§1). Every param
  shape that works now keeps working identically.
- No new database dialects implemented. The resolver is made dialect-agnostic so
  a future dialect *could* be added, but only Postgres ships.
- No redesign of the error policy beyond what §4 rules. `warn + nil` is preserved
  unless a decision in §4 says otherwise.

### 0.3 Governing Principles (from `RULES.md`)
- **Design against public contracts, not internal representations.** Each
  boundary in §1–§3 is defined by the shape passed in and the shape returned.
- **Behaviour spec before implementation.** This document is that spec; no code
  until it is approved.
- **Show state and state changes.** Every transformation below shows literal
  `before → after` term shapes.

---

## 1. PUBLIC CONTRACT — `EctoShorts.CommonFilters.convert_params_to_filter/3`

### 1.1 Signature
```elixir
@spec convert_params_to_filter(source, params, opts) :: Ecto.Query.t()
  when source :: module() | {binary(), module()} | Ecto.Query.t(),
       params :: map() | keyword(),
       opts   :: keyword()
```

### 1.2 Inputs
| Param | Accepted shapes | Notes |
|---|---|---|
| `source` | schema module · `{source_string, schema}` tuple · pre-built `Ecto.Query` | Coerced to `Ecto.Query` via `CommonSchema.to_query/1`. Schemaless `{source, schema}` carries no field types unless `:field_types` is supplied. |
| `params` | plain map (non-struct) · keyword list | Keyword lists preserve **duplicate keys and order**; maps are converted to a keyword list internally. No validation — unknown keys fall through to field/`:where` routing (§1.5). |
| `opts` | keyword list | Recognized keys in §1.6. |

### 1.3 Output
A single `Ecto.Query.t()` with all recognized filters applied. **The function
never raises for unrecognized fields or unsupported operator/field combinations**
— it emits a `Logger.warning` and skips that filter (see §4-D1 for the one
audited exception around datetime wrappers).

### 1.4 The public param language (closed list of recognized keys)
Structural filter keys (routed to `Builder`/sub-modules):
```
:and :distinct :except :except_all :exclude :first :group_by :having
:intersect :intersect_all :join :last :limit :lock :offset :or :or_having
:or_where :page :prepend_order_by :preload :put_query_prefix :recursive_ctes
:reverse_order :select :select_merge :subquery :union :union_all :update
:where :windows :with_cte :with_named_binding :with_ties
```
Special-dispatch keys: `:as`, `:at` (binding selectors).
Implicit keys: **any schema association name** (→ implicit join + recurse), **any
other key** (→ treated as a `:where` field predicate).

> The exhaustive per-key table (accepted shapes, emitted clause, warn/nil cases,
> file:line) lives in `inventory/01-common-filters.md` §7 and is incorporated by
> reference. The refactor MUST preserve every row of that table except where §4
> rules otherwise.

### 1.5 Predicate value language (the part this refactor reshapes internally)
Within `:where` / `:or_where` / `:having` / `:or_having` / `:and` / `:or` and
bare field keys, a field maps to a **value expression**. The public value
grammar (callers depend on this) is:

```
value_expr :=
    scalar                              # {field: 1}                 → field == 1
  | nil                                 # {field: {==: nil}}         → is_nil(field)
  | [v, ...]                            # {field: [1,2]}             → field IN [1,2]  (scalar) / overlap (array)
  | %{op => operand}  | [op: operand]   # {field: %{gt: 5}}          → field > 5
  | %{:not => value_expr}               # {field: %{not: %{eq: 5}}}  → NOT (field == 5)
  | %{agg => %{op => v}}                # {field: %{avg: %{gt: 5}}}  → avg(field) > 5
  | %{op => %{all|any => qspec}}        # {id: %{==: %{all: %{from: C, ...}}}}
  | %{arithmetic: %{...}}               # computed-field comparison (CLAUDE.md)
  | %{aggregate: %{...}}                # aggregate comparison (CLAUDE.md)
  | %{elements: value_expr}             # force array routing (CLAUDE.md)
  | %{op => %{value|field|date|datetime|parent_as => ...}}  # RHS expressions
  | %{contains|contained_by|has_key|has_any_key|has_all_keys => ...}  # JSONB (map fields)
  | datetime/date wrappers (:ago :from_now :add)
```

**Operator aliases (public, kept):**
`:eq→:==`, `:ne→:!=`, `:gt→:>`, `:gte→:>=`, `:lt→:<`, `:lte→:<=`,
`:downcase→:lower`, `:upcase→:upper`.

This public grammar is **frozen**. §2 defines the *internal canonical* grammar the
resolver produces from it.

### 1.6 Recognized `opts`
| Key | Meaning |
|---|---|
| `:field_types` | `keyword()` of `field → Ecto type`; overrides schema reflection (required for typed routing on schemaless sources). |
| `:allowed_keys` | string-field allowlist used when no schema is present (field-name resolution, §3.3). |
| `:sorter` | custom 1-arity sorter replacing `sort_filter_params/1`. |
| `:dynamic_builder` | per-call `DynamicBuilder` override (dialect adapter). |
| `:query_builder_module` | per-call `QueryBuilder` override. |
| (app config) | `:repo`, `:replica`, `:dynamic_builder_module`, `:query_builder_module`, `:query_provider_module`, `:error_module`, `:max_positional_bindings`. |

---

## 2. INTERNAL CONTRACT — Canonical-Term Grammar & Resolver

This is the heart of the refactor. **Resolution of T3** (probe conflict): a
canonical term is produced **inline, at the leaf, within the fold** — there is no
intermediate normalized tree. The grammar below defines what a *single resolved
leaf* looks like when it is handed to a dialect adapter; it is never materialized
as a rewritten copy of the whole param structure.

### 2.1 The resolved leaf (what the dialect adapter / Expr modules receive)
```
ExprInput := {
  binding   :: query_binding,        # root | {:as, name} | {:at, pos}
  field     :: atom,                 # already resolved, never a string, never nil
  negated   :: :not | nil,           # negation lifted out, applied once at the end
  term      :: canonical_term,       # see 2.2 — operators canonical, values cast
  routing   :: :scalar | :array | :map | :common
}
```

### 2.2 `canonical_term` grammar (closed)
```
canonical_op   := :== | :!= | :> | :>= | :< | :<=          # aliases already resolved
agg_fn         := :avg | :count | :max | :min | :sum
quantifier     := :all | :any
arith_op       := :+ | :- | :* | :/
dt_wrapper     := :date | :datetime
dt_op          := :ago | :from_now | :add
case_op        := :lower | :upper                          # :downcase/:upcase resolved away

canonical_term :=
  # — scalar / nil / membership (routing :scalar or :array per field type) —
    {canonical_op, scalar_value}                           # cast scalar
  | {canonical_op, nil}                                    # nil check
  | {:in, [cast_value, ...]}                               # membership
  | {canonical_op, [cast_value, ...]}                      # list (==/!= → membership; array → overlap)

  # — string —
  | {:like | :ilike, pattern | [pattern, ...]}             # patterns pre-wrapped per §4-D5
  | {canonical_op, {case_op, value}}                       # lower/upper transform

  # — aggregate —
  | {agg_fn, {canonical_op, cast_value | nil}}

  # — quantified —
  | {canonical_op, {quantifier, qspec}}                    # qspec = subquery | list

  # — datetime / date —
  | {canonical_op, {dt_wrapper, {dt_op, [count: int, interval: bin, field: atom?]}}}

  # — arithmetic (computed field) —
  | {canonical_op, {:value, {arith_op, {{:field, atom}, {:value, cast_value}}}}}

  # — parent_as —
  | {canonical_op, {:parent_as, {binding_atom, field_atom}}}
  | {:parent_as, {binding_atom, field_atom}}               # bare, implies :==

  # — array-specific (routing :array) —
  | {:count, {canonical_op, integer}}
  | {quantifier, {canonical_op | :in, value | [value]}}

  # — map / JSONB (routing :map) —
  | {:contains | :contained_by, {key, value} | json_binary | json_list}
  | {:has_key, key}
  | {:has_any_key, [key, ...]}
  | {:has_all_keys, [key, ...]}

  # — common shorthand (routing :common) —
  | {:ids, [value]} | {:before|:after|:since|:until, value} | {:exists, query}
  | {:start_date|:end_date|:since_date|:until_date, timestamp}
```

**Invariants the resolver guarantees before a term reaches a dialect adapter:**
1. Every operator is canonical (no `:eq`, `:gt`, `:downcase`, …).
2. Every scalar/list value is already cast to the field's Ecto type.
3. `field` is a resolved atom; field-name strings have been converted/validated.
4. `:not` has been lifted into the `negated` slot exactly once.
5. `routing` is decided (scalar/array/map/common) — adapters do not re-infer it.
6. Wrapper sugar (`:arithmetic`, `:aggregate`, `:elements`, datetime wrappers,
   common shorthands like `:ids`/`:start_date`) has been expanded to the closed
   forms above, **and the shorthand's implicit field is resolved** (e.g. `:ids`
   carries `:id`, `:start_date` carries `:inserted_at`) so `CommonExpr` no longer
   hardcodes field names.

### 2.3 Resolver contract (dialect-agnostic)
A new module — working name `EctoShorts.QueryBuilder.TermResolver` (final name in
the plan) — owns all raw→canonical work. It contains **no SQL and no dialect
knowledge**; it depends only on Ecto type casting and schema reflection.

```elixir
@spec canonicalize(source, key :: atom, raw_term, opts) ::
        {:ok, %{field: atom, routing: routing, term: canonical_term, negated: :not | nil}}
      | :skip                       # field/op unresolvable; a warning was already emitted

# Supporting pure helpers (no SQL):
@spec canonical_op(raw_op) :: canonical_op
@spec resolve_field(source, name :: atom | binary, opts) :: {:ok, atom} | :skip
@spec routing_family(source, field :: atom, opts) :: routing
@spec cast(field_type, value) :: cast_value
```

- `canonicalize/4` is the only entry the fold calls per leaf. It returns `:skip`
  (after warning) for unknown fields / unsupported shapes, so the fold simply
  drops that leaf — preserving today's `warn + nil` (§4).
- Aliases live here (resolution of probe answer "alias home = in the dispatch
  reduce, above Expr" — the resolver IS that layer, sitting above the adapters).

### 2.4 Dialect adapter contract (`EctoShorts.DynamicBuilder`)
```elixir
@callback build_dynamic(routing, ExprInput) :: Ecto.Query.dynamic_expr() | nil
```
The Postgres adapter dispatches on `routing` to the matching **pure** Expr module
and applies `negated` once. Adapters receive only canonical input — they perform
no casting, aliasing, field resolution, or schema reflection.

### 2.5 Worked examples — every distinct shape

Each row shows the **public param** a caller writes (left), the **resolved
`ExprInput`** the resolver hands to the adapter (middle: `field` · `negated` ·
`term` · `routing`), and the **emitted SQL** (right). Examples use the `Post`
schema (`inventory/04` §6): `views :integer`, `title :string`,
`published :boolean`, `tags {:array,:string}`, `inserted_at/published_at
:utc_datetime`; `UserData.data :map`. SQL is shown in Ecto-fragment shorthand;
`^x` marks a bound parameter.

#### Scalar / nil / membership — `routing: :scalar`
| Public param | `field` · `negated` · `term` | Emitted SQL |
|---|---|---|
| `%{id: 1}` | `:id` · `nil` · `{:==, 1}` | `id == ^1` |
| `%{views: %{gt: 10}}` | `:views` · `nil` · `{:>, 10}` | `views > ^10` |
| `%{published_at: %{eq: nil}}` | `:published_at` · `nil` · `{:==, nil}` | `is_nil(published_at)` |
| `%{published_at: %{ne: nil}}` | `:published_at` · `nil` · `{:!=, nil}` | `not is_nil(published_at)` |
| `%{published: %{in: [true, false]}}` | `:published` · `nil` · `{:in, [true, false]}` | `published in ^[true, false]` |
| `%{published: [true, false]}` | `:published` · `nil` · `{:==, [true, false]}` | `published in ^[true, false]` *(list rewrite)* |
| `%{published: %{ne: [true]}}` | `:published` · `nil` · `{:!=, [true]}` | `is_nil(published) or published not in ^[true]` *(D-NEQ-LIST)* |

#### String match & transform — `routing: :scalar`
| Public param | `field` · `negated` · `term` | Emitted SQL |
|---|---|---|
| `%{title: %{like: "hello"}}` | `:title` · `nil` · `{:like, "%hello%"}` | `like(title, ^"%hello%")` *(auto-wrap, D-LIKE-WRAP)* |
| `%{title: %{like: "hello%"}}` | `:title` · `nil` · `{:like, "hello%"}` | `like(title, ^"hello%")` *(preserved)* |
| `%{title: %{ilike: ["a", "b"]}}` | `:title` · `nil` · `{:ilike, ["%a%", "%b%"]}` | `fragment("? ILIKE ANY(?)", title, ^[...])` |
| `%{title: %{eq: %{downcase: "HELLO"}}}` | `:title` · `nil` · `{:==, {:lower, "HELLO"}}` | `lower(title) == ^"HELLO"` *(`:downcase`→`:lower`)* |

#### Aggregate — `routing: :scalar`
| Public param | `field` · `negated` · `term` | Emitted SQL |
|---|---|---|
| `%{views: %{avg: %{gt: 10}}}` | `:views` · `nil` · `{:avg, {:>, 10}}` | `avg(views) > ^10` |
| `%{views: %{aggregate: %{fn: :sum, compare: :==, value: 1000}}}` | `:views` · `nil` · `{:sum, {:==, 1000}}` | `sum(views) == ^1000` |

#### Quantified subquery — `routing: :scalar`
| Public param | `field` · `negated` · `term` | Emitted SQL |
|---|---|---|
| `%{id: %{eq: %{all: %{from: Comment, where: %{published: true}}}}}` | `:id` · `nil` · `{:==, {:all, «subquery»}}` | `id == all(SELECT ... FROM comments WHERE published = ^true)` |

#### Datetime / date wrappers — `routing: :scalar`
| Public param | `field` · `negated` · `term` | Emitted SQL |
|---|---|---|
| `%{inserted_at: %{eq: %{ago: {1, :day}}}}` | `:inserted_at` · `nil` · `{:==, {:datetime, {:ago, [count: 1, interval: "day"]}}}` | `inserted_at == ago(^1, "day")` |
| `%{published_at: %{gte: %{from_now: {1, :day}}}}` | `:published_at` · `nil` · `{:>=, {:datetime, {:from_now, [count: 1, interval: "day"]}}}` | `published_at >= from_now(^1, "day")` |
| `%{inserted_at: %{gte: %{date: %{add: %{count: 7, interval: "day"}}}}}` | `:inserted_at` · `nil` · `{:>=, {:date, {:add, [count: 7, interval: "day"]}}}` | `date(inserted_at) >= date(...)` |

#### Arithmetic (computed field) & parent_as — `routing: :scalar`
| Public param | `field` · `negated` · `term` | Emitted SQL |
|---|---|---|
| `%{views: %{arithmetic: %{compare: :>, add: %{field: :id, value: 5}}}}` | `:views` · `nil` · `{:>, {:value, {:+, {{:field, :id}, {:value, 5}}}}}` | `views > (id + ^5)` |
| `%{post_id: %{parent_as: %{post: :id}}}` | `:post_id` · `nil` · `{:parent_as, {:post, :id}}` | `post_id == field(parent_as(:post), :id)` |

#### Array — `routing: :array` (schema-backed `tags`, or schemaless via `:elements`/`:field_types`)
| Public param | `field` · `negated` · `term` | Emitted SQL |
|---|---|---|
| `%{tags: %{in: ["a", "b"]}}` *(schema array field)* | `:tags` · `nil` · `{:in, ["a", "b"]}` | `fragment("? && ?", tags, ^["a","b"])` *(overlap)* |
| `%{tags: %{elements: %{in: ["a", "b"]}}}` *(schemaless)* | `:tags` · `nil` · `{:in, ["a", "b"]}` | `fragment("? && ?", tags, ^["a","b"])` |
| `%{tags: "elixir"}` *(with `field_types: [tags: {:array, :string}]`)* | `:tags` · `nil` · `{:==, "elixir"}` | `^"elixir" in tags` *(membership)* |
| `%{tags: %{elements: %{count: %{gt: 3}}}}` | `:tags` · `nil` · `{:count, {:>, 3}}` | `array_length(tags, 1) > ^3` |
| `%{tags: %{elements: %{all: %{in: ["a"]}}}}` | `:tags` · `nil` · `{:all, {:in, ["a"]}}` | `fragment("? <@ ?", tags, ^["a"])` *(subset)* |

#### Map / JSONB — `routing: :map` (`data :map`, or `:field_types`)
| Public param | `field` · `negated` · `term` | Emitted SQL |
|---|---|---|
| `%{data: %{contains: %{role: "admin"}}}` | `:data` · `nil` · `{:contains, {:role, "admin"}}` | `fragment("? @> ?::jsonb", data, ^%{role: "admin"})` |
| `%{data: %{contained_by: %{role: "admin"}}}` | `:data` · `nil` · `{:contained_by, {:role, "admin"}}` | `fragment("? <@ ?::jsonb", data, ^%{role: "admin"})` |
| `%{data: %{has_key: "role"}}` | `:data` · `nil` · `{:has_key, "role"}` | `fragment("jsonb_exists(?, ?)", data, ^"role")` |
| `%{data: %{has_any_key: ["a", "b"]}}` | `:data` · `nil` · `{:has_any_key, ["a", "b"]}` | `fragment("jsonb_exists_any(?, ?)", data, ^["a","b"])` |

#### Common shorthand — `routing: :common` (field resolved by resolver, §3.6 / D-CommonExpr-FIELD)
| Public param | `field` · `negated` · `term` | Emitted SQL |
|---|---|---|
| `%{ids: [1, 2, 3]}` | `:id` · `nil` · `{:ids, [1, 2, 3]}` | `id in ^[1, 2, 3]` |
| `%{before: 100}` | `:id` · `nil` · `{:before, 100}` | `id < ^100` |
| `%{after: 100}` | `:id` · `nil` · `{:after, 100}` | `id > ^100` |
| `%{start_date: ts}` | `:inserted_at` · `nil` · `{:start_date, ts}` | `inserted_at >= ^ts` |
| `%{end_date: ts}` | `:inserted_at` · `nil` · `{:end_date, ts}` | `inserted_at <= ^ts` |
| `%{exists: «subquery»}` | *(no field)* · `nil` · `{:exists, «subquery»}` | `exists(subquery)` |

#### Negation — applies to any shape above (`negated` slot)
| Public param | `field` · `negated` · `term` | Emitted SQL |
|---|---|---|
| `%{views: %{not: %{eq: 10}}}` | `:views` · `:not` · `{:==, 10}` | `not (views == ^10)` |
| `%{published: %{not: %{in: [true]}}}` | `:published` · `:not` · `{:in, [true]}` | `is_nil(published) or published not in ^[true]` |
| `%{published_at: %{not: %{eq: nil}}}` | `:published_at` · `:not` · `{:==, nil}` | `not is_nil(published_at)` |

> **Reading note:** the middle column is the post-resolution shape — operators
> canonical, values cast, field an atom, `:not` lifted out. The left column is
> what callers actually write (with aliases like `eq`/`gt`/`downcase` still
> present). The resolver (§2.3) is the only thing that turns left into middle.

---

## 3. BEHAVIOR ACROSS BOUNDARIES

### 3.1 Boundary map (target)
```
convert_params_to_filter/3
  │  coerce source → Ecto.Query        (CommonSchema.to_query/1)
  │  sort params                       (§3.2 — single-pass reduce)
  ▼
reduce_filters  (one fold over sorted entries)         ── EctoShorts.CommonFilters
  ├─ binding selectors :as/:at         → resolve binding, recurse
  ├─ structural keys (§1.4)            → Builder → filter sub-modules   (UNCHANGED behavior)
  ├─ assoc shorthand                   → implicit join + recurse
  ├─ :and/:or grouping                 → recurse with same/or filter type
  └─ predicate leaves (:where/:or_where/field/:having/:or_having)
        │  for each {key, raw_term}:
        ▼
     TermResolver.canonicalize/4   ── DIALECT-AGNOSTIC (§2.3)
        │   {:ok, %{field, routing, term, negated}}  |  :skip(+warn)
        ▼
     DynamicBuilder.build_dynamic/2  (dialect adapter, §2.4)
        ▼
     ScalarExpr | ArrayExpr | MapExpr | CommonExpr   ── PURE (emit dynamic only)
        │
        ▼  merge_dynamic into accumulator (:and / :or) → where/or_where on query
```

### 3.2 `sort_filter_params/1` — single-pass reduce (D2)
**Behavior (unchanged):** reorder entries to evaluation order
`:where → others → :or_where → terminal(:last, :subquery)`.
**Change:** replace the four `Enum.filter` scans with one `Enum.reduce` that
classifies each entry into four accumulators, then concatenates. Output order is
**identical** to today (verified against `inventory/01` §2 example).

### 3.3 Field-name resolution (moves into TermResolver, §2.3)
Behavior preserved from `field_name_to_atom/3` (`inventory/02` §7), restated as a
flat contract (no nested defensive conditionals):
| Case | Result |
|---|---|
| already an atom | passthrough |
| string, schema present, field in schema | `String.to_existing_atom/1` |
| string, schema present, field absent | `:skip` + warn "does not exist on schema" |
| string, no schema, in `:allowed_keys` | `String.to_atom/1` |
| string, no schema, not in `:allowed_keys` | `:skip` + warn "not in :allowed_keys" |
| string, no schema, no `:allowed_keys` | `:skip` + warn "no schema or :allowed_keys" |

### 3.4 Field-type routing (moves into TermResolver, §2.3)
Preserved from `dispatch_field_expr/dispatch_field_type` (`inventory/02` §4, §14):
priority `opts[:field_types]` → schema reflection. `{:array, _}`→`:array`;
`:map`/`{:map,_}`→`:map`; common-shorthand keys→`:common`; else `:scalar`.
Invalid schema field → `:skip` + warn (preserved).

### 3.5 Casting (moves into TermResolver, §2.3) — concern split (D5)
Today `cast_value/2` (18 overloads) **both** casts values **and** unwraps
operators/aliases. Split into two pure responsibilities:
- `canonical_op/1` — alias resolution only.
- `cast/2` — `Types.cast` against the (possibly `{:array, inner}`) field type
  only; recurses into list elements and into operand positions of canonical terms
  **without** itself rewriting operators.
Observable casting behavior (array element casting, integer cast of `:count`,
inner-type cast of `:all`/`:in`, enum casting) is preserved exactly
(`inventory/02` §5, `inventory/04` §2 enum/typed-casting rows).

### 3.6 Expr-module purity (B1/B2) — what is removed
| Module | Current violation (`inventory/03` §Purity) | Target |
|---|---|---|
| `CommonExpr` | hardcodes `:id`, `:inserted_at` | field arrives resolved in `ExprInput.field` (resolver expands shorthand→field) |
| `ScalarExpr` | `Keyword.get(params, :field)` / `Keyword.fetch!` for datetime/arith field & count/interval | resolver pre-extracts these into the canonical term's keyword payload; ScalarExpr reads positionally from the closed shape, never fetches/falls back |
| `ArrayExpr`, `MapExpr` | none | unchanged (already pure) |

After refactor, the four Expr modules contain **zero** calls to `Types.cast`,
`String.to_*atom`, `op_alias`, `CommonSchema.*`, or hardcoded field literals.
(This is a mechanical verification gate — see §5.)

### 3.7 `comparison_impl` decomposition (D1)
Split the ~370-line `comparison_impl` into per-family private dispatchers —
`scalar_comparison`, `quantified_comparison`, `aggregate_comparison`,
`datetime_comparison`, `arithmetic_comparison`, `parent_as_comparison`,
`nil_comparison` — selected by matching the closed canonical shapes in §2.2.
Collapse the leaf code-generators (`apply_scalar_comparison`,
`apply_parent_as_comparison`, `apply_arith_comparison`, `apply_dyn_comparison`,
the 42 overloads) into a single matrix:
```elixir
@spec apply_comparison(canonical_op, lhs_dyn, rhs_dyn, :plain | :negated) :: dynamic
```
The emitted SQL for every `(op, negated)` pair is preserved exactly per
`inventory/03` §ScalarExpr tables.

### 3.8 Structural filters (UNCHANGED)
All non-predicate keys (`:join`, `:order_by`, `:select`, `:with_cte`, set ops,
pagination, etc.) keep their current modules and behavior verbatim, including
their warn/nil cases (`inventory/01` §7, §9). The reduce in §3.1 routes to them
exactly as today. They are in scope only insofar as they call the shared field
resolver (§3.3) — their public behavior does not change.

---

## 4. BEHAVIOR DECISIONS (resolving contested behavior — T2)

**Parity baseline (T2 ruling):** parity is measured against **this spec**, not
against current code and not against current tests. Where a decision below says
*Keep*, current behavior is the contract. Where it says *Change*, the spec
overrides code and tests, and the test audit (§5) updates the test.

| ID | Behavior (current) | Ruling | Rationale |
|---|---|---|---|
| D-WARN | Unsupported field/op combos & invalid fields → `Logger.warning` + skip (query unchanged). 37+ cases in `inventory/04` §3. | **Keep** | Probe E1. Pure structural refactor; `:skip` from `TermResolver` reproduces it. |
| D-API | Public param language & opts (§1). | **Keep / frozen** | Probe E2 — zero public breaks. |
| D-INTERNAL | Module names, arities, sub-module boundaries (`build_dynamic`, `apply_expr`, `dispatch_expr`, `cast_value`, `field_name_to_atom`). | **Change freely** | Probe E2 — internal-only breaks allowed. These names need not survive. |
| D1 | `comparison_impl` 370-line monolith; 42 `apply_*` generators. | **Change (decompose)** | §3.7. Output SQL identical. |
| D-NEQ-LIST | `{field: {!=: [a,b]}}` → `is_nil(field) OR field NOT IN [a,b]` (`inventory/04` audit). | **Keep, document** | NULL-inclusion is deliberate SQL semantics; document it in moduledocs, do not change. |
| D-LIKE-WRAP | `{like: "x"}`→`"%x%"` but `"x%"` preserved (heuristic). | **Keep, document** | Public behavior; freeze and document the heuristic in §1.5. |
| D-ELEMENTS | Schemaless arrays need `:elements`; `:field_types` makes it unnecessary (audit MEDIUM). | **Keep** | Documented gotcha in CLAUDE.md; out of scope for a behavior change here. |
| D-PROVIDER | Lock/join provider contracts loosely validated. | **Keep** | Out of scope; structural refactor only. Flag for a later effort. |
| D-CommonExpr-FIELD | `CommonExpr` hardcodes `:id`/`:inserted_at`. | **Change (internal)** | §3.6 — field resolved upstream; observable SQL unchanged (still targets `id`/`inserted_at` for those shorthands). |

**Open items requiring confirmation during design (not blocking the spec):**
- The remaining audit candidates in `inventory/04` §5 (LOW severity) are **Keep +
  document** by default; any that should *change* must be raised in the test
  audit (§5) and added to this table before implementation.

---

## 5. VERIFICATION STRATEGY (defines "done")

Per probe G1/G4/G5 — tests are **not** the contract; this spec is.

1. **Spec approval** (this document) — gate 1.
2. **Test audit (case-by-case, G4):** walk every test in
   `test/ecto_shorts/common_filters/` and
   `test/ecto_shorts/common_filters_schemaless/` against §1–§4. For each test:
   - **Agrees with spec** → keep.
   - **Disagrees** → the test is presumed wrong; resolve interactively, record the
     decision as a new row in §4, then update the test. No blanket auto-rewrite.
   - Produce `autoresearch/probe-260619-0650/test-audit.md` (per-test verdict).
3. **Mechanical purity gates** (must hold post-refactor):
   ```
   # Expr modules contain no casting/aliasing/resolution/reflection/hardcoded fields:
   grep -nE "Types\.cast|to_existing_atom|to_atom|op_alias|CommonSchema|:inserted_at|:id\b" \
     lib/ecto_shorts/dynamic_builders/postgres/{scalar,array,map,common}_expr.ex   # → empty
   # sort_filter_params uses a single reduce (no 4× Enum.filter):
   ```
4. **Behavioral gates:** `mix test` (post-audit suite) · `mix credo` ·
   `mix dialyzer` all green.
5. **Implementation** is delegated to `claude-copilot:code-implementer` per
   `RULES.md`, against the approved spec + plan.

---

## 6. TARGET MODULE INVENTORY (deltas only)

| Module | Change |
|---|---|
| `EctoShorts.CommonFilters` | `sort_filter_params` → single-pass reduce; `reduce_filters` stays a fold; predicate leaves route through `TermResolver` then the dialect adapter. Public API unchanged. |
| `EctoShorts.QueryBuilder.TermResolver` *(new, dialect-agnostic)* | Owns `canonicalize/4`, `canonical_op/1`, `resolve_field/3`, `routing_family/3`, `cast/2`. Absorbs the raw→canonical logic currently in `Postgres.{build_dynamic,apply_expr,dispatch_expr,cast_value,build_rhs_entry,field_name_to_atom}`. |
| `EctoShorts.DynamicBuilders.Postgres` | Reduced to a thin dialect adapter implementing `build_dynamic/2` over canonical `ExprInput`; dispatches by `routing` to the pure Expr modules and applies negation. No normalization. |
| `EctoShorts.DynamicBuilders.Postgres.ScalarExpr` | Pure. `comparison_impl` decomposed (§3.7); `apply_*` collapsed to one matrix; datetime/arith field & count/interval read from the closed canonical payload (no `Keyword.fetch!`). |
| `…ArrayExpr`, `…MapExpr` | Pure already; receive canonical terms only. |
| `…CommonExpr` | Pure; field arrives via `ExprInput.field` (no hardcoded `:id`/`:inserted_at`). |
| Structural filter sub-modules | Unchanged except shared field resolution via §3.3. |

---

## 7. Out-of-scope follow-ups (logged, not done here)
- Error-policy redesign (fail-fast vs warn+nil) — D-WARN keeps current behavior.
- Provider-contract hardening (D-PROVIDER).
- Coverage gaps in `inventory/04` §4 (limit, recursive-CTE depth, arithmetic
  nesting, association-`through:`).
```
