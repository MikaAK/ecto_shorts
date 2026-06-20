defmodule EctoShorts.CommonFilters.IntersectAll do
  @moduledoc since: "3.0.0"
  @moduledoc false

  alias EctoShorts.{CommonFilters, LogUtils}

  alias Ecto.Query
  require Ecto.Query

  @logger_prefix "EctoShorts.CommonFilters.IntersectAll"

  def build_query(:intersect_all, _source, query, _selected_binding, nil, _opts), do: query

  def build_query(:intersect_all, _source, query, _selected_binding, term, _opts)
      when not is_map(term) and not is_list(term) do
    LogUtils.warning(@logger_prefix, "Expected :intersect_all to be an Ecto.Query, map, or keyword list, got: #{inspect(term)}")
    query
  end

  def build_query(:intersect_all, source, query, _selected_binding, term, opts) do
    source
    |> to_query(term, opts)
    |> intersect_all_expr(query)
  end

  defp to_query(_source, %Ecto.Query{} = query, _opts), do: query

  defp to_query(source, term, opts) do
    CommonFilters.convert_params_to_filter(source, term, opts)
  end

  defp intersect_all_expr(expr, query), do: Query.intersect_all(query, ^expr)
end
