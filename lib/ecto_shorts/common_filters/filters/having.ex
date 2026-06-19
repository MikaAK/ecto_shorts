defmodule EctoShorts.CommonFilters.Having do
  @moduledoc since: "3.0.0"
  @moduledoc false

  alias EctoShorts.CommonQuery
  alias EctoShorts.CommonFilters.Builder

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

  defp resolve_source(source, _query, {:as, nil}), do: source

  defp resolve_source(source, query, {:as, name}) when is_atom(name) do
    CommonQuery.get_query_binding_source(query, name) || source
  end

  defp resolve_source(source, query, {:at, pos}) when is_integer(pos) do
    CommonQuery.get_query_binding_source(query, pos) || source
  end
end
