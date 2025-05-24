# Architecture Overview

This document explains the architecture of ecto_shorts, showing how its different modules work together to provide a cohesive solution for working with Ecto.

## Core Components

ecto_shorts consists of four main modules, each with a specific responsibility:

1. **Actions**: Provides a consistent interface for CRUD operations
2. **CommonFilters**: Converts parameter maps into Ecto queries
3. **CommonChanges**: Handles associations in Ecto changesets
4. **SchemaHelpers**: Provides utility functions for working with Ecto schemas

Let's explore each component and how they interact.

## Component Relationships

The following diagram illustrates the relationships between the core components:

```
                 +----------------+
                 |                |
                 |     Actions    |
                 |                |
                 +-------+--------+
                         |
                         | uses
                         v
+----------------+     +----------------+     +----------------+
|                |     |                |     |                |
| SchemaHelpers  |<----+ CommonFilters  |     | CommonChanges  |
|                |     |                |     |                |
+----------------+     +----------------+     +----------------+
                         ^                      ^
                         |                      |
                         | uses                 | uses
                         |                      |
                 +-------+----------------------+-------+
                 |                                      |
                 |                Ecto                  |
                 |                                      |
                 +--------------------------------------+
```

### Actions

The `Actions` module is the primary entry point for most users. It provides functions for common database operations:

- `create/3`: Creates a new record
- `get/3`: Gets a record by ID with consistent `{:ok, record}` or `{:error, reason}` returns
- `find/3`: Finds records matching filters with the first result
- `all/3`: Gets all records matching filters
- `count/3`: Counts records matching filters
- `update/4`: Updates a record
- `delete/3`: Deletes a record
- `find_or_create/3`: Finds a record or creates it if not found
- `find_and_update/4`: Finds a record and updates it
- `find_and_upsert/4`: Finds a record and updates it or creates it if not found

`Actions` uses `CommonFilters` to convert parameter maps into Ecto queries for read operations, and `CommonChanges` to handle associations for create and update operations. It also provides consistent error handling and return values across all operations.

### CommonFilters

The `CommonFilters` module is responsible for converting parameter maps into Ecto queries. It provides a declarative way to build complex queries:

```elixir
# Parameter map
%{
  age: %{gte: 18, lte: 65},
  name: %{ilike: "john"},
  roles: ["admin", "moderator"],
  preload: [:posts, :comments],
  first: 10
}

# Converted to an Ecto query
from u in User,
  where: u.age >= 18 and u.age <= 65,
  where: ilike(u.name, "%john%"),
  join: r in assoc(u, :roles), as: :ecto_shorts_roles,
  where: r.code in ["admin", "moderator"],
  preload: [:posts, :comments],
  limit: 10
```

`CommonFilters` uses `SchemaHelpers` to inspect schemas and determine the appropriate query to build. It supports a wide range of filter types including:

- Exact matches (`field: value`)
- Comparison operators (`field: %{gte: value, lte: value}`)
- Pattern matching (`field: %{ilike: pattern}`)
- Association filtering (`association: [value1, value2]`)
- Common query modifiers (`first`, `last`, `preload`, `order_by`)

### CommonChanges

The `CommonChanges` module handles associations in Ecto changesets. It provides functions to intelligently determine whether to use `put_assoc` or `cast_assoc` based on the data:

```elixir
# Starting with a changeset
changeset = User.changeset(%User{}, user_params)

# Handle the posts association
changeset = CommonChanges.put_or_cast_assoc(changeset, :posts)
```

`CommonChanges` uses `SchemaHelpers` to inspect schemas and determine the type of association. Key functions include:

- `preload_change_assoc/3`: Preloads an association and prepares it for changes
- `put_or_cast_assoc/3`: Intelligently chooses between `put_assoc` and `cast_assoc`
- `put_when/3`: Conditionally applies a function to a changeset
- `changeset_field_nil?/2` and `changeset_field_empty?/2`: Helper functions for checking field values

These functions simplify common patterns when working with associations in Ecto changesets.

### SchemaHelpers

The `SchemaHelpers` module provides utility functions for working with Ecto schemas:

- `has_field?/2`: Checks if a schema has a specific field
- `has_assoc?/2`: Checks if a schema has a specific association
- `get_assoc_type/2`: Gets the type of a schema's association

These functions are used by `CommonFilters` and `CommonChanges` to inspect schemas and make decisions about how to handle them.

## Data Flow

Let's trace the data flow through ecto_shorts for common operations:

### Create Operation

1. User calls `Actions.create(User, attrs)`
2. `Actions` looks for a `create_changeset/1` function on the `User` schema
3. If not found, it falls back to `changeset/2`
4. It applies the changeset to a new `User` struct
5. If a custom changeset function is provided via the `:changeset` option, it's applied
6. The changeset is inserted into the database using the specified repo
7. It returns `{:ok, user}` or `{:error, changeset}`

When associations are involved:

1. The changeset is built as described above
2. For each association in the attributes, the schema's changeset function handles it
3. If using `CommonChanges.preload_change_assoc/3` in the schema's changeset function:
   - The association is preloaded if needed
   - `CommonChanges.put_or_cast_assoc/3` is called
   - `SchemaHelpers` determines the association type
   - Based on the association type and data, the appropriate Ecto function (`put_assoc` or `cast_assoc`) is applied

### Read Operation

1. User calls `Actions.all(User, filters)`
2. `Actions` calls `CommonFilters.convert_params_to_filter(User, filters)`
3. `CommonFilters` uses `CommonSchema.get_schema_query` to get the base query
4. For each filter parameter, it calls `create_schema_filter` to build the appropriate query
5. For common filters (like `preload`, `first`, `last`), it delegates to `QueryBuilder.Common`
6. For field filters, it delegates to `QueryBuilder.Schema`
7. For association filters, it joins the associated tables with appropriate aliases
8. It returns the complete Ecto query to `Actions`
9. `Actions` executes the query using the specified repo (or replica if provided)
10. It returns the results to the user

### Update Operation

1. User calls `Actions.update(User, id, attrs)`
2. `Actions` gets the user with the given ID
3. If not found, it returns `{:error, :not_found}`
4. It uses the standard `changeset/2` function on the `User` schema
5. If a custom changeset function is provided via the `:changeset` option, it's applied instead
6. The changeset is updated in the database using the specified repo
7. It returns `{:ok, user}` or `{:error, changeset}`

When associations are involved:

1. The changeset is built as described above
2. For each association in the attributes, the schema's changeset function handles it
3. If using `CommonChanges.preload_change_assoc/3` in the schema's changeset function:
   - The association is preloaded if needed
   - `CommonChanges.put_or_cast_assoc/3` is called
   - Based on the data structure (IDs, maps, or structs), it determines whether to use `put_assoc` or `cast_assoc`
   - For many-to-many relationships with just IDs, it performs a member update

### Delete Operation

1. User calls `Actions.delete(User, id)`
2. `Actions` gets the user with the given ID
3. If not found, it returns `{:error, :not_found}`
4. It deletes the user from the database using the specified repo
5. It returns `{:ok, user}` or `{:error, changeset}`

## Extension Points

ecto_shorts is designed to be extensible. Here are some common extension points:

### Custom Filters

You can extend `CommonFilters` with custom filtering logic:

```elixir
defmodule MyApp.CustomFilters do
  import Ecto.Query
  alias EctoShorts.CommonFilters

  def convert_params_to_filter(queryable, params, opts \\ []) do
    # Apply custom filters
    queryable = apply_custom_filters(queryable, params)
    
    # Delegate to CommonFilters for standard filters
    standard_params = Map.drop(params, [:custom_filter])
    CommonFilters.convert_params_to_filter(queryable, standard_params, opts)
  end
  
  defp apply_custom_filters(queryable, %{custom_filter: value}) do
    # Apply custom filter logic
    from q in queryable, where: q.custom_field == ^value
  end
  defp apply_custom_filters(queryable, _), do: queryable
end
```

### Custom Search

You can implement custom search functionality by adding a `by_search/2` function to your schema:

```elixir
defmodule MyApp.User do
  use Ecto.Schema
  import Ecto.Query

  schema "users" do
    # Fields...
  end

  def by_search(query, search_term) do
    search_pattern = "%#{search_term}%"
    
    from u in query,
      where: ilike(u.name, ^search_pattern) or ilike(u.email, ^search_pattern)
  end
end
```

### Custom Actions

You can create your own version of the `Actions` module that uses your custom filters:

```elixir
defmodule MyApp.CustomActions do
  alias MyApp.{Repo, CustomFilters}
  
  def all(queryable, filters \\ %{}, opts \\ []) do
    opts = Keyword.put_new(opts, :repo, Repo)
    repo = Keyword.get(opts, :repo)
    
    queryable
    |> CustomFilters.convert_params_to_filter(filters, opts)
    |> repo.all()
  end
  
  # Implement other actions similarly
end
```

## Design Decisions

Several key design decisions shaped the architecture of ecto_shorts:

### 1. Separation of Concerns

Each module has a clear responsibility:
- `Actions` handles CRUD operations
- `CommonFilters` handles query building
- `CommonChanges` handles association management
- `SchemaHelpers` provides utility functions

This separation makes the codebase more maintainable and easier to understand.

### 2. Consistent Return Values

All functions in `Actions` return consistent values:
- `{:ok, record}` for successful operations
- `{:error, reason}` for failed operations

This consistency makes error handling more straightforward.

### 3. Parameter-Based Filtering

The parameter-based filtering system in `CommonFilters` provides a declarative way to build complex queries. This approach is more readable and maintainable than building queries manually.

### 4. Intelligent Association Handling

The `CommonChanges` module intelligently determines whether to use `put_assoc` or `cast_assoc` based on the data. This simplifies working with associations and reduces the need for boilerplate code.

### 5. Schema Inspection

The `SchemaHelpers` module provides functions to inspect schemas at runtime. This allows `CommonFilters` and `CommonChanges` to make decisions based on the schema's structure.

## Conclusion

The architecture of ecto_shorts is designed to provide a cohesive solution for working with Ecto. By separating concerns into distinct modules and providing clear extension points, it offers a flexible and maintainable approach to database operations.

Whether you're using ecto_shorts as-is or extending it with custom functionality, understanding its architecture will help you make the most of this powerful library.
