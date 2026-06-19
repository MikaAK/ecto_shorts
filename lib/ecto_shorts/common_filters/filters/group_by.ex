defmodule EctoShorts.CommonFilters.GroupBy do
  @moduledoc since: "3.0.0"
  @moduledoc false

  alias EctoShorts.CommonQuery
  alias EctoShorts.CommonSchema
  alias EctoShorts.QueryBinding

  alias Ecto.Query
  require Ecto.Query

  @logger_prefix "EctoShorts.CommonFilters.GroupBy"

  def build_query(:group_by, source, query, selected_binding, params, _opts) do
    reduce_params(source, query, selected_binding, params)
  end

  defp reduce_params(source, query, selected_binding, field_name)
       when is_atom(field_name) do
    case validate_schema_field(source, query, selected_binding, field_name) do
      :error ->
        query

      {:ok, field_name} ->
        Query.group_by(query, ^[dynamic_field_expr(selected_binding, field_name)])
    end
  end

  defp reduce_params(source, query, selected_binding, entries) when is_list(entries) do
    exprs = reduce_params_exprs(source, query, selected_binding, entries)

    if entries !== [] and exprs === [] do
      query
    else
      Query.group_by(query, ^exprs)
    end
  end

  defp reduce_params(_source, query, _selected_binding, expr) do
    Query.group_by(query, ^expr)
  end

  defp reduce_params_exprs(source, query, selected_binding, entries) do
    exprs =
      Enum.reduce(entries, [], fn
        field_name, acc when is_atom(field_name) ->
          case validate_schema_field(source, query, selected_binding, field_name) do
            :error -> acc
            {:ok, field_name} -> [dynamic_field_expr(selected_binding, field_name) | acc]
          end

        %Ecto.Query.DynamicExpr{} = dynamic_expr, acc ->
          [dynamic_expr | acc]

        other, acc ->
          [other | acc]
      end)

    Enum.reverse(exprs)
  end

  defp validate_schema_field(source, query, selected_binding, field_name) do
    effective_source = resolve_source(source, query, selected_binding)

    if schema_field?(effective_source, field_name) do
      {:ok, field_name}
    else
      EctoShorts.LogUtils.warning(
        @logger_prefix,
        "Field \"#{field_name}\" does not exist on schema #{inspect(CommonSchema.get_schema(effective_source))}, skipping field reference"
      )

      :error
    end
  end

  defp schema_field?(source, field_name) do
    case CommonSchema.get_schema_reflection(source, :fields) do
      fields when is_list(fields) -> field_name in fields
      _ -> true
    end
  end

  defp resolve_source(source, _query, {:as, nil}), do: source

  defp resolve_source(source, query, {:as, name}) when is_atom(name) do
    CommonQuery.get_query_binding_source(query, name) || source
  end

  defp resolve_source(source, query, {:at, pos}) when is_integer(pos) do
    CommonQuery.get_query_binding_source(query, pos) || source
  end

  ## Generated Functions

  {target_binding_var, binding_patterns} = QueryBinding.query_binding_contracts(__MODULE__)

  for {quoted_binding_head, quoted_binding_body} <- binding_patterns do
    defp dynamic_field_expr(unquote(quoted_binding_head), field_name) do
      Query.dynamic(
        [unquote_splicing(quoted_binding_body)],
        field(unquote(target_binding_var), ^field_name)
      )
    end
  end
end
