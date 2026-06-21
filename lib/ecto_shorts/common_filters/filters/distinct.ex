defmodule EctoShorts.CommonFilters.Distinct do
  @moduledoc since: "3.0.0"
  @moduledoc """
  Implements the `:distinct` structural filter for `EctoShorts.CommonFilters`.

  Adds a `DISTINCT ON` clause to the query. Accepts `true` (plain DISTINCT), a
  field atom, a list of `{direction, field}` tuples, or an
  a dynamic expression. Used via params, not called directly:

      EctoShorts.Actions.all(Post, %{distinct: true})
      EctoShorts.Actions.all(Post, %{distinct: :title})
      EctoShorts.Actions.all(Post, %{distinct: [asc: :inserted_at, asc: :id]})

  See `EctoShorts.QueryBuilder` for the `build_query/6` callback contract.
  """

  alias EctoShorts.CommonQuery
  alias EctoShorts.CommonSchema
  alias EctoShorts.LogUtils
  alias EctoShorts.QueryBinding
  alias EctoShorts.Types

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

  @logger_prefix "EctoShorts.CommonFilters.Distinct"

  {target_binding_var, binding_patterns} =
    QueryBinding.query_binding_contracts(__MODULE__)

  def build_query(:distinct, source, query, selected_binding, params, _opts) do
    build_distinct(source, query, selected_binding, Types.cast(:boolean, params))
  end

  defp build_distinct(_source, query, _selected_binding, expr) when is_boolean(expr) do
    Query.distinct(query, ^expr)
  end

  for {quoted_binding_head, quoted_binding_body} <- binding_patterns do
    defp dynamic_field_expr(unquote(quoted_binding_head), field_name) do
      Query.dynamic(
        [unquote_splicing(quoted_binding_body)],
        field(unquote(target_binding_var), ^field_name)
      )
    end
  end

  defp build_distinct(source, query, selected_binding, field_name)
       when is_atom(field_name) do
    case validate_schema_field(source, query, selected_binding, field_name) do
      {:error, _} ->
        query

      {:ok, field_name} ->
        Query.distinct(query, ^[asc: dynamic_field_expr(selected_binding, field_name)])
    end
  end

  defp build_distinct(source, query, selected_binding, entries) when is_list(entries) do
    exprs = build_distinct_exprs(source, query, selected_binding, entries)

    if entries !== [] and exprs === [] do
      query
    else
      Query.distinct(query, ^exprs)
    end
  end

  defp build_distinct(_source, query, _selected_binding, %Ecto.Query.DynamicExpr{} = expr) do
    Query.distinct(query, ^expr)
  end

  defp build_distinct(_source, query, _selected_binding, expr) do
    LogUtils.warning(
      @logger_prefix,
      "Expected :distinct to be a boolean, field atom, list of fields, or DynamicExpr, got: #{inspect(expr)}"
    )

    query
  end

  defp build_distinct_exprs(source, query, selected_binding, entries) do
    exprs =
      Enum.reduce(entries, [], fn
        {dir, field_name}, acc when dir in @order_directions and is_atom(field_name) ->
          case validate_schema_field(source, query, selected_binding, field_name) do
            {:error, _} -> acc
            {:ok, field_name} -> [{dir, dynamic_field_expr(selected_binding, field_name)} | acc]
          end

        field_name, acc when is_atom(field_name) ->
          case validate_schema_field(source, query, selected_binding, field_name) do
            {:error, _} -> acc
            {:ok, field_name} -> [{:asc, dynamic_field_expr(selected_binding, field_name)} | acc]
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
      LogUtils.warning(
        @logger_prefix,
        "Field \"#{field_name}\" does not exist on schema #{inspect(CommonSchema.get_schema(effective_source))}, skipping field reference"
      )

      {:error, :unknown_field}
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
end
