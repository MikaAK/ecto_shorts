defmodule EctoShorts.DynamicBuilders.Postgres.CommonExpr do
  @moduledoc since: "3.0.0"
  @moduledoc false

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
          field,
          negated,
          expr,
          _opts
        ) do
      {operator, term} = expr

      selected_binding
      |> dispatch_expr(operator, field, term)
      |> maybe_negate(negated)
    end

    defp field_dyn(unquote(quoted_binding_head), field_name) do
      Query.dynamic(
        [unquote_splicing(quoted_binding_body)],
        field(unquote(target_binding_var), ^field_name)
      )
    end
  end

  def dynamic_expr(_selected_binding, _field, _negated, _expr, _opts), do: nil

  defp dispatch_expr(binding, :ids, field, term) do
    dyn = field_dyn(binding, field)
    Query.dynamic([], ^dyn in ^term)
  end

  defp dispatch_expr(binding, :after, field, term) do
    dyn = field_dyn(binding, field)
    Query.dynamic([], ^dyn > ^term)
  end

  defp dispatch_expr(binding, :before, field, term) do
    dyn = field_dyn(binding, field)
    Query.dynamic([], ^dyn < ^term)
  end

  defp dispatch_expr(binding, :since, field, term) do
    dyn = field_dyn(binding, field)
    Query.dynamic([], ^dyn >= ^term)
  end

  defp dispatch_expr(binding, :until, field, term) do
    dyn = field_dyn(binding, field)
    Query.dynamic([], ^dyn <= ^term)
  end

  defp dispatch_expr(binding, operator, field, term) when operator in [:start_date, :since_date] do
    dyn = field_dyn(binding, field)
    Query.dynamic([], ^dyn >= ^term)
  end

  defp dispatch_expr(binding, operator, field, term) when operator in [:end_date, :until_date] do
    dyn = field_dyn(binding, field)
    Query.dynamic([], ^dyn <= ^term)
  end

  defp dispatch_expr(_binding, :exists, _field, term) do
    Query.dynamic([], exists(term))
  end

  defp dispatch_expr(_binding, _operator, _field, _term), do: nil

  defp maybe_negate(nil, _negated), do: nil
  defp maybe_negate(expr, :not), do: Query.dynamic([], not (^expr))
  defp maybe_negate(expr, _negated), do: expr
end
