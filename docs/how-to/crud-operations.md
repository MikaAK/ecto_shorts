# How to Use Actions for CRUD Operations

This guide shows you how to use the `Actions` module in ecto_shorts to simplify your Create, Read, Update, and Delete (CRUD) operations.

## Understanding Actions

The `Actions` module provides a consistent interface for performing common database operations. It wraps Ecto's `Repo` functions with additional functionality, such as automatic handling of associations and filtering.

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
2. If not found, it will fall back to `changeset/2`
3. Apply the changeset to a new struct
4. Insert the record into the database

#### Custom Changeset Function

You can specify a custom changeset function:

```elixir
{:ok, user} = Actions.create(User, %{name: "John Doe"}, changeset_fun: :sign_up_changeset)
```

This will call `User.sign_up_changeset(%User{}, %{name: "John Doe"})`.

### Reading Records

#### Get a Record by ID

```elixir
# Get a user by ID
{:ok, user} = Actions.get(User, 1)

# If the record doesn't exist, it returns an error
{:error, :not_found} = Actions.get(User, 999)
```

#### Get a Record by Attributes

```elixir
# Get a user by email
{:ok, user} = Actions.get_by(User, %{email: "john@example.com"})

# If no record matches, it returns an error
{:error, :not_found} = Actions.get_by(User, %{email: "nonexistent@example.com"})
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

Like `create`, `update` will look for an `update_changeset/2` function on your schema, falling back to `changeset/2` if not found.

### Deleting Records

```elixir
# Delete a user by ID
{:ok, deleted_user} = Actions.delete(User, 1)

# If the record doesn't exist, it returns an error
{:error, :not_found} = Actions.delete(User, 999)
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

The `Actions` module automatically handles associations using `CommonChanges`:

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

All read operations support the same filters as `CommonFilters`:

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

1. **Create context modules**: Organize your code by creating context modules that use `Actions` to perform database operations.

2. **Set default options**: Define default options for `Actions` in your context modules to avoid repetition.

3. **Use proper schemas**: Make sure your schemas have appropriate changeset functions and validations.

4. **Handle errors**: Always handle the error cases from `Actions` functions, especially for operations that can return `{:error, :not_found}`.

5. **Use preloading wisely**: Only preload associations when you need them to avoid unnecessary database queries.

## Conclusion

The `Actions` module in ecto_shorts provides a consistent, powerful interface for performing CRUD operations. By abstracting away the details of Ecto's `Repo` functions and automatically handling associations and filtering, it helps you write cleaner, more maintainable code.

For more information on available options, see the [Actions Reference](../reference/actions.md).
