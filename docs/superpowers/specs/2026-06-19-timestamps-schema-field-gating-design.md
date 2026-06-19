# Gate timestamp insertion on schema field presence

**Date:** 2026-06-19
**Module:** `EctoShorts.CommonParams.Timestamps` (`lib/ecto_shorts/common_params/timestamps.ex`)
**Origin:** PR review comment (P1) on line 66.

## Problem

`Timestamps.put_timestamps/4` and `put_set_updated_at/4` unconditionally add
`:inserted_at` / `:updated_at` (or their configured source fields) to the
prepared insert/update data. When the target is a schema-backed source whose
schema does **not** define that field, `Repo.insert_all/3` and
`Repo.update_all/3` raise an unknown-field error for an otherwise valid schema.

### State change

Schema-backed source whose schema has **no** `:inserted_at` field, default opts:

```
before:  Map.put(input, :inserted_at, ~U[...])  -> insert_all raises (unknown field :inserted_at)
after:   input unchanged                         -> insert_all succeeds
```

The same defect exists on three paths:

1. `inserted_at` on insert — `maybe_put_inserted_at/4` (`else` branch, line 66).
2. `updated_at` on insert — `put_timestamp_updated_at/4`.
3. `updated_at` on update (`:set` group) — `put_set_updated_at/4`.

## Design

A timestamp field is added only when there is positive reason to believe the
target accepts it. Three cases, evaluated in priority order:

| Case | Condition | Behavior |
|---|---|---|
| Schemaless | `schema == nil` | Add (current behavior — no schema to introspect; caller owns the source) |
| Explicit intent | a `*_at` value **or** a `*_source` key is present in `opts` for that field | Add (user override wins, even when the field is absent from the schema) |
| Schema-backed default | otherwise | Add **only if** the resolved source field is in `schema.__schema__(:fields)` |

"Explicit intent" is resolved per field:

- inserted_at: `Keyword.has_key?(opts, :inserted_at) or Keyword.has_key?(opts, :inserted_at_source)`
- updated_at: `Keyword.has_key?(opts, :updated_at) or Keyword.has_key?(opts, :updated_at_source)`

The existing short-circuits are preserved and continue to take precedence:
`source_key === false` and (for updated_at) `value === false` still skip the
field outright.

### Shared helper

```elixir
defp include_timestamp?(nil, _source_key, _explicit?), do: true
defp include_timestamp?(_schema, _source_key, true), do: true
defp include_timestamp?(schema, source_key, false), do: source_key in schema.__schema__(:fields)
```

Each of the three entry paths computes `explicit?` for its field and returns
the input unchanged when `include_timestamp?/3` is false.

### Accepted consequence

Because explicit opts force inclusion and the schema gate applies only to the
default case, a typo'd explicit source on a schema-backed source (e.g.
`inserted_at_source: :creatd_on`) is silently dropped by `insert_all` rather
than raising. This is the direct, intended consequence of "explicit opt forces
inclusion" and is accepted; no warning is emitted.

## Testing

New file `test/ecto_shorts/common_params/timestamps_test.exs` (mirrors lib
path). Calls `Timestamps` functions directly on plain maps — no DB required,
since only `__schema__/1` introspection is exercised.

New support schema (timestamp-free) under `test/support/schema/` — every
existing test schema declares `timestamps()`, so none can express the
defect. The new schema has a primary key and ordinary fields but no
`timestamps()` call.

Cases, repeated across `inserted_at` (insert), `updated_at` (insert), and
`updated_at` (update `:set`):

- **(a) schema lacks field + default opts** → timestamp key absent from output.
- **(b) schema lacks field + explicit value** → timestamp key present.
- **(c) schema lacks field + explicit custom source** → custom source key present.
- **(d) schema defines field + default opts** → timestamp key present (regression guard).
- **(e) schemaless (`schema == nil`)** → timestamp key present (regression guard).

## Out of scope

- No change to timestamp type resolution, casting, or truncation.
- No change to `CommonParams` call sites — `schema` is already threaded through.
- No warning/telemetry for dropped explicit sources.
