# Relax `adapter_for_repo!/1` — warn-and-default instead of raising on unknown adapters

Date: 2026-06-19

## Problem

`EctoShorts.DynamicBuilders.adapter_for_repo!/1` raises at runtime whenever the
repo's database adapter is anything other than `Ecto.Adapters.Postgres`. End
users on other databases hit a hard exception instead of a recoverable path,
even though the library already supports custom dynamic builders via config and
call-time options.

## Goal

When the dynamic adapter cannot be resolved from a known database adapter,
emit a warning and fall back to `EctoShorts.DynamicBuilders.Postgres` rather
than raising. Keep the existing "repo not configured" error intact.

## Scope

- `EctoShorts.DynamicBuilders.adapter_for_repo!/1`
  (`lib/ecto_shorts/dynamic_builders.ex`) and its surrounding moduledoc.
- No changes to `Config.repo!/1` or any other caller.

## Behavior

Resolution order is unchanged: `:dynamic_builder` opt → `:dynamic_builder_module`
config → repo adapter inference. Only the repo-inference branch changes.

### Before

```elixir
case repo.__adapter__() do
  Ecto.Adapters.Postgres -> EctoShorts.DynamicBuilders.Postgres
  Ecto.Adapters.MyXQL    -> raise "Adapter not yet implemented: Ecto.Adapters.MyXQL"
  Ecto.Adapters.SQL      -> raise "Adapter not yet implemented: Ecto.Adapters.SQL"
  Ecto.Adapters.Tds      -> raise "Adapter not yet implemented: Ecto.Adapters.SQL"
  adapter                -> raise "The adapter #{inspect(adapter)} is not supported..."
end
```

### After

```elixir
case repo.__adapter__() do
  Ecto.Adapters.Postgres ->
    EctoShorts.DynamicBuilders.Postgres

  adapter ->
    Logger.warning("""
    EctoShorts has no built-in dynamic builder for #{inspect(adapter)}; \
    defaulting to EctoShorts.DynamicBuilders.Postgres, which may generate \
    invalid SQL for this database. Configure a dialect-specific builder via \
    `config :ecto_shorts, dynamic_builder_module: MyApp.DynamicBuilder` or the \
    `:dynamic_builder` call-time option.
    """)

    EctoShorts.DynamicBuilders.Postgres
end
```

## Behavior matrix

| Situation | Before | After |
|---|---|---|
| `:dynamic_builder` opt set | use it | use it |
| `dynamic_builder_module` config set | use it | use it |
| repo adapter = Postgres | `Postgres` (silent) | `Postgres` (silent) |
| repo adapter = MyXQL/Tds/SQL/other | raise | warn + `Postgres` |
| no repo & nothing configured | raise (repo!) | raise (repo!) — unchanged |

## Decisions

- **No-repo still raises.** The `Config.repo!(opts)` line is preserved; the
  function keeps its `!` name.
- **Warn every call.** Plain `Logger.warning`, no throttling, for simplicity.
- **Postgres path stays silent.**

## Doc fixes (same moduledoc)

- "All other adapters raise at runtime…" → warn-and-default.
- Config example wrongly reads `config :ecto_shorts, dynamic_builder:`; the real
  key is `:dynamic_builder_module`. Correct it.
- Add `require Logger`.

## Testing

- Unknown adapter → returns `DynamicBuilders.Postgres` and emits a warning
  (assert via `ExUnit.CaptureLog`).
- Postgres adapter → returns `Postgres` with no warning.
- No repo configured → still raises.
