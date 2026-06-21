# Getting Started with EctoShorts

## What is EctoShorts?

EctoShorts is a data-driven query and CRUD API for Elixir applications built on Ecto.
You pass plain maps of parameters and get back records — filtering, pagination, ordering,
associations, and changeset helpers are all driven by the same map-based interface,
without writing repetitive query boilerplate.

## Install

Add `ecto_shorts` to your dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ecto_shorts, "~> 3.0"}
  ]
end
```

Then fetch:

```bash
mix deps.get
```

## Configure

Tell EctoShorts which Ecto repo to use in your application config:

```elixir
# config/config.exs
config :ecto_shorts,
  repo: MyApp.Repo,
  replica: MyApp.Repo
```

The `replica` key is optional — when omitted it falls back to `repo`. Set it to a
separate read-replica repo to route all read operations there automatically. In the
example above both point to `MyApp.Repo`, which is the simplest starting setup.

## Your First Query

Given a schema like:

```elixir
defmodule MyApp.User do
  use Ecto.Schema

  schema "users" do
    field :name, :string
    field :age, :integer
    timestamps()
  end
end
```

Fetch all users aged 18 or older:

```elixir
EctoShorts.Actions.all(MyApp.User, %{age: %{gte: 18}})
# => [%MyApp.User{id: 1, name: "Ada", age: 22, ...}, %MyApp.User{id: 4, name: "Bob", age: 34, ...}]
```

The return value is a plain list of structs — the same as calling `MyApp.Repo.all(query)`
after building the query by hand.

All filter keys accept string keys as well as atom keys. This is useful when 
receiving JSON-decoded payloads or Phoenix controller params directly:

```elixir
# From a Phoenix controller
EctoShorts.Actions.all(MyApp.User, %{"age" => %{"gte" => 18}})
# => same result as above
```

You can narrow results further by stacking filters in the same map:

```elixir
EctoShorts.Actions.all(MyApp.User, %{age: %{gte: 18, lte: 30}, name: %{ilike: "ada"}})
# => [%MyApp.User{id: 1, name: "Ada", age: 22, ...}]
```

To fetch a single record by id, use `get/3`:

```elixir
EctoShorts.Actions.get(MyApp.User, 1)
# => %MyApp.User{id: 1, name: "Ada", age: 22, ...}
```

To find a single record matching filter params, use `find/3`:

```elixir
EctoShorts.Actions.find(MyApp.User, %{name: "Ada"})
# => {:ok, %MyApp.User{id: 1, name: "Ada", age: 22, ...}}
```

## Your First Write

Create a record by passing the schema module and a params map:

```elixir
EctoShorts.Actions.create(MyApp.User, %{name: "Ada", age: 22})
# => {:ok, %MyApp.User{id: 1, name: "Ada", age: 22, ...}}
```

On failure (e.g. a changeset validation error), you get an error tuple:

```elixir
EctoShorts.Actions.create(MyApp.User, %{name: nil})
# => {:error, %Ecto.Changeset{valid?: false, ...}}
```

Update and delete follow the same pattern:

```elixir
# Update by id
EctoShorts.Actions.update(MyApp.User, 1, %{age: 23})
# => {:ok, %MyApp.User{id: 1, name: "Ada", age: 23, ...}}

# Delete by id
EctoShorts.Actions.delete(MyApp.User, 1, [])
# => {:ok, %MyApp.User{id: 1, ...}}
```

## Next Steps

Now that you have EctoShorts installed and running your first queries and writes,
explore the guides for each feature area:

**Guides**

- [Filtering](guides/filtering.md) — the full query language: comparison operators, membership, pattern matching, null checks, boolean groups, and association filters
- [CRUD Actions](guides/crud-actions.md) — `create`, `find`, `get`, `update`, `delete`, and the `find_and_*` / `find_or_*` helpers
- [Associations and Changes](guides/associations-changes.md) — changeset helpers for `has_many`, `belongs_to`, and common field transforms
- [Pagination and Ordering](guides/pagination-ordering.md) — `:limit`, `:offset`, `:page`, `:order_by`, and `:reverse_order`
- [Bulk Operations and Transactions](guides/bulk-and-transactions.md) — `create_many`, `update_all`, `delete_all`, and `Ecto.Multi` helpers
- [Extending EctoShorts](guides/extending.md) — custom `QueryBuilder`, `QueryProvider`, and `DynamicBuilder` implementations

**Reference**

- [API Reference](reference/api-reference.md) — complete function signatures and option tables
- [Filter Keys](reference/filter-keys.md) — exhaustive table of every recognized filter key and its SQL equivalent
- [Configuration](reference/configuration.md) — all application config keys and runtime override options

**Explanation**

- [Architecture](explanation/architecture.md) — how the filter pipeline, query builder, and dynamic builder fit together
- [Filter Pipeline](explanation/filter-pipeline.md) — detailed walkthrough of param processing and query composition
