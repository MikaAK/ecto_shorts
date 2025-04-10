# EctoShorts

[![Hex version badge](https://img.shields.io/hexpm/v/ecto_shorts.svg)](https://hex.pm/packages/ecto_shorts)
[![Coveralls](https://github.com/MikaAK/ecto_shorts/actions/workflows/coveralls.yml/badge.svg)](https://github.com/MikaAK/ecto_shorts/actions/workflows/coveralls.yml)
[![Credo](https://github.com/MikaAK/ecto_shorts/actions/workflows/credo.yml/badge.svg)](https://github.com/MikaAK/ecto_shorts/actions/workflows/credo.yml)
[![Dialyzer](https://github.com/MikaAK/ecto_shorts/actions/workflows/dialyzer.yml/badge.svg)](https://github.com/MikaAK/ecto_shorts/actions/workflows/dialyzer.yml)

Ecto Shorts is a library focused on making Ecto easier to use in your Elixir applications by providing a concise, consistent API for common database operations.

## Installation

```elixir
def deps do
  [
    {:ecto_shorts, "~> 2.3"}
  ]
end
```

## Documentation

Our documentation is organized according to the [Diátaxis framework](https://diataxis.fr/), which divides documentation into four distinct categories based on user needs:

### [Tutorials](./docs/tutorials/index.md)

Learning-oriented content to help you get started with ecto_shorts:

- [Getting Started with ecto_shorts](./docs/tutorials/getting-started.md)
- [Building a Complete Application](./docs/tutorials/complete-application.md)

### [How-to Guides](./docs/how-to/index.md)

Problem-oriented guides to help you accomplish specific tasks:

- [How to Filter Data with CommonFilters](./docs/how-to/filtering-data.md)
- [How to Manage Associations with CommonChanges](./docs/how-to/managing-associations.md)
- [How to Use Actions for CRUD Operations](./docs/how-to/crud-operations.md)
- [How to Implement Custom Filters](./docs/how-to/custom-filters.md)
- [How to Configure ecto_shorts](./docs/how-to/configuration.md)

### [Reference](./docs/reference/index.md)

Technical information about ecto_shorts components:

- [API Reference](./docs/reference/api-reference.md)
- [Filter Options Reference](./docs/reference/filter-options.md)
- [Actions Reference](./docs/reference/actions.md)

### [Explanation](./docs/explanation/index.md)

Conceptual information to help you understand ecto_shorts:

- [Why ecto_shorts Exists](./docs/explanation/why-ecto-shorts.md)
- [Architecture Overview](./docs/explanation/architecture.md)
- [Comparison with Other Approaches](./docs/explanation/comparison.md)
- [Best Practices](./docs/explanation/best-practices.md)

The full documentation is also available at [https://hexdocs.pm/ecto_shorts](https://hexdocs.pm/ecto_shorts).


## Overview

ecto_shorts consists of four main modules:

### Actions

Provides a consistent interface for CRUD operations:

```elixir
# Create a user
{:ok, user} = EctoShorts.Actions.create(User, %{name: "John", email: "john@example.com"})

# Get a user by ID
{:ok, user} = EctoShorts.Actions.get(User, 1)

# Get users with filters
users = EctoShorts.Actions.all(User, %{age: %{gte: 18}, preload: :posts})

# Update a user
{:ok, user} = EctoShorts.Actions.update(User, 1, %{name: "Jane"})

# Delete a user
{:ok, user} = EctoShorts.Actions.delete(User, 1)
```

### CommonFilters

Converts parameter maps into Ecto queries:

```elixir
# Simple filter
EctoShorts.Actions.all(User, %{name: "John"})

# Complex filters
EctoShorts.Actions.all(User, %{
  age: %{gte: 18, lte: 65},
  name: %{ilike: "j"},
  roles: ["admin", "moderator"],
  preload: [:posts, :comments],
  first: 10
})

# Association filters
EctoShorts.Actions.all(User, %{
  roles: ["ADMIN", "SUPERUSER"]
})

# Array field filters
EctoShorts.Actions.all(User, %{
  items: [1, 2],
  cart: 3
})
```

### CommonChanges

Handles associations in Ecto changesets:

```elixir
# Update a user's roles (many-to-many)
{:ok, user} = EctoShorts.Actions.update(User, 1, %{
  roles: [1, 2, 3]  # List of role IDs
})

# Or with the lower-level API
changeset = CommonChanges.put_or_cast_assoc(changeset, :roles)
```

### SchemaHelpers

Provides utility functions for working with Ecto schemas:

```elixir
# Check if a schema has a field
if EctoShorts.SchemaHelpers.has_field?(User, :email) do
  # Do something with the email field
end

# Check if a schema has an association
if EctoShorts.SchemaHelpers.has_assoc?(User, :posts) do
  # Do something with the posts association
end
```

## Common Options

All actions accept these options:

- `:repo` - A module that uses the Ecto.Repo Module
- `:replica` - A read replica to use for read operations

For more detailed information, please refer to our [documentation](./docs/index.md).
