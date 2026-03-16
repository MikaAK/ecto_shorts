defmodule EctoShorts.CommonFilters.OrderBy do
  @moduledoc false

  alias EctoShorts.QueryBinding
  alias EctoShorts.Logger

  alias Ecto.Query
  require Ecto.Query

  @directions [
    :asc,
    :asc_nulls_last,
    :asc_nulls_first,
    :desc,
    :desc_nulls_last,
    :desc_nulls_first
  ]

  @logger_prefix "EctoShorts.CommonFilters.OrderBy"

  {target_binding_var, binding_patterns} = QueryBinding.query_binding_contracts(__MODULE__)

  def build_query(:order_by, _source, query, selected_binding, params, _opts) do
    build_order_by(query, selected_binding, params)
  end

  def build_query(:prepend_order_by, _source, query, selected_binding, params, _opts) do
    build_prepend_order_by(query, selected_binding, params)
  end

  def build_query(:reverse_order, _source, query, _selected_binding, value, _opts) do
    case value do
      true ->
        Query.reverse_order(query)

      term ->
        Logger.warning(
          @logger_prefix,
          "Expected :reverse_order value to be true, got: #{inspect(term)}"
        )

        query
    end
  end

  for {quoted_binding_head, quoted_binding_body} <- binding_patterns do
    defp field_dyn(unquote(quoted_binding_head), field_name) do
      Query.dynamic(
        [unquote_splicing(quoted_binding_body)],
        field(unquote(target_binding_var), ^field_name)
      )
    end
  end

  defp build_order_by(query, selected_binding, field_name) when is_atom(field_name) do
    Query.order_by(query, ^[desc: field_dyn(selected_binding, field_name)])
  end

  defp build_order_by(query, selected_binding, {dir, field_name})
       when dir in @directions and is_atom(field_name) do
    Query.order_by(query, ^[{dir, field_dyn(selected_binding, field_name)}])
  end

  defp build_order_by(query, selected_binding, entries) when is_list(entries) do
    Query.order_by(query, ^build_order_exprs(selected_binding, entries))
  end

  defp build_order_by(query, _selected_binding, expr) do
    Query.order_by(query, ^expr)
  end

  defp build_prepend_order_by(query, selected_binding, field_name) when is_atom(field_name) do
    Query.prepend_order_by(query, ^[desc: field_dyn(selected_binding, field_name)])
  end

  defp build_prepend_order_by(query, selected_binding, {dir, field_name})
       when dir in @directions and is_atom(field_name) do
    Query.prepend_order_by(query, ^[{dir, field_dyn(selected_binding, field_name)}])
  end

  defp build_prepend_order_by(query, selected_binding, entries)
       when is_list(entries) do
    Query.prepend_order_by(query, ^build_order_exprs(selected_binding, entries))
  end

  defp build_prepend_order_by(query, _selected_binding, expr) do
    Query.prepend_order_by(query, ^expr)
  end

  defp build_order_exprs(selected_binding, entries) do
    Enum.map(entries, fn
      {dir, field_name} when dir in @directions and is_atom(field_name) ->
        {dir, field_dyn(selected_binding, field_name)}

      field_name when is_atom(field_name) ->
        {:desc, field_dyn(selected_binding, field_name)}

      %Ecto.Query.DynamicExpr{} = dynamic_expr ->
        dynamic_expr

      other ->
        other
    end)
  end
end
