# How to Use Actions for CRUD Operations

This guide shows you how to use the `Actions` module in ecto_shorts to simplify your Create, Read, Update, and Delete (CRUD) operations.

## Understanding Actions

The `Actions` module provides a consistent interface for performing common database operations. It wraps Ecto's `Repo` functions with additional functionality, such as automatic handling of associations and filtering. Each function follows predictable patterns for error handling and option processing, making your database code more consistent and maintainable.

## Basic CRUD Operations

### Creating Records

To create a new record:

```elixir
alias EctoShorts.Actions

# Create a user
{:ok, user} = Actions.create(User, %{name: "John Doe", email: "john@example.com"})
```

By default, `Actions.create` will:
1. Look for a `create_changeset/1` function on your schema
2. If not found, it will fall back to `changeset/2` with a new struct
3. Apply the changeset to the data
4. Insert the record into the database

#### Custom Changeset Function

You can specify a custom changeset function using the `:changeset` option:

```elixir
# Using a named function in the schema
{:ok, user} = Actions.create(User, %{name: "John Doe"}, changeset: :sign_up_changeset)

# Using an anonymous function
{:ok, user} = Actions.create(User, %{name: "John Doe"}, changeset: fn schema, params -> 
  schema
  |> User.changeset(params)
  |> Ecto.Changeset.validate_required([:email])
end)
```

The `:changeset` option can be:
- A 2-arity function that receives the schema data and params
- A 1-arity function that receives the changeset.

### Reading Records

#### Get a Record by ID

```elixir
# Get a user by ID - this returns the record directly, not a tuple
user = Actions.get(User, 1)

# If the record doesn't exist, it returns nil
nil = Actions.get(User, 999)
```

#### Find a Record by ID with Tuple Response

```elixir
# Find a user by ID - this returns a tuple result
{:ok, user} = Actions.find(User, %{id: 1})

# If the record doesn't exist, it returns an error
{:error, %{code: :not_found}} = Actions.find(User, %{id: 999})
```

#### Find a Record by Attributes

```elixir
# Find a user by email
{:ok, user} = Actions.find(User, %{email: "john@example.com"})

# If no record matches, it returns an error
{:error, %{code: :not_found}} = Actions.find(User, %{email: "nonexistent@example.com"})
```

#### Get All Records

```elixir
# Get all users
users = Actions.all(User)

# Get all active users
active_users = Actions.all(User, %{active: true})
```

#### Count Records

```elixir
# Count all users
count = Actions.count(User)

# Count active users
active_count = Actions.count(User, %{active: true})
```

### Updating Records

```elixir
# Update a user by ID
{:ok, updated_user} = Actions.update(User, 1, %{name: "Jane Doe"})

# If the record doesn't exist, it returns an error
{:error, :not_found} = Actions.update(User, 999, %{name: "Jane Doe"})
```

When updating, the function will:
1. Find the record by ID
2. Apply the updates using the schema's changeset function
3. Update the record in the database

If the record doesn't exist, it returns `{:error, %{code: :not_found}}`.

You can also customize the changeset process using the `:changeset` option, just like with `create`.

### Deleting Records

```elixir
# Delete a user by ID
{:ok, deleted_user} = Actions.delete(User, 1)

# If the record doesn't exist, it returns an error
{:error, %{code: :not_found}} = Actions.delete(User, 999)

# You can also delete an existing record directly
{:ok, deleted_user} = Actions.delete(user)
```

## Advanced Usage

### Specifying a Repo

By default, `Actions` will use the repo configured in your application. You can specify a different repo:

```elixir
# Use a specific repo
{:ok, user} = Actions.create(User, %{name: "John"}, repo: MyApp.CustomRepo)
```

### Using a Replica for Reads

If you have a read replica set up, you can use it for read operations:

```elixir
# Use a read replica
{:ok, user} = Actions.get(User, 1, replica: MyApp.ReplicaRepo)
```

### Handling Associations

The `Actions` module automatically handles associations through Ecto's changeset mechanisms:

```elixir
# Create a user with posts
{:ok, user} = Actions.create(User, %{
  name: "John Doe",
  email: "john@example.com",
  posts: [
    %{title: "Post 1", content: "Content 1"},
    %{title: "Post 2", content: "Content 2"}
  ]
})
```

### Using Filters

All read operations support the powerful filtering capabilities of `CommonFilters`:

```elixir
# Get users with age between 20 and 30, preload their posts
users = Actions.all(User, %{
  age: %{gte: 20, lte: 30},
  preload: :posts
})
```

### Transactions

You can use `Actions` within a transaction:

```elixir
alias MyApp.Repo

Repo.transaction(fn ->
  with {:ok, user} <- Actions.create(User, %{name: "John"}),
       {:ok, post} <- Actions.create(Post, %{title: "Post", user_id: user.id}) do
    {user, post}
  else
    {:error, changeset} -> Repo.rollback(changeset)
  end
end)
```

## Practical Examples

### User Registration

```elixir
defmodule MyApp.Accounts do
  alias EctoShorts.Actions
  alias MyApp.{User, Repo}

  @actions_opts [repo: Repo]

  def register_user(attrs) do
    Actions.create(User, attrs, @actions_opts)
  end
end
```

### Blog Post Management

```elixir
defmodule MyApp.Blog do
  alias EctoShorts.Actions
  alias MyApp.{Post, Repo}

  @actions_opts [repo: Repo]

  def create_post(attrs) do
    Actions.create(Post, attrs, @actions_opts)
  end

  def get_post(id, preloads \\ []) do
    Actions.get(Post, id, [preload: preloads] ++ @actions_opts)
  end

  def list_posts(filters \\ %{}) do
    Actions.all(Post, filters, @actions_opts)
  end

  def update_post(id, attrs) do
    Actions.update(Post, id, attrs, @actions_opts)
  end

  def delete_post(id) do
    Actions.delete(Post, id, @actions_opts)
  end

  def get_user_posts(user_id, filters \\ %{}) do
    filters = Map.put(filters, :user_id, user_id)
    Actions.all(Post, filters, @actions_opts)
  end
end
```

### E-commerce Order Processing

```elixir
defmodule MyApp.Orders do
  alias EctoShorts.Actions
  alias MyApp.{Order, Repo}

  @actions_opts [repo: Repo]

  def create_order(attrs) do
    Actions.create(Order, attrs, @actions_opts)
  end

  def get_order(id) do
    Actions.get(Order, id, [preload: [:items, :customer]] ++ @actions_opts)
  end

  def list_customer_orders(customer_id) do
    Actions.all(Order, %{customer_id: customer_id, preload: :items}, @actions_opts)
  end

  def update_order_status(id, status) do
    Actions.update(Order, id, %{status: status}, @actions_opts)
  end

  def cancel_order(id) do
    Actions.update(Order, id, %{status: "cancelled"}, @actions_opts)
  end
end
```

## Best Practices

1. **Create context modules**: Organize your code by creating context modules that use `Actions` to perform database operations. This encapsulates related functionality and provides a clean API.

2. **Set default options**: Define default options for `Actions` in your context modules to avoid repetition and ensure consistency.

3. **Use proper schemas**: Make sure your schemas have appropriate changeset functions and validations. Consider adding specific changeset functions for different operations (e.g., `create_changeset/1`, `update_changeset/2`).

4. **Handle errors consistently**: Always handle the error cases from `Actions` functions. Remember that most operations return `{:error, %{code: :not_found}}` when records aren't found.

5. **Use preloading wisely**: Only preload associations when you need them to avoid unnecessary database queries. You can use the `preload` filter parameter to specify which associations to load.

6. **Leverage filtering capabilities**: Take advantage of the powerful filtering capabilities provided by `CommonFilters` to write expressive and concise queries.

## Conclusion

The `Actions` module in ecto_shorts provides a consistent, powerful interface for performing CRUD operations. By abstracting away the details of Ecto's `Repo` functions and automatically handling associations and filtering, it helps you write cleaner, more maintainable code.

Key benefits of using the `Actions` module include:

- Consistent return values and error handling
- Simplified parameter handling and filtering
- Automatic handling of associations
- Support for multiple repositories and read replicas
- Flexible customization options

For more information on available options and advanced usage, see the `EctoShorts.Actions` module documentation.
