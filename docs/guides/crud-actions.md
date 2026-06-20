# CRUD Actions

`EctoShorts.Actions` is the single entry point for reading and writing data in
EctoShorts. Every function accepts a queryable (a schema module or an
`Ecto.Query`) and an optional params map, then delegates to the configured repo.

For setup, see [Getting Started](../getting-started.md). For the full filter
language used in params, see [filtering.md](filtering.md).

---

## Runtime options

All actions accept an `opts` keyword list. Common keys:

| Key | Purpose |
|-----|---------|
| `:repo` | Override the write repo for this call. Defaults to the app-configured repo. |
| `:replica` | Override the read repo for this call. Defaults to the app-configured replica (falls back to `:repo`). |
| `:preload` | Preload associations after the operation, e.g. `preload: [:comments]`. |
| `:dynamic_builder` | Per-call override of the dynamic-expression builder module. |
| `:query_builder` | Per-call override of the query-builder module. |
| `:query_provider` | Per-call override of the query-provider module. |

---

## Reading records

### `all/1` — fetch all records

Returns every record for the queryable with no filtering.

```elixir
posts = EctoShorts.Actions.all(MyApp.Post)
# => [%MyApp.Post{}, %MyApp.Post{}, ...]
```

### `all/2` — fetch all with filter params

Accepts a map of filter params. See [filtering.md](filtering.md) for the full
filter language.

```elixir
posts = EctoShorts.Actions.all(MyApp.Post, %{published: true})
# => [%MyApp.Post{published: true}, ...]

# No results returns an empty list, never an error.
posts = EctoShorts.Actions.all(MyApp.Post, %{title: "does not exist"})
# => []
```

### `all/3` — fetch all with params and options

```elixir
posts =
  EctoShorts.Actions.all(
    MyApp.Post,
    %{published: true},
    order_by: :inserted_at,
    preload: [:comments],
    replica: MyApp.ReadonlyRepo
  )
# => [%MyApp.Post{comments: [%MyApp.Comment{}, ...]}, ...]
```

### `get/3` — fetch by primary key

Returns the struct or `nil`. Does **not** return `{:ok, _}`.

```elixir
post = EctoShorts.Actions.get(MyApp.Post, 1)
# => %MyApp.Post{id: 1, ...}  or  nil

post = EctoShorts.Actions.get(MyApp.Post, 999)
# => nil

post = EctoShorts.Actions.get(MyApp.Post, 1, preload: [:comments])
# => %MyApp.Post{id: 1, comments: [...]}
```

### `find/3` — fetch a single record by params

Returns `{:ok, struct}` when found, or `{:error, error_message}` when no
record matches. Use this when you need the error path explicitly.

```elixir
{:ok, post} = EctoShorts.Actions.find(MyApp.Post, %{id: 1})
# => {:ok, %MyApp.Post{id: 1, ...}}

{:error, _not_found} = EctoShorts.Actions.find(MyApp.Post, %{id: 999})
# => {:error, %ErrorMessage{code: :not_found, ...}}

# With preload
{:ok, post} = EctoShorts.Actions.find(MyApp.Post, %{id: 1}, preload: [:comments])
# => {:ok, %MyApp.Post{id: 1, comments: [...]}}
```

> `find/3` delegates to Ecto.Repo.one/2, so pass filters that match at most
> one row. Passing filters that match multiple rows raises at runtime.

### `exists?/3` — check whether a record exists

Returns `true` or `false` directly.

```elixir
EctoShorts.Actions.exists?(MyApp.Post, %{published: true})
# => true

EctoShorts.Actions.exists?(MyApp.Post, %{id: 999})
# => false
```

### `stream/3` — stream records

Returns an `Enumerable.t()` backed by Ecto.Repo.stream/2. **Must be consumed
inside a transaction.** Use `transact/2` as the wrapper.

```elixir
EctoShorts.Actions.transact(fn ->
  MyApp.Post
  |> EctoShorts.Actions.stream(%{published: true})
  |> Stream.each(&process_post/1)
  |> Stream.run()
end)
# => {:ok, :ok}
```

Options:

- `:max_rows` (default `500`) — rows fetched from the database per batch.
- `:repo` — the repo to open the cursor on.

### `aggregate/3` — run an aggregate function

Returns a single scalar value. Defaults to counting records.

```elixir
count = EctoShorts.Actions.aggregate(MyApp.Post, %{published: true})
# => 42

total_views = EctoShorts.Actions.aggregate(
  MyApp.Post,
  %{published: true},
  aggregate: :sum,
  key: :views
)
# => 18_500

avg_views = EctoShorts.Actions.aggregate(
  MyApp.Post,
  %{},
  aggregate: :avg,
  key: :views
)
# => #Decimal<123.5>  (or a float, depending on column type)
```

Supported `:aggregate` values: `:count` (default), `:sum`, `:avg`, `:min`,
`:max`. The `:key` option selects the column (default `:id`).

---

## Writing records

### `create/3` — insert a new record

Builds a changeset via the schema's `changeset/2` and inserts it.

```elixir
{:ok, post} = EctoShorts.Actions.create(MyApp.Post, %{title: "Hello", body: "World"})
# => {:ok, %MyApp.Post{id: 1, title: "Hello", body: "World"}}

{:error, changeset} = EctoShorts.Actions.create(MyApp.Post, %{title: nil})
# => {:error, %Ecto.Changeset{valid?: false, errors: [title: {"can't be blank", [...]}]}}
```

### `update/4` — update by id or struct

Pass either an integer/binary id (the record is fetched first) or an already-
loaded struct.

```elixir
# Update by id — fetches then updates
{:ok, post} = EctoShorts.Actions.update(MyApp.Post, 1, %{title: "Updated"})
# => {:ok, %MyApp.Post{id: 1, title: "Updated"}}

# Update a struct you already have
{:ok, post} = EctoShorts.Actions.update(MyApp.Post, post, %{title: "Updated again"})
# => {:ok, %MyApp.Post{id: 1, title: "Updated again"}}

# Record not found
{:error, _not_found} = EctoShorts.Actions.update(MyApp.Post, 999, %{title: "x"})
# => {:error, %ErrorMessage{code: :not_found, ...}}

# Optimistic locking conflict
{:error, _stale} = EctoShorts.Actions.update(MyApp.Post, 1, %{title: "race"}, optimistic_lock: :lock_version)
# => {:error, %ErrorMessage{code: :stale, ...}}
```

### `delete/1` — delete a struct, changeset, or list

```elixir
{:ok, deleted} = EctoShorts.Actions.delete(post)
# => {:ok, %MyApp.Post{id: 1, ...}}

{:ok, deleted_list} = EctoShorts.Actions.delete([post1, post2])
# => {:ok, [%MyApp.Post{...}, %MyApp.Post{...}]}
```

### `delete/2` — delete with options

```elixir
{:ok, deleted} = EctoShorts.Actions.delete(post, repo: MyApp.Repo)
# => {:ok, %MyApp.Post{id: 1, ...}}
```

### `delete/3` — delete by id

Fetches the record with `find/3`, then deletes it.

```elixir
{:ok, deleted} = EctoShorts.Actions.delete(MyApp.Post, 1, [])
# => {:ok, %MyApp.Post{id: 1, ...}}

{:error, _not_found} = EctoShorts.Actions.delete(MyApp.Post, 999, [])
# => {:error, %ErrorMessage{code: :not_found, ...}}
```

---

## Compound operations

### `find_and_create/4` — find, or create with different params

Looks for a record matching `find_params`. If found, returns it. If not found,
creates a new record using `create_params`.

```elixir
# First call — post does not exist yet:
{:ok, post} = EctoShorts.Actions.find_and_create(
  MyApp.Post,
  %{title: "Hello"},
  %{title: "Hello", body: "World"}
)
# => {:ok, %MyApp.Post{id: 1, title: "Hello", body: "World"}}

# Second call — post already exists:
{:ok, post} = EctoShorts.Actions.find_and_create(
  MyApp.Post,
  %{title: "Hello"},
  %{title: "Hello", body: "World"}
)
# => {:ok, %MyApp.Post{id: 1, title: "Hello", body: "World"}}
```

### `find_and_update/4` — find then update

Returns `{:error, %ErrorMessage{code: :not_found}}` when no record matches.

```elixir
{:ok, post} = EctoShorts.Actions.find_and_update(
  MyApp.Post,
  %{id: 1},
  %{title: "Updated"}
)
# => {:ok, %MyApp.Post{id: 1, title: "Updated"}}

{:error, _not_found} = EctoShorts.Actions.find_and_update(
  MyApp.Post,
  %{id: 999},
  %{title: "Missing"}
)
# => {:error, %ErrorMessage{code: :not_found, ...}}
```

### `find_and_upsert/4` — find then update, or create

When found, updates with `upsert_params`. When not found, creates from
`Map.merge(find_params, upsert_params)`.

```elixir
{:ok, post} = EctoShorts.Actions.find_and_upsert(
  MyApp.Post,
  %{title: "Hello"},
  %{body: "New body"}
)
# Found path:   {:ok, %MyApp.Post{title: "Hello", body: "New body"}}
# Created path: {:ok, %MyApp.Post{title: "Hello", body: "New body"}}
```

### `find_and_delete/3` — find then delete

```elixir
{:ok, deleted} = EctoShorts.Actions.find_and_delete(
  MyApp.Post,
  %{title: "Hello"}
)
# => {:ok, %MyApp.Post{id: 1, title: "Hello", ...}}

{:error, _not_found} = EctoShorts.Actions.find_and_delete(
  MyApp.Post,
  %{title: "does not exist"}
)
# => {:error, %ErrorMessage{code: :not_found, ...}}
```

### `find_or_create/3` — find using the schema's query fields, or create

Filters `params` down to the schema's declared query fields for the lookup.
Creates from the full `params` map when not found.

```elixir
{:ok, post} = EctoShorts.Actions.find_or_create(
  MyApp.Post,
  %{title: "Hello", body: "World"}
)
# => {:ok, %MyApp.Post{id: 1, title: "Hello", body: "World"}}
```

---

## Transactions

### `transact/2` — preferred transaction boundary

Runs a 0- or 1-arity function (or an `Ecto.Multi`) in a transaction and
normalizes the result. By default (`:strict` mode), `{:error, reason}` triggers
a rollback and `{:ok, value}` is unwrapped.

```elixir
{:ok, post} = EctoShorts.Actions.transact(fn ->
  EctoShorts.Actions.create(MyApp.Post, %{title: "Hello"})
end)
# => {:ok, %MyApp.Post{id: 1, title: "Hello"}}

# On error the transaction is rolled back:
{:error, changeset} = EctoShorts.Actions.transact(fn ->
  EctoShorts.Actions.create(MyApp.Post, %{title: nil})
end)
# => {:error, %Ecto.Changeset{...}}
```

### `transaction/2` — lower-level transaction

Wraps the function or `Ecto.Multi` in a transaction without normalizing the
result. A function that returns `{:ok, value}` produces `{:ok, {:ok, value}}`.
Use `transact/2` for the common case.

```elixir
{:ok, {:ok, post}} = EctoShorts.Actions.transaction(fn ->
  EctoShorts.Actions.create(MyApp.Post, %{title: "Hello"})
end)
```

---

## See also

- [filtering.md](filtering.md) — the filter language used in params
- [pagination-ordering.md](pagination-ordering.md) — `:limit`, `:offset`, `:page`, `:order_by`
- [associations-changes.md](associations-changes.md) — changeset helpers
- [bulk-and-transactions.md](bulk-and-transactions.md) — `insert_all`, `create_many`, `batch`, and friends
- [../reference/api-reference.md](../reference/api-reference.md) — full function reference
