# Remove orphaned `build_dynamic/4` term API and fix stale docs

Date: 2026-06-19

## Problem

The v3.0.0 refactor (commit `4615e68`, "adapter is now thin") moved
term→predicate resolution into `EctoShorts.CommonFilters.PredicateBuilder`. The
live path is now:

    CommonFilters → PredicateBuilder → %Predicate{} → DynamicBuilders.build_dynamic/3

That refactor left a cluster of orphaned artifacts referencing the old
term-based `build_dynamic/4` entry, which no longer has any caller and is broken
(it calls `adapter.build_dynamic/4`, a callback no adapter implements).

## Inventory

| # | Artifact | State |
|---|---|---|
| 1 | `DynamicBuilders.build_dynamic/4` (term form, `dynamic_builders.ex:106`) | Dead + broken — no callers; calls a nonexistent adapter `/4` callback |
| 2 | `DynamicBuilders` moduledoc doctests (`:95`, `:98`) | Use the broken `/4` term form with a nonexistent `MyApp.Repo` |
| 3 | `Postgres` moduledoc (`postgres.ex:1–45`) | Claims `build_dynamic/4` is "the only public entry point"; module implements `/3` (predicate) |
| 4 | `DynamicBuilder` behaviour moduledoc (`dynamic_builder.ex:33`) | "Implement a custom adapter" example shows old `/4 {key, term}` signature, contradicting its own v3.0.0 note |
| 5 | `dynamic_builder.ex:21, 41` | Stale config key: `Config.dynamic_builder/0` / `config :ecto_shorts, dynamic_builder:` (real key is `:dynamic_builder_module`) |
| 6 | `test/support/test_payload_probe_adapter.ex`, `test_dynamic_expression_adapter.ex` | Dead — unreferenced; both use the old `/4` signature |

## Decision

Delete it all. The term path is fully replaced by `PredicateBuilder` + `/3`.
This is a pre-3.0.0-release branch, the `/4` entry has zero callers, and it is
already broken, so removal cannot break a working caller.

## Changes (5 files, no behavior change to the live `/3` path)

### Deletions
1. `lib/ecto_shorts/dynamic_builders.ex` — remove the `build_dynamic/4` term
   clause, its `@doc`, and doctests. Keep `build_dynamic/3` (predicate form).
   Remove the `build_dynamic/4` cross-reference in the `/3` doc.
2. `test/support/test_payload_probe_adapter.ex` — delete.
3. `test/support/test_dynamic_expression_adapter.ex` — delete.

### Doc fixes (point at the real `/3` predicate entry)
4. `lib/ecto_shorts/dynamic_builders/postgres.ex` moduledoc — document
   `build_dynamic/3` as the entry: consumes a resolved
   `%EctoShorts.CommonFilters.Predicate{}` + binding selector + opts, returns a
   `DynamicExpr` or `nil`. Replace the two `/4` examples with `/3` predicate
   examples (placeholder output, matching existing style; not run as doctests —
   there is no `doctest EctoShorts.DynamicBuilders.Postgres`).
5. `lib/ecto_shorts/dynamic_builder.ex` moduledoc — fix the custom-adapter
   example to the `/3` predicate signature; fix `Config.dynamic_builder/0` →
   `dynamic_builder_module/0` and `config :ecto_shorts, dynamic_builder:` →
   `:dynamic_builder_module`.

## Verification

- `grep -rn "build_dynamic" lib test` shows no remaining `/4` callers, defs, or
  doc references.
- `mix test` — full suite green (1440 tests).
- `mix credo` — no new issues.
