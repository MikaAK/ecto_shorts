defmodule EctoShorts.SchemaHelpers do
  @moduledoc since: "2.5.0"
  @moduledoc """
  Provides helper functions for common checks on
  Ecto schema data.
  """

  @type ecto_type :: Ecto.Type.t()
  @type schema :: Ecto.Queryable.t()
  @type schema_data :: Ecto.Schema.t()
  @type key :: atom()
  @type params :: map()

  def schema_module?(nil), do: false
  def schema_module?(module) when is_atom(module), do: function_exported?(module, :__schema__, 2)
  def schema_module?(_), do: false

  def schema_source?({_source, schema}), do: schema_module?(schema)
  def schema_source?(schema) when is_atom(schema), do: schema_module?(schema)
  def schema_source?(_), do: false

  def schema_from_source({_, schema}), do: schema
  def schema_from_source(schema), do: schema

  @doc """
  This is a simple wrapper function for `get_schema_assoc_module/2`
  that returns the atom `:error` if the association key is not found on
  the given Ecto schema module.

  ## Examples

      iex> EctoShorts.SchemaHelpers.fetch_schema_assoc_module!(EctoShorts.Schemas.Post, :comments)
      EctoShorts.Schemas.Comment

      iex> EctoShorts.SchemaHelpers.fetch_schema_assoc_module!(EctoShorts.Schemas.Post, :comments_authors)
      EctoShorts.Schemas.User

      iex> EctoShorts.SchemaHelpers.fetch_schema_assoc_module!(EctoShorts.Schemas.Post, :does_not_exist)
      ** (ArgumentError) association key not found for the schema EctoShorts.Schemas.Post, got: :does_not_exist
  """
  @spec fetch_schema_assoc_module!(schema(), key()) :: schema()
  def fetch_schema_assoc_module!(schema, key) do
    with :error <- fetch_schema_assoc_module(schema, key) do
      raise ArgumentError,
            "association key not found for the schema #{inspect(schema)}, got: #{inspect(key)}"
    end
  end

  @doc """
  This is a simple wrapper function for `get_schema_assoc_module/2`
  that returns the atom `:error` if the association key is not found on
  the given Ecto schema module.

  ## Examples

      iex> EctoShorts.SchemaHelpers.fetch_schema_assoc_module(EctoShorts.Schemas.Post, :comments)
      EctoShorts.Schemas.Comment

      iex> EctoShorts.SchemaHelpers.fetch_schema_assoc_module(EctoShorts.Schemas.Post, :comments_authors)
      EctoShorts.Schemas.User

      iex> EctoShorts.SchemaHelpers.fetch_schema_assoc_module(EctoShorts.Schemas.Post, :does_not_exist)
      :error
  """
  @spec fetch_schema_assoc_module(schema(), key()) :: schema() | :error
  def fetch_schema_assoc_module(schema, key) do
    with nil <- get_schema_assoc_module(schema, key) do
      :error
    end
  end

  @doc """
  Recursively resolves the related schema module for an association
  key on a given schema module.

  This function handles both direct and `:through` associations.
  For `:through` associations, it recursively follows the
  association path until it reaches the final related schema.

  ## Examples

      iex> EctoShorts.SchemaHelpers.get_schema_assoc_module(EctoShorts.Schemas.Post, :comments)
      EctoShorts.Schemas.Comment

      iex> EctoShorts.SchemaHelpers.get_schema_assoc_module(EctoShorts.Schemas.Post, :comments_authors)
      EctoShorts.Schemas.User

      iex> EctoShorts.SchemaHelpers.get_schema_assoc_module(EctoShorts.Schemas.Post, :does_not_exist)
      nil
  """
  @spec get_schema_assoc_module(schema(), key()) :: schema() | nil
  def get_schema_assoc_module(schema, key) do
    get_related_schema(schema, key)
  end

  defp get_related_schema(nil, _key) do
    nil
  end

  defp get_related_schema(schema, key) do
    case schema.__schema__(:association, key) do
      %{through: [field1, field2]} ->
        schema
        |> get_related_schema(field1)
        |> get_related_schema(field2)

      %{related: schema} ->
        schema

      _ ->
        nil
    end
  end

  @doc """
  Checks if the type of a given field on a schema is an array type.

  This is useful when you want to handle fields differently based
  on whether they store multiple values (e.g. `{:array, :string}`)
  or a single value.

  ## Examples

      iex> EctoShorts.SchemaHelpers.field_type_array?(EctoShorts.Schemas.Post, :tags)
      true

      iex> EctoShorts.SchemaHelpers.field_type_array?(EctoShorts.Schemas.Post, :title)
      false

  """
  @spec field_type_array?(schema(), key()) :: boolean()
  def field_type_array?(schema, key) do
    case field_type(schema, key) do
      {:array, _} -> true
      _ -> false
    end
  end

  @doc """
  Returns the declared Ecto type of a given field in a schema.

  This uses the schema's `__schema__/2` introspection to
  retrieve the field type, which can be a primitive type
  (e.g. `:string`, `:integer`) or a composite like
  `{:array, :string}`.

  ## Examples

      iex> EctoShorts.SchemaHelpers.field_type(EctoShorts.Schemas.Post, :title)
      :string

      iex> EctoShorts.SchemaHelpers.field_type(EctoShorts.Schemas.Post, :tags)
      {:array, :string}

  """
  @spec field_type(schema(), key()) :: ecto_type() | nil
  def field_type(schema, key) do
    schema.__schema__(:type, key)
  end

  @doc """
  Returns `true` if the value of `key` is not an
  `Ecto.Association.NotLoaded` struct, otherwise `false.`

  ## Examples

      # Given a Post struct with a not preloaded :comments association
      iex> post = %EctoShorts.Schemas.Post{comments: %Ecto.Association.NotLoaded{}}
      ...> EctoShorts.SchemaHelpers.association_loaded?(post, :comments)
      false

      # If the association is preloaded (even as an empty list), it returns true
      iex> post_with_comments = %EctoShorts.Schemas.Post{comments: []}
      ...> EctoShorts.SchemaHelpers.association_loaded?(post_with_comments, :comments)
      true
  """
  @spec association_loaded?(schema_data(), key()) :: boolean()
  def association_loaded?(schema_data, key), do: !association_not_loaded?(schema_data, key)

  @doc """
  Returns `true` if the value of `key` is an `Ecto.Association.NotLoaded`
  struct, otherwise `false.`

  ## Examples

      # Suppose we have a User struct whose :profile association hasn't been preloaded
      iex> post = %EctoShorts.Schemas.Post{comments: %Ecto.Association.NotLoaded{}}
      ...> EctoShorts.SchemaHelpers.association_not_loaded?(post, :comments)
      true
  """
  @spec association_not_loaded?(schema_data(), key()) :: boolean()
  def association_not_loaded?(schema_data, key) do
    schema_data
    |> Map.get(key)
    |> is_struct(Ecto.Association.NotLoaded)
  end

  @doc """
  Returns `true` if all items in the list has been created
  (persisted), otherwise returns `false`.

  It checks each element in the `values` list to see if it
  appears to be a persisted record, by verifying that all
  primary key fields are set .

  If all items have their primary keys present and non-nil,
  the result is `true`. If any item is missing a primary
  key (indicating it hasn't been persisted to the database
  yet), the result is `false`.

  ## Examples

      # List where one user has not been saved (id is nil)
      iex> posts = [%EctoShorts.Schemas.Post{id: 1}, %EctoShorts.Schemas.Post{id: 2}, %EctoShorts.Schemas.Post{id: nil}]
      ...> EctoShorts.SchemaHelpers.all_created?(EctoShorts.Schemas.Post, posts)
      false

      # List where all posts have an id (all are persisted)
      iex> posts_all_saved = [%EctoShorts.Schemas.Post{id: 10}, %EctoShorts.Schemas.Post{id: 11}]
      ...> EctoShorts.SchemaHelpers.all_created?(EctoShorts.Schemas.Post, posts_all_saved)
      true
  """
  @spec all_created?(schema(), list(schema_data() | params() | any())) :: boolean()
  def all_created?(schema, values), do: Enum.all?(values, &created?(schema, &1))

  @doc """
  Returns `true` if any item in the list has been created
  (persisted), otherwise returns `false`.

  It checks each element in the `values` list to see if it
  appears to be a persisted record, by verifying that all
  primary key fields are set .

  If any items has all primary keys present and non-nil,
  the result is `true`. If any item is missing a primary
  key (indicating it hasn't been persisted to the database
  yet), the result is `false`.

  ## Examples

      # List with a mix of persisted and non-persisted items
      iex> data = [%EctoShorts.Schemas.Post{id: nil}, %EctoShorts.Schemas.Post{id: 5}, %{title: "Charlie"}]
      ...> EctoShorts.SchemaHelpers.any_created?(EctoShorts.Schemas.Post, data)
      true

      # List where no item has been persisted yet (no ids present)
      iex> new_data = [%EctoShorts.Schemas.Post{id: nil}, %{title: "Dana"}]
      ...> EctoShorts.SchemaHelpers.any_created?(EctoShorts.Schemas.Post, new_data)
      false
  """
  @spec any_created?(schema(), list(schema_data() | params() | any())) :: boolean()
  def any_created?(schema, values), do: Enum.any?(values, &created?(schema, &1))

  @doc """
  Checks if a given struct or map likely represents a record
  that has been created/persisted (all primary key fields
  are set).

  This function determines whether the `data` (which can be
  an Ecto schema struct, an Ecto changeset, or a plain map
  of fields) has all of its primary key fields present and
  not `nil`. In other words, it returns `true` if the item
  looks like it has been inserted into the database (since
  the primary keys, often an `id`, are typically assigned
  by the database upon insertion). Otherwise, it returns
  `false`.

  Under the hood, this function uses `has_primary_key?/2` for
  the actual check when `data` is a map or struct. If `data`
  is not a map (for example, if someone accidentally passes
  just an integer or other type), `created?/2` will
  immediately return `false`.

  ## Examples

      # An Ecto schema struct with an id (persisted record)
      iex> schema_data = %EctoShorts.Schemas.Post{id: 42}
      ...> EctoShorts.SchemaHelpers.created?(EctoShorts.Schemas.Post, schema_data)
      true

      # A changeset for an existing record (id present in data)
      iex> changeset = Ecto.Changeset.change(%EctoShorts.Schemas.Post{id: 42})
      ...> EctoShorts.SchemaHelpers.created?(EctoShorts.Schemas.Post, changeset)
      true

      # A map representing a new record (no id yet)
      iex> EctoShorts.SchemaHelpers.created?(EctoShorts.Schemas.Post, %{title: "example"})
      false
  """
  @spec created?(schema(), schema_data() | params() | any()) :: boolean()
  def created?(schema, data) when is_map(data), do: has_primary_key?(schema, data)
  def created?(_schema, _term), do: false

  @doc """
  Returns `true` if all items in the given list are Ecto
  schema structs, otherwise returns `false`.

  ## Examples

      # A list where every element is an Ecto schema struct
      iex> list = [%EctoShorts.Schemas.Post{}, %EctoShorts.Schemas.Comment{}]
      ...> EctoShorts.SchemaHelpers.all_schema_struct?(list)
      true

      # A list with mixed types (one struct, one map)
      iex> mixed_list = [%EctoShorts.Schemas.Post{}, %{title: "Not a schema"}]
      ...> EctoShorts.SchemaHelpers.all_schema_struct?(mixed_list)
      false
  """
  @spec all_schema_struct?(list(schema_data() | any())) :: boolean()
  def all_schema_struct?(values), do: Enum.all?(values, &schema_struct?/1)

  @doc """
  Returns `true` if any item in the given list is an Ecto
  schema struct, otherwise returns `false`.

  ## Examples

      # A list containing at least one Ecto struct
      iex> items = [%EctoShorts.Schemas.Post{}, %{id: 1, title: "Frank"}]
      ...> EctoShorts.SchemaHelpers.any_schema_struct?(items)
      true

      # A list of maps with no Ecto structs
      iex> maps = [%{title: "George"}, %{title: "Hannah"}]
      ...> EctoShorts.SchemaHelpers.any_schema_struct?(maps)
      false
  """
  @spec any_schema_struct?(list(schema_data() | any())) :: boolean()
  def any_schema_struct?(values), do: Enum.any?(values, &schema_struct?/1)

  @doc """
  Returns `true` if the given value is an Ecto schema struct,
  otherwise returns `false`.

  ## Examples

      iex> EctoShorts.SchemaHelpers.schema_struct?(%EctoShorts.Schemas.Post{})
      true

      iex> EctoShorts.SchemaHelpers.schema_struct?(%{title: "Not a schema"})
      false
  """
  @spec schema_struct?(schema_data() | any()) :: boolean()
  def schema_struct?(%{__meta__: %{schema: _}}), do: true
  def schema_struct?(_), do: false

  @doc """
  Filters a map (or list of maps) to include only the primary
  key fields of the given schema.

  Given a schema module and some parameters (either as a single
  map or a list of maps), this function will return only the
  key-value pairs that correspond to the schema's primary key(s).

  All other fields in the input are filtered out.

  If you provide a single map as `params`, the result will be a
  new map containing only the primary key fields from the original.
  If you provide a list of maps, it will perform this filtering
  for each map in the list, returning a list of maps that each
  contain only primary key fields.

  This is useful for extracting IDs or identifying keys from data.
  For instance, you might have a list of changes or records and
  want to get just the IDs to query the database for existing
  records, or to compare sets of IDs.

  **Note:** The function expects the schema module to be an Ecto
  schema that defines primary keys. The keys in the input maps
  can be atoms or strings, and it will handle both by converting
  to string for comparison.
  """
  @spec filter_primary_key(params() | list(params()), schema()) :: params() | list(params())
  def filter_primary_key(params_list, schema) when is_list(params_list) do
    primary_key = schema.__schema__(:primary_key)

    params_list
    |> Enum.map(&take_if_all_keys_member(&1, primary_key))
    |> Enum.reject(&is_nil/1)
  end

  def filter_primary_key(params, schema) do
    take_if_all_keys_member(params, schema.__schema__(:primary_key)) || %{}
  end

  defp take_if_all_keys_member(_params, []) do
    nil
  end

  defp take_if_all_keys_member(params, keys) do
    params = Map.take(params, keys)

    if all_keys_member?(params, keys) do
      params
    else
      nil
    end
  end

  def all_only_primary_key?(schema, params_list) when is_list(params_list) do
    Enum.all?(params_list, fn params -> all_only_primary_key?(schema, params) end)
  end

  def all_only_primary_key?(schema, params) when is_map(params) do
    all_keys_member?(params, schema.__schema__(:primary_key))
  end

  @doc """
  Returns `true` if every item in the list has all of its primary
  key fields set (not nil).

  This function checks each element in the `values` list (which can
  include Ecto schema structs, changesets, or plain maps) and
  ensures that for each element, all primary key fields defined in
  `schema` are present and not `nil`.

  If all items have their primary keys, it returns `true`.
  If at-least one item is missing any primary key, it returns `false`.

  ## Examples

      # A list where one struct is missing its primary key
      iex> records = [%EctoShorts.Schemas.Post{id: 5}, %EctoShorts.Schemas.Post{id: nil}, %{id: 8}]
      ...> EctoShorts.SchemaHelpers.all_has_primary_key?(EctoShorts.Schemas.Post, records)
      false

      # A list where every item has the primary key set (structs or maps)
      iex> records = [%EctoShorts.Schemas.Post{id: 5}, %{id: 6}]
      ...> EctoShorts.SchemaHelpers.all_has_primary_key?(EctoShorts.Schemas.Post, records)
      true
  """
  @spec all_has_primary_key?(schema(), list(params() | schema_data())) :: boolean()
  def all_has_primary_key?(schema, values) do
    Enum.all?(values, &has_primary_key?(schema, &1))
  end

  @doc """
  Returns `true` if at least one item in the list has all of its
  primary key fields set.

  It iterates through the `values` list and checks each element
  (using `primary_key?/2`). If at least one element has every
  primary key present and non-nil, this function returns `true`.

  If no element in the list has a complete set of primary keys,
  it returns `false`.

  ## Examples

      # List has one map with a full primary key (id present)
      iex> list = [%{id: nil}, %{id: 100}, %{title: "New"}]
      ...> EctoShorts.SchemaHelpers.any_has_primary_key?(EctoShorts.Schemas.Post, list)
      true

      # No item in the list has a primary key
      iex> list2 = [%{id: nil}, %{title: "No ID"}]
      ...> EctoShorts.SchemaHelpers.any_has_primary_key?(EctoShorts.Schemas.Post, list2)
      false
  """
  @spec any_has_primary_key?(schema(), list(params() | schema_data())) :: boolean()
  def any_has_primary_key?(schema, values) do
    Enum.any?(values, &has_primary_key?(schema, &1))
  end

  @doc """
  Checks if the given data structure has all primary key fields
  (for the specified schema) set to non-nil values.

  This is a low-level predicate that verifies the presence of primary
  keys in `data` according to the primary key definition of `schema`.

  It's flexible in terms of what `data` can be:

  - If `data` is an Ecto schema struct (e.g., a `%EctoShorts.Schemas.Post{}` struct), it
    will go through each primary key field of that schema and ensure
    none of those fields are `nil` in the struct.

  - If `data` is an Ecto changeset, it will look at the changeset's
    underlying data and perform the same check on that struct.

  - If `data` is a map, it will check that all keys corresponding to
    the schema's primary key fields are present in the map and have non
    `nil` values. It handles both atom and string keys by converting the
    schema's primary key names to strings for comparison.

  - For any other type of `data`, the function will simply return `false`.

  In practice, `has_primary_key?/2` tells you if `data` has enough
  information to uniquely identify a record of type `schema`.
  This is often true when the record has been fetched from or saved to
  the database.

  If this returns `false`, it means `data` is either incomplete (missing
  an ID or other primary key) or not an appropriate data structure for
  the given schema.

  ## Examples

      # Ecto schema struct with primary key set
      iex> post = %EctoShorts.Schemas.Post{id: 7, title: "Helen"}
      ...> EctoShorts.SchemaHelpers.has_primary_key?(EctoShorts.Schemas.Post, post)
      true

      # Ecto changeset for a struct with primary key set
      iex> changeset = Ecto.Changeset.change(%EctoShorts.Schemas.Post{id: 8, title: "Ian"})
      ...> EctoShorts.SchemaHelpers.has_primary_key?(EctoShorts.Schemas.Post, changeset)
      true

      # Map with all primary key fields present
      iex> attrs = %{"id" => 9, "name" => "Jill"}
      ...> EctoShorts.SchemaHelpers.has_primary_key?(EctoShorts.Schemas.Post, attrs)
      true

      # Map missing the primary key
      iex> incomplete_attrs = %{title: "Kelly"}
      ...> EctoShorts.SchemaHelpers.has_primary_key?(EctoShorts.Schemas.Post, incomplete_attrs)
      false
  """
  @spec has_primary_key?(Ecto.Queryable.t(), Ecto.Changeset.t() | Ecto.Schema.t() | map()) ::
          boolean()
  def has_primary_key?(schema, %{data: %{__meta__: _} = schema_data}) do
    has_primary_key?(schema, schema_data)
  end

  def has_primary_key?(schema, schema_data_or_params) do
    has_all_non_nil_keys?(schema_data_or_params, schema.__schema__(:primary_key))
  end

  def primary_key_count(schema) do
    Enum.count(schema.__schema__(:primary_key))
  end

  @doc """
  Returns a list of the primary key field names (as atoms)
  for the given schema.

  This function simply retrieves the primary key fields defined
  in the Ecto schema module `schema`. In most cases,
  this will return a list with a single atom (e.g., `[:id]`).
  However, for schemas with composite primary keys, it can
  return multiple atoms.

  ## Examples

      iex> EctoShorts.SchemaHelpers.primary_key(EctoShorts.Schemas.Post)
      [:id]

      # Example for a schema with composite primary keys (for illustration)
      iex> EctoShorts.SchemaHelpers.primary_key(EctoShorts.Schemas.CompositePrimaryKey)
      [:comment_id, :post_id]
  """
  def primary_key(schema) do
    schema.__schema__(:primary_key)
  end

  defp has_all_non_nil_keys?(_, []) do
    false
  end

  defp has_all_non_nil_keys?(%_{} = schema_data, keys) do
    Enum.all?(keys, fn key ->
      Map.has_key?(schema_data, key) and not (schema_data |> Map.fetch!(key) |> is_nil())
    end)
  end

  defp has_all_non_nil_keys?(params, keys) do
    Enum.all?(keys, fn key ->
      (Map.has_key?(params, key) and Map.get(params, key) !== nil) or
        (Map.has_key?(params, to_string(key)) and Map.get(params, to_string(key)) !== nil)
    end)
  end

  defp all_keys_member?(_, []) do
    false
  end

  defp all_keys_member?(params, keys) do
    Enum.all?(params, fn
      {key, val} when is_atom(key) -> key in keys and not is_nil(val)
      {key, val} when is_binary(key) -> String.to_existing_atom(key) in keys and not is_nil(val)
    end)
  end
end
