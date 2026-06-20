defmodule EctoShorts.CommonFilters.OrHaving do
  @moduledoc since: "3.0.0"
  @moduledoc """
  Implements the `:or_having` structural filter for `EctoShorts.CommonFilters`.

  Adds an `OR HAVING` clause to the query, combining with any existing `HAVING`
  conditions using `OR`. Accepts a `{field, op_map}` tuple, an
  a dynamic expression, or `nil` (no-op). Automatically adds a `GROUP BY`
  on the primary key when none is present. Used via params, not called directly:

      EctoShorts.Actions.all(Post, %{or_having: {:comment_count, %{gte: 5}}})

  See `EctoShorts.QueryBuilder` for the `build_query/6` callback contract.
  """

  alias EctoShorts.CommonQuery
  alias EctoShorts.CommonFilters.Builder
  alias EctoShorts.LogUtils

  @logger_prefix "EctoShorts.CommonFilters.OrHaving"

  def build_query(:or_having, _source, query, _selected_binding, nil, _opts) do
    query
  end

  def build_query(:or_having, _source, query, selected_binding, %Ecto.Query.DynamicExpr{} = dyn, opts) do
    Builder.place_or_having(query, [dyn], selected_binding, opts)
  end

  def build_query(:or_having, source, query, selected_binding, {key, value}, opts) do
    effective_source = resolve_source(source, query, selected_binding)
    Builder.or_having_from_params(query, effective_source, key, value, selected_binding, opts)
  end

  def build_query(:or_having, _source, query, _selected_binding, term, _opts) do
    LogUtils.warning(
      @logger_prefix,
      "Expected :or_having value to be a {field, op} tuple, DynamicExpr, or nil, got: #{inspect(term)}"
    )

    query
  end

  defp resolve_source(source, _query, {:as, nil}), do: source

  defp resolve_source(source, query, {:as, name}) when is_atom(name) do
    CommonQuery.get_query_binding_source(query, name) || source
  end

  defp resolve_source(source, query, {:at, pos}) when is_integer(pos) do
    CommonQuery.get_query_binding_source(query, pos) || source
  end
end
