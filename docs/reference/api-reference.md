# API Reference

This reference document provides detailed information about all the modules, functions, and options available in EctoShorts. It serves as a comprehensive technical reference for developers who need specific details about the library's components.

For practical guides on how to use these features, please refer to the [How-to Guides](/docs/how-to/) section.

## `EctoShorts.Actions`

The `EctoShorts.Actions` module provides a consistent interface for performing CRUD operations on Ecto schemas.

### Functions

#### `EctoShorts.Actions.create/3`

```elixir
create(schema, attrs, opts \\ [])
```

Creates a new record of the given schema with the provided attributes.

**Parameters:**
- `schema`: The schema module to create a record for
- `attrs`: A map of attributes to set on the new record
- `opts`: Options (see below)

**Options:**
- `:repo`: The `Ecto.Repo` to use (defaults to the configured repo)
- `:changeset_fun`: The changeset function to use (defaults to `create_changeset/1` or `changeset/2`)
- Any other options are passed to the repo's `insert/2` function

**Returns:**
- `{:ok, record}` if the record was created successfully
- `{:error, changeset}` if there was an error

**Example:**
```elixir
{:ok, user} = EctoShorts.Actions.create(User, %{name: "John", email: "john@example.com"})
```

See also: `EctoShorts.Actions.find_or_create/3`, `Ecto.Repo.insert/2`

#### `EctoShorts.Actions.get/3`

```elixir
get(schema, id, opts \\ [])
```

Gets a record of the given schema by its ID.

**Parameters:**
- `schema`: The schema module to get a record for
- `id`: The ID of the record to get
- `opts`: Options (see below)

**Options:**
- `:repo`: The `Ecto.Repo` to use (defaults to the configured repo)
- `:replica`: A read replica to use for the query
- `:preload`: Fields to preload on the record
- Any other options are passed to `EctoShorts.CommonFilters.convert_params_to_filter/3`

**Returns:**
- `{:ok, record}` if the record was found
- `{:error, %ErrorMessage{code: :not_found, message: "Record not found", details: %{id: id}}}` if the record was not found

**Example:**
```elixir
{:ok, user} = EctoShorts.Actions.get(User, 1, preload: [:posts])
```

See also: `EctoShorts.Actions.get_by/3`, `EctoShorts.Actions.find/3`

#### `EctoShorts.Actions.get_by/3`

```elixir
get_by(schema, attrs, opts \\ [])
```

Gets a record of the given schema by the provided attributes.

**Parameters:**
- `schema`: The schema module to get a record for
- `attrs`: A map of attributes to filter by
- `opts`: Options (see below)

**Options:**
- `:repo`: The `Ecto.Repo` to use (defaults to the configured repo)
- `:replica`: A read replica to use for the query
- `:preload`: Fields to preload on the record
- Any other options are passed to `EctoShorts.CommonFilters.convert_params_to_filter/3`

**Returns:**
- `{:ok, record}` if the record was found
- `{:error, %ErrorMessage{code: :not_found, message: "Record not found", details: %{id: id}}}` if the record was not found

**Example:**
```elixir
{:ok, user} = EctoShorts.Actions.get_by(User, %{email: "john@example.com"})
```

See also: `EctoShorts.Actions.get/3`, `EctoShorts.Actions.find/3`

#### `EctoShorts.Actions.all/3`

```elixir
all(schema, filters \\ %{}, opts \\ [])
```

Gets all records of the given schema that match the provided filters.

**Parameters:**
- `schema`: The schema module to get records for
- `filters`: A map of filters to apply (see `EctoShorts.CommonFilters`)
- `opts`: Options (see below)

**Options:**
- `:repo`: The `Ecto.Repo` to use (defaults to the configured repo)
- `:replica`: A read replica to use for the query
- Any other options are passed to `EctoShorts.CommonFilters.convert_params_to_filter/3`

**Returns:**
- A list of records that match the filters

**Example:**
```elixir
users = EctoShorts.Actions.all(User, %{age: %{gte: 18}})
```

See also: `EctoShorts.Actions.count/3`, `Ecto.Repo.all/2`

#### `EctoShorts.Actions.count/3`

```elixir
count(schema, filters \\ %{}, opts \\ [])
```

Counts the number of records of the given schema that match the provided filters.

**Parameters:**
- `schema`: The schema module to count records for
- `filters`: A map of filters to apply (see `EctoShorts.CommonFilters`)
- `opts`: Options (see below)

**Options:**
- `:repo`: The `Ecto.Repo` to use (defaults to the configured repo)
- `:replica`: A read replica to use for the query
- Any other options are passed to `EctoShorts.CommonFilters.convert_params_to_filter/3`

**Returns:**
- An integer representing the count of matching records

**Example:**
```elixir
count = EctoShorts.Actions.count(User, %{active: true})
```

See also: `EctoShorts.Actions.all/3`

#### `EctoShorts.Actions.update/4`

```elixir
update(schema, id, attrs, opts \\ [])
```

Updates a record of the given schema with the provided attributes.

**Parameters:**
- `schema`: The schema module to update a record for
- `id`: The ID of the record to update
- `attrs`: A map of attributes to update on the record
- `opts`: Options (see below)

**Options:**
- `:repo`: The `Ecto.Repo` to use (defaults to the configured repo)
- `:changeset_fun`: The changeset function to use (defaults to `update_changeset/2` or `changeset/2`)
- Any other options are passed to the repo's `update/2` function

**Returns:**
- `{:ok, record}` if the record was updated successfully
- `{:error, changeset}` if there was an error
- `{:error, %ErrorMessage{code: :not_found, message: "Record not found", details: %{id: id}}}` if the record was not found

**Example:**
```elixir
{:ok, user} = EctoShorts.Actions.update(User, 1, %{name: "Jane"})
```

See also: `EctoShorts.Actions.find_and_update/4`, `Ecto.Repo.update/2`

#### `EctoShorts.Actions.delete/3`

```elixir
delete(schema, id, opts \\ [])
```

Deletes a record of the given schema.

**Parameters:**
- `schema`: The schema module to delete a record for
- `id`: The ID of the record to delete
- `opts`: Options (see below)

**Options:**
- `:repo`: The `Ecto.Repo` to use (defaults to the configured repo)
- Any other options are passed to the repo's `delete/2` function

**Returns:**
- `{:ok, record}` if the record was deleted successfully
- `{:error, changeset}` if there was an error
- `{:error, %ErrorMessage{code: :not_found, message: "Record not found", details: %{id: id}}}` if the record was not found

**Example:**
```elixir
{:ok, user} = EctoShorts.Actions.delete(User, 1)
```

See also: `Ecto.Repo.delete/2`

## `EctoShorts.CommonFilters`

The `EctoShorts.CommonFilters` module provides functions to convert parameter maps into Ecto queries. It implements a declarative way to build complex Ecto queries using parameter maps.

### Functions

#### `EctoShorts.CommonFilters.convert_params_to_filter/3`

```elixir
convert_params_to_filter(queryable, params, opts \\ [])
```

Converts a map of parameters into an Ecto query.

**Parameters:**
- `queryable`: The queryable to filter (a schema module or an existing query)
- `params`: A map of parameters to convert to filters
- `opts`: Options (see below)

**Options:**
- `:filter_mode`: `:and` (default) or `:or` - determines how multiple filters are combined
- `:query_mode`: `:all` (default) or `:count` - determines whether to return all records or just a count

**Returns:**
- An `Ecto.Query` with the filters applied

**Example:**
```elixir
query = EctoShorts.CommonFilters.convert_params_to_filter(User, %{age: %{gte: 18}})
users = MyApp.Repo.all(query)
```

See also: `EctoShorts.QueryBuilder.Schema`, `EctoShorts.QueryBuilder.Common`

## `EctoShorts.CommonChanges`

The `EctoShorts.CommonChanges` module provides functions to handle associations in Ecto changesets. It simplifies working with associations by intelligently determining whether to use `put_assoc/4` or `cast_assoc/3` based on the data provided.

### Functions

#### `EctoShorts.CommonChanges.put_or_cast_assoc/3`

```elixir
put_or_cast_assoc(changeset, assoc_field, opts \\ [])
```

Intelligently determines whether to use `put_assoc/4` or `cast_assoc/3` based on the data.

**Parameters:**
- `changeset`: The `Ecto.Changeset` to modify
- `assoc_field`: The association field to handle
- `opts`: Options (see below)

**Options:**
- `:ids`: A list of IDs to use for the association (for many-to-many relationships)
- `:with`: A function to apply to each associated item before casting
- `:required`: Whether the association is required
- Any other options are passed to `Ecto.Changeset.cast_assoc/3` or `Ecto.Changeset.put_assoc/4`

**Returns:**
- The modified changeset

**Example:**
```elixir
changeset = EctoShorts.CommonChanges.put_or_cast_assoc(changeset, :posts)
```

See also: `EctoShorts.CommonChanges.put_or_cast_assocs/3`, `Ecto.Changeset.cast_assoc/3`, `Ecto.Changeset.put_assoc/4`

#### `EctoShorts.CommonChanges.put_or_cast_assocs/3`

```elixir
put_or_cast_assocs(changeset, assoc_fields, opts \\ [])
```

Applies `put_or_cast_assoc/3` to multiple association fields.

**Parameters:**
- `changeset`: The `Ecto.Changeset` to modify
- `assoc_fields`: A list of association fields to handle
- `opts`: Options (see `EctoShorts.CommonChanges.put_or_cast_assoc/3`)

**Returns:**
- The modified changeset

**Example:**
```elixir
changeset = EctoShorts.CommonChanges.put_or_cast_assocs(changeset, [:posts, :comments])
```

See also: `EctoShorts.CommonChanges.put_or_cast_assoc/3`

## `EctoShorts.SchemaHelpers`

The `EctoShorts.SchemaHelpers` module provides helper functions for working with Ecto schemas. These utilities help with common schema-related operations such as checking for fields and associations.

### Functions

#### `EctoShorts.SchemaHelpers.has_field?/2`

```elixir
has_field?(schema, field)
```

Checks if a schema has a specific field.

**Parameters:**
- `schema`: The schema module to check
- `field`: The field to check for

**Returns:**
- `true` if the schema has the field, `false` otherwise

**Example:**
```elixir
if EctoShorts.SchemaHelpers.has_field?(User, :email) do
  # Do something with the email field
end
```

See also: `EctoShorts.SchemaHelpers.has_assoc?/2`

#### `EctoShorts.SchemaHelpers.has_assoc?/2`

```elixir
has_assoc?(schema, assoc)
```

Checks if a schema has a specific association.

**Parameters:**
- `schema`: The schema module to check
- `assoc`: The association to check for

**Returns:**
- `true` if the schema has the association, `false` otherwise

**Example:**
```elixir
if EctoShorts.SchemaHelpers.has_assoc?(User, :posts) do
  # Do something with the posts association
end
```

See also: `EctoShorts.SchemaHelpers.has_field?/2`, `EctoShorts.SchemaHelpers.get_assoc_type/2`

#### `EctoShorts.SchemaHelpers.get_assoc_type/2`

```elixir
get_assoc_type(schema, assoc)
```

Gets the type of a schema's association.

**Parameters:**
- `schema`: The schema module to check
- `assoc`: The association to get the type for

**Returns:**
- The association type (`:has_one`, `:has_many`, `:belongs_to`, or `:many_to_many`)
- `nil` if the schema doesn't have the association

**Example:**
```elixir
case EctoShorts.SchemaHelpers.get_assoc_type(User, :posts) do
  :has_many -> # Handle has_many association
  :belongs_to -> # Handle belongs_to association
  _ -> # Handle other cases
end
```

See also: `EctoShorts.SchemaHelpers.has_assoc?/2`, `Ecto.Schema`

## Common Filter Options

The following filter options are available in the `params` map passed to `EctoShorts.CommonFilters.convert_params_to_filter/3` and `EctoShorts.Actions.all/3`:

### Basic Filters

- `field_name: value` - Filters records where the field equals the value
- `field_name: [value1, value2]` - Filters records where the field is in the list of values

### Comparison Operators

- `field_name: %{gt: value}` - Greater than
- `field_name: %{gte: value}` - Greater than or equal to
- `field_name: %{lt: value}` - Less than
- `field_name: %{lte: value}` - Less than or equal to

### Text Search

- `field_name: %{like: value}` - Case-sensitive LIKE query (adds % wildcards)
- `field_name: %{ilike: value}` - Case-insensitive LIKE query (adds % wildcards)

### Date Filters

- `start_date: date` - Filters records inserted on or after the date
- `end_date: date` - Filters records inserted on or before the date

### Pagination

- `first: n` - Gets the first n records
- `last: n` - Gets the last n records
- `before: id` - Gets records with IDs before the specified ID
- `after: id` - Gets records with IDs after the specified ID

### Association Filters

- `assoc_name: value` - Filters records where the association field equals the value
- `assoc_name: [value1, value2]` - Filters records where the association field is in the list of values

### Preloading

- `preload: field_name` - Preloads a single association
- `preload: [field1, field2]` - Preloads multiple associations
- `preload: [field1: [nested_field]]` - Preloads nested associations

### Custom Search

- `search: term` - Uses the schema's `by_search/2` function to perform a custom search

## Common Options

The following options are available in the `opts` keyword list passed to most functions:

### Repository Options

- `:repo` - The `Ecto.Repo` to use for the operation
- `:replica` - A read replica to use for read operations

### Changeset Options

- `:changeset_fun` - The changeset function to use for create and update operations

### Filter Options

- `:filter_mode` - `:and` (default) or `:or` - determines how multiple filters are combined
- `:query_mode` - `:all` (default) or `:count` - determines whether to return all records or just a count

For more detailed information about all available filter options, see the [Filter Options Reference](/docs/reference/filter-options.md).

## Error Handling

Most functions in EctoShorts return tagged tuples to indicate success or failure:

- `{:ok, result}` - The operation was successful
- `{:error, reason}` - The operation failed

EctoShorts uses the `ErrorMessage` struct from the [elixir_error_message](https://github.com/MikaAK/elixir_error_message) package for standardized error handling. This provides a consistent error format with error codes, messages, and additional details.

Common error reasons include:

- `%ErrorMessage{code: :not_found, ...}` - The requested record was not found
- `%Ecto.Changeset{}` - The operation failed due to validation errors
- `%ErrorMessage{code: :bad_request, ...}` - Invalid parameters were provided
- `%ErrorMessage{code: :internal_server_error, ...}` - An unexpected error occurred

It's important to handle these errors appropriately in your application code. For example:

```elixir
case EctoShorts.Actions.get(User, id) do
  {:ok, user} -> 
    # Process the user
  {:error, %ErrorMessage{code: :not_found}} -> 
    # Handle not found error
end
```
