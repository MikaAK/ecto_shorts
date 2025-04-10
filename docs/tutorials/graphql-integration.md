# Building a GraphQL API with ecto_shorts

In this tutorial, we'll build a GraphQL API for a blog application using `ecto_shorts` and Absinthe. You'll learn how to create a complete API with queries and mutations while leveraging the power of `ecto_shorts` to simplify your database operations.

## What you'll learn

- How to set up a GraphQL schema with Absinthe
- How to implement resolvers using `ecto_shorts`
- How to handle complex filters and associations
- Best practices for structuring your GraphQL API

## Prerequisites

- Basic knowledge of Elixir and Phoenix
- A Phoenix application with Ecto set up
- Basic understanding of GraphQL concepts

## Step 1: Setting up your project

First, let's make sure we have all the necessary dependencies. Add the following to your `mix.exs` file:

```elixir
defp deps do
  [
    # ... other deps
    {:ecto_shorts, "~> 2.0"},
    {:absinthe, "~> 1.7"},
    {:absinthe_plug, "~> 1.5"}
  ]
end
```

Run `mix deps.get` to install the dependencies.

## Step 2: Creating your GraphQL schema

Let's create a basic GraphQL schema for our blog application. We'll define types for users and posts, along with queries and mutations:

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

## Step 3: Creating context modules

Now, let's create context modules that will handle our business logic using `ecto_shorts`. This follows the Phoenix context pattern and keeps our code organized:

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

Let's test our context functions in the IEx console:

```elixir
# Start the interactive Elixir shell
$ iex -S mix

# Try creating a user
iex> MyApp.Accounts.create_user(%{name: "Jane Doe", email: "jane@example.com", age: 28})
{:ok, %MyApp.User{id: 1, name: "Jane Doe", email: "jane@example.com", age: 28}}

# Try fetching the user
iex> MyApp.Accounts.get_user(1)
{:ok, %MyApp.User{id: 1, name: "Jane Doe", email: "jane@example.com", age: 28}}
```

This approach:
- Maintains separation of concerns
- Makes your code more testable
- Allows reuse of context functions across different parts of your application

## Step 4: Creating GraphQL resolvers

Next, let's create our resolver functions. We'll show two approaches: the recommended context-based approach and a direct approach for quick prototyping:

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

## Step 5: Testing your GraphQL API

Let's test our GraphQL API using GraphiQL, which is included with Absinthe Plug. Start your Phoenix server with `mix phx.server` and navigate to `http://localhost:4000/graphiql` in your browser.

Try running the following queries and mutations:

### Fetching a user

```graphql
query {
  user(id: "1") {
    id
    name
    email
    age
  }
}
```

### Creating a user

```graphql
mutation {
  createUser(name: "John Smith", email: "john@example.com", age: 35) {
    id
    name
    email
    age
  }
}
```

### Listing users with filters

```graphql
query {
  users(ageMin: 25, ageMax: 40) {
    id
    name
    email
    age
  }
}
```

## Step 6: Understanding the benefits of context modules

While using `ecto_shorts` directly in resolvers works, there are several reasons to prefer context modules:

1. **Separation of concerns**: Context modules separate business logic from GraphQL-specific code, following the principle of single responsibility
2. **Testability**: Context functions are easier to test in isolation without GraphQL dependencies
3. **Reusability**: Context functions can be reused across different parts of your application (REST APIs, LiveView, etc.)
4. **Maintainability**: Changes to database access patterns only need to be made in one place
5. **Consistency**: Following the Phoenix context pattern makes your code more consistent and easier for other developers to understand
6. **Error handling**: Centralized error handling and transformation can be implemented at the context level

## Step 7: Handling complex filters

As our API grows, we'll need to handle more complex filtering requirements. Let's create a helper module to convert GraphQL arguments to `ecto_shorts` filters:

```elixir
defmodule MyAppWeb.Schema.Helpers do
  @moduledoc """
  Helper functions for GraphQL resolvers, including argument conversion for ecto_shorts.
  """

  @doc """
  Converts GraphQL arguments to ecto_shorts filter parameters.
  
  Handles various filter types:
  - Direct field mappings (id, email, status)
  - Range filters with _min and _max suffixes
  - Text search with ilike
  - Global search
  - Association preloading
  - Pagination
  
  ## Examples
  
      iex> convert_args_to_filters(%{age_min: 18, age_max: 65, name: "John"})
      %{age: %{gte: 18, lte: 65}, name: %{ilike: "John"}}
  """
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

Now, let's update our resolver to use this helper:

```elixir
def list_users(_parent, args, _resolution) do
  filters = MyAppWeb.Schema.Helpers.convert_args_to_filters(args)
  {:ok, Accounts.list_users(filters)}
end
```

Let's test this with a more complex query in GraphiQL:

```graphql
query {
  users(ageMin: 25, ageMax: 40, name: "Jo", limit: 5) {
    id
    name
    email
    age
  }
}
```

This should return users with names containing "Jo" who are between 25 and 40 years old, limited to 5 results. The helper makes our resolvers more concise and maintainable, while still leveraging the full power of `ecto_shorts` filtering capabilities.

## Step 8: Optimizing associations with Dataloader and EctoShorts

When working with GraphQL APIs, efficiently loading related data is crucial for performance. Absinthe provides Dataloader to help solve the N+1 query problem, and we can integrate it with `ecto_shorts` to leverage its powerful filtering capabilities.

Let's set up Dataloader with `ecto_shorts` in our GraphQL schema:

```elixir
defmodule MyAppWeb.Schema do
  use Absinthe.Schema
  import_types MyAppWeb.Schema.Types
  import Absinthe.Resolution.Helpers, only: [dataloader: 1, dataloader: 3]

  # Configure the dataloader
  def context(ctx) do
    loader =
      Dataloader.new()
      |> Dataloader.add_source(MyApp.Accounts, data_query())
      |> Dataloader.add_source(MyApp.Blog, data_query())

    Map.put(ctx, :loader, loader)
  end

  def plugins do
    [Absinthe.Middleware.Dataloader | Absinthe.Plugin.defaults()]
  end

  # Use EctoShorts.CommonFilters for query building
  defp data_query do
    Dataloader.Ecto.new(
      MyApp.Repo,
      query: &EctoShorts.CommonFilters.convert_params_to_filter/2
    )
  end

  # Schema definition continues...
end
```

Now, let's update our user type to use Dataloader for loading posts with filtering capabilities:

```elixir
defmodule MyAppWeb.Schema.Types do
  use Absinthe.Schema.Notation
  import Absinthe.Resolution.Helpers, only: [dataloader: 1, dataloader: 3]

  object :user do
    field :id, :id
    field :name, :string
    field :email, :string
    field :age, :integer
    
    field :posts, list_of(:post) do
      # Arguments for filtering posts
      arg :limit, :integer
      arg :offset, :integer
      arg :title, :string, description: "Filter posts by title (case-insensitive)"
      arg :published, :boolean, description: "Filter by publication status"
      
      # Use dataloader with EctoShorts filtering
      resolve dataloader(MyApp.Blog, :posts, args: %{scope: &build_posts_query/2})
    end
  end
  
  # Helper function to build the query based on GraphQL arguments
  defp build_posts_query(args, _parent) do
    # Convert GraphQL arguments to EctoShorts filters
    filters = %{}
    
    # Add title filter with case-insensitive search if provided
    filters = if Map.has_key?(args, :title) do
      Map.put(filters, :title, %{ilike: "%#{args.title}%"})
    else
      filters
    end
    
    # Add published filter if provided
    filters = if Map.has_key?(args, :published) do
      Map.put(filters, :published, args.published)
    else
      filters
    end
    
    # Add pagination
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
  
  # Other type definitions...
end
```

The key benefit of this approach is that `EctoShorts.CommonFilters.convert_params_to_filter/2` handles the query building for Dataloader, allowing you to use all the powerful filtering capabilities of `ecto_shorts` in your GraphQL resolvers.

### How it works

1. We configure Dataloader to use `EctoShorts.CommonFilters.convert_params_to_filter/2` as the query builder
2. In our GraphQL field definitions, we use `dataloader/3` with a custom scope function
3. The scope function converts GraphQL arguments to `ecto_shorts` filter parameters
4. Dataloader uses these filters to efficiently load only the data needed

This approach has several advantages:

- **Solves N+1 query problems** - Dataloader batches and caches queries
- **Leverages ecto_shorts filtering** - All filter types from `ecto_shorts` are available
- **Declarative query building** - No need to write complex Ecto queries manually
- **Consistent API** - The same filtering capabilities used elsewhere in your app

Let's test this with a query that fetches a user and their posts with filtering:

```graphql
query {
  user(id: "1") {
    id
    name
    email
    posts(limit: 5, title: "elixir", published: true) {
      id
      title
      content
    }
  }
}
```

This query will efficiently fetch a user with ID 1 and their published posts that have "elixir" in the title, limited to 5 results.

## Step 9: Handling additional associations

```elixir
Let's enhance our API to handle more complex associations between resources. For example, let's add comments to posts:

```elixir
# In your GraphQL schema
object :post do
  field :id, :id
  field :title, :string
  field :content, :string
  field :published, :boolean
  field :user_id, :id
  
  field :comments, list_of(:comment) do
    arg :limit, :integer
    arg :offset, :integer
    arg :content, :string, description: "Filter comments by content"
    resolve dataloader(MyApp.Blog, :comments, args: %{scope: &build_comments_query/2})
  end
  
  field :user, :user, resolve: dataloader(MyApp.Accounts)
end

object :comment do
  field :id, :id
  field :content, :string
  field :post_id, :id
  field :user_id, :id
  
  field :user, :user, resolve: dataloader(MyApp.Accounts)
  field :post, :post, resolve: dataloader(MyApp.Blog)
end

# Helper function to build the comments query
defp build_comments_query(args, _parent) do
  filters = %{}
  
  # Add content filter with case-insensitive search if provided
  filters = if Map.has_key?(args, :content) do
    Map.put(filters, :content, %{ilike: "%#{args.content}%"})
  else
    filters
  end
  
  # Add pagination
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
```
```

Let's test this with a more complex query that demonstrates the power of Dataloader with EctoShorts:

```graphql
query {
  user(id: "1") {
    id
    name
    email
    posts(limit: 5, title: "elixir", published: true) {
      id
      title
      content
      user { # This won't cause an N+1 query problem
        name
      }
      comments(limit: 3, content: "great") {
        id
        content
        user { # This won't cause an N+1 query problem either
          name
        }
      }
    }
  }
}
```

This query demonstrates the power of Dataloader with EctoShorts:

1. It fetches a user with ID 1
2. It loads the user's published posts containing "elixir" in the title, limited to 5
3. For each post, it loads the author (which is the same user, but Dataloader will optimize this)
4. For each post, it loads up to 3 comments containing the word "great"
5. For each comment, it loads the user who wrote it

All of this is done with optimized database queries, avoiding the N+1 query problem, and using the powerful filtering capabilities of `ecto_shorts`.

## Step 10: Implementing error handling

Let's improve our API by adding proper error handling. The `EctoShorts.Actions` functions return consistent error tuples that we can transform for GraphQL responses:

```elixir
defmodule MyAppWeb.Schema.ErrorHandler do
  @doc """
  Converts ecto_shorts error tuples to GraphQL-friendly error formats
  """
  def handle_error({:error, %{code: :not_found}}) do
    {:error, message: "Resource not found"}
  end
  
  def handle_error({:error, %{code: :validation_failed, changeset: changeset}}) do
    errors = Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end)
    {:error, message: "Validation failed", details: errors}
  end
  
  def handle_error({:error, error}) do
    {:error, message: "An error occurred", details: inspect(error)}
  end
end

Now, let's update our resolvers to use this error handler:

```elixir
# In your resolver
def create_user(_parent, args, _resolution) do
  case Accounts.create_user(args) do
    {:ok, user} -> {:ok, user}
    error -> MyAppWeb.Schema.ErrorHandler.handle_error(error)
  end
end
```

Let's test error handling by trying to create a user with invalid data:

```graphql
mutation {
  createUser(name: "", email: "not-an-email") {
    id
    name
    email
  }
}
```

You should receive a structured error response that helps the client understand what went wrong.
```

## Step 11: Putting it all together

Let's review what we've built in this tutorial:

1. A GraphQL schema with types for users, posts, and comments
2. Context modules using `ecto_shorts` for database operations
3. GraphQL resolvers that leverage our context modules
4. A helper for converting GraphQL arguments to `ecto_shorts` filters
5. Dataloader integration with `ecto_shorts` for efficient relational queries
6. Support for complex nested queries with filtering at each level
7. Proper error handling for GraphQL responses

## What's next?

Now that you have a working GraphQL API powered by `ecto_shorts`, you might want to explore:

- Adding authentication and authorization
- Implementing subscriptions for real-time updates
- Adding more complex filtering options
- Optimizing performance with dataloader

## Conclusion

In this tutorial, you've learned how to build a GraphQL API using `ecto_shorts` and Absinthe. By leveraging the filtering capabilities of `ecto_shorts`, you've created a powerful and flexible API with minimal code.

The key takeaways from this tutorial are:

1. Using context modules provides better organization and maintainability
2. `ecto_shorts` simplifies database operations in GraphQL resolvers
3. Helper functions can convert GraphQL arguments to `ecto_shorts` filters
4. Proper error handling improves the API experience

By following these patterns, you can build GraphQL APIs that are maintainable, testable, and take full advantage of `ecto_shorts` for simplified database access.
