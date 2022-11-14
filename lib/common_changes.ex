defmodule EctoShorts.CommonChanges do
  @moduledoc """
  This module is responsible for determining put/cast assoc as well as creating and updating model relations
  """
  import Logger, only: [warn: 1]

  import Ecto.Changeset, only: [
    get_field: 2,
    put_assoc: 4,
    cast_assoc: 2,
    cast_assoc: 3
  ]

  alias EctoShorts.{Actions, SchemaHelpers, Config}
  alias Ecto.Changeset

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

  @doc "Checks if field on changeset is empty list in data or changes"
  @spec changeset_field_empty?(Changeset.t, atom) :: boolean
  def changeset_field_empty?(changeset, key) do
    get_field(changeset, key) === []
  end

  @doc "Checks if field on changeset is nil in data or changes"
  @spec changeset_field_nil?(Changeset.t, atom) :: boolean
  def changeset_field_nil?(changeset, key) do
    is_nil(get_field(changeset, key))
  end

  @doc """
  This function is the primary use function
  Preloads changeset assoc if change is made and then and put_or_cast's it


  ## Example

    iex> CommonChanges.preload_change_assoc(changeset, :my_relation)
    iex> CommonChanges.preload_change_assoc(changeset, :my_relation, repo: MyApp.OtherRepo)
    iex> CommonChanges.preload_change_assoc(changeset, :my_relation, required: true)
  """
  @spec preload_change_assoc(Changeset.t, atom, keyword()) :: Changeset.t
  @spec preload_change_assoc(Changeset.t, atom) :: Changeset.t
  def preload_change_assoc(changeset, key, opts) do
    if Map.has_key?(changeset.params, Atom.to_string(key)) do
      changeset
        |> preload_changeset_assoc(key, opts)
        |> put_or_cast_assoc(key, opts)
    else
      cast_assoc(changeset, key, opts)
    end
  end

  def preload_change_assoc(changeset, key) do
    if Map.has_key?(changeset.params, Atom.to_string(key)) do
      changeset
        |> preload_changeset_assoc(key)
        |> put_or_cast_assoc(key)
    else
      cast_assoc(changeset, key)
    end
  end

  @doc "Preloads a changesets association"
  @spec preload_changeset_assoc(Changeset.t, atom) :: Changeset.t
  @spec preload_changeset_assoc(Changeset.t, atom, keyword()) :: Changeset.t
  def preload_changeset_assoc(changeset, key, opts \\ [])

  def preload_changeset_assoc(changeset, key, opts) do
    opts = Keyword.merge(default_opts(), opts)

    if opts[:ids] do
      schema = changeset_relationship_schema(changeset, key)

      preloaded_data = Actions.all(schema, %{ids: opts[:ids]}, repo: opts[:repo])

      Map.update!(changeset, :data, &Map.put(&1, key, preloaded_data))
    else
      Map.update!(changeset, :data, &opts[:repo].preload(&1, key, opts))
    end
  end

  defp changeset_relationship_schema(changeset, key) do
    if Map.has_key?(changeset.types, key) and relationship_exists?(changeset.types[key]) do
      changeset.types
        |> Map.get(key)
        |> elem(1)
        |> Map.get(:queryable)
    else
      warn "Changeset relationship for CommonChanges.put_or_cast_assoc #{key} was not found"

      changeset
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

      SchemaHelpers.all_schemas?(params_data) -> put_assoc(
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
            Keyword.put(opts, :ids, params_data |> data_ids |> Enum.reject(&is_nil/1))
          )
          |> cast_assoc(key, opts)

      true -> cast_assoc(changeset, key, opts)
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

  def default_opts, do: [repo: Config.repo()]
end
