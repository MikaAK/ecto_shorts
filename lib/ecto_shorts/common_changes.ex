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
      |> load_changeset_assoc(key, opts)
      |> put_or_cast_assoc(key, opts)
    else
      Changeset.cast_assoc(changeset, key, opts)
    end
  end

  def load_changeset_assoc(changeset, key, opts) do
    value = get_changeset_params(changeset, key) || %{}

    assoc = fetch_changeset_association!(changeset, key)
    assoc_source = assoc.queryable
    assoc_schema = assoc.related

    query_params = build_query_params(value, assoc_schema)

    if Enum.any?(query_params) do
      if assoc.cardinality === :many do
        records = Actions.all(assoc_source, query_params, opts)
        Changeset.change(changeset, %{key => records})
      else
        case Actions.find(assoc_source, query_params, opts) do
          {:ok, record} -> Changeset.change(changeset, %{key => record})
          {:error, _} -> changeset
        end
      end
    else
      changeset
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
  def preload_changeset_assoc(
        %{data: %{__meta__: %{schema: schema}} = schema_data} = changeset,
        preloads,
        opts \\ []
      ) do
    if SchemaHelpers.created?(schema, schema_data) do
      %{changeset | data: Actions.preload(schema_data, preloads, opts)}
    else
      changeset
    end
  end

  @doc """
  ...
  """
  def build_changeset(changeset, params) when is_list(params) do
    build_changeset(changeset, Map.new(params))
  end

  def build_changeset(%{__meta__: %{schema: schema}} = schema_data, params) do
    build_changeset(schema, schema_data, params)
  end

  def build_changeset(%{data: %{__meta__: %{schema: schema}}} = changeset, params) do
    build_changeset(schema, changeset, params)
  end

  def build_changeset(schema, params) do
    build_changeset(schema, struct(schema), params)
  end

  @doc """
  ...
  """
  def build_changeset(schema, struct_or_changeset, params) do
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

  def put_or_cast_assoc(changeset, key, opts) do
    if params_has_key?(changeset, key) do
      apply_put_or_cast_assoc(changeset, key, get_changeset_params(changeset, key), opts)
    else
      Changeset.cast_assoc(changeset, key, opts)
    end
  end

  defp apply_put_or_cast_assoc(changeset, key, nil, opts) do
    Changeset.put_assoc(changeset, key, nil, opts)
  end

   defp apply_put_or_cast_assoc(changeset, key, [], opts) do
    Changeset.put_assoc(changeset, key, [], opts)
  end

  defp apply_put_or_cast_assoc(%{data: %{__meta__: %{schema: schema}}} = changeset, key, values, opts) when is_list(values) do
    cond do
      SchemaHelpers.all_schema_struct?(values) ->
        apply_put_assoc(changeset, key, values, opts)

      SchemaHelpers.only_primary_key_exists?(schema, values) ->
        apply_put_assoc(changeset, key, values, opts)

      SchemaHelpers.any_created?(schema, values) ->
        Changeset.cast_assoc(changeset, key, opts)

      true ->
        Changeset.cast_assoc(changeset, key, opts)
    end
  end

  defp apply_put_or_cast_assoc(changeset, key, value, opts) do
    if SchemaHelpers.schema_struct?(value) do
      apply_put_assoc(changeset, key, value, opts)
    else
      Changeset.cast_assoc(changeset, key, opts)
    end
  end

  defp apply_put_assoc(changeset, key, values, opts) when is_list(values) do
    assoc = fetch_changeset_association!(changeset, key)
    assoc_query_source = assoc.queryable
    assoc_schema = assoc.related

    {params_list, entries} = unzip_schema_data(values)

    query_params = build_query_params(params_list, assoc_schema)

    if query_params === %{} do
      Changeset.put_assoc(changeset, key, entries, opts)
    else
      changeset = preload_changeset_assoc(changeset, key, opts)

      records = Actions.all(assoc_query_source, query_params, opts)

      Changeset.put_assoc(changeset, key, entries ++ records, opts)
    end
  end

  defp apply_put_assoc(changeset, key, %_{} = schema_data, opts) do
    Changeset.put_assoc(changeset, key, schema_data, opts)
  end

  defp apply_put_assoc(changeset, key, params, opts) do
    assoc = fetch_changeset_association!(changeset, key)
    assoc_query_source = assoc.queryable
    assoc_schema = assoc.related

    changeset = preload_changeset_assoc(changeset, key, opts)

    query_params = SchemaHelpers.filter_primary_key(params, assoc_schema)

    case Actions.find(assoc_query_source, query_params, opts) do
      {:ok, record} -> Changeset.put_assoc(changeset, key, record, opts)
      {:error, _} -> changeset
    end
  end

  defp unzip_schema_data(values) do
    Enum.reduce(values, {[], []}, fn
      %_{} = schema_data, {entries, acc} -> {entries, [schema_data | acc]}
      value, {entries, acc} -> {[value | entries], acc}
    end)
  end

  # @doc """
  # ...
  # """
  # def cast_assoc(changeset, key, opts \\ []) do
  #   apply_cast_assoc(changeset, key, get_changeset_params(changeset, key), opts)
  # end

  # defp apply_cast_assoc(changeset, key, nil, opts) do
  #   Changeset.cast_assoc(changeset, key, opts)
  # end

  # defp apply_cast_assoc(changeset, key, list_of_params, opts) when is_list(list_of_params) do
  #   changeset
  #   |> maybe_change(key, list_of_params)
  #   |> Changeset.cast_assoc(key, opts)
  # end

  # defp apply_cast_assoc(changeset, key, params, opts) do
  #   changeset
  #   |> maybe_change(key, params)
  #   |> Changeset.cast_assoc(key, opts)
  # end

  # defp maybe_change(changeset, _key, []), do: changeset
  # defp maybe_change(changeset, _key, params) when params === %{}, do: changeset
  # defp maybe_change(changeset, key, params), do: Changeset.change(changeset, %{key => params})

  # defp collect_preloads(schema, params) do
  #   schema
  #   |> to_preloads_set(params, %{})
  #   |> flatten_preloads_set([])
  # end

  # defp to_preloads_set(schema, params, acc) when is_map(params) do
  #   to_preloads_set(schema, Map.to_list(params), acc)
  # end

  # defp to_preloads_set(_schema, [], acc) do
  #   acc
  # end

  # defp to_preloads_set(schema, [head | tail], acc) do
  #   with acc <- to_preloads_set(schema, head, acc) do
  #     to_preloads_set(schema, tail, acc)
  #   end
  # end

  # defp to_preloads_set(schema, {key, value}, acc) do
  #   if key in schema.__schema__(:associations) do
  #     case SchemaHelpers.get_related_schema(schema, key) do
  #       nil ->
  #         acc

  #       related_schema ->
  #         existing_data = Map.get(acc, key, %{})
  #         value = to_preloads_set(related_schema, value, existing_data)
  #         Map.put(acc, key, value)
  #     end
  #   else
  #     acc
  #   end
  # end

  # defp to_preloads_set(schema, key, acc) do
  #   if key in schema.__schema__(:associations) do
  #     Map.put_new(acc, key, %{})
  #   else
  #     acc
  #   end
  # end

  # defp flatten_preloads_set(preloads, acc) when is_map(preloads) and not is_struct(preloads) do
  #   preloads
  #   |> Map.to_list()
  #   |> flatten_preloads_set(acc)
  # end

  # defp flatten_preloads_set([], acc) do
  #   acc
  # end

  # defp flatten_preloads_set([head | tail], acc) do
  #   with acc <- flatten_preloads_set(head, acc) do
  #     flatten_preloads_set(tail, acc)
  #   end
  # end

  # defp flatten_preloads_set({key, preloads}, acc)
  #      when is_map(preloads) and not is_struct(preloads) do
  #   if Enum.any?(preloads) do
  #     case flatten_preloads_set(preloads, []) do
  #       [] -> [key | acc]
  #       values -> [{key, Enum.reverse(values)} | acc]
  #     end
  #   else
  #     [key | acc]
  #   end
  # end

  # defp flatten_preloads_set(_, acc) do
  #   acc
  # end

  defp build_query_params(params, schema) when is_list(params) do
    filtered_params = SchemaHelpers.filter_primary_key(params, schema)

    if size_greater_than_one?(filtered_params) and SchemaHelpers.primary_key_count(schema) > 1 do
      %{or_where: filtered_params}
    else
      Enum.reduce(filtered_params, %{}, fn params, acc ->
        Enum.reduce(params, acc, fn
          {key, val}, acc when is_binary(val) or is_integer(val) ->
            Map.update(acc, key, [val], &[val | &1])
        end)
      end)
    end
  end

  defp build_query_params(params, schema) do
    SchemaHelpers.filter_primary_key(params, schema)
  end

  defp size_greater_than_one?([_, _ | _tail]), do: true
  defp size_greater_than_one?(_), do: false

  defp params_has_key?(%{params: params}, key) when is_map(params),
    do: Map.has_key?(params, to_string(key))

  defp params_has_key?(%{params: _}, _key), do: false

  defp get_changeset_params(%{params: params}, key) when is_map(params),
    do: Map.get(params, to_string(key))

  defp get_changeset_params(%{params: _}, _key), do: nil

  def fetch_changeset_association!(%{data: %{__meta__: %{schema: schema}}} = changeset, key) do
    with :ok <- validate_changeset_type!(changeset, key) do
      case Map.get(changeset.types, key) do
        {:assoc, assoc} ->
          assoc

        _ ->
          raise ArgumentError,
                "Expected key to be an association for schema #{inspect(schema)}, got: #{inspect(key)}"
      end
    end
  end

  defp validate_changeset_type!(%{data: %{__meta__: %{schema: schema}}} = changeset, key) do
    if changeset_type?(changeset, key) do
      :ok
    else
      raise ArgumentError,
            "Expected field to be a query field or direct association for schema #{inspect(schema)}, got: #{inspect(key)}"
    end
  end

  defp changeset_type?(%{types: types} = _changeset, key) do
    Map.has_key?(types, key)
  end
end
