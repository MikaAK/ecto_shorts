defmodule EctoShorts.CommonFilters.SubQuery do
  @moduledoc since: "3.0.0"
  @moduledoc false

  alias EctoShorts.CommonFilters

  alias Ecto.Query
  require Ecto.Query

  @logger_prefix "EctoShorts.CommonFilters.SubQuery"

  def build_query(:subquery, _source, query, _selected_binding, params, opts) do
    if (is_map(params) and not is_struct(params)) or Keyword.keyword?(params) do
      query
      |> CommonFilters.convert_params_to_filter(params, opts)
      |> Query.subquery()
    else
      EctoShorts.LogUtils.warning(
        @logger_prefix,
        "Expected :subquery value to be a keyword list or map of filter params, got: #{inspect(params)}"
      )

      query
    end
  end
end
