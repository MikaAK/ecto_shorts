defmodule EctoShorts.SchemaHelpers do
  @moduledoc since: "2.5.0"
  @moduledoc """
  Provides helper functions for common checks on
  Ecto schema data.
  """

  alias EctoShorts.Utils

  @type ecto_type :: Ecto.Type.t()
  @type schema :: Ecto.Queryable.t()
  @type schema_data :: Ecto.Schema.t()
  @type key :: atom()
  @type params :: map()

  @doc """
  Recursively resolves the related schema module for an association
  key on a given schema module.

  This function handles both direct and `:through` associations.
  For `:through` associations, it recursively follows the
  association path until it reaches the final related schema.

  ## Examples

      iex> EctoShorts.SchemaHelpers.get_related_schema(EctoShorts.Schemas.Post, :comments)
      EctoShorts.Schemas.Comment

      iex> EctoShorts.SchemaHelpers.get_related_schema(EctoShorts.Schemas.Post, :comments_authors)
      EctoShorts.Schemas.User

      iex> EctoShorts.SchemaHelpers.get_related_schema(EctoShorts.Schemas.Post, :does_not_exist)
      nil
  """
  @spec get_related_schema(schema(), key()) :: schema() | nil
  def get_related_schema(schema, key), do: lookup_related_schema(schema, key)

  defp lookup_related_schema(nil, _), do: nil

  defp lookup_related_schema(schema, []), do: schema

  defp lookup_related_schema(schema, [key | path]) do
    schema
    |> lookup_related_schema(key)
    |> lookup_related_schema(path)
  end

  defp lookup_related_schema(schema, key) do
    case schema.__schema__(:association, key) do
      %{related: schema} -> schema
      %{through: path} -> lookup_related_schema(schema, path)
      _ -> nil
    end
  end

  @doc """
  Returns the declared Ecto type of a given field in a schema.

  This uses the schema's `__schema__/2` introspection to
  retrieve the field type, which can be a primitive type
  (e.g. `:string`, `:integer`) or a composite like
  `{:array, :string}`.

  ## Examples

      iex> EctoShorts.SchemaHelpers.schema_field_type(EctoShorts.Schemas.Post, :title)
      :string

      iex> EctoShorts.SchemaHelpers.schema_field_type(EctoShorts.Schemas.Post, :tags)
      {:array, :string}

  """
  @spec schema_field_type(schema(), key()) :: ecto_type() | nil
  def schema_field_type(schema, key), do: schema.__schema__(:type, key)

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
  def all_schema_struct?(values), do: Utils.all?(values, &schema_struct?/1)

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
  def schema_struct?(%_{__meta__: %{schema: schema}}), do: schema_module?(schema)
  def schema_struct?(_), do: false

  def schema_module?(module) when is_atom(module) and module !== nil,
    do: function_exported?(module, :__schema__, 2)

  def schema_module?(_), do: false

  def source_has_schema?({_source, schema}), do: schema_module?(schema)
  def source_has_schema?(schema) when is_atom(schema), do: schema_module?(schema)
  def source_has_schema?(_), do: false

  def primary_key_count(schema), do: Enum.count(schema.__schema__(:primary_key))

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
  def primary_key(schema), do: schema.__schema__(:primary_key)

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
  @spec filter_primary_keys(params() | list(params()), schema()) :: params() | list(params())
  def filter_primary_keys(params_list, schema) when is_list(params_list) do
    params_list
    |> Enum.reduce([], fn params, acc ->
      case filter_primary_keys(params, schema) do
        [] -> acc
        values -> [values | acc]
      end
    end)
    |> Enum.reverse()
  end

  def filter_primary_keys(params, schema) when is_map(params) do
    primary_key = schema.__schema__(:primary_key)

    values = Map.take(params, primary_key)

    if has_required_keys?(values, primary_key) do
      values
    else
      %{}
    end
  end

  def only_has_primary_keys?(_schema, []), do: false

  def only_has_primary_keys?(_schema, params) when params === %{}, do: false

  def only_has_primary_keys?(schema, params_list) when is_list(params_list) do
    Utils.all?(params_list, fn params -> only_has_primary_keys?(schema, params) end)
  end

  def only_has_primary_keys?(schema, params) when is_map(params) do
    keys = schema.__schema__(:primary_key)

    has_required_keys?(params, keys) and params === Map.take(params, keys)
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
      ...> EctoShorts.SchemaHelpers.all_has_primary_keys?(EctoShorts.Schemas.Post, records)
      false

      # A list where every item has the primary key set (structs or maps)
      iex> records = [%EctoShorts.Schemas.Post{id: 5}, %{id: 6}]
      ...> EctoShorts.SchemaHelpers.all_has_primary_keys?(EctoShorts.Schemas.Post, records)
      true
  """
  @spec all_has_primary_keys?(schema(), list(params() | schema_data())) :: boolean()
  def all_has_primary_keys?(schema, values) do
    Utils.all?(values, &has_primary_keys?(schema, &1))
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
      ...> EctoShorts.SchemaHelpers.any_has_primary_keys?(EctoShorts.Schemas.Post, list)
      true

      # No item in the list has a primary key
      iex> list2 = [%{id: nil}, %{title: "No ID"}]
      ...> EctoShorts.SchemaHelpers.any_has_primary_keys?(EctoShorts.Schemas.Post, list2)
      false
  """
  @spec any_has_primary_keys?(schema(), list(params() | schema_data())) :: boolean()
  def any_has_primary_keys?(schema, values) do
    Enum.any?(values, &has_primary_keys?(schema, &1))
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

  In practice, `has_primary_keys?/2` tells you if `data` has enough
  information to uniquely identify a record of type `schema`.
  This is often true when the record has been fetched from or saved to
  the database.

  If this returns `false`, it means `data` is either incomplete (missing
  an ID or other primary key) or not an appropriate data structure for
  the given schema.

  ## Examples

      # Ecto schema struct with primary key set
      iex> post = %EctoShorts.Schemas.Post{id: 7, title: "Helen"}
      ...> EctoShorts.SchemaHelpers.has_primary_keys?(EctoShorts.Schemas.Post, post)
      true

      # Map with all primary key fields present
      iex> attrs = %{"id" => 9, "name" => "Jill"}
      ...> EctoShorts.SchemaHelpers.has_primary_keys?(EctoShorts.Schemas.Post, attrs)
      true

      # Map missing the primary key
      iex> incomplete_attrs = %{title: "Kelly"}
      ...> EctoShorts.SchemaHelpers.has_primary_keys?(EctoShorts.Schemas.Post, incomplete_attrs)
      false
  """
  def has_primary_keys?(schema, value),
    do: has_required_keys?(value, schema.__schema__(:primary_key))

  defp has_required_keys?(%_{} = schema_data, keys) do
    Utils.all?(keys, fn key ->
      nil_value? = Map.get(schema_data, key) === nil
      Map.has_key?(schema_data, key) and not nil_value?
    end)
  end

  defp has_required_keys?(params, keys) do
    Utils.all?(keys, fn key ->
      map_has_non_nil_key?(params, key) or map_has_non_nil_key?(params, to_string(key))
    end)
  end

  defp map_has_non_nil_key?(map, key) do
    Map.has_key?(map, key) and Map.get(map, key) !== nil
  end
end
