# How to Filter Data with CommonFilters

This guide shows you how to use the powerful filtering capabilities of ecto_shorts to query your database efficiently.

## Basic Filtering

The `CommonFilters` module in ecto_shorts allows you to convert parameter maps into Ecto queries. This makes it easy to build dynamic queries based on user input or application logic.

### Simple Equality Filters

To filter records by a simple equality condition:

```elixir
# Get users with the name "John"
EctoShorts.Actions.all(User, %{name: "John"})

# Get posts with a specific title
EctoShorts.Actions.all(Post, %{title: "My First Post"})
```

This is equivalent to:

```elixir
from u in User, where: u.name == "John"
```

### Multiple Conditions

You can combine multiple conditions:

```elixir
# Get users named "John" who are 30 years old
EctoShorts.Actions.all(User, %{name: "John", age: 30})
```

This is equivalent to:

```elixir
from u in User, where: u.name == "John" and u.age == 30
```

## Advanced Filtering

### Comparison Operators

ecto_shorts supports various comparison operators:

```elixir
# Get users older than 30
EctoShorts.Actions.all(User, %{age: %{gt: 30}})

# Get users 30 or older
EctoShorts.Actions.all(User, %{age: %{gte: 30}})

# Get users younger than 30
EctoShorts.Actions.all(User, %{age: %{lt: 30}})

# Get users 30 or younger
EctoShorts.Actions.all(User, %{age: %{lte: 30}})

# Get users between 20 and 30 years old
EctoShorts.Actions.all(User, %{age: %{gte: 20, lte: 30}})
```

### Text Search

For text fields, you can use `like` and `ilike` (case-insensitive like):

```elixir
# Get users whose name contains "John" (case sensitive)
EctoShorts.Actions.all(User, %{name: %{like: "John"}})

# Get users whose name contains "john" (case insensitive)
EctoShorts.Actions.all(User, %{name: %{ilike: "john"}})
```

The `like` and `ilike` operators automatically add `%` wildcards around your search term, so `%{name: %{ilike: "john"}}` becomes `ilike(u.name, "%john%")` in the query.

### List Operators

You can filter by checking if a value is in a list:

```elixir
# Get users with specific IDs
EctoShorts.Actions.all(User, %{id: [1, 2, 3]})
```

This is equivalent to:

```elixir
from u in User, where: u.id in [1, 2, 3]
```

### Filtering by Associations

You can filter records based on their associations:

```elixir
# Get users who have the role "admin" or "moderator"
EctoShorts.Actions.all(User, %{roles: ["admin", "moderator"]})
```

This is equivalent to:

```elixir
from u in User,
  inner_join: r in assoc(u, :roles), as: :ecto_shorts_roles,
  where: r.code in ["admin", "moderator"]
```

### Array Field Filtering

For PostgreSQL array fields, you can filter by array contents:

```elixir
# Get users who have specific items in their cart
EctoShorts.Actions.all(User, %{cart_items: [1, 2]})

# Get users who have a specific item in their cart
EctoShorts.Actions.all(User, %{cart_items: 3})
```

The first example is equivalent to:

```elixir
from u in User, where: u.cart_items == [1, 2]
```

The second example is equivalent to:

```elixir
from u in User, where: 3 in u.cart_items
```

## Pagination and Ordering

### Limiting Results

You can limit the number of results:

```elixir
# Get the first 10 users
EctoShorts.Actions.all(User, %{first: 10})

# Get the last 10 users
EctoShorts.Actions.all(User, %{last: 10})
```

### Cursor-based Pagination

You can implement cursor-based pagination using the `before` and `after` filters:

```elixir
# Get users after a specific ID
EctoShorts.Actions.all(User, %{after: 10})

# Get users before a specific ID
EctoShorts.Actions.all(User, %{before: 20})
```

### Date Range Filtering

You can filter by date ranges:

```elixir
# Get users created after a specific date
EctoShorts.Actions.all(User, %{start_date: ~D[2023-01-01]})

# Get users created before a specific date
EctoShorts.Actions.all(User, %{end_date: ~D[2023-12-31]})

# Get users created within a date range
EctoShorts.Actions.all(User, %{
  start_date: ~D[2023-01-01],
  end_date: ~D[2023-12-31]
})
```

## Preloading Associations

You can preload associations using the `preload` filter:

```elixir
# Preload a single association
EctoShorts.Actions.all(User, %{preload: :posts})

# Preload multiple associations
EctoShorts.Actions.all(User, %{preload: [:posts, :comments]})

# Preload nested associations
EctoShorts.Actions.all(User, %{preload: [posts: :comments]})
```

## Custom Search

You can implement custom search functionality by adding a `by_search/2` function to your schema:

```elixir
# In your User schema
def by_search(query, search_term) do
  search_pattern = "%#{search_term}%"
  
  import Ecto.Query
  from u in query,
    where: ilike(u.name, ^search_pattern) or ilike(u.email, ^search_pattern)
end
```

Then you can use it with the `search` filter:

```elixir
# Search for users by name or email
EctoShorts.Actions.all(User, %{search: "john"})
```

## Combining Filters

You can combine multiple filters for complex queries:

```elixir
# Get active users created in 2023 with admin role, preload their posts,
# and limit to the first 10 results
EctoShorts.Actions.all(User, %{
  active: true,
  start_date: ~D[2023-01-01],
  end_date: ~D[2023-12-31],
  roles: ["admin"],
  preload: :posts,
  first: 10
})
```

## Using with Actions

All the filter options work with any of the Actions functions:

```elixir
# Get a specific user with preloaded posts
EctoShorts.Actions.get(User, 1, %{preload: :posts})

# Get the first user matching criteria
EctoShorts.Actions.get_by(User, %{email: "john@example.com"})

# Count users matching criteria
EctoShorts.Actions.count(User, %{age: %{gte: 18}})
```

## Conclusion

The CommonFilters module in ecto_shorts provides a powerful, flexible way to build dynamic queries. By converting parameter maps into Ecto queries, it simplifies your code and makes it more maintainable.

For more information on available filters, see the Filter Options Reference section in the documentation.
