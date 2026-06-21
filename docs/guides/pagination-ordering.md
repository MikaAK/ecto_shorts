# Pagination and Ordering

EctoShorts exposes pagination and ordering through the same params map you pass
to any action. No special API is needed — just add the relevant keys to your
filter map.

For the full filter language, see [filtering.md](filtering.md). For writing and
reading records, see [crud-actions.md](crud-actions.md).

---

## Limiting results

### `:limit` / `:first` — take the first N records

Both keys route to the same `LIMIT` clause. Use whichever reads more naturally.

```elixir
posts = EctoShorts.Actions.all(MyApp.Post, %{limit: 10})
# => [%MyApp.Post{}, ...]  (at most 10 records)

posts = EctoShorts.Actions.all(MyApp.Post, %{first: 5})
# => [%MyApp.Post{}, ...]  (at most 5 records)
```

### `:last` — take the last N records (terminal filter)

`:last` is a **terminal filter**: it runs after all other filters and wraps the
query in a subquery. The subquery orders the inner rows descending, applies the
limit, then re-orders the result ascending so the records come back in natural
order.

```elixir
# Last 5 published posts by primary key
posts = EctoShorts.Actions.all(MyApp.Post, %{published: true, last: 5})
# => [%MyApp.Post{}, ...] (the 5 most recently inserted)

# Last 10 by a specific field
posts = EctoShorts.Actions.all(MyApp.Post, %{last: {:inserted_at, 10}})
# => [%MyApp.Post{}, ...] (10 records with the largest inserted_at values, ascending)
```

> Because `:last` wraps a subquery, it cannot be combined with `:limit`/`:first`
> in the same params map.

---

## Skipping records

### `:offset` — skip the first N records

```elixir
# Skip the first 20 records
posts = EctoShorts.Actions.all(MyApp.Post, %{limit: 10, offset: 20})
# => [%MyApp.Post{}, ...] records 21–30
```

---

## Ordering

### `:order_by` — set the sort order

Accepts the same values as `Ecto.Query.order_by/3`:

```elixir
# Order by a single field ascending
posts = EctoShorts.Actions.all(MyApp.Post, %{order_by: :title})

# Explicit direction
posts = EctoShorts.Actions.all(MyApp.Post, %{order_by: {:desc, :inserted_at}})

# Multiple fields
posts = EctoShorts.Actions.all(MyApp.Post, %{order_by: [asc: :title, desc: :inserted_at]})
```

### `:prepend_order_by` — add clauses before existing ORDER BY

Inserts new order clauses before the ones already on the query. Useful when
composing queries where an inner scope has its own ordering.

```elixir
posts = EctoShorts.Actions.all(
  MyApp.Post,
  %{order_by: :title, prepend_order_by: {:desc, :pinned}}
)
# Effective order: pinned DESC, title ASC
```

### `:reverse_order` — flip the current ORDER BY

When `true`, reverses the direction of every clause in the current `ORDER BY`.

```elixir
posts = EctoShorts.Actions.all(
  MyApp.Post,
  %{order_by: :title, reverse_order: true}
)
# Effective order: title DESC
```

---

## Offset-based pagination

Combine `:page` (a map with `:index` and `:size`) for a clean pagination API:

```elixir
# Page 1
page1 = EctoShorts.Actions.all(MyApp.Post, %{page: %{index: 1, size: 20}})
# => first 20 records

# Page 2
page2 = EctoShorts.Actions.all(MyApp.Post, %{page: %{index: 2, size: 20}})
# => records 21–40
```

Under the hood, `:page` computes `LIMIT size OFFSET (index - 1) * size`.

> `:page` and `:offset`/`:limit` address the same SQL clauses. Do not mix them
> in the same params map.

---

## Cursor-based pagination

`:page` also supports forward and backward cursor pagination:

```elixir
# First page — no cursor
page1 = EctoShorts.Actions.all(
  MyApp.Post,
  %{page: %{after: nil, by: :id, size: 10}}
)
# => first 10 posts ordered by id ASC

# Next page — pass the last id as the cursor
last_id = List.last(page1).id
page2 = EctoShorts.Actions.all(
  MyApp.Post,
  %{page: %{after: last_id, by: :id, size: 10}}
)
# => next 10 posts where id > last_id

# Backward pagination
page_prev = EctoShorts.Actions.all(
  MyApp.Post,
  %{page: %{before: first_id, by: :id, size: 10}}
)
# => 10 posts where id < first_id, ordered by id DESC
```

---

## Include tied rows

### `:with_ties` — include rows tied on the last ORDER BY key

Applies `WITH TIES` to the `LIMIT` clause, ensuring that rows that share the
same value as the last selected row are included even when they exceed the
limit. Requires an `ORDER BY` and a `LIMIT`; both are applied automatically
when missing (defaults: 1 000-row limit, ascending primary-key order).

```elixir
# Top 3 by score, including all ties at position 3
posts = EctoShorts.Actions.all(
  MyApp.Post,
  %{order_by: {:desc, :score}, limit: 3, with_ties: true}
)
# => could return more than 3 rows if multiple posts share the 3rd-highest score

# Passing a limit inline
posts = EctoShorts.Actions.all(
  MyApp.Post,
  %{order_by: {:desc, :score}, with_ties: [limit: 5]}
)
```

---

## End-to-end paginated example

```elixir
defmodule MyApp.PostPaginator do
  @page_size 20

  def list_page(page_number, filters \\ %{}) do
    EctoShorts.Actions.all(
      MyApp.Post,
      Map.merge(filters, %{
        page: %{index: page_number, size: @page_size},
        order_by: {:desc, :inserted_at}
      }),
      preload: [:author]
    )
  end
end

# Fetch page 1
posts = MyApp.PostPaginator.list_page(1)
# => [%MyApp.Post{author: %MyApp.User{}, ...}, ...]

# Fetch page 2 with an extra filter
posts = MyApp.PostPaginator.list_page(2, %{published: true})
# => next 20 published posts
```

---

## See also

- [filtering.md](filtering.md) — predicate and structural filter keys
- [crud-actions.md](crud-actions.md) — the full read API
- [../reference/api-reference.md](../reference/api-reference.md) — full parameter reference table
