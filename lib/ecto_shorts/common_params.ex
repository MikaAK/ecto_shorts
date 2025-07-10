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

  It works by normalizing params data (such as maps or structs),
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
  alias EctoShorts.{CommonSchema, SchemaHelpers, Utils}

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
    utc_now = DateTime.utc_now()

    updates = schema |> build_updates(params, []) |> flatten_updates()

    if updates === [] do
      []
    else
      updates
      |> set_timestamp_updated_at(utc_now, schema, opts)
      |> Enum.map(fn {key, values} -> {key, Enum.sort(values)} end)
      |> Enum.sort()
    end
  end

  defp set_timestamp_updated_at(updates, datetime, schema, opts) do
    updated_at_source = opts[:updated_at] || opts[:updated_at_source] || @updated_at

    datetime = prepare_timestamp_updated_at(datetime, updated_at_source, schema, opts)

    Keyword.update(
      updates,
      :set,
      [{updated_at_source, datetime}],
      &Keyword.put(&1, updated_at_source, datetime)
    )
  end

  defp flatten_updates(normalized_updates) do
    normalized_updates
    |> Enum.group_by(fn {op, _key, _value} -> op end)
    |> Enum.map(fn {op, updates} ->
      {op, Enum.map(updates, fn {_, key, value} -> {key, value} end)}
    end)
  end

  defp build_updates(schema, %{} = params, acc) do
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

  defp normalize_update(schema, key, {op, value}, acc) when op in [:pull, :push] do
    case validate_field_type_of_array(schema, key) do
      :ok ->
        value
        |> List.wrap()
        |> Enum.reduce(acc, fn value, acc ->
          [{op, key, value} | acc]
        end)

      {:error, actual_type} ->
        raise ArgumentError,
              """
              The field `#{inspect(key)}` on schema `#{inspect(schema)}` is not a type of `:array`
              and cannot be used with the `Ecto.Query` update operator `#{inspect(op)}`.

              actual type:
              #{inspect(actual_type)}
              """
    end
  end

  defp normalize_update(schema, key, {:inc, value}, acc) do
    case validate_field_type_of_integer(schema, key) do
      :ok ->
        if is_integer(value) do
          [{:inc, key, value} | acc]
        else
          raise ArgumentError,
                "Expected value for key `#{inspect(key)}` to be an integer, got: #{inspect(value)}"
        end

      {:error, actual_type} ->
        raise ArgumentError,
              """
              The field `#{inspect(key)}` on schema `#{inspect(schema)}` is not a type of `:integer`
              and cannot be used with the `Ecto.Query` update operator `:inc`.

              actual type:
              #{inspect(actual_type)}
              """
    end
  end

  defp normalize_update(_schema, key, {:set, value}, acc) do
    [{:set, key, value} | acc]
  end

  defp normalize_update(_schema, key, value, acc) do
    [{:set, key, value} | acc]
  end

  defp validate_field_type_of_integer(schema, key) do
    case schema.__schema__(:type, key) do
      :integer -> :ok
      val -> {:error, val}
    end
  end

  defp validate_field_type_of_array(schema, key) do
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
  def convert_to_insert_all_params(schema, params_list \\ [], opts \\ []) do
    with {:ok, insert_maps, changed_keys, has_primary_key?} <-
           build_inserts(params_list, schema, opts) do
      insert_opts =
        if has_primary_key? do
          on_conflict_options(schema, changed_keys)
        else
          []
        end

      {:ok, {insert_maps, insert_opts}}
    end
  end

  defp build_inserts(params_list, schema, opts) do
    case prepare_inserts(params_list, schema, opts) do
      {insert_maps, [], changed_key_set, has_primary_key?} ->
        changed_keys =
          changed_key_set
          |> MapSet.to_list()
          |> Enum.sort()

        {:ok, Enum.reverse(insert_maps), changed_keys, has_primary_key?}

      {_, errors, _, _} ->
        {:error, Enum.reverse(errors)}
    end
  end

  defp prepare_inserts(params_list, schema, opts) do
    utc_now = DateTime.utc_now()

    Enum.reduce(
      params_list,
      {[], [], MapSet.new(), false},
      fn params, {entries, errors, changed_key_set, has_primary_key?} ->
        case change_insert(schema, params, opts) do
          {:ok, insert_data, changed_keys} ->
            changed_key_set = Enum.reduce(changed_keys, changed_key_set, &MapSet.put(&2, &1))

            entry = serialize_insert_data(schema, insert_data, utc_now, changed_keys, opts)

            has_primary_key? =
              if has_primary_key? do
                has_primary_key?
              else
                SchemaHelpers.primary_key_exist?(schema, entry)
              end

            {[entry | entries], errors, changed_key_set, has_primary_key?}

          {:error, e} ->
            {entries, [e | errors], changed_key_set, has_primary_key?}
        end
      end
    )
  end

  defp change_insert(schema, {%{data: schema_data} = _changeset, params}, opts) do
    params = Map.take(params, schema.__schema__(:query_fields))

    changed_keys = collect_changed_keys(schema_data, params)

    if opts[:validate] === false do
      {:ok, struct(schema_data, params), changed_keys}
    else
      with {:ok, insert_data} <-
             schema_data
             |> CommonSchema.prepare_changeset(params, opts)
             |> Changeset.apply_action(changeset_action(schema, schema_data)) do
        {:ok, insert_data, changed_keys}
      end
    end
  end

  defp change_insert(schema, {%_{} = schema_data, params}, opts) do
    params = Map.take(params, schema.__schema__(:query_fields))

    changed_keys = collect_changed_keys(schema_data, params)

    if opts[:validate] === false do
      {:ok, struct(schema_data, params), changed_keys}
    else
      with {:ok, insert_data} <-
             schema_data
             |> CommonSchema.prepare_changeset(params, opts)
             |> Changeset.apply_action(changeset_action(schema, schema_data)) do
        {:ok, insert_data, changed_keys}
      end
    end
  end

  defp change_insert(schema, %{data: schema_data} = changeset, opts) do
    params =
      changeset.params
      |> Utils.atomize_keys(opts)
      |> Map.take(schema.__schema__(:query_fields))

    changed_keys = collect_changed_keys(schema_data, params)

    if opts[:validate] === false do
      {:ok, schema_data, changed_keys}
    else
      with {:ok, insert_data} <-
             Changeset.apply_action(changeset, changeset_action(schema, schema_data)) do
        {:ok, insert_data, changed_keys}
      end
    end
  end

  defp change_insert(schema, %_{} = schema_data, opts) do
    changed_keys = schema.__schema__(:query_fields)

    if opts[:validate] === false do
      {:ok, schema_data, changed_keys}
    else
      with {:ok, insert_data} <-
             schema_data
             |> CommonSchema.prepare_changeset(opts)
             |> Changeset.apply_action(changeset_action(schema, schema_data)) do
        {:ok, insert_data, changed_keys}
      end
    end
  end

  defp change_insert(schema, params, opts) do
    params = Map.take(params, schema.__schema__(:query_fields))

    changed_keys =
      Enum.reduce(schema.__schema__(:query_fields), [], fn query_field, acc ->
        if Map.has_key?(params, query_field) do
          [query_field | acc]
        else
          acc
        end
      end)

    if opts[:validate] === false do
      {:ok, struct(schema, params), changed_keys}
    else
      with {:ok, insert_data} <-
             schema
             |> CommonSchema.prepare_changeset(params, opts)
             |> Changeset.apply_action(:insert) do
        insert_data =
          if SchemaHelpers.primary_key_exist?(schema, params) do
            struct!(insert_data, SchemaHelpers.filter_primary_key(params, schema))
          else
            insert_data
          end

        {:ok, insert_data, changed_keys}
      end
    end
  end

  defp changeset_action(schema, schema_data) do
    if SchemaHelpers.primary_key_exist?(schema, schema_data) do
      :update
    else
      :insert
    end
  end

  defp on_conflict_options(schema, replace_fields) do
    if replace_fields === [] do
      [conflict_target: schema.__schema__(:primary_key)]
    else
      [conflict_target: schema.__schema__(:primary_key), on_conflict: {:replace, replace_fields}]
    end
  end

  defp serialize_insert_data(schema, insert_data, utc_now, changed_keys, opts) do
    insert_data
    |> Map.take(schema.__schema__(:query_fields))
    |> filter_insert_changes(changed_keys)
    |> put_placeholders(opts[:placeholders] || %{}, opts)
    |> put_timestamps(utc_now, schema, opts)
  end

  defp filter_insert_changes(insert_data, changed_keys) do
    Enum.reduce(insert_data, %{}, fn {key, value}, acc ->
      if value !== nil or (value === nil and Enum.member?(changed_keys, key)) do
        Map.put(acc, key, value)
      else
        acc
      end
    end)
  end

  defp collect_changed_keys(map_a, map_b) do
    Enum.reduce(map_b, [], fn {key, val}, acc ->
      if Map.get(map_a, key) != val do
        [key | acc]
      else
        acc
      end
    end)
  end

  defp put_placeholders(data, placeholders, opts) do
    Enum.reduce(placeholders, data, &put_placeholder(&1, &2, opts))
  end

  defp put_placeholder({key, placeholder_value}, data, opts) do
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

  defp on_placeholder_conflict(input, key, opts) do
    case Keyword.get(opts, :on_placeholder_conflict, :nothing) do
      {:replace, keys} ->
        if Enum.member?(keys, key) do
          put_placeholder(input, key)
        else
          input
        end

      :replace_all ->
        put_placeholder(input, key)

      :nothing ->
        input

      term ->
        raise ArgumentError,
              "Expected the value for option :on_placeholder_conflict to be one of " <>
                "[:replace, :replace_all, :nothing], got: #{inspect(term)}"
    end
  end

  defp put_placeholder(input, key), do: Map.put(input, key, {:placeholder, key})

  defp put_timestamps(input, datetime, schema, opts) do
    input
    |> maybe_put_inserted_at(datetime, schema, opts)
    |> put_timestamp_updated_at(datetime, schema, opts)
  end

  defp maybe_put_inserted_at(input, datetime, schema, opts) do
    source_key = inserted_at_source_key(opts)

    if source_key === false do
      input
    else
      result =
        if Map.has_key?(input, source_key) do
          case Map.get(input, source_key) do
            nil ->
              normalize_timestamp_inserted_at(datetime, source_key, schema, opts)

            existing_timestamp ->
              normalize_timestamp_inserted_at(existing_timestamp, source_key, schema, opts)
          end
        else
          normalize_timestamp_inserted_at(datetime, source_key, schema, opts)
        end

      Map.put(input, source_key, result)
    end
  end

  defp inserted_at_source_key(opts) do
    cond do
      Keyword.has_key?(opts, :inserted_at) -> opts[:inserted_at]
      Keyword.has_key?(opts, :inserted_at_source) -> opts[:inserted_at_source]
      true -> @inserted_at
    end
  end

  defp normalize_timestamp_inserted_at(datetime, inserted_at_source, schema, opts) do
    timestamp_type = timestamp_type(opts, :inserted_at, inserted_at_source, schema)

    datetime
    |> cast_datetime(timestamp_type)
    |> truncate_datetime()
  end

  defp put_timestamp_updated_at(input, datetime, schema, opts) do
    source_key = updated_at_source_key(opts)

    if source_key === false do
      input
    else
      value = prepare_timestamp_updated_at(datetime, source_key, schema, opts)
      Map.put(input, source_key, value)
    end
  end

  defp updated_at_source_key(opts) do
    cond do
      Keyword.has_key?(opts, :updated_at) -> opts[:updated_at]
      Keyword.has_key?(opts, :updated_at_source) -> opts[:updated_at_source]
      true -> @updated_at
    end
  end

  defp prepare_timestamp_updated_at(datetime, updated_at_source, schema, opts) do
    timestamp_type = timestamp_type(opts, :updated_at, updated_at_source, schema)

    datetime
    |> cast_datetime(timestamp_type)
    |> truncate_datetime()
  end

  defp timestamp_type(opts, key, type_source, schema) do
    opts[:timestamps][key] ||
      opts[:timestamp_type] ||
      schema.__schema__(:type, type_source) ||
      @utc_datetime
  end

  defp cast_datetime(%NaiveDateTime{} = naive_datetime, _), do: naive_datetime
  defp cast_datetime(datetime, @naive_datetime), do: DateTime.to_naive(datetime)
  defp cast_datetime(datetime, @utc_datetime), do: datetime

  defp truncate_datetime(%DateTime{} = datetime), do: DateTime.truncate(datetime, :second)

  defp truncate_datetime(%NaiveDateTime{} = naive_datetime),
    do: NaiveDateTime.truncate(naive_datetime, :second)
end
