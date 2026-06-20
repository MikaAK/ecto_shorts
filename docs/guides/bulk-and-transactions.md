# Bulk Operations and Transactions

This guide covers the high-throughput and multi-record APIs in `EctoShorts.Actions`:
bulk SQL helpers (`insert_all`, `update_all`, `delete_all`), multi-record
transactional helpers (`create_many`, `find_many`, `update_many`, `delete_many`,
`find_or_create_many`, `find_and_upsert_many`), batch loaders, and transaction
wrappers.

See also the [CRUD actions guide](crud-actions.md) for single-record operations.

---

## Bulk SQL helpers

These helpers map directly to Ecto's `Repo.insert_all/3` and `Repo.update_all/3`
and are the right choice when you need maximum throughput and can trade per-row
changeset validation for speed.

### `insert_all/3`

Inserts many rows in a single SQL statement.

```elixir
# Prepare params with timestamps via CommonParams, then insert:
{:ok, inserts} =
  EctoShorts.CommonParams.convert_to_insert_params(Post, [
    %{title: "First post", body: "Body 1"},
    %{title: "Second post", body: "Body 2"}
  ])

{:ok, {count, _}} = EctoShorts.Actions.insert_all(Post, inserts)
# => {:ok, {2, nil}}
```

`convert_to_insert_params/3` validates each entry through the schema's
`changeset/2`, adds `:inserted_at`/`:updated_at` timestamps, and filters to
schema fields.  Pass `validate: false` to skip validation:

```elixir
{:ok, inserts} =
  EctoShorts.CommonParams.convert_to_insert_params(Post, params, validate: false)
```

#### Upsert on conflict

Use `build_on_conflict_options/3` to generate conflict resolution options:

```elixir
{:ok, inserts} =
  EctoShorts.CommonParams.convert_to_insert_params(Post, [
    %{id: 1, title: "Updated title", body: "Updated body"}
  ])

conflict_opts =
  EctoShorts.CommonParams.build_on_conflict_options(Post, inserts, [])
# => [conflict_target: [:id], on_conflict: {:replace, [:body, :title, :updated_at]}]

{:ok, {count, _}} = EctoShorts.Actions.insert_all(Post, inserts ++ conflict_opts)
```

Pass `:on_conflict_replace` to control which fields are replaced:

```elixir
# Do nothing on conflict (insert-or-ignore):
conflict_opts =
  EctoShorts.CommonParams.build_on_conflict_options(Post, inserts,
    on_conflict_replace: :none
  )
# => [conflict_target: [:id], on_conflict: :nothing]

# Replace only specific fields:
conflict_opts =
  EctoShorts.CommonParams.build_on_conflict_options(Post, inserts,
    on_conflict_replace: [:title]
  )
```

#### Return shape

```
{:ok, {non_neg_integer(), nil | [term()]}}
{:error, term()}
```

### `update_all/4`

Updates all records matching `find_params` in a single SQL statement.

```elixir
# Set a field:
{2, nil} = EctoShorts.Actions.update_all(Post, %{published: false}, %{title: "Draft"})

# Increment a field:
{1, nil} = EctoShorts.Actions.update_all(Post, %{id: 1}, %{views: {:inc, 1}})
```

Supported update operations: `:set` (default), `:inc`, `:push`, `:pull`.

#### Return shape

```
{non_neg_integer(), nil}
```

### `delete_all/3`

Deletes all records matching `params` in a single SQL statement.

```elixir
# Delete all draft posts:
{3, nil} = EctoShorts.Actions.delete_all(Post, %{published: false})

# Delete everything in the table:
{10, nil} = EctoShorts.Actions.delete_all(Post)
```

#### Return shape

```
{non_neg_integer(), nil}
```

---

## Multi-record transactional helpers

These helpers run multiple operations inside a single `Ecto.Multi` transaction.
Any failure rolls back the entire batch.  They all return `{:ok, [struct]}` on
success.

### `create_many/3`

Inserts each record individually (with changeset validation) inside a
transaction.

```elixir
{:ok, posts} =
  EctoShorts.Actions.create_many(Post, [
    %{title: "Post 1", body: "Body 1"},
    %{title: "Post 2", body: "Body 2"}
  ])
# => {:ok, [%Post{id: 1, title: "Post 1", ...}, %Post{id: 2, title: "Post 2", ...}]}
```

#### Return shape

```
{:ok, [struct()]}
{:error, term()}
```

### `find_many/3`

Finds multiple records in a single transaction.  A missing record rolls back
with a `:not_found` error.

```elixir
{:ok, posts} = EctoShorts.Actions.find_many(Post, [%{id: 1}, %{id: 2}])
# => {:ok, [%Post{id: 1, ...}, %Post{id: 2, ...}]}

# If id 99 does not exist:
{:error, :not_found} = EctoShorts.Actions.find_many(Post, [%{id: 1}, %{id: 99}])
```

#### Return shape

```
{:ok, [struct()]}
{:error, :not_found | term()}
```

### `update_many/3`

Updates multiple records in a single transaction.  Each entry is a
`{find_params, update_params}` tuple or a map with an `:id` key.

```elixir
{:ok, posts} =
  EctoShorts.Actions.update_many(Post, [
    {%{id: 1}, %{title: "Updated 1"}},
    {%{id: 2}, %{title: "Updated 2"}}
  ])
# => {:ok, [%Post{id: 1, title: "Updated 1", ...}, %Post{id: 2, title: "Updated 2", ...}]}
```

#### Return shape

```
{:ok, [struct()]}
{:error, term()}
```

### `delete_many/3`

Deletes multiple records in a single transaction.  Entries can be structs,
filter param maps, or raw id values.

```elixir
{:ok, deleted} = EctoShorts.Actions.delete_many(Post, [post1, post2])
# => {:ok, [%Post{...}, %Post{...}]}
```

#### Return shape

```
{:ok, [struct()]}
{:error, term()}
```

### `find_or_create_many/3`

For each entry, finds a matching record or creates one from the same params.

```elixir
{:ok, posts} =
  EctoShorts.Actions.find_or_create_many(Post, [
    %{title: "Existing post"},
    %{title: "New post", body: "New body"}
  ])
# => {:ok, [%Post{...}, %Post{...}]}
```

#### Return shape

```
{:ok, [struct()]}
{:error, term()}
```

### `find_and_upsert_many/3`

Finds and upserts multiple records.  Entries can be `{find_params, upsert_params}`
tuples or maps with an `:id` key.

```elixir
{:ok, posts} =
  EctoShorts.Actions.find_and_upsert_many(Post, [
    {%{id: 1}, %{title: "Updated"}},
    {%{title: "New"}, %{body: "New body"}}
  ])
# => {:ok, [%Post{id: 1, title: "Updated", ...}, %Post{title: "New", ...}]}
```

#### Return shape

```
{:ok, [struct()]}
{:error, term()}
```

---

## Batch loaders

Batch loaders are designed for DataLoader-style N+1 avoidance.  They fetch
many records in one query and group or zip them by key.

### `batch/3`

Fetches records and groups them by a batch key.  Returns a plain map; does
**not** return `{:ok, _}`.

```elixir
# Group posts by author_id:
grouped = EctoShorts.Actions.batch(Post, [%{author_id: 1}, %{author_id: 2}],
  batch_keys: :author_id,
  cardinality: :many
)
# => %{1 => [%Post{author_id: 1, ...}], 2 => [%Post{author_id: 2, ...}]}

# Fetch one post per id (raises ArgumentError if duplicates):
grouped = EctoShorts.Actions.batch(Post, [%{id: 1}, %{id: 2}],
  batch_keys: :id,
  cardinality: :one
)
# => %{1 => %Post{id: 1, ...}, 2 => %Post{id: 2, ...}}
```

Options:

* `:batch_keys` (default `:id`) — atom or list of atoms used to group results.
* `:cardinality` (default `:many`) — `:one` returns a single struct per key;
  `:many` returns a list.
* `:preload` — applied after grouping.

#### Return shape

```
%{batch_key_value() => struct() | [struct()]}
```

Returns `%{}` when `params` is empty or no records are found.

### `batch_find/4`

Batch-fetches records and zips them back into the original entries.

```elixir
entries = [
  %{permalink: "hello-world", title: "Updated title"},
  %{permalink: "missing-post", title: "Will not match"}
]

results = EctoShorts.Actions.batch_find(Post, entries, :permalink)
# => [{%Post{permalink: "hello-world", ...}, %{permalink: "hello-world", title: "Updated title"}},
#     %{permalink: "missing-post", title: "Will not match"}]
```

Unmatched entries are returned unchanged.  Matched entries become
`{resolved_struct, original_params}` tuples.

#### Return shape

```
[{struct(), map()} | map()]
```

---

## Transaction wrappers

### `transaction/2`

Wraps a function or `Ecto.Multi` in a database transaction.  Returns whatever
the function returns, wrapped in `{:ok, _}`.

```elixir
{:ok, result} =
  EctoShorts.Actions.transaction(fn ->
    {:ok, post} = EctoShorts.Actions.create(Post, %{title: "Hello"})
    post
  end)
# => {:ok, %Post{title: "Hello", ...}}
```

Note: if the inner function already returns `{:ok, value}`, the result is
`{:ok, {:ok, value}}`.  Use `transact/2` when you want the inner `{:ok, _}`
unwrapped automatically.

#### Return shape

```
{:ok, term()}
{:error, term()}
```

### `transact/2`

A higher-level transaction boundary that normalises the return value.

When the inner function returns `{:ok, value}`, `transact/2` unwraps it to
`{:ok, value}`.  When the inner function returns `{:error, reason}`, the
transaction is rolled back and `{:error, reason}` is returned.

```elixir
{:ok, post} =
  EctoShorts.Actions.transact(fn ->
    EctoShorts.Actions.create(Post, %{title: "Hello"})
    # must return {:ok, _} or {:error, _}
  end)
# => {:ok, %Post{title: "Hello", ...}}

# Error causes rollback:
{:error, changeset} =
  EctoShorts.Actions.transact(fn ->
    EctoShorts.Actions.create(Post, %{title: nil})  # validation fails
  end)
```

`Ecto.Multi` is also accepted:

```elixir
multi =
  Ecto.Multi.new()
  |> Ecto.Multi.insert(:post, Post.changeset(%Post{}, %{title: "Hello"}))

{:ok, post} = EctoShorts.Actions.transact(multi)
# => {:ok, %Post{...}}
```

Options:

* `:strict` (default `true`) — when `true`, rolls back on `{:error, reason}`
  and unwraps `{:ok, value}`.  Set to `false` to disable normalisation.

#### Return shape

```
{:ok, term()}
{:error, term()}
```

---

## Choosing the right helper

| Goal | Helper |
|---|---|
| Insert many rows fast (no per-row validation) | `insert_all/3` + `CommonParams.convert_to_insert_params/3` |
| Insert many rows with validation and rollback | `create_many/3` |
| Update rows matching a filter | `update_all/4` |
| Update specific records with rollback | `update_many/3` |
| Delete rows matching a filter | `delete_all/3` |
| Delete specific records with rollback | `delete_many/3` |
| Find or create in bulk | `find_or_create_many/3` |
| Upsert in bulk | `find_and_upsert_many/3` |
| DataLoader-style grouping | `batch/3` |
| DataLoader-style zip | `batch_find/4` |
| Custom transaction with rollback | `transact/2` |
| Raw transaction wrapper | `transaction/2` |
