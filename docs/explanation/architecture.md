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
- `get/3`: Gets a record by ID
- `get_by/3`: Gets a record by attributes
- `all/3`: Gets all records matching filters
- `count/3`: Counts records matching filters
- `update/4`: Updates a record
- `delete/3`: Deletes a record

`Actions` uses `CommonFilters` to convert parameter maps into Ecto queries for read operations, and `CommonChanges` to handle associations for create and update operations.

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

`CommonFilters` uses `SchemaHelpers` to inspect schemas and determine the appropriate query to build.

### CommonChanges

The `CommonChanges` module handles associations in Ecto changesets. It provides functions to intelligently determine whether to use `put_assoc` or `cast_assoc` based on the data:

```elixir
# Starting with a changeset
changeset = User.changeset(%User{}, user_params)

# Handle the posts association
changeset = CommonChanges.put_or_cast_assoc(changeset, :posts)
```

`CommonChanges` uses `SchemaHelpers` to inspect schemas and determine the type of association.

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
5. For each association in the attributes, it calls `CommonChanges.put_or_cast_assoc/3`
6. `CommonChanges` uses `SchemaHelpers` to determine the type of each association
7. Based on the association type and data, it applies the appropriate Ecto function (`put_assoc` or `cast_assoc`)
8. `Actions` inserts the changeset into the database using the specified repo
9. It returns `{:ok, user}` or `{:error, changeset}`

### Read Operation

1. User calls `Actions.all(User, filters)`
2. `Actions` calls `CommonFilters.convert_params_to_filter(User, filters)`
3. `CommonFilters` uses `SchemaHelpers` to inspect the `User` schema
4. For each filter parameter, it builds the appropriate Ecto query
5. For association filters, it joins the associated tables
6. It returns the Ecto query to `Actions`
7. `Actions` executes the query using the specified repo
8. It returns the results to the user

### Update Operation

1. User calls `Actions.update(User, id, attrs)`
2. `Actions` gets the user with the given ID
3. If not found, it returns `{:error, :not_found}`
4. It looks for an `update_changeset/2` function on the `User` schema
5. If not found, it falls back to `changeset/2`
6. It applies the changeset to the user
7. For each association in the attributes, it calls `CommonChanges.put_or_cast_assoc/3`
8. `CommonChanges` uses `SchemaHelpers` to determine the type of each association
9. Based on the association type and data, it applies the appropriate Ecto function (`put_assoc` or `cast_assoc`)
10. `Actions` updates the changeset in the database using the specified repo
11. It returns `{:ok, user}` or `{:error, changeset}`

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
