# How to Use ecto_shorts with GraphQL

This guide shows you how to integrate ecto_shorts with GraphQL APIs built using Absinthe in Elixir applications.

## Prerequisites

- Basic knowledge of GraphQL and Absinthe
- A working Phoenix application with ecto_shorts installed
- Absinthe set up in your application

## Setting Up Your GraphQL Schema

First, let's set up a basic GraphQL schema with Absinthe:

```elixir
defmodule MyAppWeb.Schema do
  use Absinthe.Schema
  import_types MyAppWeb.Schema.Types

  query do
    @desc "Get a user by ID"
    field :user, :user do
      arg :id, non_null(:id)
      resolve &MyAppWeb.Schema.Resolvers.Accounts.get_user/3
    end

    @desc "List users with optional filters"
    field :users, list_of(:user) do
      arg :name, :string
      arg :email, :string
      arg :age_min, :integer
      arg :age_max, :integer
      arg :search, :string
      arg :preload, list_of(:string)
      resolve &MyAppWeb.Schema.Resolvers.Accounts.list_users/3
    end
  end

  mutation do
    @desc "Create a new user"
    field :create_user, :user do
      arg :name, non_null(:string)
      arg :email, non_null(:string)
      arg :age, :integer
      resolve &MyAppWeb.Schema.Resolvers.Accounts.create_user/3
    end

    @desc "Update a user"
    field :update_user, :user do
      arg :id, non_null(:id)
      arg :name, :string
      arg :email, :string
      arg :age, :integer
      resolve &MyAppWeb.Schema.Resolvers.Accounts.update_user/3
    end

    @desc "Delete a user"
    field :delete_user, :user do
      arg :id, non_null(:id)
      resolve &MyAppWeb.Schema.Resolvers.Accounts.delete_user/3
    end
  end
end

defmodule MyAppWeb.Schema.Types do
  use Absinthe.Schema.Notation

  object :user do
    field :id, :id
    field :name, :string
    field :email, :string
    field :age, :integer
    field :posts, list_of(:post)
  end

  object :post do
    field :id, :id
    field :title, :string
    field :content, :string
    field :user_id, :id
  end
end
```

## Best Practice: Using Context Modules

The recommended approach is to use context modules that leverage ecto_shorts internally:

```elixir
# Context module
defmodule MyApp.Accounts do
  alias EctoShorts.Actions
  alias MyApp.{Repo, User}

  @actions_opts [repo: Repo]

  def get_user(id) do
    Actions.get(User, id, @actions_opts)
  end

  def list_users(filters \\ %{}) do
    Actions.all(User, filters, @actions_opts)
  end

  def create_user(attrs) do
    Actions.create(User, attrs, @actions_opts)
  end

  def update_user(id, attrs) do
    Actions.update(User, id, attrs, @actions_opts)
  end

  def delete_user(id) do
    Actions.delete(User, id, @actions_opts)
  end
end

# Resolver module
defmodule MyAppWeb.Schema.Resolvers.Accounts do
  alias MyApp.Accounts

  def get_user(_parent, %{id: id}, _resolution) do
    Accounts.get_user(id)
  end

  def list_users(_parent, args, _resolution) do
    # Convert GraphQL args to ecto_shorts filters
    filters = args
    |> Map.take([:id, :email])
    |> Map.new(fn {k, v} -> {k, v} end)

    # Handle range filters
    filters = if Map.has_key?(args, :age_min) or Map.has_key?(args, :age_max) do
      age_filter = %{}
      age_filter = if Map.has_key?(args, :age_min), do: Map.put(age_filter, :gte, args.age_min), else: age_filter
      age_filter = if Map.has_key?(args, :age_max), do: Map.put(age_filter, :lte, args.age_max), else: age_filter
      Map.put(filters, :age, age_filter)
    else
      filters
    end

    # Handle name filter (ilike)
    filters = if Map.has_key?(args, :name) do
      Map.put(filters, :name, %{ilike: args.name})
    else
      filters
    end

    # Handle search
    filters = if Map.has_key?(args, :search) do
      Map.put(filters, :search, args.search)
    else
      filters
    end

    # Handle preloads
    filters = if Map.has_key?(args, :preload) do
      preloads = args.preload |> Enum.map(&String.to_existing_atom/1)
      Map.put(filters, :preload, preloads)
    else
      filters
    end

    {:ok, Accounts.list_users(filters)}
  end

  def create_user(_parent, args, _resolution) do
    Accounts.create_user(args)
  end

  def update_user(_parent, %{id: id} = args, _resolution) do
    attrs = Map.drop(args, [:id])
    Accounts.update_user(id, attrs)
  end

  def delete_user(_parent, %{id: id}, _resolution) do
    Accounts.delete_user(id)
  end
end
```

This approach:
- Maintains separation of concerns
- Makes your code more testable
- Allows reuse of context functions across different parts of your application

## Direct ecto_shorts Usage in Resolvers

While not recommended for production applications, you can use ecto_shorts directly in resolvers for quick prototyping or simpler applications:

```elixir
defmodule MyAppWeb.Schema.Resolvers.Accounts do
  alias EctoShorts.Actions
  alias MyApp.{Repo, User}

  @actions_opts [repo: Repo]

  def get_user(_parent, %{id: id}, _resolution) do
    # Note: While this works, it's generally better practice to use a context module
    # This approach is shown for demonstration purposes only
    Actions.get(User, id, @actions_opts)
  end

  def list_users(_parent, args, _resolution) do
    # Convert GraphQL args to ecto_shorts filters
    filters = args
    |> Map.take([:id, :email])
    |> Map.new(fn {k, v} -> {k, v} end)

    # Handle range filters
    filters = if Map.has_key?(args, :age_min) or Map.has_key?(args, :age_max) do
      age_filter = %{}
      age_filter = if Map.has_key?(args, :age_min), do: Map.put(age_filter, :gte, args.age_min), else: age_filter
      age_filter = if Map.has_key?(args, :age_max), do: Map.put(age_filter, :lte, args.age_max), else: age_filter
      Map.put(filters, :age, age_filter)
    else
      filters
    end

    # Handle name filter (ilike)
    filters = if Map.has_key?(args, :name) do
      Map.put(filters, :name, %{ilike: args.name})
    else
      filters
    end

    # Handle search
    filters = if Map.has_key?(args, :search) do
      Map.put(filters, :search, args.search)
    else
      filters
    end

    # Handle preloads
    filters = if Map.has_key?(args, :preload) do
      preloads = args.preload |> Enum.map(&String.to_existing_atom/1)
      Map.put(filters, :preload, preloads)
    else
      filters
    end

    # Note: While this works, it's generally better practice to use a context module
    # This approach is shown for demonstration purposes only
    {:ok, Actions.all(User, filters, @actions_opts)}
  end

  def create_user(_parent, args, _resolution) do
    # Note: While this works, it's generally better practice to use a context module
    # This approach is shown for demonstration purposes only
    Actions.create(User, args, @actions_opts)
  end

  def update_user(_parent, %{id: id} = args, _resolution) do
    # Note: While this works, it's generally better practice to use a context module
    # This approach is shown for demonstration purposes only
    attrs = Map.drop(args, [:id])
    Actions.update(User, id, attrs, @actions_opts)
  end

  def delete_user(_parent, %{id: id}, _resolution) do
    # Note: While this works, it's generally better practice to use a context module
    # This approach is shown for demonstration purposes only
    Actions.delete(User, id, @actions_opts)
  end
end
```

## Why Context Modules Are Better

While using ecto_shorts directly in resolvers works, there are several reasons to prefer context modules:

1. **Separation of concerns**: Context modules separate business logic from GraphQL-specific code
2. **Testability**: Context functions are easier to test in isolation
3. **Reusability**: Context functions can be reused across different parts of your application
4. **Maintainability**: Changes to database access patterns only need to be made in one place
5. **Consistency**: Following the Phoenix context pattern makes your code more consistent and easier for other developers to understand

## Handling Complex Filters

For complex GraphQL filtering needs, you can create a helper function to convert GraphQL arguments to ecto_shorts filters:

```elixir
defmodule MyAppWeb.Schema.Helpers do
  def convert_args_to_filters(args) do
    # Start with direct mappings
    filters = args
    |> Map.take([:id, :email, :status])
    |> Map.new(fn {k, v} -> {k, v} end)

    # Handle range filters
    filters = Enum.reduce([:age, :price, :rating], filters, fn field, acc ->
      min_key = String.to_atom("#{field}_min")
      max_key = String.to_atom("#{field}_max")
      
      if Map.has_key?(args, min_key) or Map.has_key?(args, max_key) do
        range_filter = %{}
        range_filter = if Map.has_key?(args, min_key), do: Map.put(range_filter, :gte, args[min_key]), else: range_filter
        range_filter = if Map.has_key?(args, max_key), do: Map.put(range_filter, :lte, args[max_key]), else: range_filter
        Map.put(acc, field, range_filter)
      else
        acc
      end
    end)

    # Handle text search filters
    text_fields = [:name, :title, :description]
    filters = Enum.reduce(text_fields, filters, fn field, acc ->
      if Map.has_key?(args, field) do
        Map.put(acc, field, %{ilike: args[field]})
      else
        acc
      end
    end)

    # Handle search
    filters = if Map.has_key?(args, :search) do
      Map.put(filters, :search, args.search)
    else
      filters
    end

    # Handle preloads
    filters = if Map.has_key?(args, :preload) do
      preloads = args.preload |> Enum.map(&String.to_existing_atom/1)
      Map.put(filters, :preload, preloads)
    else
      filters
    end

    # Handle pagination
    filters = if Map.has_key?(args, :limit) do
      Map.put(filters, :first, args.limit)
    else
      filters
    end

    filters = if Map.has_key?(args, :offset) do
      Map.put(filters, :offset, args.offset)
    else
      filters
    end

    filters
  end
end
```

Then use it in your resolvers:

```elixir
def list_users(_parent, args, _resolution) do
  filters = MyAppWeb.Schema.Helpers.convert_args_to_filters(args)
  {:ok, Accounts.list_users(filters)}
end
```

## Handling Associations in GraphQL

ecto_shorts makes it easy to handle associations in GraphQL:

```elixir
# In your GraphQL schema
object :user do
  field :id, :id
  field :name, :string
  field :email, :string
  field :posts, list_of(:post) do
    arg :limit, :integer
    arg :offset, :integer
    resolve &MyAppWeb.Schema.Resolvers.Accounts.get_user_posts/3
  end
end

# In your resolver
def get_user_posts(user, args, _resolution) do
  filters = MyAppWeb.Schema.Helpers.convert_args_to_filters(args)
  filters = Map.put(filters, :user_id, user.id)
  
  {:ok, MyApp.Blog.list_posts(filters)}
end
```

## Conclusion

ecto_shorts integrates well with GraphQL APIs, providing a clean way to handle database operations in your resolvers. While you can use ecto_shorts directly in resolvers, it's generally better practice to use context modules that leverage ecto_shorts internally.

By following the patterns described in this guide, you can build GraphQL APIs that are maintainable, testable, and leverage the power of ecto_shorts for simplified database access.
