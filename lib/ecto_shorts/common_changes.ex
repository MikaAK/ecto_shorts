defmodule EctoShorts.CommonChanges do
  @moduledoc """
  Simplifies working with associations in Ecto changesets.

  The `EctoShorts.CommonChanges` module provides functions that intelligently handle
  associations in Ecto changesets, making it easier to work with relationships
  between schemas. It automatically determines whether to use `put_assoc/4` or
  `cast_assoc/3` based on the data provided.

  ## Key Features

  * **Intelligent association handling** - Automatically chooses between `put_assoc/4` and `cast_assoc/3`
  * **Many-to-many relationship support** - Easily update many-to-many relationships with just a list of IDs
  * **Preloading associations** - Preload associations before applying changes
  * **Conditional changeset functions** - Apply changes only when specific conditions are met
  * **Association validation** - Ensure associations are properly provided

  ## Preloading Associations on Change

  When working with associations in changesets, you often need to preload the
  association before applying changes. The `preload_change_assoc/3` function
  simplifies this process:

  ```elixir
  defmodule MyApp.Accounts.User do
    import Ecto.Changeset
    alias EctoShorts.CommonChanges

    def changeset(user, params) do
      user
      |> cast(params, [:name, :email])
      |> validate_required([:name, :email])
      |> CommonChanges.preload_change_assoc(:address)
    end
  end
  ```

  This allows you to pass an address as a map or as a struct directly in the params.

  ## Validating Relations

  You can ensure that a relation is provided either via an ID or as a nested map:

  ```elixir
  defmodule MyApp.Accounts.User do
    import Ecto.Changeset
    alias EctoShorts.CommonChanges

    def changeset(user, params) do
      user
      |> cast(params, [:name, :email, :address_id])
      |> validate_required([:name, :email])
      |> CommonChanges.preload_change_assoc(:address,
        required_when_missing: :address_id
      )
    end
  end
  ```

  ## Conditional Functions
  We can also run functions when something happens by defining conditional functions like so:

      defmodule MyApp.Accounts.User do
        alias EctoShorts.CommonChanges

        def changeset(changeset, params) do
          changeset
            |> cast([:name, :email, :address_id])
            |> validate_required([:name, :email])
            |> CommonChanges.put_when(
              &CommonChanges.changeset_field_nil?(&1, :email),
              &put_change(&1, :email, "some_default@gmail.com")
            )
        end
      end

  """
  require Logger

  import Ecto.Changeset, only: [
    get_field: 2,
    put_assoc: 4,
    cast_assoc: 2,
    cast_assoc: 3
  ]

  alias Ecto.Changeset
  alias EctoShorts.{Actions, Config, SchemaHelpers}

  @doc """
  Runs a changeset function only if the specified condition function returns true.

  This function provides a clean way to conditionally apply changes to a changeset
  based on a predicate function.

  ## Parameters

  * `changeset` - The Ecto changeset to potentially modify
  * `when_func` - A function that takes a changeset and returns a boolean
  * `change_func` - A function that takes a changeset and returns a modified changeset

  ## Returns

  * The modified changeset if the condition was true
  * The original changeset if the condition was false

  ## Examples

      iex> CommonChanges.put_when(
      ...>   changeset,
      ...>   &CommonChanges.changeset_field_nil?(&1, :email),
      ...>   &put_change(&1, :email, "default@example.com")
      ...> )
  """
  @spec put_when(
    Changeset.t,
    ((Changeset.t) -> boolean),
    ((Changeset.t) -> Changeset.t)
  ) :: Changeset.t
  def put_when(changeset, when_func, change_func) do
    if when_func.(changeset) do
      change_func.(changeset)
    else
      changeset
    end
  end

  @doc """
  Returns true if the field on the changeset is an empty list in
  the data or changes.

  Useful for conditional logic based on whether a collection association is empty.

  ## Parameters

  * `changeset` - The Ecto changeset to check
  * `key` - The field name to check for emptiness

  ## Returns

  * `true` if the field is an empty list
  * `false` otherwise

  ## Examples

      iex> EctoShorts.CommonChanges.changeset_field_empty?(changeset, :comments)
  """
  @spec changeset_field_empty?(Changeset.t, atom) :: boolean
  def changeset_field_empty?(changeset, key) do
    get_field(changeset, key) === []
  end

  @doc """
  Returns true if the field on the changeset is nil in the data
  or changes.

  Useful for conditional logic based on whether a field or association is nil.

  ## Parameters

  * `changeset` - The Ecto changeset to check
  * `key` - The field name to check for nil value

  ## Returns

  * `true` if the field is nil
  * `false` otherwise

  ## Examples

      iex> EctoShorts.CommonChanges.changeset_field_nil?(changeset, :comments)
  """
  @spec changeset_field_nil?(Changeset.t, atom) :: boolean
  def changeset_field_nil?(changeset, key) do
    changeset |> get_field(key) |> is_nil()
  end

  @doc """
  Preloads an association and then intelligently applies put_or_cast_assoc.

  This function is the primary entry point for association handling. It preloads
  the association if a change is made to it, and then determines whether to use
  `put_assoc/4` or `cast_assoc/3` based on the data.

  ## Parameters

  * `changeset` - The Ecto changeset to modify
  * `key` - The association field name
  * `opts` - Options for controlling the behavior

  ## Options

  * `required_when_missing` - Sets `:required` to true if the
    field is `nil` in both changes and data. This is useful when
    you have both an association and a foreign key field, and you
    want to ensure one of them is provided.

  * `:required` - Indicates if the association is mandatory.
    For one-to-one associations, a non-nil value satisfies
    this validation. For many associations, a non-empty list
    is sufficient. See [Ecto.Changeset.cast_assoc/3](https://hexdocs.pm/ecto/Ecto.Changeset.html#cast_assoc/3)
    for more information.

  * `:ids` - A list of IDs to preload for the association. Useful when
    working with many-to-many relationships.

  ## Returns

  * The modified changeset with the association preloaded and properly cast or put

  ## Examples

      iex> CommonChanges.preload_change_assoc(changeset, :my_relation)
      iex> CommonChanges.preload_change_assoc(changeset, :my_relation, required_when_missing: :my_relation_id)
      iex> CommonChanges.preload_change_assoc(changeset, :my_relation, required: true)
      iex> CommonChanges.preload_change_assoc(changeset, :my_relation, required_when_missing: :my_relation_id)
  """
  @spec preload_change_assoc(Changeset.t(), atom(), keyword()) :: Changeset.t
  def preload_change_assoc(changeset, key, opts) do
    required? =
      if opts[:required_when_missing] do
        changeset_field_nil?(changeset, opts[:required_when_missing])
      else
        opts[:required] === true
      end

    opts = Keyword.put(opts, :required, required?)

    if Map.has_key?(changeset.params, Atom.to_string(key)) do
      changeset
      |> preload_changeset_assoc(key, opts)
      |> put_or_cast_assoc(key, opts)
    else
      cast_assoc(changeset, key, opts)
    end
  end

  @spec preload_change_assoc(Changeset.t(), atom()) :: Changeset.t
  def preload_change_assoc(changeset, key) do
    if Map.has_key?(changeset.params, Atom.to_string(key)) do
      changeset
      |> preload_changeset_assoc(key)
      |> put_or_cast_assoc(key)
    else
      cast_assoc(changeset, key)
    end
  end

  @doc """
  Preloads an association on a changeset's data.

  This function preloads the specified association on the changeset's data,
  making it available for further operations.

  ## Parameters

  * `changeset` - The Ecto changeset to modify
  * `key` - The association field name
  * `opts` - Options for controlling the preload behavior

  ## Options

  * `:ids` - A list of IDs to preload for the association. When provided,
    only records with these IDs will be preloaded.

  ## Returns

  * The modified changeset with the association preloaded

  ## Examples

      iex> CommonChanges.preload_changeset_assoc(changeset, :posts)
      iex> CommonChanges.preload_changeset_assoc(changeset, :roles, ids: [1, 2, 3])
  """
  @spec preload_changeset_assoc(Changeset.t, atom) :: Changeset.t
  @spec preload_changeset_assoc(Changeset.t, atom, keyword()) :: Changeset.t
  def preload_changeset_assoc(changeset, key, opts \\ [])

  def preload_changeset_assoc(changeset, key, opts) do
    if opts[:ids] do
      schema = changeset_relationship_schema(changeset, key)

      preloaded_data = Actions.all(schema, %{ids: opts[:ids]}, opts)

      Map.update!(changeset, :data, &Map.put(&1, key, preloaded_data))
    else
      Map.update!(changeset, :data, &Config.repo!(opts).preload(&1, key, opts))
    end
  end

  defp changeset_relationship_schema(changeset, key) do
    if Map.has_key?(changeset.types, key) and relationship_exists?(changeset.types[key]) do
      {:assoc, assoc} = Map.get(changeset.types, key)

      assoc.queryable
    else
      %parent_schema{} = changeset.data

      raise ArgumentError, "The key #{inspect(key)} is not an association for the queryable #{inspect(parent_schema)}."
    end
  end

  @doc """
  Intelligently determines whether to use put_assoc or cast_assoc based on the data.

  This function examines the data in the changeset and automatically chooses the
  appropriate Ecto function to handle the association:
  * Uses `put_assoc/4` when the association data is already a struct or list of structs
  * Uses `cast_assoc/3` when the association data is a map or list of maps that needs to be cast

  ## Special Handling for Many-to-Many Relationships

  When working with many-to-many relationships, you can pass a list of IDs or maps with IDs,
  and this function will update the association to match exactly what you provide:
  1. Keep records with the specified IDs in the association
  2. Remove any other records that were previously associated
  3. Add any new records that weren't previously associated

  ## Parameters

  * `changeset` - The Ecto changeset to modify
  * `key` - The association field name
  * `opts` - Options to pass to the underlying put_assoc or cast_assoc function

  ## Returns

  * The modified changeset with the association properly handled

  ## Examples

  With a belongs_to association:

      iex> EctoShorts.CommonChanges.put_or_cast_assoc(post_changeset, :user)

  With a has_many association:

      iex> EctoShorts.CommonChanges.put_or_cast_assoc(user_changeset, :posts)

  With a many_to_many association using IDs:

      iex> EctoShorts.CommonChanges.put_or_cast_assoc(user_changeset, :roles)
      # When params contain: "roles" => [1, 2, 3]

  With a many_to_many association using maps with IDs:

      iex> EctoShorts.CommonChanges.put_or_cast_assoc(change(user, fruits: [%{id: 1}, %{id: 3}]), :fruits)
  """
  @spec put_or_cast_assoc(Changeset.t, atom) :: Changeset.t
  @spec put_or_cast_assoc(Changeset.t, atom, Keyword.t) :: Changeset.t
  def put_or_cast_assoc(changeset, key, opts \\ []) do
    params_data = Map.get(changeset.params, Atom.to_string(key))

    find_method_and_put_or_cast(changeset, key, params_data, opts)
  end

  defp find_method_and_put_or_cast(changeset, key, nil, opts) do
    cast_assoc(changeset, key, opts)
  end

  defp find_method_and_put_or_cast(changeset, key, params_data, opts) when is_list(params_data) do
    cond do
      SchemaHelpers.all_schemas?(params_data) ->
        put_assoc(
          changeset,
          key,
          params_data,
          opts
        )

      member_update?(params_data) ->
        schema = changeset_relationship_schema(changeset, key)
        data = Actions.all(schema, ids: data_ids(params_data))

        put_assoc(changeset, key, data, opts)

      SchemaHelpers.any_created?(params_data) ->
        changeset
        |> preload_changeset_assoc(
          key,
          Keyword.put(opts, :ids, params_data |> data_ids() |> Enum.reject(&is_nil/1))
        )
        |> cast_assoc(key, opts)

      true ->
        cast_assoc(changeset, key, opts)

    end
  end

  defp find_method_and_put_or_cast(changeset, key, param_data, opts) do
    if SchemaHelpers.schema?(param_data) do
      put_assoc(changeset, key, param_data, opts)
    else
      cast_assoc(changeset, key, opts)
    end
  end

  defp member_update?(schemas) do
    Enum.all?(schemas, fn
      %{id: id} = item when item === %{id: id} -> true
      _ -> false
    end)
  end

  defp data_ids(data), do: Enum.map(data, &Map.get(&1, :id))

  defp relationship_exists?({:assoc, _}), do: true
  defp relationship_exists?(_), do: false
end
