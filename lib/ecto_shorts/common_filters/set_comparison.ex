defmodule EctoShorts.CommonFilters.SetComparison do
  @moduledoc false

  alias EctoShorts.CommonFilters
  alias EctoShorts.CommonFilters.Select
  alias EctoShorts.DynamicBuilders.Postgres.Normalizer
  alias EctoShorts.Logger

  @logger_prefix "EctoShorts.CommonFilters.SetComparison"

  def build_quantified_query(outer_key, params, opts)
      when is_map(params) and not is_struct(params) do
    build_quantified_query(outer_key, Map.to_list(params), opts)
  end

  def build_quantified_query(outer_key, params, opts) do
    if Keyword.keyword?(params) do
      source = Keyword.fetch!(params, :from)
      where_params = Keyword.get(params, :where, [])

      select_term =
        quantified_select_field(source, Keyword.get(params, :select, outer_key), outer_key, opts)

      inner_query = CommonFilters.convert_params_to_filter(source, where_params, opts)

      Select.build_query(:select, source, inner_query, {:as, nil}, select_term, opts)
    else
      Logger.warning(
        @logger_prefix,
        "Expected a map or keyword list, got: #{inspect(params)}"
      )

      params
    end
  end

  defp quantified_select_field(_source, field_name, _outer_key, _opts) when is_atom(field_name),
    do: field_name

  defp quantified_select_field(source, field_name, outer_key, opts) when is_binary(field_name) do
    Normalizer.normalize_field_name(source, field_name, opts) || outer_key
  end

  defp quantified_select_field(source, field_name, outer_key, opts)
       when is_map(field_name) and not is_struct(field_name) do
    quantified_select_field(source, Map.to_list(field_name), outer_key, opts)
  end

  defp quantified_select_field(source, field_name, outer_key, opts) when is_list(field_name) do
    if Keyword.keyword?(field_name) do
      quantified_select_field(source, Keyword.fetch!(field_name, :field), outer_key, opts)
    else
      field_name
    end
  end
end
