defmodule EctoShorts.CommonFilters.Having do
  @moduledoc since: "3.0.0"
  @moduledoc """
  Implements the `:having` structural filter for `EctoShorts.CommonFilters`.

  Adds a `HAVING` clause to the query for filtering on aggregate values. Accepts
  a `{field, op_map}` tuple, a dynamic expression, or `nil` (no-op).
  Automatically adds a `GROUP BY` on the primary key when none is already
  present. Used via params, not called directly:

      EctoShorts.Actions.all(Post, %{having: %{comment_count: %{gte: 5}}})

  See `EctoShorts.QueryBuilder` for the `build_query/6` callback contract.
  """

  alias EctoShorts.CommonQuery
  alias EctoShorts.CommonFilters.Builder
  alias EctoShorts.LogUtils

  @logger_prefix "EctoShorts.CommonFilters.Having"

  def build_query(:having, _source, query, _selected_binding, nil, _opts) do
    query
  end

  def build_query(:having, _source, query, selected_binding, %Ecto.Query.DynamicExpr{} = dyn, opts) do
    Builder.place_having(query, [dyn], selected_binding, opts)
  end

  def build_query(:having, source, query, selected_binding, {key, value}, opts) do
    effective_source = resolve_source(source, query, selected_binding)
    Builder.having_from_params(query, effective_source, key, value, selected_binding, opts)
  end

  def build_query(:having, _source, query, _selected_binding, term, _opts) do
    LogUtils.warning(
      @logger_prefix,
      "Expected :having value to be a {field, op} tuple, DynamicExpr, or nil, got: #{inspect(term)}"
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
