defmodule EctoShorts.Actions.Batch do
  @moduledoc since: "3.0.0"
  @moduledoc false

  # Normalizes batch lookup params and groups fetched records by batch key.
  #
  # Used internally by `EctoShorts.Actions.batch/5` and
  # `EctoShorts.Actions.batch_preload/4` to build the lookup queries and
  # shape the results into a key-to-record(s) map.

  alias EctoShorts.CommonSchema

  def build_batch_params(_schema, _list_of_params, [], _opts) do
    []
  end

  def build_batch_params(schema, params_list, batch_keys, opts) do
    query_fields = CommonSchema.get_query_fields(opts, schema)

    if Enum.all?(batch_keys, &(&1 in query_fields)) do
      params_list
      |> Enum.map(fn params -> normalize_batch_key(params, batch_keys) end)
      |> Enum.uniq()
      |> Enum.map(&{:or_where, &1})
    else
      raise ArgumentError,
            "Expected batch keys to be a subset of query fields #{inspect(query_fields)}, got: #{inspect(batch_keys)}"
    end
  end

  def normalize_batch_key(params, keys) when is_list(params) and is_list(keys) do
    params |> Map.new() |> normalize_batch_key(keys)
  end

  def normalize_batch_key(params, keys) when is_map(params) and is_list(keys) do
    Map.take(params, keys)
  end

  def normalize_batch_key(params, key) when is_map(params) do
    Map.get(params, key)
  end

  def normalize_batch_key(value, key) when is_atom(key) do
    %{key => value}
  end

  def handle_batch_response(records, cardinality, batch_key) do
    records
    |> Enum.map(fn {key, values} ->
      case {cardinality, values} do
        {:one, [value]} ->
          {key, value}

        {:one, _} ->
          raise ArgumentError,
                "Expected at most one value for batch key #{inspect(batch_key)}, got #{length(values)}"

        {_, grouped_values} ->
          {key, grouped_values}
      end
    end)
    |> Map.new()
  end

  def normalize_key_fields(key) when is_atom(key), do: [key]
  def normalize_key_fields(keys) when is_list(keys), do: keys
  def normalize_key_fields(keys), do: keys

  def zip_batch_result({_find_params, other_params}, record) do
    {record, other_params}
  end

  def zip_batch_result(original_params, record) do
    {record, original_params}
  end

  def extract_lookup_params(entries, keys) do
    entries
    |> Stream.with_index()
    |> Enum.reduce({[], %{}}, &reduce_preload_entry(&1, &2, keys))
  end

  defp reduce_preload_entry({entry, index}, {values_acc, index_map}, keys) do
    case normalize_preload_params(entry) do
      nil ->
        {values_acc, index_map}

      params ->
        batch_key = build_batch_key(params, keys)

        if batch_key === %{} do
          {values_acc, index_map}
        else
          {[batch_key | values_acc], Map.put(index_map, index, batch_key)}
        end
    end
  end

  defp normalize_preload_params({params, _other}) do
    normalize_preload_params(params)
  end

  defp normalize_preload_params(params) when is_list(params) do
    Map.new(params)
  end

  defp normalize_preload_params(params) when is_map(params) and not is_struct(params) do
    params
  end

  defp normalize_preload_params(_), do: nil

  defp build_batch_key(params, true) do
    params
  end

  defp build_batch_key(params, keys) when is_list(keys) do
    Map.take(params, keys)
  end

  defp build_batch_key(params, key) when is_atom(key) do
    Map.take(params, [key])
  end

  defp build_batch_key(params, key_fn) when is_function(key_fn) do
    case key_fn.(params) do
      map when is_map(map) -> map
      term -> raise "Expected batch key function to return a map, got: #{inspect(term)}"
    end
  end
end
