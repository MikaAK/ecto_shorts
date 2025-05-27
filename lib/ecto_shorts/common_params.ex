defmodule EctoShorts.CommonParams do
  @moduledoc since: "2.5.0"
  @moduledoc """
  Provides helper functions for preparing data used with the
  Ecto repo functions `update_all` and `insert_all`.

  This module is responsible for taking application-level data
  and transforming it into the structures required by Ecto for
  performing bulk operations. It offers a simple interface for
  validating records, generating timestamps, handling placeholder
  values, and preparing conflict resolution behavior.

  It works by normalizing input data (such as maps or structs),
  optionally validating it through the schema’s `changeset/2`,
  and then generating the appropriate keyword lists or maps used
  by Ecto’s insert and update functions. If configured, it also
  automatically manages timestamps for `inserted_at` and
  `updated_at`, and handles scenarios where placeholder values
  need to be substituted during insert operations.

  This is especially useful when performing batch inserts or
  updates, ensuring consistent timestamp handling, optional
  schema validation, and support for placeholder values across
  your application.
  """

  alias Ecto.Changeset
  alias EctoShorts.{CommonChanges, SchemaHelpers, Utils}

  @type schema :: Ecto.Queryable.t()
  @type params :: map()
  @type insert_all_params :: map()
  @type update_all_params :: keyword()
  @type changesets :: Ecto.Changeset.t()
  @type opts :: keyword()

  @utc_datetime :utc_datetime
  @naive_datetime :naive_datetime

  @inserted_at :inserted_at
  @updated_at :updated_at

  @doc """
  Converts a map of update parameters into the format expected by
  [Ecto.Repo.update_all](https://hexdocs.pm/ecto/Ecto.Repo.html#c:update_all/3).

  This is useful when you need to perform a bulk update on a set of records.
  The parameters are grouped by action (for example, set, increment, push),
  and the result is returned in the format required by `update_all/3`.

  You can also choose to automatically update the `updated_at` field.

  ## Options

    * `updated_at` – Manually provide the timestamp value for the `updated_at` field.
    * `updated_at_source` – Change the field name that is used instead of `:updated_at`.
    * `updated_at_timestamp_type` – Override the format of the `updated_at` field
      (for example, UTC or naive datetime).
    * `timestamp_type` – Fallback timestamp format type if the above is not provided.
  """
  @spec convert_to_update_all_params(schema(), params()) :: update_all_params()
  @spec convert_to_update_all_params(schema(), params(), opts()) :: update_all_params()
  def convert_to_update_all_params(schema, params, opts \\ []) do
    utc_now = datetime_utc_now()

    schema
    |> build_updates(params, [])
    |> flatten_updates()
    |> set_timestamp_updated_at(utc_now, schema, opts)
    |> Enum.map(fn {key, values} -> {key, Enum.sort(values)} end)
    |> Enum.sort()
  end

  defp set_timestamp_updated_at(updates, datetime, schema, opts) do
    updated_at_source = opts[:updated_at] || opts[:updated_at_source] || @updated_at

    datetime = serialize_timestamp_updated_at(datetime, updated_at_source, schema, opts)

    Keyword.update(
      updates,
      :set,
      [{updated_at_source, datetime}],
      &Keyword.put(&1, updated_at_source, datetime)
    )
  end

  defp flatten_updates(normalized_updates) do
    normalized_updates
    |> Enum.group_by(fn {operator, _key, _value} -> operator end)
    |> Enum.map(fn {operator, updates} ->
      {operator, Enum.map(updates, fn {_, key, value} -> {key, value} end)}
    end)
  end

  defp build_updates(schema, params, acc) when is_map(params) do
    build_updates(schema, Map.to_list(params), acc)
  end

  defp build_updates(_schema, [], acc) do
    acc
  end

  defp build_updates(schema, [head | tail], acc) do
    with acc <- build_updates(schema, head, acc) do
      build_updates(schema, tail, acc)
    end
  end

  defp build_updates(schema, {key, value}, acc) do
    if key in schema.__schema__(:query_fields) do
      EctoShorts.Utils.apply_expressions(acc, value, fn value, acc ->
        normalize_update(schema, key, value, acc)
      end)
    else
      acc
    end
  end

  defp normalize_update(schema, key, {operator, value}, acc) when operator in [:pull, :push] do
    case validate_field_type_array(schema, key) do
      :ok ->
        value
        |> List.wrap()
        |> Enum.reduce(acc, fn value, acc ->
          [{operator, key, value} | acc]
        end)

      {:error, actual_type} ->
        raise ArgumentError,
          """
          Expected the key `#{key}` in schema `#{inspect(schema)}` to be of
          `array` type for the Ecto.Query update operator `#{operator}`, but
          got: `#{inspect(actual_type)}`
          """
    end
  end

  defp normalize_update(schema, key, {:inc, value}, acc) do
    case validate_field_type_integer(schema, key) do
      :ok ->
        if is_integer(value) do
          [{:inc, key, value} | acc]
        else
          raise ArgumentError, "Expected the value of key #{inspect(key)} to be an integer, got: #{inspect(value)}"
        end

      {:error, actual_type} ->
        raise ArgumentError,
          """
          Expected the key `#{key}` in schema `#{inspect(schema)}` to be of
          `integer` type for the Ecto.Query update operator `:inc`, but
          got: `#{inspect(actual_type)}`
          """
    end
  end

  defp normalize_update(_schema, key, {:set, value}, acc) do
    [{:set, key, value} | acc]
  end

  defp normalize_update(_schema, key, value, acc) do
    [{:set, key, value} | acc]
  end

  defp validate_field_type_integer(schema, key) do
    case schema.__schema__(:type, key) do
      :integer -> :ok
      val -> {:error, val}
    end
  end

  defp validate_field_type_array(schema, key) do
    case schema.__schema__(:type, key) do
      {:array, _} -> :ok
      val -> {:error, val}
    end
  end

  @doc """
  Converts a list of parameters or structs into the format
  expected by [Ecto.Repo.insert_all](https://hexdocs.pm/ecto/Ecto.Repo.html#c:insert_all/3), with support for
  validation, timestamps, and placeholder substitution.

  ## Options

  ### Placeholder Options

  These control how certain field values are replaced with placeholders.
  Placeholders are useful when you want to defer resolution of the final
  value to a later process, or signal that a special condition applies.

    * `placeholders`: A map where the key is the field name (as an atom)
      and the value is the placeholder value to match against.
      If the field value matches, it will be replaced with a tuple like
      `{:placeholder, :field_name}`, where `:field_name` refers to the
      actual name of the field being substituted.

    * `on_placeholder_conflict`: Controls what happens when a placeholder
      value is provided but the record already contains a different value.
      You can choose from:

        * `nothing` – Keep the existing value unchanged.

        * `replace_all` – Always use the placeholder regardless of conflict.

        * `{replace, fields}` – Only replace fields listed in the provided list.

  ### Timestamp Options

  These let you configure how inserted and updated timestamps are applied.

    * `inserted_at`, `updated_at`: Manually set the values for each timestamp.

    * `inserted_at_source`, `updated_at_source`: Customize the field name
      (for example, use `created_on` instead of `inserted_at`).

    * `inserted_at_timestamp_type`, `updated_at_timestamp_type`: Override
      the timestamp format type (e.g. naive or UTC).

    * `timestamp_type`: A fallback type for both inserted and updated fields.

  ### Validation Options

    * `validate`: If `true`, each entry is passed through the schema’s
      `changeset/2` function for validation. If `false`, raw structs are
      constructed without validation.
  """
  @spec convert_to_insert_all_params(schema(), list(params())) ::
          {:ok, {list(insert_all_params()), opts()}} | {:error, changesets()}
  @spec convert_to_insert_all_params(schema(), list(params()), opts()) ::
          {:ok, {list(insert_all_params()), opts()}} | {:error, changesets()}
  def convert_to_insert_all_params(schema, params_list, opts \\ []) do
    utc_now = datetime_utc_now()

    with {:ok, inserts, action, changed_keys} <-
           apply_insert_changes(
             params_list,
             schema,
             utc_now,
             opts
           ) do
      if action === :upsert do
        {:ok, {inserts, on_conflict_options(schema, changed_keys)}}
      else
        {:ok, {inserts, []}}
      end
    end
  end

  @doc false
  def serialize_insert(schema, data, changed_keys, utc_now, opts) do
    data
    |> Map.take(schema.__schema__(:query_fields))
    |> drop_if_value_nil_and_not_a_change(changed_keys)
    |> put_placeholders(opts[:placeholders] || %{}, opts)
    |> put_timestamps(utc_now, schema, opts)
  end

  defp apply_insert_changes(params_list, schema, utc_now, opts) do
    results =
      Enum.reduce(
        params_list,
        {[], [], :insert, MapSet.new()},
        fn params, {oks, errors, action, changed_keys_map_set} ->
          case apply_insert_change(schema, params, opts) do
            {:ok, schema_data, changed_keys} ->
              data =
                serialize_insert(
                  schema,
                  schema_data,
                  changed_keys,
                  utc_now,
                  opts
                )

              action =
                if action === :upsert or
                     SchemaHelpers.has_primary_key?(schema, data) do
                  :upsert
                else
                  action
                end

              changed_keys_map_set =
                Enum.reduce(changed_keys, changed_keys_map_set, fn key, acc ->
                  MapSet.put(acc, key)
                end)

              {[data | oks], errors, action, changed_keys_map_set}

            {:error, e} ->
              {oks, [e | errors], action, changed_keys_map_set}
          end
        end
      )

    case results do
      {inserts, [], action, changed_keys_map_set} ->
        {:ok, inserts, action, MapSet.to_list(changed_keys_map_set)}

      {_oks, errors, _action, _changed_keys_map_set} ->
        {:error, errors}
    end
  end

  defp apply_insert_change(
         schema,
         {%{data: %{__meta__: _} = schema_data} = changeset, params},
         opts
       ) do
    if opts[:validate] === false do
      changed_keys = get_params_changed_keys(params, schema, opts)

      {:ok, struct(schema_data, params), changed_keys}
    else
      changeset = CommonChanges.changeset(schema, changeset, params)

      changed_keys = get_params_changed_keys(params, schema, opts)

      with {:ok, schema_data} <-
             Changeset.apply_action(
               changeset,
               changeset_action(schema, schema_data)
             ) do
        {:ok, schema_data, changed_keys}
      end
    end
  end

  defp apply_insert_change(schema, {%{__meta__: _} = schema_data, params}, opts) do
    if opts[:validate] === false do
      changed_keys = get_params_changed_keys(params, schema, opts)

      {:ok, struct(schema_data, params), changed_keys}
    else
      changeset = CommonChanges.changeset(schema, schema_data, params)

      changed_keys = get_params_changed_keys(params, schema, opts)

      with {:ok, schema_data} <-
             Changeset.apply_action(
               changeset,
               changeset_action(schema, schema_data)
             ) do
        {:ok, schema_data, changed_keys}
      end
    end
  end

  defp apply_insert_change(
         schema,
         %{data: %{__meta__: _} = schema_data} = changeset,
         opts
       ) do
    changed_keys = get_struct_changed_keys(schema_data, schema, opts)

    if opts[:validate] === false do
      {:ok, schema_data, changed_keys}
    else
      changeset = CommonChanges.changeset(schema, changeset, %{})

      with {:ok, schema_data} <-
             Changeset.apply_action(
               changeset,
               changeset_action(schema, schema_data)
             ) do
        {:ok, schema_data, changed_keys}
      end
    end
  end

  defp apply_insert_change(schema, %{__meta__: _} = schema_data, opts) do
    changed_keys =
      schema
      |> struct()
      |> get_struct_changed_keys(schema, opts)

    if opts[:validate] === false do
      {:ok, schema_data, changed_keys}
    else
      changeset = CommonChanges.changeset(schema, schema_data, %{})

      with {:ok, schema_data} <-
             Changeset.apply_action(
               changeset,
               changeset_action(schema, schema_data)
             ) do
        {:ok, schema_data, changed_keys}
      end
    end
  end

  defp apply_insert_change(schema, params, opts) do
    if opts[:validate] === false do
      schema_data = struct(schema, params)

      changed_keys = get_params_changed_keys(params, schema, opts)

      {:ok, schema_data, changed_keys}
    else
      created_data =
        if SchemaHelpers.has_primary_key?(schema, params) do
          Map.take(params, SchemaHelpers.primary_key(schema))
        else
          %{}
        end

      changeset = CommonChanges.changeset(schema, struct!(schema, created_data), params)

      changed_keys = get_params_changed_keys(params, schema, opts)

      with {:ok, schema_data} <-
             Changeset.apply_action(
               changeset,
               changeset_action(schema, params)
             ) do
        {:ok, schema_data, changed_keys}
      end
    end
  end

  @doc false
  def changeset_action(schema, data) do
    if SchemaHelpers.has_primary_key?(schema, data) do
      :update
    else
      :insert
    end
  end

  @doc false
  def get_struct_changed_keys(struct, schema, opts) do
    struct
    |> Utils.to_jsonable_map()
    |> Map.keys()
    |> filter_supported_insert_fields(schema, opts)
  end

  @doc false
  def get_params_changed_keys(params, schema, opts) do
    params
    |> Utils.keys_to_atom(opts)
    |> Map.keys()
    |> filter_supported_insert_fields(schema, opts)
  end

  @doc false
  def filter_supported_insert_fields(keys, schema, opts) do
    keys
    |> Enum.filter(&(&1 in schema.__schema__(:query_fields)))
    |> Kernel.--(schema.__schema__(:primary_key))
    |> Kernel.--([inserted_at_source(opts)])
  end

  @doc false
  def on_conflict_options(schema, changed_keys) do
    if function_exported?(schema, :on_conflict_options, 0) do
      schema.on_conflict_options()
    else
      opts = [conflict_target: schema.__schema__(:primary_key)]

      # setting on_conflict to {:replace, []} causes an ecto error
      # so don't add that option if changed keys is empty.
      if changed_keys === [] do
        opts
      else
        Keyword.put(opts, :on_conflict, {:replace, changed_keys})
      end
    end
  end

  defp drop_if_value_nil_and_not_a_change(data, changed_keys) do
    data
    |> Enum.reject(fn {key, val} -> is_nil(val) and key not in changed_keys end)
    |> Map.new()
  end

  @doc false
  def put_placeholders(data, placeholders, opts) do
    Enum.reduce(placeholders, data, &put_placeholder(&1, &2, opts))
  end

  def put_placeholder({key, placeholder_value}, data, opts) do
    if Map.has_key?(data, key) do
      if Map.get(data, key) === placeholder_value do
        put_placeholder(data, key)
      else
        on_placeholder_conflict(data, key, opts)
      end
    else
      data
    end
  end

  defp on_placeholder_conflict(data, key, opts) do
    case Keyword.get(opts, :on_placeholder_conflict, :nothing) do
      {:replace, keys} -> if key in keys, do: put_placeholder(data, key), else: data
      :replace_all -> put_placeholder(data, key)
      :nothing -> data
    end
  end

  defp put_placeholder(data, key), do: Map.put(data, key, {:placeholder, key})

  @doc false
  def put_timestamps(data, datetime, schema, opts) do
    data
    |> maybe_put_inserted_at(datetime, schema, opts)
    |> put_timestamp_updated_at(datetime, schema, opts)
  end

  defp maybe_put_inserted_at(data, datetime, schema, opts) do
    inserted_at_source = inserted_at_source(opts)

    if inserted_at_source === false do
      data
    else
      case Map.get(data, inserted_at_source) do
        nil ->
          Map.put(
            data,
            inserted_at_source,
            serialize_timestamp_inserted_at(datetime, inserted_at_source, schema, opts)
          )

        _ ->
          data
      end
    end
  end

  defp put_timestamp_updated_at(data, datetime, schema, opts) do
    updated_at_source = updated_at_source(opts)

    if updated_at_source === false do
      data
    else
      Map.put(
        data,
        updated_at_source,
        serialize_timestamp_updated_at(datetime, updated_at_source, schema, opts)
      )
    end
  end

  defp serialize_timestamp_inserted_at(datetime, inserted_at_source, schema, opts) do
    datetime
    |> maybe_to_naive_datetime(timestamp_type(opts, :inserted_at, inserted_at_source, schema))
    |> truncate_datetime()
  end

  defp serialize_timestamp_updated_at(datetime, updated_at_source, schema, opts) do
    datetime
    |> maybe_to_naive_datetime(timestamp_type(opts, :updated_at, updated_at_source, schema))
    |> truncate_datetime()
  end

  defp inserted_at_source(opts) do
    opts[:inserted_at] || opts[:inserted_at_source] || @inserted_at
  end

  defp updated_at_source(opts) do
    opts[:updated_at] || opts[:updated_at_source] || @updated_at
  end

  defp timestamp_type(opts, key, type_source, schema) do
    opts[:timestamps][key] ||
      opts[:timestamp_type] ||
      schema.__schema__(:type, type_source) ||
      @utc_datetime
  end

  defp datetime_utc_now, do: DateTime.utc_now()

  defp truncate_datetime(datetime) when is_struct(datetime, DateTime) do
    DateTime.truncate(datetime, :second)
  end

  defp truncate_datetime(naive_datetime) when is_struct(naive_datetime, NaiveDateTime) do
    NaiveDateTime.truncate(naive_datetime, :second)
  end

  defp maybe_to_naive_datetime(datetime, @naive_datetime), do: DateTime.to_naive(datetime)
  defp maybe_to_naive_datetime(datetime, @utc_datetime), do: datetime
end
