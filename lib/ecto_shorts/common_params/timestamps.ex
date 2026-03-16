defmodule EctoShorts.CommonParams.Timestamps do
  @moduledoc since: "3.0.0"
  @moduledoc """
  Manages `inserted_at` and `updated_at` timestamps for bulk operations.

  Used internally by `EctoShorts.CommonParams` to automatically set
  timestamp fields on insert and update data. Supports configurable
  source field names, timestamp types (`:utc_datetime`, `:naive_datetime`),
  and manual override values via options.
  """

  @utc_datetime :utc_datetime
  @naive_datetime :naive_datetime

  @inserted_at :inserted_at
  @updated_at :updated_at

  def put_timestamps(input, datetime, schema, opts) do
    input
    |> maybe_put_inserted_at(datetime, schema, opts)
    |> put_timestamp_updated_at(datetime, schema, opts)
  end

  def put_set_updated_at(updates, datetime, schema, opts) do
    source_key = get_updated_at_source(opts)
    value = Keyword.get(opts, :updated_at)

    cond do
      source_key === false ->
        updates

      value === false ->
        updates

      true ->
        value = prepare_timestamp_updated_at(value || datetime, source_key, schema, opts)

        Keyword.update(
          updates,
          :set,
          [{source_key, value}],
          &Keyword.put(&1, source_key, value)
        )
    end
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
    if Keyword.has_key?(opts, :inserted_at_source) do
      opts[:inserted_at_source]
    else
      @inserted_at
    end
  end

  defp normalize_timestamp_inserted_at(datetime, inserted_at_source, schema, opts) do
    timestamp_type = timestamp_type(opts, :inserted_at, inserted_at_source, schema)

    datetime
    |> cast_datetime(timestamp_type)
    |> truncate_datetime()
  end

  defp put_timestamp_updated_at(input, datetime, schema, opts) do
    source_key = get_updated_at_source(opts)
    value = Keyword.get(opts, :updated_at)

    cond do
      source_key === false ->
        input

      value === false ->
        input

      true ->
        value = prepare_timestamp_updated_at(value || datetime, source_key, schema, opts)
        Map.put(input, source_key, value)
    end
  end

  defp get_updated_at_source(opts) do
    if Keyword.has_key?(opts, :updated_at_source) do
      opts[:updated_at_source]
    else
      @updated_at
    end
  end

  defp cast_datetime(%NaiveDateTime{} = naive_datetime, _), do: naive_datetime
  defp cast_datetime(datetime, @naive_datetime), do: DateTime.to_naive(datetime)
  defp cast_datetime(datetime, @utc_datetime), do: datetime

  defp truncate_datetime(%DateTime{} = datetime), do: DateTime.truncate(datetime, :second)

  defp truncate_datetime(%NaiveDateTime{} = naive_datetime),
    do: NaiveDateTime.truncate(naive_datetime, :second)

  defp timestamp_type(opts, key, type_source, schema) do
    schema_timestamp_type =
      if schema !== nil do
        schema.__schema__(:type, type_source)
      end

    opts[:"#{key}_timestamp_type"] ||
      Keyword.get(opts[:timestamps] || [], key) ||
      opts[:timestamp_type] ||
      schema_timestamp_type ||
      @utc_datetime
  end

  defp prepare_timestamp_updated_at(datetime, updated_at_source, schema, opts) do
    timestamp_type = timestamp_type(opts, :updated_at, updated_at_source, schema)

    datetime
    |> cast_datetime(timestamp_type)
    |> truncate_datetime()
  end
end
