defmodule EctoShorts.CommonFilters.Distinct do
  @moduledoc false

  alias EctoShorts.QueryBinding
  alias Ecto.Query

  require Ecto.Query

  @order_directions [
    :asc,
    :asc_nulls_last,
    :asc_nulls_first,
    :desc,
    :desc_nulls_last,
    :desc_nulls_first
  ]

  {target_binding_var, binding_patterns} =
    QueryBinding.query_binding_contracts(__MODULE__)

  def build_query(:distinct, _source, query, selected_binding, params, _opts) do
    build_distinct(query, selected_binding, params)
  end

  defp build_distinct(query, _selected_binding, expr) when is_boolean(expr) do
    Query.distinct(query, ^expr)
  end

  for {quoted_binding_head, quoted_binding_body} <- binding_patterns do
    defp field_dyn(unquote(quoted_binding_head), field_name) do
      Query.dynamic(
        [unquote_splicing(quoted_binding_body)],
        field(unquote(target_binding_var), ^field_name)
      )
    end
  end

  defp build_distinct(query, selected_binding, field_name)
       when is_atom(field_name) do
    Query.distinct(query, ^[asc: field_dyn(selected_binding, field_name)])
  end

  defp build_distinct(query, selected_binding, entries) when is_list(entries) do
    Query.distinct(query, ^build_distinct_exprs(selected_binding, entries))
  end

  defp build_distinct(query, _selected_binding, expr) do
    Query.distinct(query, ^expr)
  end

  defp build_distinct_exprs(selected_binding, entries) do
    Enum.map(entries, fn
      {dir, field_name} when dir in @order_directions and is_atom(field_name) ->
        {dir, field_dyn(selected_binding, field_name)}

      field_name when is_atom(field_name) ->
        {:asc, field_dyn(selected_binding, field_name)}

      %Ecto.Query.DynamicExpr{} = dynamic_expr ->
        dynamic_expr

      other ->
        other
    end)
  end
end
