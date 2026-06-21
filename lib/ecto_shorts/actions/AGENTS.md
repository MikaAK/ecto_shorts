# lib/ecto_shorts/actions — Actions Subsystem

`EctoShorts.Actions` (defined in the parent directory as `actions.ex`) delegates every operation to one of the modules in this directory. Each file in this directory handles one group of related operations.

## File responsibilities

| File | Group | What it handles |
|---|---|---|
| `crud.ex` | CRUD | `all`, `get`, `find`, `create`, `update`, `delete`, `stream`, `aggregate`, `find_or_create`, `find_and_create`, `find_and_update`, `find_and_upsert`, `find_and_delete` |
| `bulk.ex` | Bulk | `insert_all`, `update_all`, `delete_all` — runs a single repo call, no transactions |
| `multi.ex` | Multi | `create_many`, `find_many`, `update_many`, `delete_many`, `find_or_create_many`, `find_and_upsert_many` — builds an `Ecto.Multi` and runs it in a transaction |
| `batch.ex` | Batch | `batch`, `batch_find` — groups records by key and zips them into caller entries |
| `transaction.ex` | Transaction | `transaction`, `transact` — wraps a function or `Ecto.Multi` in a repo transaction |
| `error.ex` | Error | Builds `ErrorMessage` structs for `:not_found` and `:stale` responses |
| `source.ex` | Source | `Source.t()` — a struct for key-value lookup sources (alternative to schema modules) |

## Repo selection

- **Reads** call `Config.replica!(opts)`, which prefers `:replica` over `:repo`.
- **Writes** call `Config.repo!(opts)`.
- Both raise if no repo is configured.

The `:repo` and `:replica` options can be passed at the call site to override the application config for a single call.

## Preload handling

When `:preload` is in opts, it is applied after the main operation completes. For multi-record operations it is applied to the full result list. The preload is done on the **replica** (or `:repo` if no replica is set).

## Error shapes

Errors come from `Config.error_module()` (default `EctoShorts.Actions.Error`). The default module returns `ErrorMessage` structs with a `:code` field:

- `:not_found` — `find/3` found no record, or `find_many/3` encountered a nil.
- `:stale` — `update/4` with optimistic locking detected a concurrent modification.
- `{:error, changeset}` — validation failed.

## Multi operations

The `multi.ex` module builds an `Ecto.Multi` struct (a list of named database operations) and then runs it with `transaction/2`. If any step fails, all earlier steps are rolled back.

Operations inside a multi are named by their index. The `handle_multi_response/2` function converts the multi result map `%{0 => record, 1 => record, ...}` into a plain list in index order.

## Bulk operations

Bulk operations bypass `Ecto.Multi` and call the repo directly. They are faster than multi operations for large sets but do not provide per-record error messages — if anything fails, the whole call fails.

`Bulk.insert_all` calls `CommonParams.convert_to_insert_params/3` to validate and transform entries before the repo call.

## Reducer Contract

Actions receive params maps that configure how an operation should run. These are collections of configuration options, not operations themselves.

**Rule:** When you receive a params map, use `Enum.reduce/3` to walk each configuration entry. Common params keys are `:where`, `:limit`, `:offset`, `:order_by`, `:preload`, etc. Each `{key, value}` pair is a separate directive to the query builder.

## Public vs Internal Forms

- **Public API**: params maps and keyword lists passed to Action functions like `all/3`, `get/3`, `create/3`.
- **Internal dispatch**: tuples and opcodes are handled by `CommonFilters` and `CommonParams`, not by Actions.

Actions never expose internal tuple forms in their public examples.

## String-Key Safety

String keys in params are normalized before they reach the filter pipeline. Actions do not perform string-to-atom conversion.

## Error Protocol

- Return `{:ok, result}` or `{:error, reason}`.
- Reason can be an `ErrorMessage` struct (from `Config.error_module()`) or a changeset.
- Callers match `{:error, _} ->` not `:skip ->`.
