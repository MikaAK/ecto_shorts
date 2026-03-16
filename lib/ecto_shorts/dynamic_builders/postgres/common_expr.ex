defmodule EctoShorts.DynamicBuilders.Postgres.CommonExpr do
  alias Ecto.Query
  alias EctoShorts.QueryBinding

  require Ecto.Query

  @operators [
    :ids,
    :before,
    :after,
    :until,
    :since,
    :exists,
    :start_date,
    :end_date,
    :since_date,
    :until_date
  ]

  def operators, do: @operators

  {target_binding_var, binding_patterns} = QueryBinding.query_binding_contracts(__MODULE__)

  for {quoted_binding_head, quoted_binding_body} <- binding_patterns do
    def dynamic_expr(
          unquote(quoted_binding_head) = selected_binding,
          operator,
          negated,
          term,
          _opts
        ) do
      selected_binding
      |> dispatch_expr(operator, term)
      |> maybe_negate(negated)
    end

    defp field_dyn(unquote(quoted_binding_head), field_name) do
      Query.dynamic(
        [unquote_splicing(quoted_binding_body)],
        field(unquote(target_binding_var), ^field_name)
      )
    end
  end

  def dynamic_expr(_selected_binding, _operator, _negated, _term, _opts), do: nil

  defp dispatch_expr(binding, :ids, term) do
    dyn = field_dyn(binding, :id)
    Query.dynamic([], ^dyn in ^term)
  end

  defp dispatch_expr(binding, :after, term) do
    dyn = field_dyn(binding, :id)
    Query.dynamic([], ^dyn > ^term)
  end

  defp dispatch_expr(binding, :before, term) do
    dyn = field_dyn(binding, :id)
    Query.dynamic([], ^dyn < ^term)
  end

  defp dispatch_expr(binding, :since, term) do
    dyn = field_dyn(binding, :id)
    Query.dynamic([], ^dyn >= ^term)
  end

  defp dispatch_expr(binding, :until, term) do
    dyn = field_dyn(binding, :id)
    Query.dynamic([], ^dyn <= ^term)
  end

  defp dispatch_expr(binding, operator, term) when operator in [:start_date, :since_date] do
    dyn = field_dyn(binding, :inserted_at)
    Query.dynamic([], ^dyn >= ^term)
  end

  defp dispatch_expr(binding, operator, term) when operator in [:end_date, :until_date] do
    dyn = field_dyn(binding, :inserted_at)
    Query.dynamic([], ^dyn <= ^term)
  end

  defp dispatch_expr(_binding, :exists, term) do
    Query.dynamic([], exists(term))
  end

  defp dispatch_expr(_binding, _operator, _term), do: nil

  defp maybe_negate(nil, _negated), do: nil
  defp maybe_negate(expr, :not), do: Query.dynamic([], not (^expr))
  defp maybe_negate(expr, _negated), do: expr
end
