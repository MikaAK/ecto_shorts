defmodule EctoShorts.CommonFilters.UnionAll do
  @moduledoc since: "3.0.0"
  @moduledoc """
  Implements the `:union_all` structural filter for `EctoShorts.CommonFilters`.

  Combines the current query with a second query using SQL `UNION ALL` (returns
  all rows from both queries, preserving duplicates). The value may be a
  pre-built `Ecto.Query`, a params map, or a keyword list converted via
  `EctoShorts.CommonFilters.convert_params_to_filter/3`. Used via params, not
  called directly:

      EctoShorts.Actions.all(Post, %{union_all: %{status: :archived}})

  See `EctoShorts.QueryBuilder` for the `build_query/6` callback contract.
  """

  alias EctoShorts.{CommonFilters, LogUtils}

  alias Ecto.Query
  require Ecto.Query

  @logger_prefix "EctoShorts.CommonFilters.UnionAll"

  def build_query(:union_all, _source, query, _selected_binding, nil, _opts), do: query

  def build_query(:union_all, _source, query, _selected_binding, term, _opts)
      when not is_map(term) and not is_list(term) do
    LogUtils.warning(@logger_prefix, "Expected :union_all to be an Ecto.Query, map, or keyword list, got: #{inspect(term)}")
    query
  end

  def build_query(:union_all, source, query, _selected_binding, term, opts) do
    source
    |> to_query(term, opts)
    |> union_all_expr(query)
  end

  defp to_query(_source, %Ecto.Query{} = query, _opts), do: query

  defp to_query(source, term, opts) do
    CommonFilters.convert_params_to_filter(source, term, opts)
  end

  defp union_all_expr(expr, query), do: Query.union_all(query, ^expr)
end
