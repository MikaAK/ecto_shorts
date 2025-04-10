# Why ecto_shorts Exists

This document explains the design philosophy and motivation behind ecto_shorts, helping you understand why it was created and the problems it solves.

## The Problem with Standard Ecto

[Ecto](https://hexdocs.pm/ecto/Ecto.html) is a powerful database wrapper and query generator for Elixir. It provides a robust foundation for working with databases in Elixir applications. However, when building real-world applications, developers often encounter several challenges:

### 1. Repetitive Boilerplate Code

Standard Ecto requires writing similar code patterns repeatedly across different contexts:

```elixir
# Creating a record
def create_user(attrs) do
  %User{}
  |> User.changeset(attrs)
  |> Repo.insert()
end

# Getting a record by ID
def get_user(id) do
  User
  |> Repo.get(id)
  |> case do
    nil -> {:error, :not_found}
    user -> {:ok, user}
  end
end

# Updating a record
def update_user(user, attrs) do
  user
  |> User.changeset(attrs)
  |> Repo.update()
end
```

This pattern is repeated for every schema in your application, leading to a lot of boilerplate code.

### 2. Complex Query Building

Building complex queries with Ecto can be verbose and difficult to read:

```elixir
query = from u in User,
  where: u.age >= 18 and u.age <= 65,
  where: ilike(u.name, "%john%"),
  join: r in assoc(u, :roles),
  where: r.name in ["admin", "moderator"],
  preload: [:posts, :comments],
  limit: 10

users = Repo.all(query)
```

### 3. Association Handling

Handling associations, especially many-to-many relationships, requires careful consideration:

```elixir
def update_user_roles(user, role_ids) do
  roles = Repo.all(from r in Role, where: r.id in ^role_ids)
  
  user
  |> Repo.preload(:roles)
  |> User.changeset(%{})
  |> Ecto.Changeset.put_assoc(:roles, roles)
  |> Repo.update()
end
```

### 4. Inconsistent Return Values

Different Ecto functions return different types of values:

- `Repo.get/2` returns `nil` or a struct
- `Repo.insert/1` returns `{:ok, struct}` or `{:error, changeset}`
- `Repo.all/1` returns a list of structs

This inconsistency requires handling different return types throughout your application.

## The ecto_shorts Solution

ecto_shorts was created to address these challenges by providing a more concise, consistent, and developer-friendly way to work with Ecto.

### 1. Simplified CRUD Operations

The `Actions` module provides a consistent interface for CRUD operations:

```elixir
# Creating a record
{:ok, user} = Actions.create(User, %{name: "John", email: "john@example.com"})

# Getting a record by ID
{:ok, user} = Actions.get(User, 1)

# Updating a record
{:ok, user} = Actions.update(User, 1, %{name: "Jane"})

# Deleting a record
{:ok, user} = Actions.delete(User, 1)
```

This eliminates boilerplate code and provides consistent return values.

### 2. Declarative Filtering

The `CommonFilters` module allows you to build complex queries using simple parameter maps:

```elixir
# Get users with age between 18 and 65, with "john" in their name,
# who have admin or moderator roles, preload their posts and comments,
# and limit to 10 results
users = Actions.all(User, %{
  age: %{gte: 18, lte: 65},
  name: %{ilike: "john"},
  roles: ["admin", "moderator"],
  preload: [:posts, :comments],
  first: 10
})
```

This declarative approach is more readable and maintainable than building queries manually.

### 3. Intelligent Association Handling

The `CommonChanges` module simplifies working with associations:

```elixir
# Update a user's roles
{:ok, user} = Actions.update(User, 1, %{
  roles: [1, 2, 3]  # List of role IDs
})
```

ecto_shorts automatically determines whether to use `put_assoc` or `cast_assoc` based on the data, and handles many-to-many relationships intelligently.

### 4. Consistent Return Values

All functions in ecto_shorts return consistent values:

- `{:ok, record}` for successful operations
- `{:error, reason}` for failed operations

This consistency makes error handling more straightforward.

## Design Philosophy

ecto_shorts is built on several key design principles:

### 1. Convention Over Configuration

ecto_shorts follows the "convention over configuration" principle, providing sensible defaults while allowing customization when needed. For example, it automatically looks for `create_changeset/1` and `update_changeset/2` functions on schemas, falling back to `changeset/2` if they don't exist.

### 2. Declarative Over Imperative

ecto_shorts favors a declarative approach, where you describe what you want rather than how to get it. This is evident in the parameter-based filtering system, which allows you to express complex queries in a simple, declarative way.

### 3. Consistency and Predictability

ecto_shorts aims to provide a consistent and predictable API. All functions follow similar patterns and return consistent values, making the library easy to learn and use.

### 4. Composability

ecto_shorts is designed to be composable. You can use it alongside standard Ecto functions, and you can build on top of it to create higher-level abstractions.

### 5. Progressive Disclosure

ecto_shorts follows the principle of progressive disclosure, providing simple interfaces for common tasks while allowing access to more advanced features when needed. You can start with basic CRUD operations and gradually explore more complex filtering and association handling.

## Real-World Benefits

Using ecto_shorts in real-world applications provides several benefits:

### 1. Reduced Code Duplication

By eliminating boilerplate code, ecto_shorts reduces code duplication and makes your codebase more maintainable.

### 2. Improved Readability

The declarative filtering system makes complex queries more readable and easier to understand.

### 3. Faster Development

With less boilerplate and simpler APIs, you can develop features faster and with fewer bugs.

### 4. Better Maintainability

A consistent API and reduced code duplication make your codebase easier to maintain and extend.

### 5. Easier Testing

With consistent return values and simpler interfaces, testing becomes more straightforward.

## Conclusion

ecto_shorts was created to make working with Ecto more enjoyable and productive. By providing a more concise, consistent, and developer-friendly API, it helps you focus on building your application rather than wrestling with database queries.

Whether you're building a small prototype or a large production application, ecto_shorts can help you write cleaner, more maintainable code while still leveraging the power of Ecto.
