defmodule EctoShorts.CommonFilters.Offset do
  @moduledoc false

  alias Ecto.Query
  alias EctoShorts.QueryBinding

  require Ecto.Query

  def build_query(:offset, _source, query, selected_binding, expr, _opts) do
    apply_offset(query, selected_binding, expr)
  end

  {_, binding_patterns} = QueryBinding.query_binding_contracts(__MODULE__)

  for {quoted_binding_head, quoted_binding_body} <- binding_patterns do
    defp apply_offset(query, unquote(quoted_binding_head), expr) do
      Query.offset(query, [unquote_splicing(quoted_binding_body)], ^expr)
    end
  end

  defp apply_offset(query, _selected_binding, expr) do
    Query.offset(query, ^expr)
  end
end
