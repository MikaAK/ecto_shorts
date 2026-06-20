defmodule EctoShorts.CommonFilters.Update do
  @moduledoc since: "3.0.0"
  @moduledoc false

  alias EctoShorts.CommonFilters.UpdateExpr
  alias EctoShorts.QueryBinding

  alias Ecto.Query
  require Ecto.Query

  def build_query(:update, _source, query, _selected_binding, nil, _opts), do: query

  def build_query(:update, source, query, selected_binding, map, opts)
      when is_map(map) and not is_struct(map) do
    build_query(:update, source, query, selected_binding, Map.to_list(map), opts)
  end

  def build_query(:update, source, query, selected_binding, term, _opts) do
    expr =
      if Keyword.keyword?(term) do
        UpdateExpr.build_update_expr(source, term)
      else
        term
      end

    update_expr(query, selected_binding, expr)
  end

  ## Generated Functions

  {_, binding_patterns} = QueryBinding.query_binding_contracts(__MODULE__)

  for {quoted_binding_head, quoted_binding_body} <- binding_patterns do
    defp update_expr(query, unquote(quoted_binding_head), expr) do
      Query.update(query, [unquote_splicing(quoted_binding_body)], ^expr)
    end
  end
end
