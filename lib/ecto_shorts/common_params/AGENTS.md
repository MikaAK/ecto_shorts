# lib/ecto_shorts/common_params — Bulk Operation Param Helpers

`CommonParams` (defined in the parent directory as `common_params.ex`) delegates timestamp and placeholder logic to the two files in this directory.

## Files

| File | What it handles |
|---|---|
| `timestamps.ex` | Adds `:inserted_at` and `:updated_at` fields to insert and update param maps. Reads the schema's timestamp configuration to determine field names and types. Accepts override options (`:inserted_at`, `:updated_at`, `:inserted_at_source`, etc.). |
| `placeholders.ex` | Replaces field values with `{:placeholder, field}` tuples when they match a placeholder map. Used with `Ecto.Repo.insert_all/3`'s `:placeholders` option to avoid repeating the same value across thousands of rows. |

## How they are used

Both modules are called from `common_params.ex:build_insert_map/5` after the entry has been validated and filtered to schema fields:

1. `Placeholders.put_placeholders/3` is called first to substitute matching values.
2. `Timestamps.put_timestamps/4` is called after to add `:inserted_at` and `:updated_at`.

For `update_all` operations, only `Timestamps.put_set_updated_at/4` is called (not `put_timestamps/4`).

## Timestamp type detection

`Timestamps` checks the schema's field type for `:inserted_at` and `:updated_at` to decide whether to generate a `DateTime` (`:utc_datetime`, `:utc_datetime_usec`) or a `NaiveDateTime` (`:naive_datetime`, `:naive_datetime_usec`). If the schema does not have those fields, timestamps are not added.

## Placeholder conflict resolution

When a field value in the params does not match the placeholder value, the `:on_placeholder_conflict` option controls what happens:
- `:nothing` (default) — keep the original value.
- `:replace_all` — always use the placeholder.
- `{:replace, fields}` — only replace the listed fields.

## Reducer Contract

CommonParams receives param entries that configure bulk insert/update operations.

**Rule:** When you walk through params using `Enum.reduce/3` or `Map.to_list/1`, assign meaning at the `{key, value}` boundary. Each entry is a separate configuration instruction, not part of a larger tagged structure.

## Public vs Internal Forms

- **Public API**: param maps and keyword lists passed to `convert_to_insert_params/3` and `convert_to_update_params/3`.
- **Internal dispatch**: normalized maps with timestamp and placeholder fields already resolved.

CommonParams does not expose tuple opcodes in its public API.

## String-Key Safety

String keys in params are normalized before reaching CommonParams. The module does not perform string-to-atom conversion.

## Error Protocol

- Return `{:ok, result}` or `{:error, reason_atom}`.
- Never return bare `:skip`.
- Callers match `{:error, _} ->` not `:skip ->`.
