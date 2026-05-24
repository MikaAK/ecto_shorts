defmodule EctoShorts.CommonFilters.Limit do
  @moduledoc since: "3.0.0"
  @moduledoc false

  alias EctoShorts.QueryBinding
  alias EctoShorts.Types

  alias Ecto.Query
  require Ecto.Query

  def build_query(:limit, _source, query, selected_binding, expr, _opts) do
    apply_limit(query, selected_binding, Types.cast(:integer, expr))
  end

  ## Generated Functions

  {_, binding_patterns} = QueryBinding.query_binding_contracts(__MODULE__)

  for {quoted_binding_head, quoted_binding_body} <- binding_patterns do
    defp apply_limit(query, unquote(quoted_binding_head), expr) do
      Query.limit(query, [unquote_splicing(quoted_binding_body)], ^expr)
    end
  end

  defp apply_limit(query, _selected_binding, expr) do
    Query.limit(query, ^expr)
  end
end
