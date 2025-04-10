# API Reference

This reference document provides detailed information about all the modules, functions, and options available in ecto_shorts.

## EctoShorts.Actions

The `Actions` module provides a consistent interface for performing CRUD operations.

### Functions

#### create/3

```elixir
create(schema, attrs, opts \\ [])
```

Creates a new record of the given schema with the provided attributes.

**Parameters:**
- `schema`: The schema module to create a record for
- `attrs`: A map of attributes to set on the new record
- `opts`: Options (see below)

**Options:**
- `:repo`: The Ecto.Repo to use (defaults to the configured repo)
- `:changeset_fun`: The changeset function to use (defaults to `create_changeset/1` or `changeset/2`)
- Any other options are passed to the repo's `insert/2` function

**Returns:**
- `{:ok, record}` if the record was created successfully
- `{:error, changeset}` if there was an error

**Example:**
```elixir
{:ok, user} = EctoShorts.Actions.create(User, %{name: "John", email: "john@example.com"})
```

#### get/3

```elixir
get(schema, id, opts \\ [])
```

Gets a record of the given schema by its ID.

**Parameters:**
- `schema`: The schema module to get a record for
- `id`: The ID of the record to get
- `opts`: Options (see below)

**Options:**
- `:repo`: The Ecto.Repo to use (defaults to the configured repo)
- `:replica`: A read replica to use for the query
- `:preload`: Fields to preload on the record
- Any other options are passed to `CommonFilters.convert_params_to_filter/3`

**Returns:**
- `{:ok, record}` if the record was found
- `{:error, :not_found}` if the record was not found

**Example:**
```elixir
{:ok, user} = EctoShorts.Actions.get(User, 1, preload: [:posts])
```

#### get_by/3

```elixir
get_by(schema, attrs, opts \\ [])
```

Gets a record of the given schema by the provided attributes.

**Parameters:**
- `schema`: The schema module to get a record for
- `attrs`: A map of attributes to filter by
- `opts`: Options (see below)

**Options:**
- `:repo`: The Ecto.Repo to use (defaults to the configured repo)
- `:replica`: A read replica to use for the query
- `:preload`: Fields to preload on the record
- Any other options are passed to `CommonFilters.convert_params_to_filter/3`

**Returns:**
- `{:ok, record}` if the record was found
- `{:error, :not_found}` if the record was not found

**Example:**
```elixir
{:ok, user} = EctoShorts.Actions.get_by(User, %{email: "john@example.com"})
```

#### all/3

```elixir
all(schema, filters \\ %{}, opts \\ [])
```

Gets all records of the given schema that match the provided filters.

**Parameters:**
- `schema`: The schema module to get records for
- `filters`: A map of filters to apply (see CommonFilters)
- `opts`: Options (see below)

**Options:**
- `:repo`: The Ecto.Repo to use (defaults to the configured repo)
- `:replica`: A read replica to use for the query
- Any other options are passed to `CommonFilters.convert_params_to_filter/3`

**Returns:**
- A list of records that match the filters

**Example:**
```elixir
users = EctoShorts.Actions.all(User, %{age: %{gte: 18}})
```

#### count/3

```elixir
count(schema, filters \\ %{}, opts \\ [])
```

Counts the number of records of the given schema that match the provided filters.

**Parameters:**
- `schema`: The schema module to count records for
- `filters`: A map of filters to apply (see CommonFilters)
- `opts`: Options (see below)

**Options:**
- `:repo`: The Ecto.Repo to use (defaults to the configured repo)
- `:replica`: A read replica to use for the query
- Any other options are passed to `CommonFilters.convert_params_to_filter/3`

**Returns:**
- An integer representing the count of matching records

**Example:**
```elixir
count = EctoShorts.Actions.count(User, %{active: true})
```

#### update/4

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
- `:repo`: The Ecto.Repo to use (defaults to the configured repo)
- `:changeset_fun`: The changeset function to use (defaults to `update_changeset/2` or `changeset/2`)
- Any other options are passed to the repo's `update/2` function

**Returns:**
- `{:ok, record}` if the record was updated successfully
- `{:error, changeset}` if there was an error
- `{:error, :not_found}` if the record was not found

**Example:**
```elixir
{:ok, user} = EctoShorts.Actions.update(User, 1, %{name: "Jane"})
```

#### delete/3

```elixir
delete(schema, id, opts \\ [])
```

Deletes a record of the given schema.

**Parameters:**
- `schema`: The schema module to delete a record for
- `id`: The ID of the record to delete
- `opts`: Options (see below)

**Options:**
- `:repo`: The Ecto.Repo to use (defaults to the configured repo)
- Any other options are passed to the repo's `delete/2` function

**Returns:**
- `{:ok, record}` if the record was deleted successfully
- `{:error, changeset}` if there was an error
- `{:error, :not_found}` if the record was not found

**Example:**
```elixir
{:ok, user} = EctoShorts.Actions.delete(User, 1)
```

## EctoShorts.CommonFilters

The `CommonFilters` module provides functions to convert parameter maps into Ecto queries.

### Functions

#### convert_params_to_filter/3

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
- An Ecto query with the filters applied

**Example:**
```elixir
query = EctoShorts.CommonFilters.convert_params_to_filter(User, %{age: %{gte: 18}})
users = MyApp.Repo.all(query)
```

## EctoShorts.CommonChanges

The `CommonChanges` module provides functions to handle associations in Ecto changesets.

### Functions

#### put_or_cast_assoc/3

```elixir
put_or_cast_assoc(changeset, assoc_field, opts \\ [])
```

Intelligently determines whether to use `put_assoc` or `cast_assoc` based on the data.

**Parameters:**
- `changeset`: The changeset to modify
- `assoc_field`: The association field to handle
- `opts`: Options (see below)

**Options:**
- `:ids`: A list of IDs to use for the association (for many-to-many relationships)
- `:with`: A function to apply to each associated item before casting
- `:required`: Whether the association is required
- Any other options are passed to `cast_assoc/3` or `put_assoc/3`

**Returns:**
- The modified changeset

**Example:**
```elixir
changeset = EctoShorts.CommonChanges.put_or_cast_assoc(changeset, :posts)
```

#### put_or_cast_assocs/3

```elixir
put_or_cast_assocs(changeset, assoc_fields, opts \\ [])
```

Applies `put_or_cast_assoc/3` to multiple association fields.

**Parameters:**
- `changeset`: The changeset to modify
- `assoc_fields`: A list of association fields to handle
- `opts`: Options (see put_or_cast_assoc/3)

**Returns:**
- The modified changeset

**Example:**
```elixir
changeset = EctoShorts.CommonChanges.put_or_cast_assocs(changeset, [:posts, :comments])
```

## EctoShorts.SchemaHelpers

The `SchemaHelpers` module provides helper functions for working with Ecto schemas.

### Functions

#### has_field?/2

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

#### has_assoc?/2

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

#### get_assoc_type/2

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

## Common Filter Options

The following filter options are available in the `params` map passed to `CommonFilters.convert_params_to_filter/3` and `Actions.all/3`:

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

- `:repo` - The Ecto.Repo to use for the operation
- `:replica` - A read replica to use for read operations

### Changeset Options

- `:changeset_fun` - The changeset function to use for create and update operations

### Filter Options

- `:filter_mode` - `:and` (default) or `:or` - determines how multiple filters are combined
- `:query_mode` - `:all` (default) or `:count` - determines whether to return all records or just a count

## Error Handling

Most functions in ecto_shorts return tagged tuples to indicate success or failure:

- `{:ok, result}` - The operation was successful
- `{:error, reason}` - The operation failed

Common error reasons include:

- `:not_found` - The requested record was not found
- A changeset with errors - The operation failed due to validation errors

It's important to handle these errors appropriately in your application code.
