# Comparison with Other Approaches

This document compares ecto_shorts with other approaches to working with Ecto in Elixir applications, highlighting the differences, advantages, and trade-offs.

## Standard Ecto

The most common alternative to ecto_shorts is using Ecto directly with custom context modules, as recommended in the Phoenix guides.

### Standard Ecto Approach

```elixir
defmodule MyApp.Accounts do
  alias MyApp.{Repo, User}
  
  def create_user(attrs) do
    %User{}
    |> User.changeset(attrs)
    |> Repo.insert()
  end
  
  def get_user(id) do
    User
    |> Repo.get(id)
    |> case do
      nil -> {:error, :not_found}
      user -> {:ok, user}
    end
  end
  
  def get_user_by_email(email) do
    User
    |> Repo.get_by(email: email)
    |> case do
      nil -> {:error, :not_found}
      user -> {:ok, user}
    end
  end
  
  def list_users(opts \\ []) do
    query = User
    
    query = if Keyword.has_key?(opts, :age_min) do
      from u in query, where: u.age >= ^opts[:age_min]
    else
      query
    end
    
    query = if Keyword.has_key?(opts, :age_max) do
      from u in query, where: u.age <= ^opts[:age_max]
    else
      query
    end
    
    query = if Keyword.has_key?(opts, :search) do
      search_pattern = "%#{opts[:search]}%"
      from u in query, where: ilike(u.name, ^search_pattern) or ilike(u.email, ^search_pattern)
    else
      query
    end
    
    query = if Keyword.has_key?(opts, :roles) do
      from u in query,
        join: r in assoc(u, :roles),
        where: r.name in ^opts[:roles]
    else
      query
    end
    
    query = if Keyword.has_key?(opts, :preload) do
      from u in query, preload: ^opts[:preload]
    else
      query
    end
    
    query = if Keyword.has_key?(opts, :limit) do
      from u in query, limit: ^opts[:limit]
    else
      query
    end
    
    Repo.all(query)
  end
  
  def update_user(user, attrs) do
    user
    |> User.changeset(attrs)
    |> Repo.update()
  end
  
  def delete_user(id) do
    with {:ok, user} <- get_user(id) do
      Repo.delete(user)
    end
  end
end
```

### ecto_shorts Approach

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

With ecto_shorts, you can use the following filter syntax:

```elixir
# Get users with age between 20 and 30, with "john" in their name or email,
# who have admin or moderator roles, preload their posts,
# and limit to 10 results
MyApp.Accounts.list_users(%{
  age: %{gte: 20, lte: 30},
  search: "john",
  roles: ["admin", "moderator"],
  preload: :posts,
  first: 10
})
```

### Comparison

**Advantages of ecto_shorts:**

1. **Less boilerplate**: ecto_shorts requires significantly less code to achieve the same functionality.
2. **Declarative filtering**: The parameter-based filtering system is more readable and maintainable.
3. **Consistent return values**: All functions return `{:ok, result}` or `{:error, reason}`.
4. **Automatic association handling**: ecto_shorts intelligently handles associations.

**Advantages of standard Ecto:**

1. **More control**: You have more fine-grained control over query building.
2. **No dependencies**: You don't need an additional dependency.
3. **Standard approach**: It follows the approach recommended in the Phoenix guides.

## Ecto.Query.API Extensions

Some projects extend Ecto.Query.API with custom macros to simplify query building.

### Ecto.Query.API Extension Approach

```elixir
defmodule MyApp.QueryHelpers do
  import Ecto.Query
  
  defmacro search(field, value) do
    quote do
      ilike(unquote(field), "%#{unquote(value)}%")
    end
  end
  
  def apply_filters(query, filters) do
    Enum.reduce(filters, query, fn
      {:age_min, value}, query ->
        from q in query, where: q.age >= ^value
        
      {:age_max, value}, query ->
        from q in query, where: q.age <= ^value
        
      {:search, value}, query ->
        search_pattern = "%#{value}%"
        from q in query, where: ilike(q.name, ^search_pattern) or ilike(q.email, ^search_pattern)
        
      {:roles, value}, query ->
        from q in query,
          join: r in assoc(q, :roles),
          where: r.name in ^value
          
      {:preload, value}, query ->
        from q in query, preload: ^value
        
      {:limit, value}, query ->
        from q in query, limit: ^value
        
      _, query -> query
    end)
  end
end

defmodule MyApp.Accounts do
  import Ecto.Query
  import MyApp.QueryHelpers
  alias MyApp.{Repo, User}
  
  def list_users(filters \\ []) do
    User
    |> apply_filters(filters)
    |> Repo.all()
  end
end
```

### Comparison

**Advantages of ecto_shorts:**

1. **More comprehensive**: ecto_shorts provides a complete solution for CRUD operations, not just query building.
2. **Declarative filtering**: The parameter-based filtering system is more declarative and easier to use.
3. **Built-in support for common patterns**: ecto_shorts includes built-in support for pagination, association filtering, and more.

**Advantages of Ecto.Query.API extensions:**

1. **Custom tailored**: You can create extensions that are tailored to your specific needs.
2. **More control**: You have more control over how queries are built.
3. **No dependencies**: You don't need an additional dependency.

## ORM-like Libraries

Some libraries, like [Ash](https://ash-hq.org/) or [Ecto.Rut](https://github.com/sheharyarn/ecto_rut), provide ORM-like abstractions on top of Ecto.

### Ash Approach

```elixir
defmodule MyApp.Accounts.User do
  use Ash.Resource,
    data_layer: Ash.DataLayer.Ecto

  attributes do
    uuid_primary_key :id
    attribute :name, :string
    attribute :email, :string
    attribute :age, :integer
  end

  relationships do
    has_many :posts, MyApp.Blog.Post
    many_to_many :roles, MyApp.Accounts.Role
  end

  actions do
    defaults [:create, :read, :update, :destroy]

    read :by_email do
      argument :email, :string
      filter expr(email == ^arg.email)
    end
  end
end

# Usage
import Ash.Query

MyApp.Accounts.User
|> filter(age >= 20 and age <= 30)
|> filter(name == "John")
|> load(:posts)
|> limit(10)
|> MyApp.Ash.read!()
```

### Ecto.Rut Approach

```elixir
defmodule MyApp.Accounts do
  use Ecto.Rut.Service, repo: MyApp.Repo, schema: MyApp.User
end

# Usage
MyApp.Accounts.all(age: [gte: 20, lte: 30], name: "John", preload: :posts, limit: 10)
```

### Comparison

**Advantages of ecto_shorts:**

1. **Lighter weight**: ecto_shorts is a lighter-weight solution that focuses specifically on simplifying Ecto usage.
2. **Closer to Ecto**: ecto_shorts stays closer to Ecto's design, making it easier to adopt for teams already familiar with Ecto.
3. **More flexible**: ecto_shorts provides more flexibility in how you structure your application.

**Advantages of ORM-like libraries:**

1. **More comprehensive**: Libraries like Ash provide more comprehensive solutions that go beyond database operations.
2. **More features**: These libraries often include additional features like authorization, validation, and more.
3. **More opinionated**: They provide more guidance on how to structure your application.

## Custom Context Modules with Helper Functions

Many projects create custom context modules with helper functions to reduce boilerplate.

### Custom Context Module Approach

```elixir
defmodule MyApp.Context do
  defmacro __using__(opts) do
    repo = Keyword.get(opts, :repo, MyApp.Repo)
    
    quote do
      import Ecto.Query
      
      def create(schema, attrs) do
        struct = struct(schema)
        
        struct
        |> schema.changeset(attrs)
        |> unquote(repo).insert()
      end
      
      def get(schema, id) do
        unquote(repo).get(schema, id)
        |> case do
          nil -> {:error, :not_found}
          record -> {:ok, record}
        end
      end
      
      def get_by(schema, attrs) do
        unquote(repo).get_by(schema, attrs)
        |> case do
          nil -> {:error, :not_found}
          record -> {:ok, record}
        end
      end
      
      def update(schema, id, attrs) do
        with {:ok, record} <- get(schema, id) do
          record
          |> schema.changeset(attrs)
          |> unquote(repo).update()
        end
      end
      
      def delete(schema, id) do
        with {:ok, record} <- get(schema, id) do
          unquote(repo).delete(record)
        end
      end
    end
  end
end

defmodule MyApp.Accounts do
  use MyApp.Context, repo: MyApp.Repo
  alias MyApp.User
  
  def create_user(attrs), do: create(User, attrs)
  def get_user(id), do: get(User, id)
  def update_user(id, attrs), do: update(User, id, attrs)
  def delete_user(id), do: delete(User, id)
end
```

### Comparison

**Advantages of ecto_shorts:**

1. **More comprehensive**: ecto_shorts provides a more comprehensive solution with advanced features like filtering and association handling.
2. **Maintained package**: ecto_shorts is a maintained package with documentation, tests, and community support.
3. **No need to reinvent the wheel**: You don't need to create and maintain your own helper functions.

**Advantages of custom context modules:**

1. **Tailored to your needs**: You can create helper functions that are tailored to your specific needs.
2. **No dependencies**: You don't need an additional dependency.
3. **Complete control**: You have complete control over how the helper functions work.

## When to Choose ecto_shorts

ecto_shorts is a good choice when:

1. **You want to reduce boilerplate**: If you find yourself writing similar code patterns repeatedly, ecto_shorts can help reduce boilerplate.

2. **You need declarative filtering**: If you need to build complex queries based on user input or application logic, ecto_shorts' parameter-based filtering system can simplify this.

3. **You want consistent return values**: If you want consistent return values from your database operations, ecto_shorts provides this out of the box.

4. **You work with associations**: If you work with associations, especially many-to-many relationships, ecto_shorts can simplify this.

5. **You're building a CRUD-heavy application**: If your application is heavy on CRUD operations, ecto_shorts can significantly reduce the amount of code you need to write.

## GraphQL Integration

When building GraphQL APIs with Elixir (typically using [Absinthe](https://github.com/absinthe-graphql/absinthe)), ecto_shorts can simplify your resolver functions.

### Standard Approach with Ecto

```elixir
defmodule MyAppWeb.Schema.Resolvers.Accounts do
  alias MyApp.{Repo, User}
  
  def get_user(_parent, %{id: id}, _resolution) do
    case Repo.get(User, id) do
      nil -> {:error, "User not found"}
      user -> {:ok, user}
    end
  end
  
  def list_users(_parent, args, _resolution) do
    query = User
    
    query = if Map.has_key?(args, :name) do
      name_pattern = "%#{args.name}%"
      from u in query, where: ilike(u.name, ^name_pattern)
    else
      query
    end
    
    query = if Map.has_key?(args, :age_min) do
      from u in query, where: u.age >= ^args.age_min
    else
      query
    end
    
    {:ok, Repo.all(query)}
  end
  
  # More resolver functions...
end
```

### ecto_shorts Approach

```elixir
defmodule MyAppWeb.Schema.Resolvers.Accounts do
  alias EctoShorts.Actions
  alias MyApp.{Repo, User}
  
  @actions_opts [repo: Repo]
  
  def get_user(_parent, %{id: id}, _resolution) do
    # Note: While this works, it's generally better practice to use a context module
    # This approach is shown for comparison purposes only
    Actions.get(User, id, @actions_opts)
  end
  
  def list_users(_parent, args, _resolution) do
    # Convert GraphQL args to ecto_shorts filters
    filters = args
    |> Map.take([:id, :email, :age_min, :age_max])
    |> Map.new(fn
      {:age_min, value} -> {:age, %{gte: value}}
      {:age_max, value} -> {:age, %{lte: value}}
      {k, v} -> {k, v}
    end)
    |> Map.put_new(:preload, args[:preload] || [])
    
    # Add search if present
    filters = if Map.has_key?(args, :search) do
      Map.put(filters, :search, args.search)
    else
      filters
    end
    
    # Note: While this works, it's generally better practice to use a context module
    # This approach is shown for comparison purposes only
    {:ok, Actions.all(User, filters, @actions_opts)}
  end
  
  # More resolver functions...
end
```

The ecto_shorts approach offers several advantages in GraphQL resolvers:

1. **Consistent error handling**: Actions.get/3 returns `{:ok, record}` or `{:error, :not_found}`, which aligns well with GraphQL resolver return values.
2. **Declarative filtering**: The parameter-based filtering system makes it easy to convert GraphQL arguments to database queries.
3. **Automatic preloading**: You can easily preload associations based on GraphQL arguments.

However, it's generally better practice to use context modules rather than calling ecto_shorts directly in resolvers, as this provides better separation of concerns and makes your code more testable.

## When to Choose Other Approaches

Other approaches might be better when:

1. **You need more control**: If you need more fine-grained control over query building or database operations, using Ecto directly might be better.

2. **You have very specific requirements**: If you have very specific requirements that don't align with ecto_shorts' design, creating custom helper functions might be better.

3. **You're building a complex domain model**: If you're building a complex domain model with advanced features like authorization and validation, a more comprehensive library like Ash might be better.

4. **You want to minimize dependencies**: If you want to minimize dependencies, using Ecto directly or creating custom helper functions might be better.

## Conclusion

ecto_shorts provides a balance between the simplicity of using Ecto directly and the power of more comprehensive ORM-like libraries. It focuses specifically on simplifying common database operations while staying close to Ecto's design.

Whether ecto_shorts is the right choice for your project depends on your specific needs and preferences. Consider the advantages and trade-offs of each approach and choose the one that best fits your project.
