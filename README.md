# EctoShorts

 [![Hex version badge](https://img.shields.io/hexpm/v/ecto_shorts.svg)](https://hex.pm/packages/ecto_shorts)
 [![Coveralls](https://github.com/MikaAK/ecto_shorts/actions/workflows/coveralls.yml/badge.svg)](https://github.com/MikaAK/ecto_shorts/actions/workflows/coveralls.yml)
 [![Credo](https://github.com/MikaAK/ecto_shorts/actions/workflows/credo.yml/badge.svg)](https://github.com/MikaAK/ecto_shorts/actions/workflows/credo.yml)
 [![Dialyzer](https://github.com/MikaAK/ecto_shorts/actions/workflows/dialyzer.yml/badge.svg)](https://github.com/MikaAK/ecto_shorts/actions/workflows/dialyzer.yml)

EctoShorts is an Elixir library that provides a data-driven query API on top of Ecto, turning parameter maps into Ecto queries without writing query boilerplate. It wraps Ecto.Repo with a unified filter interface, bulk/batch operations, changeset helpers, and pluggable adapters for PostgreSQL.

Documentation: [https://hexdocs.pm/ecto_shorts](https://hexdocs.pm/ecto_shorts)

## Installation

```elixir
def deps do
  [
    {:ecto_shorts, "~> 3.0"}
  ]
end
```

## Configuration

```elixir
# config/config.exs
config :ecto_shorts,
  repo: MyApp.Repo

# Optional: use a read replica for all read operations
config :ecto_shorts,
  repo: MyApp.Repo,
  replica: MyApp.Repo.Replica
```

See [docs/configuration-guide.md](docs/configuration-guide.md) for all configuration keys.

## Usage

### Querying with filters

```elixir
# Equality
EctoShorts.Actions.all(User, %{status: :active})

# Comparison operators
EctoShorts.Actions.all(User, %{age: %{gte: 18, lte: 50}})

# Pattern match (case-insensitive)
EctoShorts.Actions.all(User, %{name: %{ilike: "steven"}})

# Null check
EctoShorts.Actions.all(User, %{deleted_at: %{is_nil: true}})

# Pagination
EctoShorts.Actions.all(Post, %{
  first: 20,
  offset: 40,
  order_by: [desc: :inserted_at],
  preload: [:author]
})
```

### Creating records

```elixir
{:ok, user} = EctoShorts.Actions.create(User, %{name: "Alice", age: 30})
```

Schemas can define a `create_changeset/1` that `Actions.create` will call automatically:

```elixir
def create_changeset(params \\ %{}), do: changeset(%__MODULE__{}, params)
```

### Updating records

```elixir
{:ok, user} = EctoShorts.Actions.update(User, user.id, %{name: "Bob"})
# or with a loaded struct
{:ok, user} = EctoShorts.Actions.update(User, user, %{name: "Bob"})
```

### find_or_create

```elixir
{:ok, user} = EctoShorts.Actions.find_or_create(User, %{email: "alice@example.com"})
```

Looks up by the given params; creates if not found. Uses the replica for the read and the primary for the write.

### Association filters

Any key matching a declared association on the schema triggers an implicit join:

```elixir
# Inner-joins to comments and filters on body
EctoShorts.Actions.all(Post, %{comments: %{body: %{ilike: "hello"}}})

# Equivalent to:
# from p in Post,
#   inner_join: c in assoc(p, :comments), as: :ecto_shorts_comments,
#   where: ilike(c.body, "%hello%")
```

### Changeset helpers

```elixir
# Auto-detect put_assoc vs cast_assoc
changeset
|> EctoShorts.CommonChanges.put_or_cast_assoc(:tags)

# Many-to-many member update: passing ID maps replaces the association set
changeset
|> EctoShorts.CommonChanges.put_or_cast_assoc(:roles)
# where the :roles change is [%{id: 1}, %{id: 3}]
```

### Building queries directly

```elixir
query = EctoShorts.CommonFilters.convert_params_to_filter(User, %{
  age: %{gte: 18},
  order_by: [asc: :name],
  first: 10
})

MyApp.Repo.all(query)
```

## Full Documentation

| Document | Contents |
|---|---|
| [Project Overview](docs/project-overview-pdr.md) | Problem statement, design goals, non-goals |
| [Codebase Summary](docs/codebase-summary.md) | Directory structure, key files, dependencies |
| [System Architecture](docs/system-architecture.md) | Component diagrams, filter pipeline, adapter extension points |
| [API Reference](docs/api-reference.md) | All public function signatures |
| [Configuration Guide](docs/configuration-guide.md) | All config keys, adapter setup, runtime overrides |
| [Code Standards](docs/code-standards.md) | Adding filters, adapters, Credo, Dialyzer |
| [Testing Guide](docs/testing-guide.md) | Test setup, DataCase, dual-file pattern, coverage |
