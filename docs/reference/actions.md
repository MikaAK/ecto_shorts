# Actions Reference

This reference document provides detailed information about the `Actions` module in ecto_shorts, which provides a consistent interface for performing CRUD operations.

## Overview

The `Actions` module simplifies common database operations by providing a consistent API for creating, reading, updating, and deleting records. It integrates with `CommonFilters` for querying and `CommonChanges` for handling associations.

## Function Reference

### create/3

```elixir
create(schema, attrs, opts \\ [])
```

Creates a new record of the given schema with the provided attributes.

#### Parameters

- `schema`: The schema module to create a record for
- `attrs`: A map of attributes to set on the new record
- `opts`: Options (see below)

#### Options

- `:repo`: The Ecto.Repo to use (defaults to the configured repo)
- `:changeset_fun`: The changeset function to use (defaults to `create_changeset/1` or `changeset/2`)
- Any other options are passed to the repo's `insert/2` function

#### Returns

- `{:ok, record}` if the record was created successfully
- `{:error, changeset}` if there was an error

#### Examples

```elixir
# Basic usage
{:ok, user} = EctoShorts.Actions.create(User, %{name: "John", email: "john@example.com"})

# With a custom repo
{:ok, user} = EctoShorts.Actions.create(User, %{name: "John"}, repo: MyApp.CustomRepo)

# With a custom changeset function
{:ok, user} = EctoShorts.Actions.create(User, %{name: "John"}, changeset_fun: :sign_up_changeset)

# With associations
{:ok, user} = EctoShorts.Actions.create(User, %{
  name: "John",
  posts: [
    %{title: "Post 1", content: "Content 1"},
    %{title: "Post 2", content: "Content 2"}
  ]
})
```

#### Implementation Details

The `create/3` function:

1. Looks for a `create_changeset/1` function on the schema
2. If not found, falls back to `changeset/2`
3. Applies the changeset to a new struct
4. Handles associations using `CommonChanges.put_or_cast_assoc/3`
5. Inserts the record into the database

### get/3

```elixir
get(schema, id, opts \\ [])
```

Gets a record of the given schema by its ID.

#### Parameters

- `schema`: The schema module to get a record for
- `id`: The ID of the record to get
- `opts`: Options (see below)

#### Options

- `:repo`: The Ecto.Repo to use (defaults to the configured repo)
- `:replica`: A read replica to use for the query
- `:preload`: Fields to preload on the record
- Any other options are passed to `CommonFilters.convert_params_to_filter/3`

#### Returns

- `{:ok, record}` if the record was found
- `{:error, :not_found}` if the record was not found

#### Examples

```elixir
# Basic usage
{:ok, user} = EctoShorts.Actions.get(User, 1)

# With preloads
{:ok, user} = EctoShorts.Actions.get(User, 1, preload: [:posts])

# With a read replica
{:ok, user} = EctoShorts.Actions.get(User, 1, replica: MyApp.ReplicaRepo)
```

#### Implementation Details

The `get/3` function:

1. Creates a query for the schema with the given ID
2. Applies any additional filters from the options
3. Executes the query using the specified repo
4. Returns the record if found, or an error if not

### get_by/3

```elixir
get_by(schema, attrs, opts \\ [])
```

Gets a record of the given schema by the provided attributes.

#### Parameters

- `schema`: The schema module to get a record for
- `attrs`: A map of attributes to filter by
- `opts`: Options (see below)

#### Options

- `:repo`: The Ecto.Repo to use (defaults to the configured repo)
- `:replica`: A read replica to use for the query
- `:preload`: Fields to preload on the record
- Any other options are passed to `CommonFilters.convert_params_to_filter/3`

#### Returns

- `{:ok, record}` if the record was found
- `{:error, :not_found}` if the record was not found

#### Examples

```elixir
# Basic usage
{:ok, user} = EctoShorts.Actions.get_by(User, %{email: "john@example.com"})

# With multiple conditions
{:ok, user} = EctoShorts.Actions.get_by(User, %{email: "john@example.com", active: true})

# With preloads
{:ok, user} = EctoShorts.Actions.get_by(User, %{email: "john@example.com"}, preload: [:posts])
```

#### Implementation Details

The `get_by/3` function:

1. Creates a query for the schema with the given attributes
2. Applies any additional filters from the options
3. Executes the query using the specified repo
4. Returns the first matching record if found, or an error if not

### all/3

```elixir
all(schema, filters \\ %{}, opts \\ [])
```

Gets all records of the given schema that match the provided filters.

#### Parameters

- `schema`: The schema module to get records for
- `filters`: A map of filters to apply (see CommonFilters)
- `opts`: Options (see below)

#### Options

- `:repo`: The Ecto.Repo to use (defaults to the configured repo)
- `:replica`: A read replica to use for the query
- Any other options are passed to `CommonFilters.convert_params_to_filter/3`

#### Returns

- A list of records that match the filters

#### Examples

```elixir
# Get all users
users = EctoShorts.Actions.all(User)

# Get users with specific filters
users = EctoShorts.Actions.all(User, %{age: %{gte: 18}, active: true})

# Get users with preloaded associations
users = EctoShorts.Actions.all(User, %{preload: [:posts, :comments]})

# Get the first 10 users
users = EctoShorts.Actions.all(User, %{first: 10})

# Get users with complex filters
users = EctoShorts.Actions.all(User, %{
  age: %{gte: 18, lte: 65},
  name: %{ilike: "john"},
  roles: ["admin", "moderator"],
  preload: [posts: :comments],
  first: 10
})
```

#### Implementation Details

The `all/3` function:

1. Creates a query for the schema with the given filters
2. Applies any additional options
3. Executes the query using the specified repo
4. Returns a list of matching records

### count/3

```elixir
count(schema, filters \\ %{}, opts \\ [])
```

Counts the number of records of the given schema that match the provided filters.

#### Parameters

- `schema`: The schema module to count records for
- `filters`: A map of filters to apply (see CommonFilters)
- `opts`: Options (see below)

#### Options

- `:repo`: The Ecto.Repo to use (defaults to the configured repo)
- `:replica`: A read replica to use for the query
- Any other options are passed to `CommonFilters.convert_params_to_filter/3`

#### Returns

- An integer representing the count of matching records

#### Examples

```elixir
# Count all users
count = EctoShorts.Actions.count(User)

# Count users with specific filters
count = EctoShorts.Actions.count(User, %{age: %{gte: 18}, active: true})
```

#### Implementation Details

The `count/3` function:

1. Creates a query for the schema with the given filters
2. Applies the count query mode
3. Executes the query using the specified repo
4. Returns the count of matching records

### update/4

```elixir
update(schema, id, attrs, opts \\ [])
```

Updates a record of the given schema with the provided attributes.

#### Parameters

- `schema`: The schema module to update a record for
- `id`: The ID of the record to update
- `attrs`: A map of attributes to update on the record
- `opts`: Options (see below)

#### Options

- `:repo`: The Ecto.Repo to use (defaults to the configured repo)
- `:changeset_fun`: The changeset function to use (defaults to `update_changeset/2` or `changeset/2`)
- Any other options are passed to the repo's `update/2` function

#### Returns

- `{:ok, record}` if the record was updated successfully
- `{:error, changeset}` if there was an error
- `{:error, :not_found}` if the record was not found

#### Examples

```elixir
# Basic usage
{:ok, user} = EctoShorts.Actions.update(User, 1, %{name: "Jane"})

# With a custom repo
{:ok, user} = EctoShorts.Actions.update(User, 1, %{name: "Jane"}, repo: MyApp.CustomRepo)

# With a custom changeset function
{:ok, user} = EctoShorts.Actions.update(User, 1, %{name: "Jane"}, changeset_fun: :profile_update_changeset)

# With associations
{:ok, user} = EctoShorts.Actions.update(User, 1, %{
  name: "Jane",
  posts: [
    %{id: 1, title: "Updated Post 1"},
    %{title: "New Post"}
  ]
})
```

#### Implementation Details

The `update/4` function:

1. Gets the record with the given ID
2. If not found, returns an error
3. Looks for an `update_changeset/2` function on the schema
4. If not found, falls back to `changeset/2`
5. Applies the changeset to the record
6. Handles associations using `CommonChanges.put_or_cast_assoc/3`
7. Updates the record in the database

### delete/3

```elixir
delete(schema, id, opts \\ [])
```

Deletes a record of the given schema.

#### Parameters

- `schema`: The schema module to delete a record for
- `id`: The ID of the record to delete
- `opts`: Options (see below)

#### Options

- `:repo`: The Ecto.Repo to use (defaults to the configured repo)
- Any other options are passed to the repo's `delete/2` function

#### Returns

- `{:ok, record}` if the record was deleted successfully
- `{:error, changeset}` if there was an error
- `{:error, :not_found}` if the record was not found

#### Examples

```elixir
# Basic usage
{:ok, user} = EctoShorts.Actions.delete(User, 1)

# With a custom repo
{:ok, user} = EctoShorts.Actions.delete(User, 1, repo: MyApp.CustomRepo)
```

#### Implementation Details

The `delete/3` function:

1. Gets the record with the given ID
2. If not found, returns an error
3. Deletes the record from the database

## Common Patterns

### Context Module Pattern

A common pattern is to create context modules that use the `Actions` module to provide a domain-specific API:

```elixir
defmodule MyApp.Accounts do
  alias EctoShorts.Actions
  alias MyApp.{Repo, User}

  @actions_opts [repo: Repo]

  def create_user(attrs) do
    Actions.create(User, attrs, @actions_opts)
  end

  def get_user(id) do
    Actions.get(User, id, @actions_opts)
  end

  def get_user_by_email(email) do
    Actions.get_by(User, %{email: email}, @actions_opts)
  end

  def list_users(filters \\ %{}) do
    Actions.all(User, filters, @actions_opts)
  end

  def update_user(id, attrs) do
    Actions.update(User, id, attrs, @actions_opts)
  end

  def delete_user(id) do
    Actions.delete(User, id, @actions_opts)
  end
end
```

### Transaction Pattern

You can use `Actions` within a transaction:

```elixir
alias MyApp.Repo
alias EctoShorts.Actions

Repo.transaction(fn ->
  with {:ok, user} <- Actions.create(User, %{name: "John"}),
       {:ok, post} <- Actions.create(Post, %{title: "Post", user_id: user.id}) do
    {user, post}
  else
    {:error, changeset} -> Repo.rollback(changeset)
  end
end)
```

### Read Replica Pattern

If you have a read replica set up, you can use it for read operations:

```elixir
defmodule MyApp.Accounts do
  alias EctoShorts.Actions
  alias MyApp.{Repo, ReplicaRepo, User}

  @write_opts [repo: Repo]
  @read_opts [repo: Repo, replica: ReplicaRepo]

  def create_user(attrs) do
    Actions.create(User, attrs, @write_opts)
  end

  def get_user(id) do
    Actions.get(User, id, @read_opts)
  end

  def list_users(filters \\ %{}) do
    Actions.all(User, filters, @read_opts)
  end
end
```

## Best Practices

1. **Create context modules**: Organize your code by creating context modules that use `Actions` to perform database operations.

2. **Set default options**: Define default options for `Actions` in your context modules to avoid repetition.

3. **Use proper schemas**: Make sure your schemas have appropriate changeset functions and validations.

4. **Handle errors**: Always handle the error cases from `Actions` functions, especially for operations that can return `{:error, :not_found}`.

5. **Use preloading wisely**: Only preload associations when you need them to avoid unnecessary database queries.

6. **Consider transactions**: Use transactions for operations that need to be atomic.

7. **Document your API**: Make sure to document your context modules and functions for other developers.
