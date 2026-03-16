defmodule EctoShorts.CommonFilters.Having do
  alias EctoShorts.DynamicBuilders
  alias EctoShorts.QueryBinding

  alias Ecto.Query
  require Ecto.Query

  {_, binding_patterns} = QueryBinding.query_binding_contracts(__MODULE__)

  def build_query(filter, _source, query, _selected_binding, nil, _opts)
      when filter in [:having, :or_having] do
    query
  end

  def build_query(:having, source, query, selected_binding, term, opts) do
    dyn = build_dynamic(source, selected_binding, term, opts)
    build_having(query, selected_binding, dyn)
  end

  def build_query(:or_having, source, query, selected_binding, term, opts) do
    dyn = build_dynamic(source, selected_binding, term, opts)
    build_or_having(query, selected_binding, dyn)
  end

  defp build_dynamic(source, selected_binding, term, opts) do
    if is_struct(term, Ecto.Query.DynamicExpr) do
      term
    else
      DynamicBuilders.build_dynamic(
        source,
        selected_binding,
        term,
        opts
      )
    end
  end

  for {quoted_binding_head, quoted_binding_body} <- binding_patterns do
    defp build_having(query, unquote(quoted_binding_head), dyn) do
      Query.having(
        query,
        [unquote_splicing(quoted_binding_body)],
        ^dyn
      )
    end
  end

  defp build_having(query, _selected_binding, dyn) do
    Query.having(query, ^dyn)
  end

  for {quoted_binding_head, quoted_binding_body} <- binding_patterns do
    defp build_or_having(query, unquote(quoted_binding_head), dyn) do
      Query.or_having(
        query,
        [unquote_splicing(quoted_binding_body)],
        ^dyn
      )
    end
  end

  defp build_or_having(query, _selected_binding, dyn) do
    Query.or_having(query, ^dyn)
  end
end
