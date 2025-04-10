# Best Practices

This document outlines best practices for using ecto_shorts effectively in your Elixir applications.

## Organizing Your Code

### Create Context Modules

Organize your code into context modules that encapsulate related functionality:

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

  def list_users(filters \\ %{}) do
    Actions.all(User, filters, @actions_opts)
  end

  # More functions...
end
```

This approach:
- Keeps your code organized and maintainable
- Provides a clear API for other parts of your application
- Allows you to add domain-specific logic as needed

### Set Default Options

Define default options for `Actions` in your context modules to avoid repetition:

```elixir
defmodule MyApp.Accounts do
  alias EctoShorts.Actions
  alias MyApp.{Repo, User}

  @actions_opts [repo: Repo]

  # Functions using @actions_opts...
end
```

For read-heavy applications with a read replica:

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

  # More functions...
end
```

## Schema Design

### Define Appropriate Changeset Functions

Define appropriate changeset functions in your schemas:

```elixir
defmodule MyApp.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field :name, :string
    field :email, :string
    field :password, :string, virtual: true
    field :password_hash, :string
    timestamps()
  end

  # For general updates
  def changeset(user, attrs) do
    user
    |> cast(attrs, [:name, :email])
    |> validate_required([:name, :email])
    |> unique_constraint(:email)
  end

  # For creating new users
  def create_changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, [:name, :email, :password])
    |> validate_required([:name, :email, :password])
    |> validate_length(:password, min: 8)
    |> hash_password()
  end

  # For updating user profiles
  def update_changeset(user, attrs) do
    user
    |> cast(attrs, [:name, :bio])
    |> validate_required([:name])
  end

  # For changing passwords
  def password_changeset(user, attrs) do
    user
    |> cast(attrs, [:password])
    |> validate_required([:password])
    |> validate_length(:password, min: 8)
    |> hash_password()
  end

  defp hash_password(changeset) do
    case changeset do
      %{valid?: true, changes: %{password: password}} ->
        put_change(changeset, :password_hash, Bcrypt.hash_pwd_salt(password))
      _ ->
        changeset
    end
  end
end
```

This approach:
- Provides specialized changesets for different operations
- Ensures proper validation for each operation
- Works seamlessly with ecto_shorts' `Actions` module

### Implement `by_search/2` for Custom Search

Implement the `by_search/2` function in your schemas to enable custom search functionality:

```elixir
defmodule MyApp.User do
  # Schema definition...

  def by_search(query, search_term) do
    search_pattern = "%#{search_term}%"
    
    import Ecto.Query
    from u in query,
      where: ilike(u.name, ^search_pattern) or ilike(u.email, ^search_pattern)
  end
end
```

This allows you to use the `search` filter parameter:

```elixir
# Search for users with "john" in their name or email
MyApp.Accounts.list_users(%{search: "john"})
```

## Filtering Best Practices

### Start with Simple Filters

Begin with simple filters and add complexity as needed:

```elixir
# Start with basic filters
users = MyApp.Accounts.list_users(%{active: true})

# Add more filters as needed
users = MyApp.Accounts.list_users(%{
  active: true,
  age: %{gte: 18},
  name: %{ilike: "john"}
})
```

### Use Preloading Wisely

Only preload associations that you actually need:

```elixir
# Good: Only preload what you need
user = MyApp.Accounts.get_user(1, preload: :posts)

# Better: Only preload specific associations when needed
user = MyApp.Accounts.get_user(1)
posts = MyApp.Blog.list_posts(%{user_id: user.id})
```

### Consider Performance

Be mindful of the performance implications of complex filters:

```elixir
# This could be expensive if there are many users
users = MyApp.Accounts.list_users(%{
  preload: [:posts, :comments, :roles],
  search: "john"
})

# Consider pagination
users = MyApp.Accounts.list_users(%{
  preload: [:posts],
  search: "john",
  first: 10
})
```

### Validate User Input

When converting user input to filter parameters, validate the input to prevent security issues:

```elixir
defmodule MyAppWeb.UserController do
  use MyAppWeb, :controller
  alias MyApp.Accounts

  def index(conn, params) do
    # Validate and sanitize user input
    filters = sanitize_filters(params)
    
    users = Accounts.list_users(filters)
    render(conn, :index, users: users)
  end
  
  defp sanitize_filters(params) do
    # Extract only allowed filters
    allowed_keys = ~w(name email age search)
    
    params
    |> Map.take(allowed_keys)
    |> Map.new(fn {k, v} -> {String.to_existing_atom(k), v} end)
  end
end
```

## Association Handling

### Use IDs for Existing Records

When referencing existing records in associations, use their IDs rather than trying to recreate the entire record:

```elixir
# Good: Use IDs for existing records
{:ok, post} = MyApp.Blog.create_post(%{
  title: "My Post",
  content: "Post content",
  user_id: user.id
})

# Better: Use IDs for many-to-many relationships
{:ok, user} = MyApp.Accounts.update_user(user.id, %{
  roles: [1, 2, 3]  # List of role IDs
})
```

### Be Careful with Nested Associations

While ecto_shorts makes it easier to work with nested associations, be mindful of the potential performance impact:

```elixir
# This could be expensive if there are many nested records
{:ok, user} = MyApp.Accounts.create_user(%{
  name: "John",
  posts: [
    %{
      title: "Post 1",
      comments: [
        %{content: "Comment 1"},
        %{content: "Comment 2"}
      ]
    },
    %{
      title: "Post 2",
      comments: [
        %{content: "Comment 3"}
      ]
    }
  ]
})

# Consider creating records separately
{:ok, user} = MyApp.Accounts.create_user(%{name: "John"})
{:ok, post} = MyApp.Blog.create_post(%{title: "Post 1", user_id: user.id})
{:ok, _comment} = MyApp.Blog.create_comment(%{content: "Comment 1", post_id: post.id})
```

### Validate Associations

Add appropriate foreign key constraints and validations to ensure data integrity:

```elixir
defmodule MyApp.Post do
  use Ecto.Schema
  import Ecto.Changeset

  schema "posts" do
    field :title, :string
    field :content, :string
    belongs_to :user, MyApp.User
    timestamps()
  end

  def changeset(post, attrs) do
    post
    |> cast(attrs, [:title, :content, :user_id])
    |> validate_required([:title, :content, :user_id])
    |> foreign_key_constraint(:user_id)
  end
end
```

## Error Handling

### Handle All Error Cases

Always handle the error cases from `Actions` functions:

```elixir
def update_user(conn, %{"id" => id, "user" => user_params}) do
  case MyApp.Accounts.update_user(id, user_params) do
    {:ok, user} ->
      conn
      |> put_flash(:info, "User updated successfully.")
      |> redirect(to: Routes.user_path(conn, :show, user))

    {:error, :not_found} ->
      conn
      |> put_flash(:error, "User not found.")
      |> redirect(to: Routes.user_path(conn, :index))

    {:error, %Ecto.Changeset{} = changeset} ->
      render(conn, :edit, user_id: id, changeset: changeset)
  end
end
```

### Use Transactions for Multi-Step Operations

Use transactions for operations that need to be atomic:

```elixir
def create_user_with_profile(user_params, profile_params) do
  alias MyApp.{Repo, Accounts, Profiles}

  Repo.transaction(fn ->
    with {:ok, user} <- Accounts.create_user(user_params),
         {:ok, profile} <- Profiles.create_profile(Map.put(profile_params, :user_id, user.id)) do
      {user, profile}
    else
      {:error, changeset} -> Repo.rollback(changeset)
    end
  end)
end
```

## Testing

### Mock the Repo in Tests

In tests, you can mock the repo to avoid hitting the database:

```elixir
# In your test helper
Mox.defmock(MockRepo, for: Ecto.Repo)

# In your test
test "create_user/1 creates a user" do
  user_params = %{name: "John", email: "john@example.com"}
  
  MockRepo
  |> expect(:insert, fn changeset ->
    assert changeset.changes.name == "John"
    assert changeset.changes.email == "john@example.com"
    {:ok, Ecto.Changeset.apply_changes(changeset)}
  end)
  
  assert {:ok, user} = MyApp.Accounts.create_user(user_params, repo: MockRepo)
  assert user.name == "John"
  assert user.email == "john@example.com"
end
```

### Test Context Modules

Write tests for your context modules to ensure they work as expected:

```elixir
defmodule MyApp.AccountsTest do
  use MyApp.DataCase
  
  alias MyApp.Accounts
  
  describe "users" do
    test "list_users/1 returns users matching filters" do
      user1 = insert(:user, name: "John", age: 25)
      user2 = insert(:user, name: "Jane", age: 30)
      
      assert [user1] = Accounts.list_users(%{name: "John"})
      assert [user2] = Accounts.list_users(%{age: %{gte: 30}})
      assert [user1, user2] = Accounts.list_users(%{})
    end
    
    test "create_user/1 creates a user" do
      assert {:ok, user} = Accounts.create_user(%{name: "John", email: "john@example.com"})
      assert user.name == "John"
      assert user.email == "john@example.com"
    end
    
    test "create_user/1 validates data" do
      assert {:error, changeset} = Accounts.create_user(%{})
      assert "can't be blank" in errors_on(changeset).name
    end
  end
end
```

## Performance Optimization

### Use Indexes

Create appropriate database indexes for fields you frequently filter on:

```elixir
defmodule MyApp.Repo.Migrations.AddIndexes do
  use Ecto.Migration

  def change do
    create index(:users, [:email])
    create index(:posts, [:user_id])
    create index(:comments, [:post_id])
  end
end
```

### Consider Pagination

Use pagination for large result sets:

```elixir
# Get the first page of results
page1 = MyApp.Accounts.list_users(%{first: 10})

# Get the next page using the last ID from the previous page
last_id = List.last(page1).id
page2 = MyApp.Accounts.list_users(%{first: 10, after: last_id})
```

### Use Read Replicas

For read-heavy applications, consider using read replicas:

```elixir
defmodule MyApp.Accounts do
  alias EctoShorts.Actions
  alias MyApp.{Repo, ReplicaRepo, User}

  @read_opts [repo: Repo, replica: ReplicaRepo]

  def get_user(id) do
    Actions.get(User, id, @read_opts)
  end

  def list_users(filters \\ %{}) do
    Actions.all(User, filters, @read_opts)
  end
end
```

## Documentation

### Document Your Context Modules

Document your context modules and functions:

```elixir
defmodule MyApp.Accounts do
  @moduledoc """
  The Accounts context.
  
  This context handles user-related functionality, including
  creating, reading, updating, and deleting users.
  """
  
  alias EctoShorts.Actions
  alias MyApp.{Repo, User}
  
  @actions_opts [repo: Repo]
  
  @doc """
  Creates a new user.
  
  ## Examples
  
      iex> create_user(%{name: "John", email: "john@example.com"})
      {:ok, %User{}}
      
      iex> create_user(%{})
      {:error, %Ecto.Changeset{}}
  """
  def create_user(attrs) do
    Actions.create(User, attrs, @actions_opts)
  end
  
  # More documented functions...
end
```

### Document Custom Filters

If you implement custom filters, make sure to document them:

```elixir
defmodule MyApp.CustomFilters do
  @moduledoc """
  Custom filters for MyApp.
  
  This module extends EctoShorts.CommonFilters with custom filtering logic.
  """
  
  @doc """
  Converts a map of parameters into an Ecto query.
  
  Supports the following custom filters:
  
  - `published_only: true` - Only returns published records
  - `min_likes: n` - Only returns records with at least n likes
  - `trending: true` - Only returns trending records (created in the last week, ordered by view count)
  
  ## Examples
  
      iex> convert_params_to_filter(Post, %{published_only: true})
      #Ecto.Query<...>
  """
  def convert_params_to_filter(queryable, params, opts \\ []) do
    # Implementation...
  end
end
```

## Conclusion

Following these best practices will help you make the most of ecto_shorts in your Elixir applications. By organizing your code effectively, designing your schemas appropriately, and being mindful of performance and error handling, you can build robust, maintainable applications with ecto_shorts.

Remember that these are guidelines, not strict rules. Adapt them to your specific needs and preferences, and don't be afraid to experiment with different approaches to find what works best for your project.
