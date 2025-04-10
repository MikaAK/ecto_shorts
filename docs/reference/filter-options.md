# Filter Options Reference

This reference document provides detailed information about all the filter options available in `EctoShorts.CommonFilters` module.

## Overview

The `EctoShorts.CommonFilters` module provides a declarative way to build complex Ecto queries using parameter maps. This approach allows you to express complex query conditions in a simple, readable format.

The filter options are processed by `EctoShorts.CommonFilters.convert_params_to_filter/2` which transforms them into Ecto queries.

## Basic Filters

### Equality Filter

Filter records where a field equals a specific value.

**Syntax:**
```elixir
%{field_name: value}
```

**Example:**
```elixir
# Get users with the name "John"
EctoShorts.Actions.all(User, %{name: "John"})
```

**Generated Query:**
```elixir
from u in User, where: u.name == "John"
```

### List Filter

Filter records where a field is in a list of values.

**Syntax:**
```elixir
%{field_name: [value1, value2, ...]}
```

**Example:**
```elixir
# Get users with IDs 1, 2, or 3
EctoShorts.Actions.all(User, %{id: [1, 2, 3]})
```

**Generated Query:**
```elixir
from u in User, where: u.id in [1, 2, 3]
```

**Implementation:** `EctoShorts.QueryBuilder.Schema.ComparisonFilter.build/3`

## Comparison Operators

Comparison operators allow you to filter records based on field values using various comparison conditions. These are implemented in `EctoShorts.QueryBuilder.Schema.ComparisonFilter`.

### Greater Than

Filter records where a field is greater than a value.

**Syntax:**
```elixir
%{field_name: %{gt: value}}
```

**Example:**
```elixir
# Get users older than 30
EctoShorts.Actions.all(User, %{age: %{gt: 30}})
```

**Generated Query:**
```elixir
from u in User, where: u.age > 30
```

**Implementation:** `EctoShorts.QueryBuilder.Schema.ComparisonFilter.build_schema_field_filters/5` with `:gt` operator

### Greater Than or Equal To

Filter records where a field is greater than or equal to a value.

**Syntax:**
```elixir
%{field_name: %{gte: value}}
```

**Example:**
```elixir
# Get users 30 or older
EctoShorts.Actions.all(User, %{age: %{gte: 30}})
```

**Generated Query:**
```elixir
from u in User, where: u.age >= 30
```

**Implementation:** `EctoShorts.QueryBuilder.Schema.ComparisonFilter.build_schema_field_filters/5` with `:gte` operator

### Less Than

Filter records where a field is less than a value.

**Syntax:**
```elixir
%{field_name: %{lt: value}}
```

**Example:**
```elixir
# Get users younger than 30
EctoShorts.Actions.all(User, %{age: %{lt: 30}})
```

**Generated Query:**
```elixir
from u in User, where: u.age < 30
```

**Implementation:** `EctoShorts.QueryBuilder.Schema.ComparisonFilter.build_schema_field_filters/5` with `:lt` operator

### Less Than or Equal To

Filter records where a field is less than or equal to a value.

**Syntax:**
```elixir
%{field_name: %{lte: value}}
```

**Example:**
```elixir
# Get users 30 or younger
EctoShorts.Actions.all(User, %{age: %{lte: 30}})
```

**Generated Query:**
```elixir
from u in User, where: u.age <= 30
```

**Implementation:** `EctoShorts.QueryBuilder.Schema.ComparisonFilter.build_schema_field_filters/5` with `:lte` operator

### Combined Comparison Operators

You can combine comparison operators for range queries.

**Syntax:**
```elixir
%{field_name: %{gte: min_value, lte: max_value}}
```

**Example:**
```elixir
# Get users between 20 and 30 years old
EctoShorts.Actions.all(User, %{age: %{gte: 20, lte: 30}})
```

**Generated Query:**
```elixir
from u in User, where: u.age >= 20 and u.age <= 30
```

**Implementation:** `EctoShorts.QueryBuilder.Schema.ComparisonFilter.build/3` which processes each comparison operator in the map

## Text Search Filters

Text search filters allow you to perform pattern matching on text fields using SQL's LIKE and ILIKE operators.

### Like (Case-Sensitive)

Filter records where a text field contains a substring (case-sensitive).

**Syntax:**
```elixir
%{field_name: %{like: value}}
```

**Example:**
```elixir
# Get users whose name contains "John" (case sensitive)
EctoShorts.Actions.all(User, %{name: %{like: "John"}})
```

**Generated Query:**
```elixir
from u in User, where: like(u.name, "%John%")
```

**Implementation:** `EctoShorts.QueryBuilder.Schema.ComparisonFilter.build_schema_field_filters/5` with `:like` operator

### ILike (Case-Insensitive)

Filter records where a text field contains a substring (case-insensitive).

**Syntax:**
```elixir
%{field_name: %{ilike: value}}
```

**Example:**
```elixir
# Get users whose name contains "john" (case insensitive)
EctoShorts.Actions.all(User, %{name: %{ilike: "john"}})
```

**Generated Query:**
```elixir
from u in User, where: ilike(u.name, "%john%")
```

**Implementation:** `EctoShorts.QueryBuilder.Schema.ComparisonFilter.build_schema_field_filters/5` with `:ilike` operator

## Date Filters

Date filters allow you to filter records based on their `inserted_at` timestamp. These filters are implemented in `EctoShorts.QueryBuilder.Common`.

### Start Date

Filter records inserted on or after a specific date.

**Syntax:**
```elixir
%{start_date: date}
```

**Example:**
```elixir
# Get users created on or after January 1, 2023
EctoShorts.Actions.all(User, %{start_date: ~D[2023-01-01]})
```

**Generated Query:**
```elixir
from u in User, where: u.inserted_at >= ^~N[2023-01-01 00:00:00]
```

**Implementation:** `EctoShorts.QueryBuilder.Common.create_schema_filter/3` with `:start_date` key

### End Date

Filter records inserted on or before a specific date.

**Syntax:**
```elixir
%{end_date: date}
```

**Example:**
```elixir
# Get users created on or before December 31, 2023
EctoShorts.Actions.all(User, %{end_date: ~D[2023-12-31]})
```

**Generated Query:**
```elixir
from u in User, where: u.inserted_at <= ^~N[2023-12-31 23:59:59.999999]
```

**Implementation:** `EctoShorts.QueryBuilder.Common.create_schema_filter/3` with `:end_date` key

### Date Range

Filter records inserted within a date range.

**Syntax:**
```elixir
%{start_date: start_date, end_date: end_date}
```

**Example:**
```elixir
# Get users created in 2023
EctoShorts.Actions.all(User, %{
  start_date: ~D[2023-01-01],
  end_date: ~D[2023-12-31]
})
```

**Generated Query:**
```elixir
from u in User,
  where: u.inserted_at >= ^~N[2023-01-01 00:00:00] and
         u.inserted_at <= ^~N[2023-12-31 23:59:59.999999]
```

**Implementation:** Combination of both `start_date` and `end_date` filters

## Pagination Filters

Pagination filters allow you to limit the number of records returned and implement cursor-based pagination. These filters are implemented in `EctoShorts.QueryBuilder.Common`.

### First N Records

Get the first N records ordered by ID.

**Syntax:**
```elixir
%{first: n}
```

**Example:**
```elixir
# Get the first 10 users
EctoShorts.Actions.all(User, %{first: 10})
```

**Generated Query:**
```elixir
from u in User, order_by: [asc: u.id], limit: 10
```

**Implementation:** `EctoShorts.QueryBuilder.Common.create_schema_filter/3` with `:first` key

### Last N Records

Get the last N records ordered by ID.

**Syntax:**
```elixir
%{last: n}
```

**Example:**
```elixir
# Get the last 10 users
EctoShorts.Actions.all(User, %{last: 10})
```

**Generated Query:**
```elixir
from u in User, order_by: [desc: u.id], limit: 10
```

**Implementation:** `EctoShorts.QueryBuilder.Common.create_schema_filter/3` with `:last` key

### Before ID

Get records with IDs before a specific ID. Useful for cursor-based pagination.

**Syntax:**
```elixir
%{before: id}
```

**Example:**
```elixir
# Get users with IDs before 100
EctoShorts.Actions.all(User, %{before: 100})
```

**Generated Query:**
```elixir
from u in User, where: u.id < 100
```

**Implementation:** `EctoShorts.QueryBuilder.Common.create_schema_filter/3` with `:before` key

### After ID

Get records with IDs after a specific ID. Useful for cursor-based pagination.

**Syntax:**
```elixir
%{after: id}
```

**Example:**
```elixir
# Get users with IDs after 100
EctoShorts.Actions.all(User, %{after: 100})
```

**Generated Query:**
```elixir
from u in User, where: u.id > 100
```

**Implementation:** `EctoShorts.QueryBuilder.Common.create_schema_filter/3` with `:after` key

## Association Filters

Association filters allow you to filter records based on their relationships with other schemas. These are implemented in `EctoShorts.QueryBuilder.Schema`.

### Filter by Association Field

Filter records based on a field in an associated schema.

**Syntax:**
```elixir
%{assoc_name: %{field_name: value}}
```

**Example:**
```elixir
# Get posts with author name "John"
EctoShorts.Actions.all(Post, %{user: %{name: "John"}})
```

**Generated Query:**
```elixir
from p in Post,
  join: u in assoc(p, :user), as: :ecto_shorts_user,
  where: u.name == "John"
```

**Implementation:** `EctoShorts.QueryBuilder.Schema.create_schema_assocation_filter/5` and `EctoShorts.QueryBuilder.Schema.ComparisonFilter.build_relational/4`

### Filter by Association List

Filter records where an association field is in a list of values.

**Syntax:**
```elixir
%{assoc_name: [value1, value2, ...]}
```

**Example:**
```elixir
# Get users with role "admin" or "moderator"
EctoShorts.Actions.all(User, %{roles: ["admin", "moderator"]})
```

**Generated Query:**
```elixir
from u in User,
  inner_join: r in assoc(u, :roles), as: :ecto_shorts_roles,
  where: r.code in ["admin", "moderator"]
```

**Implementation:** `EctoShorts.QueryBuilder.Schema.create_schema_assocation_filter/5` and `EctoShorts.QueryBuilder.Schema.ComparisonFilter.build_relational_filter/5`

## Array Field Filters

Array field filters allow you to query PostgreSQL array fields. These are implemented in `EctoShorts.QueryBuilder.Schema.ComparisonFilter`.

### Array Equality

Filter records where an array field equals a specific array.

**Syntax:**
```elixir
%{array_field: [value1, value2, ...]}
```

**Example:**
```elixir
# Get users with specific tags
EctoShorts.Actions.all(User, %{tags: ["elixir", "phoenix"]})
```

**Generated Query:**
```elixir
from u in User, where: u.tags == ["elixir", "phoenix"]
```

**Implementation:** `EctoShorts.QueryBuilder.Schema.ComparisonFilter.build_array/3` when passed a list

### Array Contains

Filter records where an array field contains a specific value.

**Syntax:**
```elixir
%{array_field: value}
```

**Example:**
```elixir
# Get users with "elixir" in their tags
EctoShorts.Actions.all(User, %{tags: "elixir"})
```

**Generated Query:**
```elixir
from u in User, where: "elixir" in u.tags
```

**Implementation:** `EctoShorts.QueryBuilder.Schema.ComparisonFilter.build_array/3` when passed a single value

## Preloading

Preloading allows you to load associated data in a single query, reducing the N+1 query problem. This is implemented in `EctoShorts.QueryBuilder.Common`.

### Preload Single Association

Preload a single association.

**Syntax:**
```elixir
%{preload: association_name}
```

**Example:**
```elixir
# Get users and preload their posts
EctoShorts.Actions.all(User, %{preload: :posts})
```

**Generated Query:**
```elixir
from u in User, preload: [:posts]
```

**Implementation:** `EctoShorts.QueryBuilder.Common.create_schema_filter/3` with `:preload` key

### Preload Multiple Associations

Preload multiple associations.

**Syntax:**
```elixir
%{preload: [assoc1, assoc2, ...]}
```

**Example:**
```elixir
# Get users and preload their posts and comments
EctoShorts.Actions.all(User, %{preload: [:posts, :comments]})
```

**Generated Query:**
```elixir
from u in User, preload: [:posts, :comments]
```

**Implementation:** `EctoShorts.QueryBuilder.Common.create_schema_filter/3` with `:preload` key and a list value

### Preload Nested Associations

Preload nested associations.

**Syntax:**
```elixir
%{preload: [assoc1: [nested_assoc]]}
```

**Example:**
```elixir
# Get users, preload their posts, and preload comments on those posts
EctoShorts.Actions.all(User, %{preload: [posts: :comments]})
```

**Generated Query:**
```elixir
from u in User, preload: [posts: :comments]
```

**Implementation:** `EctoShorts.QueryBuilder.Common.create_schema_filter/3` with `:preload` key and a keyword list value

## Custom Search

The custom search filter allows you to implement your own search logic in your schemas. This is implemented in `EctoShorts.QueryBuilder.Common`.

### Search

Use the schema's `by_search/2` function to perform a custom search.

**Syntax:**
```elixir
%{search: term}
```

**Example:**
```elixir
# Search for users with "john" in their name or email
EctoShorts.Actions.all(User, %{search: "john"})
```

**Implementation:** `EctoShorts.QueryBuilder.Common.create_schema_filter/3` with `:search` key

**Note:** This requires the schema to implement a `by_search/2` function:

```elixir
# In your User schema module
def by_search(query, search_term) do
  search_pattern = "%#{search_term}%"
  
  from u in query,
    where: ilike(u.name, ^search_pattern) or ilike(u.email, ^search_pattern)
end
```

## Combining Filters

One of the powerful features of `EctoShorts.CommonFilters` is the ability to combine multiple filters in a single query. All filters are processed sequentially and combined with AND logic by default.

**Example:**
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

**Implementation:** `EctoShorts.CommonFilters.convert_params_to_filter/2` processes each filter key-value pair and applies them to the query using `reduce_schema_filter/2`

## Filter Options

When using `EctoShorts.CommonFilters.convert_params_to_filter/3`, you can pass additional options to control how filters are applied and what kind of query is generated.

### Filter Mode

Determine how multiple filters are combined (AND or OR logic).

**Syntax:**
```elixir
EctoShorts.CommonFilters.convert_params_to_filter(queryable, params, filter_mode: :and)
# or
EctoShorts.CommonFilters.convert_params_to_filter(queryable, params, filter_mode: :or)
```

**Example:**
```elixir
# Get users with name "John" AND age 30
query = EctoShorts.CommonFilters.convert_params_to_filter(User, %{name: "John", age: 30}, filter_mode: :and)

# Get users with name "John" OR age 30
query = EctoShorts.CommonFilters.convert_params_to_filter(User, %{name: "John", age: 30}, filter_mode: :or)
```

**Implementation:** The filter mode option is processed by `EctoShorts.CommonFilters.convert_params_to_filter/3`

### Query Mode

Determine whether to return all records or just a count.

**Syntax:**
```elixir
EctoShorts.CommonFilters.convert_params_to_filter(queryable, params, query_mode: :all)
# or
EctoShorts.CommonFilters.convert_params_to_filter(queryable, params, query_mode: :count)
```

**Example:**
```elixir
# Get all users matching the filters
query = EctoShorts.CommonFilters.convert_params_to_filter(User, %{age: %{gte: 18}}, query_mode: :all)
users = Repo.all(query)

# Get the count of users matching the filters
query = EctoShorts.CommonFilters.convert_params_to_filter(User, %{age: %{gte: 18}}, query_mode: :count)
count = Repo.one(query)
```

**Implementation:** The query mode option is processed by `EctoShorts.CommonFilters.convert_params_to_filter/3`

## Best Practices

When using filter options with `EctoShorts.CommonFilters`, consider these best practices:

1. **Start simple**: Begin with basic filters and add complexity as needed. This makes your code more maintainable and easier to debug.

2. **Use preloading wisely**: Only preload associations that you actually need to avoid unnecessary database queries. Excessive preloading can significantly impact performance.

3. **Consider performance**: Complex filters can impact query performance. Use database indexes for frequently filtered fields and monitor query execution time.

4. **Validate user input**: When converting user input to filter parameters, validate the input to prevent security issues like SQL injection.

5. **Document custom filters**: If you implement custom filters using `by_search/2` or other methods, make sure to document them thoroughly for other developers.

6. **Use pagination**: For large datasets, always use pagination filters like `first` or `last` to limit the number of records returned.

7. **Combine with Ecto functions**: You can further refine the queries generated by `EctoShorts.CommonFilters` using Ecto's query functions.

## See Also

- [Filtering Data How-To Guide](/docs/how-to/filtering-data.md)
- [Custom Filters How-To Guide](/docs/how-to/custom-filters.md)
- [EctoShorts.Actions Reference](/docs/reference/actions.md)
