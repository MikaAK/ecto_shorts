defmodule EctoShorts.CommonFilters.SubQuery do
  @moduledoc false

  alias EctoShorts.CommonFilters
  alias EctoShorts.Logger

  alias Ecto.Query
  require Ecto.Query

  @logger_prefix "EctoShorts.CommonFilters.SubQuery"

  def build_query(:subquery, source, query, selected_binding, map, opts)
      when is_map(map) and not is_struct(map) do
    build_query(:subquery, source, query, selected_binding, Map.to_list(map), opts)
  end

  def build_query(:subquery, _source, query, _selected_binding, params, opts) do
    if Keyword.keyword?(params) do
      query
      |> CommonFilters.convert_params_to_filter(params, opts)
      |> Query.subquery()
    else
      Logger.warning(
        @logger_prefix,
        "Expected :subquery value to be a keyword list or map of filter params, got: #{inspect(params)}"
      )

      query
    end
  end
end
