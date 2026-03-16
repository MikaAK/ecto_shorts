defmodule EctoShorts.CommonFilters.Update do
  @moduledoc false

  alias EctoShorts.QueryBinding

  alias Ecto.Query
  require Ecto.Query

  def build_query(:update, source, query, selected_binding, map, opts)
      when is_map(map) and not is_struct(map) do
    build_query(:update, source, query, selected_binding, Map.to_list(map), opts)
  end

  def build_query(:update, _source, query, selected_binding, term, _opts) do
    apply_update_expr(query, selected_binding, term)
  end

  {_, binding_patterns} = QueryBinding.query_binding_contracts(__MODULE__)

  for {quoted_binding_head, quoted_binding_body} <- binding_patterns do
    defp apply_update_expr(query, unquote(quoted_binding_head), expr) do
      Query.update(query, [unquote_splicing(quoted_binding_body)], ^expr)
    end
  end

  defp apply_update_expr(query, _selected_binding, expr) do
    Query.update(query, ^expr)
  end
end
