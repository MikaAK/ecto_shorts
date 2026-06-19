defmodule EctoShorts.SchemaHelpers do
  @moduledoc since: "3.0.0"
  @moduledoc """
  Predicates and introspection utilities for Ecto schema data.

  Use this module when you need to check whether values are schema structs,
  verify that records have been persisted, resolve association schemas, or
  inspect field types. These utilities help you write defensive code that
  works correctly with both schema structs and plain maps.

  ## Add schema helper functions

  Check if a value is a schema struct:

      iex> EctoShorts.SchemaHelpers.schema_struct?(%EctoShorts.Schema.Post{})
      true

      iex> EctoShorts.SchemaHelpers.schema_struct?(%{title: "Not a schema"})
      false

  Check if a module is a schema:

      iex> EctoShorts.SchemaHelpers.schema_module?(EctoShorts.Schema.Post)
      true

      iex> EctoShorts.SchemaHelpers.schema_module?(String)
      false

  Resolve association schemas:

      iex> EctoShorts.SchemaHelpers.get_related_schema(EctoShorts.Schema.Post, :comments)
      EctoShorts.Schema.Comment

  Check if a record has been persisted:

      iex> EctoShorts.SchemaHelpers.any_persisted?(%EctoShorts.Schema.Post{id: 1})
      true

      iex> EctoShorts.SchemaHelpers.any_persisted?(%EctoShorts.Schema.Post{id: nil})
      false

  ## When to use schema helpers

  Use this module when you need to:

  * **Validate input types** - check that a value is a schema struct before
    accessing schema-specific fields.
  * **Handle polymorphic data** - write functions that accept both schema
    structs and plain maps.
  * **Resolve associations** - find the schema module for an association
    without manually traversing the association tree.
  * **Check persistence state** - verify that a record has been saved to the
    database before performing operations that require an ID.
  * **Inspect field types** - get the Ecto type of a field for validation or
    coercion logic.

  ## Schema struct predicates

  Use `schema_struct?/1` to check if a value is an Ecto schema struct:

      def process_record(record) do
        if EctoShorts.SchemaHelpers.schema_struct?(record) do
          # Safe to access schema-specific fields
          record.__meta__.state
        else
          # Handle plain map
          :unknown
        end
      end

  Use `schema_module?/1` to check if a module is a schema:

      def validate_schema(module) do
        if EctoShorts.SchemaHelpers.schema_module?(module) do
          module.__schema__(:fields)
        else
          raise ArgumentError, "Expected a schema module"
        end
      end

  ## Association resolution

  Use `get_related_schema/2` to resolve the schema for an association:

      def validate_association(parent_schema, assoc_key) do
        case EctoShorts.SchemaHelpers.get_related_schema(parent_schema, assoc_key) do
          nil ->
            {:error, "Association not found"}

          related_schema ->
            {:ok, related_schema.__schema__(:fields)}
        end
      end

  ### Through associations

  `get_related_schema/2` follows `:through` associations automatically:

      defmodule Post do
        schema "posts" do
          has_many :comments, Comment
          has_many :comments_authors, through: [:comments, :author]
        end
      end

      EctoShorts.SchemaHelpers.get_related_schema(Post, :comments_authors)
      # User

  The function traverses the path `[:comments, :author]` and returns the
  final schema (`User`).

  ## Persistence checks

  Use `any_persisted?/1` to check if a record has been persisted:

      def update_record(record, params) do
        if EctoShorts.SchemaHelpers.any_persisted?(record) do
          # Record exists, perform update
          Repo.update(changeset(record, params))
        else
          # Record is new, perform insert
          Repo.insert(changeset(record, params))
        end
      end

  This works with both schema structs and plain maps:

      EctoShorts.SchemaHelpers.any_persisted?(%Post{id: 1})
      # true

      EctoShorts.SchemaHelpers.any_persisted?(%{id: 42})
      # true

      EctoShorts.SchemaHelpers.any_persisted?(%{"id" => 99})
      # true

  ## Field type inspection

  Use `schema_field_type/2` to get the Ecto type of a field:

      def coerce_value(schema, field, value) do
        case EctoShorts.SchemaHelpers.schema_field_type(schema, field) do
          :integer -> String.to_integer(value)
          :string -> to_string(value)
          {:array, :string} -> String.split(value, ",")
          _ -> value
        end
      end

  ## Association preload checks

  Use `association_not_loaded?/2` to check if an association needs preloading:

      def get_comments(post) do
        if EctoShorts.SchemaHelpers.association_not_loaded?(post, :comments) do
          Repo.preload(post, :comments).comments
        else
          post.comments
        end
      end

  ## Collection predicates

  Use `all_schema_struct?/1` to check if all items are schema structs:

      def batch_insert(records) do
        if EctoShorts.SchemaHelpers.all_schema_struct?(records) do
          # All records are structs, use put_assoc
          Ecto.Changeset.put_assoc(changeset, :items, records)
        else
          # Mixed or plain maps, use cast_assoc
          Ecto.Changeset.cast_assoc(changeset, :items)
        end
      end

  Use `any_schema_struct?/1` to check if any item is a schema struct:

      def contains_persisted_records?(items) do
        EctoShorts.SchemaHelpers.any_schema_struct?(items)
      end

  ## Common patterns

  **Pattern 1: Defensive schema access**

  Check before accessing schema-specific fields:

      def get_state(record) do
        if EctoShorts.SchemaHelpers.schema_struct?(record) do
          record.__meta__.state
        else
          :unknown
        end
      end

  **Pattern 2: Polymorphic function arguments**

  Accept both schema modules and structs:

      def get_fields(source) do
        cond do
          EctoShorts.SchemaHelpers.schema_module?(source) ->
            source.__schema__(:fields)

          EctoShorts.SchemaHelpers.schema_struct?(source) ->
            source.__struct__.__schema__(:fields)

          true ->
            []
        end
      end

  **Pattern 3: Association validation**

  Verify associations exist before using them:

      def validate_association_exists(schema, key) do
        case EctoShorts.SchemaHelpers.get_related_schema(schema, key) do
          nil -> {:error, "Association \#{key} does not exist"}
          _schema -> :ok
        end
      end

  **Pattern 4: Conditional preloading**

  Only preload when needed:

      def ensure_loaded(record, assoc) do
        if EctoShorts.SchemaHelpers.association_not_loaded?(record, assoc) do
          Repo.preload(record, assoc)
        else
          record
        end
      end

  See also `EctoShorts.CommonSchema`, `EctoShorts.CommonChanges`, and
  `EctoShorts.CommonQuery`.
  """

  @doc since: "3.0.0"
  @doc """
  Recursively resolves the related schema module for an association
  key on a given schema module.

  Handles both direct and `:through` associations. For `:through`
  associations, follows the association path recursively until it
  reaches the final related schema.

  Returns `nil` when the association does not exist or the schema is `nil`.

  ## Examples

      iex> EctoShorts.SchemaHelpers.get_related_schema(EctoShorts.Schema.Post, :comments)
      EctoShorts.Schema.Comment

      iex> EctoShorts.SchemaHelpers.get_related_schema(EctoShorts.Schema.Post, :comments_authors)
      EctoShorts.Schema.User

      iex> EctoShorts.SchemaHelpers.get_related_schema(EctoShorts.Schema.Post, :does_not_exist)
      nil

  See also `schema_field_type/2` and `EctoShorts.CommonQuery.get_query_binding_source/2`.
  """
  def get_related_schema(schema, key), do: do_get_related_schema(schema, key)

  defp do_get_related_schema(nil, _), do: nil

  defp do_get_related_schema(schema, []), do: schema

  defp do_get_related_schema(schema, [key | path]) do
    schema
    |> do_get_related_schema(key)
    |> do_get_related_schema(path)
  end

  defp do_get_related_schema(schema, key) do
    case schema.__schema__(:association, key) do
      %{related: schema} -> schema
      %{through: path} -> do_get_related_schema(schema, path)
      _ -> nil
    end
  end

  @doc since: "3.0.0"
  @doc """
  Returns the declared Ecto type of a given field in a schema.

  Uses the schema's `__schema__(:type, key)` introspection. The return
  value can be a primitive type (e.g. `:string`, `:integer`) or a
  composite type like `{:array, :string}`.

  ## Examples

      iex> EctoShorts.SchemaHelpers.schema_field_type(EctoShorts.Schema.Post, :title)
      :string

      iex> EctoShorts.SchemaHelpers.schema_field_type(EctoShorts.Schema.Post, :tags)
      {:array, :string}

  See also `get_related_schema/2` and `EctoShorts.CommonSchema.get_schema_reflection/3`.
  """
  @spec schema_field_type(module(), atom()) :: atom() | {:array, atom()} | nil
  def schema_field_type(schema, key), do: schema.__schema__(:type, key)

  @doc since: "3.0.0"
  @doc """
  Returns `true` if the value at `key` on `schema_struct` is an
  `Ecto.Association.NotLoaded` struct, otherwise `false`.

  Use this to check whether an association has been preloaded before
  accessing it, to avoid accidentally traversing unloaded associations.

  ## Examples

      iex> post = %EctoShorts.Schema.Post{comments: %Ecto.Association.NotLoaded{}}
      ...> EctoShorts.SchemaHelpers.association_not_loaded?(post, :comments)
      true

      iex> post = %EctoShorts.Schema.Post{comments: []}
      ...> EctoShorts.SchemaHelpers.association_not_loaded?(post, :comments)
      false

  See also `schema_struct?/1` and `EctoShorts.CommonChanges.preload_change_assoc/3`.
  """
  @spec association_not_loaded?(struct(), atom()) :: boolean()
  def association_not_loaded?(schema_struct, key) do
    schema_struct
    |> Map.get(key)
    |> is_struct(Ecto.Association.NotLoaded)
  end

  @doc since: "3.0.0"
  @doc """
  Returns `true` if all items in the given list are Ecto schema structs,
  otherwise `false`.

  Returns `false` for empty lists and empty maps.

  ## Examples

      iex> list = [%EctoShorts.Schema.Post{}, %EctoShorts.Schema.Comment{}]
      ...> EctoShorts.SchemaHelpers.all_schema_struct?(list)
      true

      iex> mixed_list = [%EctoShorts.Schema.Post{}, %{title: "Not a schema"}]
      ...> EctoShorts.SchemaHelpers.all_schema_struct?(mixed_list)
      false

  See also `any_schema_struct?/1` and `schema_struct?/1`.
  """
  @spec all_schema_struct?(list() | map()) :: boolean()
  def all_schema_struct?([]), do: false
  def all_schema_struct?(map) when map === %{}, do: false
  def all_schema_struct?(enum), do: Enum.all?(enum, &schema_struct?/1)

  @doc since: "3.0.0"
  @doc """
  Returns `true` if any item in the given list is an Ecto schema struct,
  otherwise `false`.

  ## Examples

      iex> items = [%EctoShorts.Schema.Post{}, %{id: 1, title: "Frank"}]
      ...> EctoShorts.SchemaHelpers.any_schema_struct?(items)
      true

      iex> maps = [%{title: "George"}, %{title: "Hannah"}]
      ...> EctoShorts.SchemaHelpers.any_schema_struct?(maps)
      false

  See also `all_schema_struct?/1` and `schema_struct?/1`.
  """
  @spec any_schema_struct?(list()) :: boolean()
  def any_schema_struct?(values), do: Enum.any?(values, &schema_struct?/1)

  @doc since: "3.0.0"
  @doc """
  Returns `true` if the given value is an Ecto schema struct, otherwise `false`.

  A value is considered an Ecto schema struct when it has a `__meta__` field
  whose `:schema` key refers to a module that exports `__schema__/2`.

  ## Examples

      iex> EctoShorts.SchemaHelpers.schema_struct?(%EctoShorts.Schema.Post{})
      true

      iex> EctoShorts.SchemaHelpers.schema_struct?(%{title: "Not a schema"})
      false

  See also `schema_module?/1` and `all_schema_struct?/1`.
  """
  def schema_struct?(%{__meta__: %{schema: schema}}), do: schema_module?(schema)
  def schema_struct?(_), do: false

  @doc since: "3.0.0"
  @doc """
  Returns `true` if the given module exports `__schema__/2`, indicating
  it is an Ecto schema module.

  Returns `false` for `nil`, non-atom values, or modules that do not
  export `__schema__/2`.

  ## Examples

      iex> EctoShorts.SchemaHelpers.schema_module?(EctoShorts.Schema.Post)
      true

      iex> EctoShorts.SchemaHelpers.schema_module?(String)
      false

      iex> EctoShorts.SchemaHelpers.schema_module?(nil)
      false

  See also `schema_struct?/1`.
  """
  def schema_module?(module) when is_atom(module) and module !== nil do
    function_exported?(module, :__schema__, 2)
  end

  def schema_module?(_), do: false

  @doc since: "3.0.0"
  @doc """
  Returns `true` if the given map or struct has a non-nil `:id` (or `"id"`) key,
  indicating the record has been persisted.

  Accepts any map or schema struct. Returns `false` when there is no `:id`
  key or it is `nil`.

  ## Examples

      iex> EctoShorts.SchemaHelpers.any_persisted?(%EctoShorts.Schema.Post{id: 1})
      true

      iex> EctoShorts.SchemaHelpers.any_persisted?(%EctoShorts.Schema.Post{id: nil})
      false

      iex> EctoShorts.SchemaHelpers.any_persisted?(%{id: 42})
      true

  See also `schema_struct?/1`.
  """
  @spec any_persisted?(list() | map() | struct()) :: boolean()
  def any_persisted?(list) when is_list(list), do: Enum.any?(list, &any_persisted?/1)
  def any_persisted?(%{id: id}), do: id !== nil
  def any_persisted?(%{"id" => id}), do: id !== nil
  def any_persisted?(_), do: false
end
