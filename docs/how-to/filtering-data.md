# How to Filter Data with CommonFilters

This guide shows you how to use the powerful filtering capabilities of `EctoShorts.CommonFilters` to query your database efficiently and declaratively.

## Basic Filtering

The `EctoShorts.CommonFilters` module converts parameter maps into Ecto queries. This declarative approach makes it easy to build dynamic queries based on user input or application logic without writing complex Ecto query syntax.

### Simple Equality Filters

To filter records by a simple equality condition, provide the field name as the key and the value to match against:

```elixir
# Get users with the name "John"
EctoShorts.Actions.all(User, %{name: "John"})

# Get posts with a specific title
EctoShorts.Actions.all(Post, %{title: "My First Post"})
```

Behind the scenes, this is converted to an Ecto query equivalent to:

```elixir
from u in User, where: u.name == ^"John"
```

Note that all values are properly parameterized to prevent SQL injection.

### Multiple Conditions

You can combine multiple conditions by adding more key-value pairs to the filter map:

```elixir
# Get users named "John" who are 30 years old
EctoShorts.Actions.all(User, %{name: "John", age: 30})
```

This is equivalent to:

```elixir
from u in User, where: u.name == ^"John" and u.age == ^30
```

All conditions are combined with `AND` logic by default.

## Advanced Filtering

### Comparison Operators

`EctoShorts.CommonFilters` supports various comparison operators through nested maps:

```elixir
# Get users older than 30
EctoShorts.Actions.all(User, %{age: %{gt: 30}})

# Get users 30 or older
EctoShorts.Actions.all(User, %{age: %{gte: 30}})

# Get users younger than 30
EctoShorts.Actions.all(User, %{age: %{lt: 30}})

# Get users 30 or younger
EctoShorts.Actions.all(User, %{age: %{lte: 30}})

# Get users between 20 and 30 years old (inclusive)
EctoShorts.Actions.all(User, %{age: %{gte: 20, lte: 30}})
```

You can also use the `!=` operator to find records where a field does not equal a specific value:

```elixir
# Get users who are not 30 years old
EctoShorts.Actions.all(User, %{age: %{!=: 30}})

# Get users where status is not nil
EctoShorts.Actions.all(User, %{status: %{!=: nil}})
```

### Text Search

For text fields, you can use `like` and `ilike` (case-insensitive like) operators:

```elixir
# Get users whose name contains "John" (case sensitive)
EctoShorts.Actions.all(User, %{name: %{like: "John"}})

# Get users whose name contains "john" (case insensitive)
EctoShorts.Actions.all(User, %{name: %{ilike: "john"}})
```

The `like` and `ilike` operators automatically add `%` wildcards around your search term, so `%{name: %{ilike: "john"}}` becomes `ilike(u.name, ^"%john%")` in the query.

You can also use string transformations with the `:lower` and `:upper` modifiers:

```elixir
# Match name field converted to lowercase against "john"
EctoShorts.Actions.all(User, %{name: {:lower, "john"}})

# Match name field converted to uppercase against "JOHN"
EctoShorts.Actions.all(User, %{name: {:upper, "JOHN"}})

# Find records where name field in lowercase is not "john"
EctoShorts.Actions.all(User, %{name: %{!=: {:lower, "john"}}})
```

### List Operators

You can filter by checking if a field value is in a list by providing an array as the value:

```elixir
# Get users with specific IDs
EctoShorts.Actions.all(User, %{id: [1, 2, 3]})
```

This is equivalent to:

```elixir
from u in User, where: u.id in ^[1, 2, 3]
```

You can also use the `ids` common filter as a shorthand for filtering by primary keys:

```elixir
# Get users with specific IDs
EctoShorts.Actions.all(User, %{ids: [1, 2, 3]})
```

### Filtering by Associations

You can filter records based on their associations by using the association name as the key:

```elixir
# Get users who have posts with a specific title
EctoShorts.Actions.all(User, %{posts: %{title: "My First Post"}})

# Get users who have the role "admin" or "moderator"
EctoShorts.Actions.all(User, %{roles: %{code: ["admin", "moderator"]}})
```

This is equivalent to:

```elixir
from u in User,
  inner_join: p in assoc(u, :posts), as: :ecto_shorts_posts,
  where: p.title == ^"My First Post"

# Or for the roles example
from u in User,
  inner_join: r in assoc(u, :roles), as: :ecto_shorts_roles,
  where: r.code in ^["admin", "moderator"]
```

You can also nest association filters to query through multiple levels of relationships:

```elixir
# Get users who have posts with comments by a specific author
EctoShorts.Actions.all(User, %{posts: %{comments: %{author: "Jane"}}})
```

### Array Field Filtering

For PostgreSQL array fields, `EctoShorts.CommonFilters` provides special handling:

```elixir
# Get users who have specific items in their cart (exact match)
EctoShorts.Actions.all(User, %{cart_items: [1, 2]})

# Get users who have a specific item in their cart (contains)
EctoShorts.Actions.all(User, %{cart_items: 3})
```

The first example is equivalent to:

```elixir
from u in User, where: u.cart_items == ^[1, 2]
```

The second example is equivalent to:

```elixir
from u in User, where: ^3 in u.cart_items
```

The library automatically detects array fields in your schema and applies the appropriate query.

## Pagination and Ordering

### Limiting Results

You can limit the number of results using the `first` or `limit` filters (they're equivalent):

```elixir
# Get the first 10 users
EctoShorts.Actions.all(User, %{first: 10})

# Same as above, using limit
EctoShorts.Actions.all(User, %{limit: 10})

# Get the last 10 users (ordered by inserted_at desc)
EctoShorts.Actions.all(User, %{last: 10})
```

You can also use `offset` for pagination:

```elixir
# Get 10 users, skipping the first 20
EctoShorts.Actions.all(User, %{limit: 10, offset: 20})
```

### Cursor-based Pagination

You can implement cursor-based pagination using the `before` and `after` filters, which filter based on the primary key:

```elixir
# Get users after a specific ID
EctoShorts.Actions.all(User, %{after: 10})

# Get users before a specific ID
EctoShorts.Actions.all(User, %{before: 20})

# Combine with limit for true cursor pagination
EctoShorts.Actions.all(User, %{after: 10, first: 10})
```

These translate to:

```elixir
from u in User, where: u.id > ^10
from u in User, where: u.id < ^20
```

### Date Range Filtering

You can filter by date ranges using the `start_date` and `end_date` common filters, which operate on the `inserted_at` field:

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

These translate to:

```elixir
from u in User, where: u.inserted_at >= ^~D[2023-01-01]
from u in User, where: u.inserted_at <= ^~D[2023-12-31]
```

You can also filter on any datetime field using the comparison operators:

```elixir
# Get users whose email was updated after a specific date
EctoShorts.Actions.all(User, %{email_updated_at: %{gte: ~N[2023-01-01 00:00:00]}})
```

## Preloading Associations

You can preload associations using the `preload` filter, which works just like Ecto's `preload` option:

```elixir
# Preload a single association
EctoShorts.Actions.all(User, %{preload: :posts})

# Preload multiple associations
EctoShorts.Actions.all(User, %{preload: [:posts, :comments]})

# Preload nested associations
EctoShorts.Actions.all(User, %{preload: [posts: :comments]})
```

This is particularly useful when combined with other filters:

```elixir
# Get active users and preload their posts
EctoShorts.Actions.all(User, %{active: true, preload: :posts})
```

## Custom Search

You can implement custom search functionality by adding a `by_search/2` function to your schema module:

```elixir
# In your User schema module
def by_search(query, search_term) do
  search_pattern = "%#{search_term}%"
  
  import Ecto.Query
  from u in query,
    where: ilike(u.name, ^search_pattern) or ilike(u.email, ^search_pattern)
end
```

Then you can use it with the `search` filter parameter:

```elixir
# Search for users by name or email
EctoShorts.Actions.all(User, %{search: "john"})
```

This allows you to implement complex search logic that's specific to each schema. You can also make your `by_search/2` function accept a map for more structured searches:

```elixir
def by_search(query, %{name: name, email: email}) do
  import Ecto.Query
  query
  |> where([u], ilike(u.name, ^("%#{name}%")))
  |> where([u], ilike(u.email, ^("%#{email}%")))
end

# Then use it with
EctoShorts.Actions.all(User, %{search: %{name: "john", email: "example"}})
```

For more details on custom search, see the [Custom Filters](custom-filters.md) guide.

## Combining Filters

One of the most powerful features of `EctoShorts.CommonFilters` is the ability to combine multiple filters for complex queries:

```elixir
# Get active users created in 2023 with admin role, preload their posts,
# and limit to the first 10 results
EctoShorts.Actions.all(User, %{
  active: true,
  start_date: ~D[2023-01-01],
  end_date: ~D[2023-12-31],
  roles: %{name: "admin"},
  preload: :posts,
  first: 10
})
```

This declarative approach makes it easy to build complex queries that would otherwise require many lines of Ecto query syntax. It's particularly useful for building dynamic filters based on user input:

```elixir
# In a Phoenix controller
def index(conn, params) do
  filters = %{}
  
  # Add filters conditionally based on params
  filters = if params["status"], do: Map.put(filters, :status, params["status"]), else: filters
  filters = if params["search"], do: Map.put(filters, :search, params["search"]), else: filters
  
  # Always paginate and preload associations
  filters = Map.merge(filters, %{
    limit: 20,
    offset: params["page"] || 0,
    preload: :posts
  })
  
  users = EctoShorts.Actions.all(User, filters)
  render(conn, :index, users: users)
end
```

## Using with Actions

All the filter options work with any of the `EctoShorts.Actions` functions:

```elixir
# Get a specific user with preloaded posts
EctoShorts.Actions.get(User, 1, %{preload: :posts})

# Find a user matching criteria
EctoShorts.Actions.find(User, %{email: "john@example.com"})

# Get all users matching criteria
EctoShorts.Actions.all(User, %{age: %{gte: 18}})

# Stream users matching criteria (for large result sets)
EctoShorts.Actions.stream(User, %{active: true})

# Calculate aggregates on filtered data
EctoShorts.Actions.aggregate(User, %{active: true}, :count, :id)
```

This consistent interface makes it easy to use the same filtering logic across different types of queries.

## Ordering Results

You can order results using the `order_by` filter:

```elixir
# Order users by name ascending
EctoShorts.Actions.all(User, %{order_by: :name})

# Order users by inserted_at descending
EctoShorts.Actions.all(User, %{order_by: {:desc, :inserted_at}})

# Order by multiple fields
EctoShorts.Actions.all(User, %{order_by: [{:desc, :priority}, :name]})
```

## Performance Considerations

While `EctoShorts.CommonFilters` makes it easy to build complex queries, be mindful of performance implications:

1. **Avoid over-filtering**: Complex filters with many conditions can lead to slow queries.

2. **Use indexes**: Ensure that fields you frequently filter on are properly indexed in your database.

3. **Be careful with associations**: Filtering on associations creates joins, which can impact performance on large tables.

4. **Consider pagination**: Always use `limit` and `offset` or cursor-based pagination for large result sets.

## Conclusion

The `EctoShorts.CommonFilters` module provides a powerful, flexible way to build dynamic queries. By converting parameter maps into Ecto queries, it simplifies your code and makes it more maintainable.

For more advanced filtering needs, see the [Custom Filters](custom-filters.md) guide to learn how to extend the filtering capabilities with your own custom logic.
