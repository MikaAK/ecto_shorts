defmodule EctoShorts.CommonFilters.Limit do
  alias Ecto.Query
  alias EctoShorts.QueryBinding

  require Ecto.Query

  {_, binding_patterns} =
    QueryBinding.query_binding_contracts(__MODULE__)

  def build_query(filter, _source, query, selected_binding, expr, _opts)
      when filter in [:first, :limit] do
    apply_limit(query, selected_binding, expr)
  end

  for {quoted_binding_head, quoted_binding_body} <- binding_patterns do
    defp apply_limit(query, unquote(quoted_binding_head), expr) do
      Query.limit(query, [unquote_splicing(quoted_binding_body)], ^expr)
    end
  end

  defp apply_limit(query, _selected_binding, expr) do
    Query.limit(query, ^expr)
  end
end
