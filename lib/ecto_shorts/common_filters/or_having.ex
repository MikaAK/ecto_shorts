defmodule EctoShorts.CommonFilters.OrHaving do
  @moduledoc since: "3.0.0"
  @moduledoc false

  alias EctoShorts.CommonQuery
  alias EctoShorts.DynamicBuilders
  alias EctoShorts.QueryBinding

  alias Ecto.Query
  require Ecto.Query

  def build_query(:or_having, _source, query, _selected_binding, nil, _opts) do
    query
  end

  def build_query(:or_having, source, query, selected_binding, term, opts) do
    case build_dynamic(source, query, selected_binding, term, opts) do
      nil -> query
      dyn -> or_having_expr(query, selected_binding, dyn)
    end
  end

  defp build_dynamic(source, query, selected_binding, term, opts) do
    if is_struct(term, Ecto.Query.DynamicExpr) do
      term
    else
      source
      |> resolve_source(query, selected_binding)
      |> DynamicBuilders.build_dynamic(selected_binding, term, opts)
    end
  end

  defp resolve_source(source, _query, {:as, nil}), do: source

  defp resolve_source(source, query, {:as, name}) when is_atom(name) do
    CommonQuery.get_query_binding_source(query, name) || source
  end

  defp resolve_source(source, query, {:at, pos}) when is_integer(pos) do
    CommonQuery.get_query_binding_source(query, pos) || source
  end

  defp resolve_source(source, _query, _selected_binding), do: source

  ## Generated Functions

  {_, binding_patterns} = QueryBinding.query_binding_contracts(__MODULE__)

  for {quoted_binding_head, quoted_binding_body} <- binding_patterns do
    defp or_having_expr(query, unquote(quoted_binding_head), dyn) do
      Query.or_having(
        query,
        [unquote_splicing(quoted_binding_body)],
        ^dyn
      )
    end
  end

  defp or_having_expr(query, _selected_binding, dyn) do
    Query.or_having(query, ^dyn)
  end
end
