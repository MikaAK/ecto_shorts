defmodule EctoShorts.CommonChanges do
  @moduledoc """
  `CommonChanges` is a collection of functions to help with managing
  and creating our `&changeset/2` function in our schemas.

  ### Preloading associations on change
  Often times we want to be able to change an association with
  `(put/cast)_assoc`, but we have an awkwardness of having to use
  a preload in a spot to do this. We can aleviate that by doing the following:

      defmodule MyApp.Accounts.User do
        def changeset(changeset, params) do
          changeset
            |> cast([:name, :email])
            |> validate_required([:name, :email])
            |> EctoShorts.CommonChanges.preload_change_assoc(:address)
        end
      end

  Doing this allows us to then pass address in via a map, or even using
  the struct from the database directly to add as a relation

  ### Validating relation is passed in somehow
  We can validate for a relation being passed in via id or by using our
  preload_change_assoc by doing the following:

      defmodule MyApp.Accounts.User do
        def changeset(changeset, params) do
          changeset
            |> cast([:name, :email, :address_id])
            |> validate_required([:name, :email])
            |> EctoShorts.CommonChanges.preload_change_assoc(:address,
              required_when_missing: :address_id
            )
        end
      end

  ### Conditional functions
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
    cast_assoc: 3
  ]

  alias Ecto.Changeset
  alias EctoShorts.{Actions, Config, SchemaHelpers}

  @doc "Run's changeset function if when function returns true"
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

  ### Examples

      iex> EctoShorts.CommonChanges.changeset_field_empty?(changeset, :comments)
  """
  @spec changeset_field_empty?(Changeset.t, atom) :: boolean
  def changeset_field_empty?(changeset, key) do
    get_field(changeset, key) === []
  end

  @doc """
  Returns true if the field on the changeset is nil in the data
  or changes.

  ### Examples

      iex> EctoShorts.CommonChanges.changeset_field_nil?(changeset, :comments)
  """
  @spec changeset_field_nil?(Changeset.t, atom) :: boolean
  def changeset_field_nil?(changeset, key) do
    changeset |> get_field(key) |> is_nil()
  end

  @doc """
  This function is the primary use function
  Preloads changeset assoc if change is made and then and put_or_cast's it

  ### Options

    * `required_when_missing` - Sets `:required` to true if the
      field is `nil` in both changes and data. See the
      `:required` option documentation for details.

    * `:required` - Indicates if the association is mandatory.
      For one-to-one associations, a non-nil value satisfies
      this validation. For many associations, a non-empty list
      is sufficient. See [Ecto.Changeset.cast_assoc/3](https://hexdocs.pm/ecto/Ecto.Changeset.html#cast_assoc/3)
      for more information.

  ## Example

    iex> CommonChanges.preload_change_assoc(changeset, :my_relation)
    iex> CommonChanges.preload_change_assoc(changeset, :my_relation, repo: MyApp.OtherRepo)
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

    association_or_nil = changeset.data.__struct__.__schema__(:association, key)

    do_preload_change_assoc(changeset, key, association_or_nil, opts)
  end

  @spec preload_change_assoc(Changeset.t(), atom()) :: Changeset.t
  def preload_change_assoc(changeset, key) do
    preload_change_assoc(changeset, key, default_opts())
  end

  defp do_preload_change_assoc(changeset, _key, nil, _opts) do
    changeset
  end

  defp do_preload_change_assoc(changeset, key, %{cardinality: :many}, opts) do
    case Map.get(changeset.params, Atom.to_string(key)) do
      nil -> changeset
      params_data ->
        changeset
        |> preload_changeset_assoc(key, opts)
        |> put_assoc(key, params_data, opts)
    end
  end

  defp do_preload_change_assoc(changeset, key, _ecto_association, opts) do
    if Map.has_key?(changeset.params, Atom.to_string(key)) do
      changeset
      |> preload_changeset_assoc(key, opts)
      |> put_or_cast_assoc(key, opts)
    else
      cast_assoc(changeset, key, opts)
    end
  end

  @doc "Preloads a changesets association"
  @spec preload_changeset_assoc(Changeset.t, atom) :: Changeset.t
  @spec preload_changeset_assoc(Changeset.t, atom, keyword()) :: Changeset.t
  def preload_changeset_assoc(changeset, key, opts \\ [])

  def preload_changeset_assoc(changeset, key, opts) do
    opts = Keyword.merge(default_opts(), opts)

    ids = opts[:ids]

    if ids do
      case changeset.data.__struct__.__schema__(:association, key) do
        nil -> changeset

        association ->
          schema = changeset_relationship_schema(changeset, key)

          preloaded_data =
            if association.cardinality === :many do
              Actions.all(schema, %{id: opts[:ids]}, repo: opts[:repo])
            else
              raise ArgumentError, """
              The option `:ids` was provided with the association #{inspect(key)}
              for the schema #{inspect(schema)} which does not have the cardinality
              `:many`.

              This can only be used with `belongs_to` and `*_one` relationships.
              """
            end

          Map.update!(changeset, :data, &Map.put(&1, key, preloaded_data))
      end
    else
      Map.update!(changeset, :data, &opts[:repo].preload(&1, key, opts))
    end
  end

  @doc """
  Determines put or cast on association with some special magic

  If you pass a many to many relation only a list of id's it will count that as a `member_update` and remove or add members to the relations list

  E.G. User many_to_many Fruit

  This would update the user to have only fruits with id 1 and 3
  ```elixir
  CommonChanges.put_or_cast_assoc(change(user, fruits: [%{id: 1}, %{id: 3}]), :fruits)
  ```
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

  defp changeset_relationship_schema(changeset, key) do
    if Map.has_key?(changeset.types, key) and relationship_exists?(changeset.types[key]) do
      {:assoc, assoc} = Map.get(changeset.types, key)

      assoc.queryable
    else
      %parent_schema{} = changeset.data

      raise ArgumentError, "The key #{inspect(key)} is not an association for the queryable #{inspect(parent_schema)}."
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

  def default_opts, do: [repo: Config.repo()]
end
