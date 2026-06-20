defmodule EctoShorts.CommonFilters.SubQuery do
  @moduledoc since: "3.0.0"
  @moduledoc """
  Implements the `:subquery` structural filter for `EctoShorts.CommonFilters`.

  Converts the current query into an Ecto subquery (a terminal filter — it runs
  after other filters and changes the query's shape). Accepts a keyword list or
  map of additional filter params that are first applied via
  `EctoShorts.CommonFilters.convert_params_to_filter/3`, then the resulting
  query is wrapped with `Ecto.Query.subquery/1`. Used via params, not called
  directly:

      EctoShorts.Actions.all(Post, %{subquery: %{status: :published}})

  See `EctoShorts.QueryBuilder` for the `build_query/6` callback contract.
  """

  alias EctoShorts.CommonFilters
  alias EctoShorts.LogUtils

  alias Ecto.Query
  require Ecto.Query

  @logger_prefix "EctoShorts.CommonFilters.SubQuery"

  def build_query(:subquery, _source, query, _selected_binding, params, opts) do
    if (is_map(params) and not is_struct(params)) or Keyword.keyword?(params) do
      query
      |> CommonFilters.convert_params_to_filter(params, opts)
      |> Query.subquery()
    else
      LogUtils.warning(
        @logger_prefix,
        "Expected :subquery value to be a keyword list or map of filter params, got: #{inspect(params)}"
      )

      query
    end
  end
end
