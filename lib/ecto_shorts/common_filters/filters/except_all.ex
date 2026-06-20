defmodule EctoShorts.CommonFilters.ExceptAll do
  @moduledoc since: "3.0.0"
  @moduledoc """
  Implements the `:except_all` structural filter for `EctoShorts.CommonFilters`.

  Combines the current query with a second query using SQL `EXCEPT ALL` (returns
  all rows from the first query that are not in the second, preserving
  duplicates). The value may be a pre-built `Ecto.Query`, a params map, or a
  keyword list that is converted via `EctoShorts.CommonFilters.convert_params_to_filter/3`.
  Used via params, not called directly:

      EctoShorts.Actions.all(Post, %{except_all: %{status: :draft}})

  See `EctoShorts.QueryBuilder` for the `build_query/6` callback contract.
  """

  alias EctoShorts.{CommonFilters, LogUtils}

  alias Ecto.Query
  require Ecto.Query

  @logger_prefix "EctoShorts.CommonFilters.ExceptAll"

  def build_query(:except_all, _source, query, _selected_binding, nil, _opts), do: query

  def build_query(:except_all, _source, query, _selected_binding, term, _opts)
      when not is_map(term) and not is_list(term) do
    LogUtils.warning(@logger_prefix, "Expected :except_all to be an Ecto.Query, map, or keyword list, got: #{inspect(term)}")
    query
  end

  def build_query(:except_all, source, query, _selected_binding, term, opts) do
    source
    |> to_query(term, opts)
    |> except_all_expr(query)
  end

  defp to_query(_source, %Ecto.Query{} = query, _opts), do: query

  defp to_query(source, term, opts) do
    CommonFilters.convert_params_to_filter(source, term, opts)
  end

  defp except_all_expr(expr, query), do: Query.except_all(query, ^expr)
end
