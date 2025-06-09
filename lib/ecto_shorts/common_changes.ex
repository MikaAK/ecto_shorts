defmodule EctoShorts.CommonChanges do
  @moduledoc """
  `EctoShorts.CommonChanges` provides helper functions to
  simplify working with Ecto changesets.

  This module focuses on making common tasks easier, such as
  handling the difference between `put_assoc/4` and
  `cast_assoc/3`, automatically preloading data when needed,
  and conditionally validating or transforming fields.

  For example, when working with nested associations, you can
  delegate the logic of choosing whether to cast or put the
  association based on how the input is shaped:

      def changeset(changeset, params) do
        changeset
        |> cast(params, [:name, :email])
        |> EctoShorts.CommonChanges.preload_change_assoc(:address)
      end

  You can also apply logic only when needed. For instance,
  if a field is nil and you want to provide a fallback value:

      EctoShorts.CommonChanges.put_when(
        &EctoShorts.CommonChanges.changeset_field_nil?(&1, :email),
        &put_change(&1, :email, "default@email.com")
      )

  Or you can require a related record based on whether a
  foreign key is missing:

      EctoShorts.CommonChanges.preload_change_assoc(
        changeset,
        :address,
        required_when_missing: :address_id
      )

  These utilities help keep your changeset logic clean,
  readable, and adaptable to a variety of input shapes
  without having to handle all edge cases manually.
  """

  alias Ecto.Changeset

  alias EctoShorts.{
    Actions,
    SchemaHelpers
  }

  @type changeset :: Ecto.Changeset.t()
  @type key :: atom()
  @type preloads :: atom() | list(atom()) | keyword()
  @type pattern :: binary() | Regex.t()
  @type precision :: :microsecond | :millisecond | :second
  @type opts :: keyword()

  @doc since: "2.5.0"
  @doc """
  Truncates a `NaiveDateTime` value in a field to a specified precision.

  ## Examples

      EctoShorts.CommonChanges.truncate_datetime_change(changeset, :started_at)
  """
  @spec truncate_datetime_change(changeset(), key(), precision()) :: changeset()
  def truncate_datetime_change(changeset, key, precision \\ :second) do
    Changeset.update_change(changeset, key, fn
      datetime when is_struct(datetime, NaiveDateTime) ->
        NaiveDateTime.truncate(datetime, precision)

      datetime when is_struct(datetime, DateTime) ->
        DateTime.truncate(datetime, precision)

      value ->
        value
    end)
  end

  @doc since: "2.5.0"
  @doc """
  Applies the given function if the field hasn’t already been changed.

  ## Example
  """
  @spec put_new_change(changeset(), key(), function()) :: changeset()
  def put_new_change(changeset, key, fun) do
    if Map.has_key?(changeset.changes, key) do
      changeset
    else
      Changeset.put_change(changeset, key, fun.())
    end
  end

  @doc """
  Applies a transformation function only if a condition is true.

  ## Example

      EctoShorts.CommonChanges.put_when(
        &EctoShorts.CommonChanges.changeset_field_empty?(&1, :tags),
        &put_change(&1, :tags, ["default"])
      )
  """
  @spec put_when(
          changeset(),
          (changeset() -> boolean()),
          (changeset() -> changeset())
        ) :: changeset()
  def put_when(changeset, when_func, func) do
    if when_func.(changeset) do
      func.(changeset)
    else
      changeset
    end
  end

  @doc since: "2.5.0"
  @doc """
  Returns true if the field on the changeset is an empty list or map.
  """
  @spec changeset_change_empty?(changeset(), key()) :: boolean()
  def changeset_change_empty?(changeset, key) do
    case Changeset.get_change(changeset, key) do
      change when is_list(change) -> change === []
      change when is_map(change) -> change === %{}
      _ -> false
    end
  end

  @doc since: "2.5.0"
  @doc """
  Returns true if the change for the given key is nil.
  """
  @spec changeset_change_nil?(changeset(), key()) :: boolean()
  def changeset_change_nil?(changeset, key) do
    changeset |> Changeset.get_change(key) |> is_nil()
  end

  @doc """
  Returns true if the field on the changeset is an empty list in
  the data or changes.

  ### Examples

      EctoShorts.CommonChanges.changeset_field_empty?(changeset, :comments)
  """
  @spec changeset_field_empty?(changeset(), key()) :: boolean()
  def changeset_field_empty?(changeset, key) do
    case Changeset.get_field(changeset, key) do
      change when is_list(change) -> change === []
      change when is_map(change) -> change === %{}
      _ -> false
    end
  end

  @doc """
  Returns true if the field on the changeset is nil in the data or changes.

  ### Examples

      EctoShorts.CommonChanges.changeset_field_nil?(changeset, :comments)
  """
  @spec changeset_field_nil?(changeset(), key()) :: boolean()
  def changeset_field_nil?(changeset, key) do
    changeset
    |> Changeset.get_field(key)
    |> is_nil()
  end

  @doc """
  Preloads an association if present in the changeset params and
  applies either `cast_assoc/3` or `put_assoc/3`, depending on
  the data shape.

  This function allows direct usage of embedded maps or structs
  in the params without requiring manual preload in your
  controller or context logic.

  ## Options

    * `:required` - If set to `true`, validates that the association is not `nil`.

    * `:required_when_missing` - If the given field is `nil` in both `:changes`
      and `:data`, `:required` will be set to `true`.

    * `:repo` - Optional. Overrides the default repo used for preloading.

  ## Example

      EctoShorts.CommonChanges.preload_change_assoc(changeset, :profile)
      EctoShorts.CommonChanges.preload_change_assoc(changeset, :account, required: true)
      EctoShorts.CommonChanges.preload_change_assoc(changeset, :settings, required_when_missing: :settings_id)
      EctoShorts.CommonChanges.preload_change_assoc(changeset, :tags, repo: MyApp.CustomRepo)
  """
  @spec preload_change_assoc(changeset(), key()) :: changeset()
  @spec preload_change_assoc(changeset(), key(), opts()) :: changeset()
  def preload_change_assoc(changeset, key, opts \\ []) do
    required? =
      if Keyword.has_key?(opts, :required_when_missing) do
        changeset_field_nil?(changeset, opts[:required_when_missing])
      else
        opts[:required] === true
      end

    opts = Keyword.put(opts, :required, required?)

    if params_has_key?(changeset, key) do
      changeset
      |> preload_changeset_assoc(key, opts)
      |> put_or_cast_assoc(key, opts)
    else
      cast_assoc(changeset, key, opts)
    end
  end

  @doc """
  Preloads the specified association onto the changeset `data`
  before calling `put_assoc/3` or `cast_assoc/3`. This is used
  internally by `preload_change_assoc/3` when a key is present
  in the changeset params.

  If the `:ids` option is provided, the association is loaded using
  `Actions.all/3` and matched by those IDs. Otherwise, it uses the
  configured or provided Repo to preload the association.

  ## Options

    * `:ids` - A list of IDs to fetch the associated records directly.
    * `:repo` - An optional custom Repo module to override default repo resolution.

  This is useful when working with nested input data that must be hydrated
  into structs before being validated.
  """
  @spec preload_changeset_assoc(changeset(), preloads()) :: changeset()
  @spec preload_changeset_assoc(changeset(), preloads(), opts()) :: changeset()
  def preload_changeset_assoc(changeset, preloads, opts \\ []) do
    Map.update!(changeset, :data, &Actions.preload(&1, preloads, opts))
  end

  @doc """
  ...
  """
  def association_not_loaded?(%{data: schema_data} = _changeset, key) do
    SchemaHelpers.association_not_loaded?(schema_data, key)
  end

  @doc """
  ...
  """
  def change(%{data: _} = changeset, params) when params === %{} or params === [] do
    changeset
  end

  def change(%{data: %{__meta__: %{schema: schema}}} = changeset, params) do
    change(schema, changeset, params)
  end

  def change(%{__meta__: %{schema: schema}} = schema_data, params) do
    change(schema, schema_data, params)
  end

  def change(schema, params) when is_atom(schema) do
    change(schema, struct(schema), params)
  end

  def change(schema, struct_or_changeset, params) do
    if function_exported?(schema, :__schema__, 1) do
      schema.changeset(struct_or_changeset, params)
    else
      Changeset.change(struct_or_changeset, params)
    end
  end

  @doc """
  Determines how to apply an association change based on the shape
  of the input in `changeset.params[key]`.

  This function decides whether to use `put_assoc/4` or `cast_assoc/3`
  depending on what kind of data was passed in. This makes it easier
  to work with many-to-many relationships, nested data, or lists of IDs.

  ## Behavior

    * If given a list of structs, it uses `put_assoc/4`.
    * If given a list of maps with only `:id` fields, it fetches from the DB and replaces the relation.
    * If given a list of maps with new data, it preloads the existing relation and uses `cast_assoc/3`.
    * If given a single struct, it uses `put_assoc/4`.
    * Otherwise, it defaults to `cast_assoc/3`.

  ## Example

      EctoShorts.CommonChanges.put_or_cast_assoc(changeset, :tags)
  """
  def put_or_cast_assoc(changeset, key, opts \\ [])

  def put_or_cast_assoc(%{data: %{__meta__: _}} = changeset, key, opts) do
    if params_has_key?(changeset, key) do
      put_or_cast_assoc(changeset, key, get_changeset_params(changeset, key), opts)
    else
      Changeset.cast_assoc(changeset, key, opts)
    end
  end

  @doc """
  ...
  """
  def put_or_cast_assoc(changeset, key, values, opts) when is_list(values) do
    schema = get_changeset_schema_module(changeset)

    cond do
      SchemaHelpers.all_schema_struct?(values) ->
        put_assoc(changeset, key, values, opts)

      SchemaHelpers.all_only_primary_key?(schema, values) ->
        put_assoc(changeset, key, values, opts)

      SchemaHelpers.any_created?(schema, values) ->
        apply_cast_assoc(changeset, key, values, opts)

      true ->
        apply_cast_assoc(changeset, key, values, opts)
    end
  end

  def put_or_cast_assoc(changeset, key, value, opts) do
    if SchemaHelpers.schema_struct?(value) do
      put_assoc(changeset, key, value, opts)
    else
      apply_cast_assoc(changeset, key, value, opts)
    end
  end

  @doc """
  ...
  """
  def put_assoc(changeset, key, value, opts \\ [])

  def put_assoc(changeset, key, params_list, opts) when is_list(params_list) do
    assoc = fetch_changeset_association!(changeset, key)
    assoc_queryable = assoc.queryable
    assoc_schema = assoc.related

    {params_list, entries} = split_schema_data(params_list)

    query_params =
      params_list
      |> filter_queryable_params(assoc_schema)
      |> build_queryable_params(assoc_schema)

    if query_params === %{} do
      Changeset.put_assoc(changeset, key, entries, opts)
    else
      changeset = preload_association(changeset, key, opts)

      records = Actions.all(assoc_queryable, query_params, opts)

      Changeset.put_assoc(changeset, key, entries ++ records, opts)
    end
  end

  def put_assoc(changeset, key, %_{} = schema_data, opts) do
    Changeset.put_assoc(changeset, key, schema_data, opts)
  end

  def put_assoc(changeset, key, params, opts) do
    assoc = fetch_changeset_association!(changeset, key)
    assoc_queryable = assoc.queryable
    assoc_schema = assoc.related

    changeset = preload_association(changeset, key, opts)

    query_params = SchemaHelpers.filter_primary_key(params, assoc_schema)

    case Actions.find(assoc_queryable, query_params, opts) do
      {:ok, record} -> Changeset.put_assoc(changeset, key, record, opts)
      {:error, _} -> changeset
    end
  end

  defp split_schema_data(values) do
    Enum.reduce(values, {[], []}, fn
      %_{} = schema_data, {entries, acc} -> {entries, [schema_data | acc]}
      value, {entries, acc} -> {[value | entries], acc}
    end)
  end

  @doc """
  ...
  """
  def cast_assoc(changeset, key, opts \\ []) do
    apply_cast_assoc(changeset, key, get_changeset_params(changeset, key), opts)
  end

  defp apply_cast_assoc(changeset, key, nil, opts) do
    Changeset.cast_assoc(changeset, key, opts)
  end

  defp apply_cast_assoc(changeset, key, params_list, opts) when is_list(params_list) do
    assoc = fetch_changeset_association!(changeset, key)
    assoc_schema = assoc.related

    query_params =
      params_list
      |> filter_queryable_params(assoc_schema)
      |> build_queryable_params(assoc_schema)

    changeset
    |> load_association(assoc.queryable, key, query_params, opts)
    |> Changeset.change(%{key => params_list})
    |> Changeset.cast_assoc(key, opts)
  end

  defp apply_cast_assoc(changeset, key, params, opts) do
    assoc = fetch_changeset_association!(changeset, key)

    changeset
    |> load_association(assoc.queryable, key, params, opts)
    |> Changeset.change(%{key => params})
    |> Changeset.cast_assoc(key, opts)
  end

  defp build_queryable_params([], _schema) do
    %{}
  end

  defp build_queryable_params(params_list, schema) do
    if SchemaHelpers.primary_key_count(schema) > 1 do
      %{or_where: params_list}
    else
      Enum.reduce(params_list, %{}, fn params, acc ->
        Enum.reduce(params, acc, fn
          {key, val}, acc when is_binary(val) or is_integer(val) ->
            Map.update(acc, key, [val], &[val | &1])
        end)
      end)
    end
  end

  defp filter_queryable_params(params_list, schema) do
    params_list
    |> Enum.reduce([], fn params, acc ->
      if SchemaHelpers.has_primary_key?(schema, params) do
        [SchemaHelpers.filter_primary_key(params, schema) | acc]
      else
        acc
      end
    end)
    |> Enum.reverse()
  end

  @doc false
  def preload_association(changeset, key, opts) do
    if association_not_loaded?(changeset, key) or opts[:force] === true do
      Map.update!(changeset, :data, fn schema_data ->
        Actions.preload(schema_data, key, opts)
      end)
    else
      changeset
    end
  end

  def load_association(changeset, _source, _key, params, _opts) when params === %{} do
    changeset
  end

  def load_association(changeset, source, key, params, opts) do
    schema = schema_from_source(source)

    assoc = fetch_changeset_association!(changeset, key)

    params = SchemaHelpers.filter_primary_key(params, schema)

    if params === %{} do
      changeset
    else
      if assoc.cardinality === :many do
        records = Actions.all(source, params, opts)

        put_loaded_association(changeset, key, records)
      else
        case Actions.find(source, params, opts) do
          {:ok, record} -> put_loaded_association(changeset, key, record)
          {:error, _} -> changeset
        end
      end
    end
  end

  defp params_has_key?(changeset, key) do
    case changeset.params do
      nil -> false
      params -> Map.has_key?(params, to_string(key))
    end
  end

  defp put_loaded_association(changeset, key, records) do
    Map.update!(changeset, :data, fn schema_data ->
      Map.put(schema_data, key, records)
    end)
  end

  defp schema_from_source({_, schema}), do: schema
  defp schema_from_source(schema), do: schema

  defp get_changeset_params(%{params: nil}, _key), do: nil
  defp get_changeset_params(%{params: params}, key), do: Map.get(params, to_string(key))

  defp fetch_changeset_association!(%{types: types} = changeset, key) do
    schema = get_changeset_schema_module(changeset)

    if Map.has_key?(types, key) do
      case Map.get(types, key) do
        {:assoc, assoc} ->
          assoc

        _ ->
          raise ArgumentError,
                "expected #{inspect(key)} to be an association in the changeset for schema #{inspect(schema)}"
      end
    else
      raise ArgumentError,
            "association #{inspect(key)} not found in the changeset for schema #{inspect(schema)}"
    end
  end

  defp get_changeset_schema_module(%{data: %{__meta__: %{schema: queryable}}}) do
    queryable
  end
end
