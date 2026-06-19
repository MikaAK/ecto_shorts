# EctoShorts v3.0.0 Public API Cleanup — Design

**Date:** 2026-06-19
**Branch:** v3.0.0 (unreleased)
**Status:** Approved design, pending implementation plan

## Goal

Tighten the v3.0.0 public API before release. Because v3.0.0 is unreleased, every
rename is a **hard rename** (old name removed, no deprecation shim). The work is
grouped into four themes, A–D. Each change includes a CHANGELOG entry under the
existing v3.0.0 "Breaking changes" section.

## Guiding decisions (locked)

1. **Adapter option keys:** runtime opts are bare (`:dynamic_builder`,
   `:query_builder`, `:query_provider`); app-config keys keep the `_module`
   suffix (`:dynamic_builder_module`, `:query_builder_module`,
   `:query_provider_module`). This generalizes the existing `:dynamic_builder`
   runtime / `:dynamic_builder_module` config precedent to all three extension
   points.
2. **`delete`:** the id-based form is always 3-arity `delete(queryable, id, opts)`.
   That frees `delete(struct_or_changeset, opts)` to be the unambiguous `delete/2`.
3. **Config accessors:** bare names that mirror the config key exactly
   (`repo/0`↔`:repo`, `query_builder_module/0`↔`:query_builder_module`). Names are
   already correct; only the missing bang variants are added.
4. **Filter vocabulary:** aggressive — dedup date shorthands, rename `:elements`,
   drop the `:first` alias, and collapse the set-op and ordering key families.

---

## Theme A — Confirmed bugs & doc drift

### A1. `query_builders.ex` option-name bug
Runtime resolution reads `opts[:query_builder_module]` (`lib/ecto_shorts/query_builders.ex:74`)
but the moduledoc (line 18) and the `ArgumentError` message (line 69) say
`:query_builder`. Per decision 1 the **runtime opt becomes `:query_builder`**, so:

- Change `adapter/1` to read `opts[:query_builder]` (falling back to
  `Config.query_builder_module()` then the default adapter).
- Update moduledoc and error message to `:query_builder`.

**Before**

```elixir
opts[:query_builder_module] || Config.query_builder_module() || @default_adapter
```

**After**

```elixir
opts[:query_builder] || Config.query_builder_module() || @default_adapter
```

### A2. Adapter option-key convention
Apply decision 1 everywhere a runtime override is read or documented:

| Extension point | Runtime opt (before) | Runtime opt (after) | Config key (unchanged) |
|---|---|---|---|
| DynamicBuilder | `:dynamic_builder` | `:dynamic_builder` (already correct) | `:dynamic_builder_module` |
| QueryBuilder | `:query_builder_module` | `:query_builder` | `:query_builder_module` |
| QueryProvider | (n/a / inconsistent) | `:query_provider` | `:query_provider_module` |

Audit all of `lib/` and the moduledocs/`CLAUDE.md` for the old runtime spellings.

### A3. Stale `:aggregate` wrapper in CLAUDE.md
The `:aggregate` wrapper was removed in commit `757a16d` ("feat(aggregate): one
spelling; remove the :aggregate wrapper"). CLAUDE.md still documents it in the
"Operator wrappers" table. Remove that row and re-verify the remaining two
wrappers (`:arithmetic`, `:elements`/renamed) against current code. Sweep CLAUDE.md
for any other drift uncovered during implementation.

---

## Theme B — Actions arity ambiguity

### B1. Remove ambiguous `delete/2`
Today both `delete(data, opts)` and `delete(queryable, id)` match arity-2 and are
separated only by runtime type guards in `EctoShorts.Actions.CRUD`.

- Remove the `delete(queryable, id) when is_binary(id) or is_integer(id)` clause.
- The id form is **only** `delete(queryable, id, opts)` (3-arity).
- `delete/2` becomes unambiguously `delete(struct_or_changeset_or_list, opts)`.

**Public arities after:** `delete/1` (struct | changeset | list),
`delete/2` (same + opts), `delete/3` (queryable, id, opts).

### B2. Positional defaults → opts keyword
Move trailing positional, type-guard-dispatched defaults into `opts`:

**Before**

```elixir
batch(schema, params, batch_keys \\ :id, cardinality \\ :many, opts \\ [])
aggregate(queryable, params \\ %{}, aggregate \\ :count, key \\ :id, opts \\ [])
```

**After**

```elixir
batch(schema, params, opts \\ [])
#   opts: batch_keys: :id | [atom] (default :id), cardinality: :one | :many (default :many)
aggregate(queryable, params \\ %{}, opts \\ [])
#   opts: aggregate: :count | :sum | :avg | :min | :max (default :count), key: atom (default :id)
```

`batch_find/4` callers and internal `Batch`/`Bulk` modules that call `batch/5`
positionally must be updated to the opts form.

### B3. `all/2` keyword shorthand
`all(queryable, params_or_opts)` currently accepts a keyword list and splits it
into filter-params vs runtime-opts, conflating the two. Drop the keyword-list
branch; `all/2` accepts a **params map** only. Runtime opts go through `all/3`.
The same mixed-extraction pattern in `find/3`/`all/3` for `:order_by`/`:group_by`
(pulled from `opts` into `params`) is documented as intentional and left as-is
unless implementation shows it is load-bearing for the keyword branch.

---

## Theme C — Naming consistency

### C1. Config bang variants
Bare accessor names already match config keys. Add `!`/raising variants for the
module accessors that can be required but currently lack them:

- Existing: `repo!/1`, `replica!/1`.
- Add: `error_module!/0..1`, `dynamic_builder_module!/0..1`,
  `query_builder_module!/0..1`, `query_provider_module!/0..1` — each raising a
  clear error when the value is `nil`.

No renames to `repo/0`, `replica/0`, or the `*_module/0` accessors.

### C2. CommonChanges value-vs-change predicate pairs
The "current value" predicates and the "pending change" predicates are not
distinguishable by name. Rename to a short, parallel scheme:

| Before | After | Meaning |
|---|---|---|
| `changeset_field_nil?/2` | `field_nil?/2` | current value (data ∪ changes) is nil |
| `changeset_field_empty?/2` | `field_empty?/2` | current value is `[]`/`%{}` |
| `has_nil_change?/2` | `change_nil?/2` | no pending change for field |
| `has_empty_change?/2` | `change_empty?/2` | pending change is `[]`/`%{}` |

Mutation pair stays semantically split but is documented together:
`put_new_change/3` (no pending change) vs `put_new_value/3` (current value nil) —
names retained; docstrings cross-reference each other.

`preload_change_assoc/3` (public) vs `preload_changeset_assoc/3` (low-level): mark
the low-level one `@doc false` (or rename to signal "data-only") so the primary
entry point reads as primary. Final call deferred to implementation after reading
both bodies.

### C3. SchemaHelpers
Rename `any_created?/1` → `any_persisted?/1` to fit the `*_schema_struct?` family
and Ecto's persisted-record idiom. Update internal callers (notably CommonChanges).

---

## Theme D — Filter vocabulary (aggressive)

All changes are to the param vocabulary accepted by
`CommonFilters.convert_params_to_filter/3`.

### D1. Dedup date shorthands
`:start_date`≡`:since_date` (both `inserted_at >= value`) and `:end_date`≡`:until_date`
(both `inserted_at <= value`), field hardcoded to `:inserted_at`
(`common_expr.ex:77-85`, `predicate_builder.ex:167-169`). Keep `:since_date` /
`:until_date` (parallel to cursor `:since`/`:until`); remove `:start_date` /
`:end_date`.

### D2. Rename `:elements` → `:array`
`:elements` forces array routing for sources without type info
(`predicate_builder.ex:206-210`). `:array` reads as intent. (Note: `:field_types`
opt is an alternative path and is unaffected.) Update the CLAUDE.md wrapper table,
the schemaless gotcha note, and `FilterContract` cases.

### D3. Drop `:first` alias
`:first` routes into the `:limit` builder (`builder.ex:161-163`). Remove it; `:limit`
is the single spelling.

### D4. Collapse set operations
Replace the six keys `:union`, `:union_all`, `:except`, `:except_all`,
`:intersect`, `:intersect_all` (`builder.ex:125-147`) with a single parameterized
key:

**Before**

```elixir
%{union_all: query}
%{except: query}
```

**After**

```elixir
%{set_op: {:union, :all, query}}      # mode: :all | :distinct
%{set_op: {:except, :distinct, query}}
```

Exact tuple/map shape finalized in the plan; the six dedicated builder modules
(`Union`, `UnionAll`, …) collapse behind one `SetOperation` dispatch (a
`SetOperation` module already exists per the v3 changelog — reuse it).

### D5. Collapse ordering keys
Replace `:order_by` / `:prepend_order_by` / `:reverse_order` with `:order_by`
carrying a mode:

**Before**

```elixir
%{order_by: :inserted_at}
%{prepend_order_by: :id}
%{reverse_order: true}
```

**After**

```elixir
%{order_by: :inserted_at}                       # default mode :replace
%{order_by: %{mode: :prepend, by: :id}}
%{order_by: %{mode: :reverse}}
```

`:append` becomes expressible (it was a noted asymmetry — no `:append_order_by`
existed). Plain `:order_by` value keeps its current shorthand meaning (replace).

---

## Out of scope (candidate follow-up specs)

- Find/Multi family consolidation (`find_and_create` vs `find_or_create`,
  `find_or_create_many` vs `find_and_upsert_many`) — semantic, needs its own design.
- Bulk return-shape alignment (`update_all`/`delete_all` return raw `{count, nil}`
  vs `insert_all`'s `{:ok, {count, nil}}`).
- Predicate/Filter/Condition terminology rename of internal modules.

## Testing strategy

- Per CLAUDE.md, tests mirror `lib/` path-for-path. Each renamed/removed key or
  function updates its mirrored test file.
- Filter-vocab changes (Theme D) update `test/support/filter_contract.ex` cases and
  the per-adapter contract walk.
- Invalid-field tests keep the `capture_log` wrapper convention.
- Run `mix test`, `mix credo`, `mix dialyzer` clean before completion.
- Verify the work against every rule in RULES.md as a checklist item.

## Risk notes

- Theme D has the largest blast radius (core query language). D4/D5 change call
  shapes many downstream users rely on; the CHANGELOG migration notes must show
  before/after for each.
- Theme B `batch`/`aggregate` opts move requires finding all internal positional
  callers — dialyzer + tests are the safety net.
