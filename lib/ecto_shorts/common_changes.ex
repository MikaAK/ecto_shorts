defmodule EctoShorts.CommonChanges do
  @moduledoc """
  `EctoShorts.CommonChanges` provides helper functions to
  simplify working with Ecto changesets.

  This module focuses on making common tasks easier, such as
  handling the difference between `put_assoc/4` and
  `cast_assoc/3`, automatically preloading data when needed,
  and conditionally validating or transforming fields.

  For example:

      def changeset(changeset, params) do
        changeset
        |> cast(params, [:name, :email])
        |> EctoShorts.CommonChanges.preload_change_assoc(:address)
      end

  You can also apply logic conditionally:

      EctoShorts.CommonChanges.apply_if(
        &EctoShorts.CommonChanges.has_nil_field?(&1, :email),
        &put_change(&1, :email, "default@email.com")
      )
  """

  alias Ecto.Changeset
  alias EctoShorts.{Actions, SchemaHelpers}

  @type changeset :: Ecto.Changeset.t()
  @type key :: atom()
  @type preloads :: atom() | list(atom()) | keyword()
  @type precision :: :microsecond | :millisecond | :second
  @type opts :: keyword()

  @doc since: "2.5.0"
  @spec truncate_datetime_change(changeset(), key(), precision()) :: changeset()
  def truncate_datetime_change(changeset, key, precision \\ :second) do
    Changeset.update_change(changeset, key, fn
      %NaiveDateTime{} = datetime -> NaiveDateTime.truncate(datetime, precision)
      %DateTime{} = datetime -> DateTime.truncate(datetime, precision)
      value -> value
    end)
  end

  @spec put_change_if_missing(changeset(), key(), (-> term())) :: changeset()
  def put_change_if_missing(changeset, key, fun) do
    if Map.has_key?(changeset.changes, key) do
      changeset
    else
      Changeset.put_change(changeset, key, fun.())
    end
  end

  @spec apply_if(changeset(), (changeset() -> boolean()), (changeset() -> changeset())) ::
          changeset()
  def apply_if(changeset, condition_fun, change_fun) do
    if condition_fun.(changeset), do: change_fun.(changeset), else: changeset
  end

  @spec has_empty_change?(changeset(), key()) :: boolean()
  def has_empty_change?(changeset, key) do
    case Changeset.get_change(changeset, key) do
      [] -> true
      change when change === %{} -> true
      _ -> false
    end
  end

  @spec has_nil_change?(changeset(), key()) :: boolean()
  def has_nil_change?(changeset, key) do
    Changeset.get_change(changeset, key) === nil
  end

  @spec has_empty_field?(changeset(), key()) :: boolean()
  def has_empty_field?(changeset, key) do
    case Changeset.get_field(changeset, key) do
      [] -> true
      change when change === %{} -> true
      _ -> false
    end
  end

  @spec has_nil_field?(changeset(), key()) :: boolean()
  def has_nil_field?(changeset, key) do
    Changeset.get_field(changeset, key) === nil
  end

  @spec preload_change_assoc(changeset(), key()) :: changeset()
  @spec preload_change_assoc(changeset(), key(), opts()) :: changeset()
  def preload_change_assoc(changeset, key, opts \\ []) do
    required? =
      if Keyword.has_key?(opts, :required_when_missing) do
        has_nil_field?(changeset, opts[:required_when_missing])
      else
        opts[:required] === true
      end

    opts = Keyword.put(opts, :required, required?)

    if Map.has_key?(changeset.params, to_string(key)) do
      changeset
      |> preload_changeset_assoc(key, opts)
      |> put_or_cast_assoc(key, opts)
    else
      Changeset.cast_assoc(changeset, key, opts)
    end
  end

  def preload_changeset_assoc(%{data: schema_data} = changeset, preloads, opts \\ []) do
    schema = get_changeset_schema(changeset)

    if SchemaHelpers.has_primary_keys?(schema, schema_data) do
      %{changeset | data: Actions.preload(schema_data, preloads, opts)}
    else
      changeset
    end
  end

  def put_or_cast_assoc(changeset, key, opts \\ []) do
    value = Map.get(changeset.params, to_string(key))

    apply_assoc_from_params(changeset, key, value, opts)
  end

  defp apply_assoc_from_params(changeset, key, nil, opts),
    do: Changeset.put_assoc(changeset, key, nil, opts)

  defp apply_assoc_from_params(changeset, key, [], opts),
    do: Changeset.put_assoc(changeset, key, [], opts)

  defp apply_assoc_from_params(changeset, key, values, opts) when is_list(values) do
    schema = get_changeset_schema(changeset)

    cond do
      SchemaHelpers.all_schema_struct?(values) ->
        put_assoc(changeset, key, values, opts)

      SchemaHelpers.only_has_primary_keys?(schema, values) ->
        put_assoc(changeset, key, values, opts)

      SchemaHelpers.any_has_primary_keys?(schema, values) ->
        Changeset.cast_assoc(changeset, key, opts)

      true ->
        Changeset.cast_assoc(changeset, key, opts)
    end
  end

  defp apply_assoc_from_params(changeset, key, value, opts) do
    if SchemaHelpers.schema_struct?(value) do
      put_assoc(changeset, key, value, opts)
    else
      Changeset.cast_assoc(changeset, key, opts)
    end
  end

  def put_assoc(changeset, key, values, opts) when is_list(values) do
    assoc = fetch_changeset_assoc!(changeset, key)
    assoc_schema = assoc.related

    {params_list, structs} = split_structs_and_params(values)

    query_params = build_pk_query_params(params_list, assoc_schema)

    if query_params === %{} do
      Changeset.put_assoc(changeset, key, structs, opts)
    else
      changeset = preload_changeset_assoc(changeset, key, opts)
      records = Actions.all(assoc.queryable, query_params, opts)
      Changeset.put_assoc(changeset, key, structs ++ records, opts)
    end
  end

  def put_assoc(changeset, key, %_{} = schema_data, opts),
    do: Changeset.put_assoc(changeset, key, schema_data, opts)

  def put_assoc(changeset, key, params, opts) do
    assoc = fetch_changeset_assoc!(changeset, key)
    assoc_schema = assoc.related

    changeset = preload_changeset_assoc(changeset, key, opts)
    query_params = SchemaHelpers.filter_primary_keys(params, assoc_schema)

    case Actions.find(assoc.queryable, query_params, opts) do
      {:ok, record} -> Changeset.put_assoc(changeset, key, record, opts)
      {:error, _} -> changeset
    end
  end

  defp split_structs_and_params(values) do
    Enum.reduce(values, {[], []}, fn
      %_{} = struct, {params, structs} -> {params, [struct | structs]}
      param, {params, structs} -> {[param | params], structs}
    end)
  end

  defp build_pk_query_params(params_list, schema) when is_list(params_list) do
    case SchemaHelpers.filter_primary_keys(params_list, schema) do
      [] ->
        %{}

      pk_params_list ->
        if SchemaHelpers.primary_key_count(schema) > 1 do
          %{or_where: pk_params_list}
        else
          Enum.reduce(pk_params_list, %{}, fn pk_params, query_params ->
            Enum.reduce(pk_params, query_params, fn {key, val}, query_params ->
              Map.update(query_params, key, [val], &[val | &1])
            end)
          end)
        end
    end
  end

  defp build_pk_query_params(params, schema) do
    SchemaHelpers.filter_primary_keys(params, schema)
  end

  def fetch_changeset_assoc!(%{data: %{__meta__: %{schema: schema}}} = changeset, key) do
    with :ok <- validate_schema_key_type!(changeset, key) do
      case Map.get(changeset.types, key) do
        {:assoc, assoc} ->
          assoc

        _ ->
          raise ArgumentError,
                "Expected key to be a `has_*` or `belongs_to` association on schema #{inspect(schema)}, got: #{inspect(key)}"
      end
    end
  end

  defp validate_schema_key_type!(%{data: %{__meta__: %{schema: schema}}, types: types}, key) do
    if Map.has_key?(types, key) do
      :ok
    else
      raise ArgumentError,
            "Expected #{inspect(key)} to be a field or direct association defined in the " <>
              "schema #{inspect(schema)}, but it was not found in the schema's declared fields. " <>
              "Ensure that the field exists and is defined using `field/3`, `belongs_to/2`, " <>
              "`has_one/2`, or `has_many/2`."
    end
  end

  defp get_changeset_schema(%{data: %{__meta__: %{schema: schema}}}), do: schema
end
