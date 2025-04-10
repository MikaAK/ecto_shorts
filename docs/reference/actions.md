# Actions Reference

This reference document provides detailed information about the `EctoShorts.Actions` module, which provides a consistent interface for performing CRUD operations on Ecto schemas.

## Overview

The `EctoShorts.Actions` module is the primary entry point for most users of ecto_shorts. It simplifies common database operations by providing a consistent API for creating, reading, updating, and deleting records. It integrates with `EctoShorts.CommonFilters` for querying and `EctoShorts.CommonChanges` for handling associations.

## Function Reference

### create/3

```elixir
EctoShorts.Actions.create(schema, attrs, opts \\ [])
```

Creates a new record of the given schema with the provided attributes.

#### Parameters

- `schema`: The schema module or `{source, schema}` tuple to create a record for
- `attrs`: A map of attributes to set on the new record
- `opts`: Options (see below)

#### Options

- `:repo`: The `Ecto.Repo` to use (defaults to the configured repo)
- `:changeset`: A function to customize the changeset creation process. Can be:
  - A 2-arity function that receives the schema struct and params
  - A 1-arity function that receives the changeset
- Any other options are passed to `Ecto.Repo.insert/2`

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
{:ok, user} = EctoShorts.Actions.create(User, %{name: "John"}, changeset: &User.sign_up_changeset/2)

# With associations
{:ok, user} = EctoShorts.Actions.create(User, %{
  name: "John",
  posts: [
    %{title: "Post 1", content: "Content 1"},
    %{title: "Post 2", content: "Content 2"}
  ]
})

# With a source-schema tuple
{:ok, user} = EctoShorts.Actions.create({"users", User}, %{name: "John"})
```

#### Implementation Details

The `create/3` function:

1. Builds a changeset for the schema with the provided attributes
   - If the schema has a `create_changeset/1` function, it will be used
   - Otherwise, falls back to `changeset/2`
   - If a custom `:changeset` function is provided in the options, it will be used instead
2. Handles associations appropriately
3. Inserts the record into the database using the specified repo

### get/3

```elixir
EctoShorts.Actions.get(schema, id, opts \\ [])
```

Gets a record of the given schema by its ID.

#### Parameters

- `schema`: The schema module or `{source, schema}` tuple to get a record for
- `id`: The ID of the record to get (integer or binary ID)
- `opts`: Options (see below)

#### Options

- `:repo`: The `Ecto.Repo` to use (defaults to the configured repo)
- `:replica`: A read replica to use for the query
- Any other options are passed to `Ecto.Repo.get/3`

#### Returns

- The record if found
- `nil` if the record was not found

#### Examples

```elixir
# Basic usage
user = EctoShorts.Actions.get(User, 1)

# With a custom repo
user = EctoShorts.Actions.get(User, 1, repo: MyApp.CustomRepo)

# With a read replica
user = EctoShorts.Actions.get(User, 1, replica: MyApp.ReplicaRepo)

# With a source-schema tuple
user = EctoShorts.Actions.get({"users", User}, 1)
```

#### Implementation Details

The `get/3` function:

1. Determines which repo to use (replica takes precedence over repo)
2. Calls `Ecto.Repo.get/3` with the schema, ID, and options
3. Returns the record directly (not wrapped in a tuple)

> **Note**: Unlike `find/3`, this function returns the record directly or `nil`, not a tuple result.

### find/3

```elixir
EctoShorts.Actions.find(schema, params, opts \\ [])
```

Finds a record of the given schema that matches the provided parameters.

#### Parameters

- `schema`: The schema module or `{source, schema}` tuple to find a record for
- `params`: A map of parameters to filter by
- `opts`: Options (see below)

#### Options

- `:repo`: The `Ecto.Repo` to use (defaults to the configured repo)
- `:replica`: A read replica to use for the query
- `:order_by`: Orders the fields based on one or more fields
- Any other options are passed to `EctoShorts.CommonFilters.convert_params_to_filter/3`

#### Returns

- `{:ok, record}` if the record was found
- `{:error, %{code: :not_found}}` if no record matches the params

#### Examples

```elixir
# Basic usage
{:ok, user} = EctoShorts.Actions.find(User, %{email: "john@example.com"})

# With multiple conditions
{:ok, user} = EctoShorts.Actions.find(User, %{email: "john@example.com", active: true})

# With ordering
{:ok, user} = EctoShorts.Actions.find(User, %{active: true}, order_by: [desc: :inserted_at])

# With a custom repo
{:ok, user} = EctoShorts.Actions.find(User, %{email: "john@example.com"}, repo: MyApp.CustomRepo)

# With a source-schema tuple
{:ok, user} = EctoShorts.Actions.find({"users", User}, %{email: "john@example.com"})
```

#### Implementation Details

The `find/3` function:

1. Creates a query for the schema with the given parameters using `EctoShorts.CommonFilters`
2. Applies any additional options like ordering
3. Executes the query using the specified repo
4. Returns `{:ok, record}` if found, or `{:error, %{code: :not_found}}` if not

> **Note**: Unlike `get/3`, this function returns a tuple result.

### all/3

```elixir
EctoShorts.Actions.all(schema, filters \\ %{}, opts \\ [])
```

Fetches all records of the given schema that match the provided filters.

#### Parameters

- `schema`: The schema module, `{source, schema}` tuple, or `Ecto.Query` to get records for
- `filters`: A map of filters to apply (see `EctoShorts.CommonFilters`)
- `opts`: Options (see below)

#### Options

- `:repo`: The `Ecto.Repo` to use (defaults to the configured repo)
- `:replica`: A read replica to use for the query
- `:order_by`: Orders the results based on one or more fields
- Any other options are passed to `Ecto.Repo.all/2`

#### Returns

- A list of records that match the filters (empty list if none found)

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

# With a custom repo
users = EctoShorts.Actions.all(User, %{active: true}, repo: MyApp.CustomRepo)

# With a source-schema tuple
users = EctoShorts.Actions.all({"users", User}, %{active: true})

# With an Ecto.Query
query = from(u in User, where: u.active == true)
users = EctoShorts.Actions.all(query, %{preload: :posts})
```

#### Implementation Details

The `all/3` function:

1. Converts the filters to an Ecto query using `EctoShorts.CommonFilters.convert_params_to_filter/3`
2. Applies any additional options like ordering
3. Executes the query using the specified repo
4. Returns a list of matching records

### count/3

```elixir
EctoShorts.Actions.count(schema, filters \\ %{}, opts \\ [])
```

Counts the number of records of the given schema that match the provided filters.

#### Parameters

- `schema`: The schema module, `{source, schema}` tuple, or `Ecto.Query` to count records for
- `filters`: A map of filters to apply (see `EctoShorts.CommonFilters`)
- `opts`: Options (see below)

#### Options

- `:repo`: The `Ecto.Repo` to use (defaults to the configured repo)
- `:replica`: A read replica to use for the query
- Any other options are passed to `EctoShorts.CommonFilters.convert_params_to_filter/3`

#### Returns

- An integer representing the count of matching records

#### Examples

```elixir
# Count all users
count = EctoShorts.Actions.count(User)

# Count users with specific filters
count = EctoShorts.Actions.count(User, %{age: %{gte: 18}, active: true})

# With a custom repo
count = EctoShorts.Actions.count(User, %{active: true}, repo: MyApp.CustomRepo)

# With a source-schema tuple
count = EctoShorts.Actions.count({"users", User}, %{active: true})

# With an Ecto.Query
query = from(u in User, where: u.active == true)
count = EctoShorts.Actions.count(query)
```

#### Implementation Details

The `count/3` function:

1. Converts the filters to an Ecto query using `EctoShorts.CommonFilters.convert_params_to_filter/3`
2. Applies an aggregate count operation to the query
3. Executes the query using the specified repo
4. Returns the count of matching records

### update/4

```elixir
EctoShorts.Actions.update(schema, id_or_schema, attrs, opts \\ [])
```

Updates a record of the given schema with the provided attributes.

#### Parameters

- `schema`: The schema module or `{source, schema}` tuple to update a record for
- `id_or_schema`: Either the ID of the record to update or an existing schema struct
- `attrs`: A map of attributes to update on the record
- `opts`: Options (see below)

#### Options

- `:repo`: The `Ecto.Repo` to use (defaults to the configured repo)
- `:changeset`: A function to customize the changeset creation process. Can be:
  - A 2-arity function that receives the schema struct and params
  - A 1-arity function that receives the changeset
- Any other options are passed to `Ecto.Repo.update/2`

#### Returns

- `{:ok, record}` if the record was updated successfully
- `{:error, changeset}` if there was a validation error
- `{:error, %{code: :not_found}}` if the record was not found

#### Examples

```elixir
# Basic usage with ID
{:ok, user} = EctoShorts.Actions.update(User, 1, %{name: "Jane"})

# With an existing schema struct
user = EctoShorts.Actions.get(User, 1)
{:ok, updated_user} = EctoShorts.Actions.update(User, user, %{name: "Jane"})

# With a custom repo
{:ok, user} = EctoShorts.Actions.update(User, 1, %{name: "Jane"}, repo: MyApp.CustomRepo)

# With a custom changeset function
{:ok, user} = EctoShorts.Actions.update(User, 1, %{name: "Jane"}, changeset: &User.profile_update_changeset/2)

# With associations
{:ok, user} = EctoShorts.Actions.update(User, 1, %{
  name: "Jane",
  posts: [
    %{id: 1, title: "Updated Post 1"},
    %{title: "New Post"}
  ]
})

# With a source-schema tuple
{:ok, user} = EctoShorts.Actions.update({"users", User}, 1, %{name: "Jane"})
```

#### Implementation Details

The `update/4` function:

1. If an ID is provided, gets the record with that ID
   - If not found, returns `{:error, %{code: :not_found}}`
2. Builds a changeset for the schema with the provided attributes
   - If the schema has an `update_changeset/2` function, it will be used
   - Otherwise, falls back to `changeset/2`
   - If a custom `:changeset` function is provided in the options, it will be used instead
3. Handles associations appropriately
4. Updates the record in the database using the specified repo

### delete/3

```elixir
EctoShorts.Actions.delete(schema, id_or_schema, opts \\ [])
```

Deletes a record of the given schema.

#### Parameters

- `schema`: The schema module or `{source, schema}` tuple to delete a record for
- `id_or_schema`: Either the ID of the record to delete or an existing schema struct or changeset
- `opts`: Options (see below)

#### Options

- `:repo`: The `Ecto.Repo` to use (defaults to the configured repo)
- Any other options are passed to `Ecto.Repo.delete/2`

#### Returns

- `{:ok, record}` if the record was deleted successfully
- `{:error, changeset}` if there was a validation error
- `{:error, %{code: :not_found}}` if the record was not found
- `{:error, %{code: :internal_server_error}}` if there was an error during deletion

#### Examples

```elixir
# Delete by ID
{:ok, user} = EctoShorts.Actions.delete(User, 1)

# Delete an existing struct
user = EctoShorts.Actions.get(User, 1)
{:ok, deleted_user} = EctoShorts.Actions.delete(user)

# Delete with a custom repo
{:ok, user} = EctoShorts.Actions.delete(User, 1, repo: MyApp.CustomRepo)

# Delete with a source-schema tuple
{:ok, user} = EctoShorts.Actions.delete({"users", User}, 1)

# Delete multiple records
users = EctoShorts.Actions.all(User, %{active: false})
{:ok, deleted_users} = EctoShorts.Actions.delete(users)
```

#### Implementation Details

The `delete/3` function:

1. If an ID is provided, finds the record with that ID
   - If not found, returns `{:error, %{code: :not_found}}`
2. Creates a changeset for the record to be deleted
3. Deletes the record from the database using the specified repo
4. Returns the deleted record in an `:ok` tuple

When deleting multiple records, the function will attempt to delete all records and return a tuple with all results.

## Common Patterns

### Context Module Pattern

A common pattern is to create context modules that use the `EctoShorts.Actions` module to provide a domain-specific API:

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
    Actions.find(User, %{email: email}, @actions_opts)
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

This pattern follows the recommendations in the [Ecto documentation](https://hexdocs.pm/phoenix/contexts.html) for organizing your domain logic into context modules.

### Transaction Pattern

You can use `EctoShorts.Actions` within a transaction to ensure that multiple operations succeed or fail as a unit:

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

This pattern is useful when you need to perform multiple database operations that should be atomic.

### Read Replica Pattern

If you have a read replica set up, you can use it for read operations to distribute database load:

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

This pattern helps scale your application by directing read queries to replica databases.

## Best Practices

1. **Create context modules**: Organize your code by creating context modules that use `EctoShorts.Actions` to perform database operations. This follows the [Phoenix Contexts](https://hexdocs.pm/phoenix/contexts.html) pattern and provides a clean API for your domain logic.

2. **Set default options**: Define default options for `EctoShorts.Actions` in your context modules to avoid repetition. This makes your code more maintainable and less error-prone.

   ```elixir
   @actions_opts [repo: MyApp.Repo]
   
   def list_users(filters \\ %{}) do
     EctoShorts.Actions.all(User, filters, @actions_opts)
   end
   ```

3. **Use proper schemas**: Make sure your schemas have appropriate changeset functions and validations. `EctoShorts.Actions` will look for functions like `create_changeset/1` and `update_changeset/2` before falling back to `changeset/2`.

4. **Handle errors**: Always handle the error cases from `EctoShorts.Actions` functions, especially for operations that can return `{:error, %{code: :not_found}}` or `{:error, changeset}`.

   ```elixir
   case EctoShorts.Actions.find(User, %{email: email}) do
     {:ok, user} -> # Handle success
     {:error, %{code: :not_found}} -> # Handle not found
     {:error, changeset} -> # Handle validation errors
   end
   ```

5. **Use filtering capabilities**: Take advantage of the filtering capabilities provided by `EctoShorts.CommonFilters` to build complex queries declaratively.

   ```elixir
   EctoShorts.Actions.all(User, %{
     age: %{gte: 18},
     name: %{ilike: "%john%"},
     preload: [:posts, comments: :author],
     order_by: [desc: :inserted_at],
     first: 10
   })
   ```

6. **Use preloading wisely**: Only preload associations when you need them to avoid unnecessary database queries. Use nested preloads when appropriate.

7. **Consider transactions**: Use transactions for operations that need to be atomic, especially when working with multiple related records.

8. **Use read replicas**: For read-heavy applications, consider using read replicas to distribute database load.

9. **Document your API**: Make sure to document your context modules and functions for other developers, explaining the domain concepts and how they relate to the database schema.
