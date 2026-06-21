defmodule EctoShorts.CommonFilters.OrderBy do
  @moduledoc since: "3.0.0"
  @moduledoc """
  Implements the `:order_by` structural filter for `EctoShorts.CommonFilters`.

  Sets the `ORDER BY` clause on the query (replacing any existing order).
  Accepts a field atom (defaults to `:asc`), a `{direction, field}` tuple, a
  list of such atoms or tuples, a dynamic expression, or a map that is
  converted to a keyword list. Direction atoms: `:asc`, `:desc`,
  `:asc_nulls_last`, `:asc_nulls_first`, `:desc_nulls_last`, `:desc_nulls_first`.
  Unknown schema fields are skipped with a warning. Used via params, not called directly:

      EctoShorts.Actions.all(Post, %{order_by: :inserted_at})
      EctoShorts.Actions.all(Post, %{order_by: {:desc, :inserted_at}})
      EctoShorts.Actions.all(Post, %{order_by: [asc: :title, desc: :inserted_at]})

  See `EctoShorts.QueryBuilder` for the `build_query/6` callback contract.
  """

  alias EctoShorts.CommonQuery
  alias EctoShorts.CommonSchema
  alias EctoShorts.LogUtils
  alias EctoShorts.QueryBinding

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

  def build_query(:order_by, source, query, selected_binding, params, opts)
      when is_map(params) and not is_struct(params) do
    build_query(:order_by, source, query, selected_binding, Map.to_list(params), opts)
  end

  def build_query(:order_by, source, query, selected_binding, field_name, opts)
      when is_atom(field_name) do
    build_query(:order_by, source, query, selected_binding, [field_name], opts)
  end

  def build_query(:order_by, source, query, selected_binding, {dir, _} = entry, opts)
      when dir in @directions do
    build_query(:order_by, source, query, selected_binding, [entry], opts)
  end

  def build_query(:order_by, source, query, selected_binding, entries, _opts)
      when is_list(entries) do
    exprs =
      Enum.flat_map(entries, fn
        {dir, field_name} when dir in @directions and is_atom(field_name) ->
          case validate_schema_field(source, query, selected_binding, field_name) do
            {:error, _} -> []
            {:ok, field_name} -> [{dir, dynamic_field_expr(selected_binding, field_name)}]
          end

        field_name when is_atom(field_name) ->
          case validate_schema_field(source, query, selected_binding, field_name) do
            {:error, _} -> []
            {:ok, field_name} -> [{:asc, dynamic_field_expr(selected_binding, field_name)}]
          end

        %Ecto.Query.DynamicExpr{} = dynamic_expr ->
          [dynamic_expr]

        other ->
          [other]
      end)

    if entries !== [] and exprs === [], do: query, else: order_by_expr(query, exprs)
  end

  def build_query(:order_by, _source, query, _selected_binding, %Ecto.Query.DynamicExpr{} = expr, _opts) do
    order_by_expr(query, expr)
  end

  def build_query(:order_by, _source, query, _selected_binding, expr, _opts) do
    LogUtils.warning(
      @logger_prefix,
      "Expected :order_by to be an atom, direction tuple, list of fields, or DynamicExpr, got: #{inspect(expr)}"
    )

    query
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

  defp order_by_expr(query, exprs), do: Query.order_by(query, ^exprs)

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
