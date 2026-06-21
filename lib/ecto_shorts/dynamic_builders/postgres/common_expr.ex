defmodule EctoShorts.DynamicBuilders.Postgres.CommonExpr do
  @moduledoc since: "3.0.0"
  @moduledoc """
  Builds Postgres dynamic expressions for the temporal and range convenience
  operators.

  Covers `:ids`, `:before`, `:after`, `:until`, `:since`, `:start_date`,
  `:end_date`, `:since_date`, `:until_date`, and `:exists`, mapping them to
  `>`, `<`, `>=`, `<=`, `in`, and `exists()` SQL expressions. This module is
  part of the `Ecto.Adapters.Postgres` dynamic-builder pipeline (the only
  adapter that ships) and is reached via `EctoShorts.CommonFilters` params, for
  example:

      EctoShorts.Actions.all(Post, %{before: ~U[2024-01-01 00:00:00Z]})

  rather than being called directly.
  """

  alias Ecto.Query
  alias EctoShorts.DynamicBuilders.Postgres.FieldAccessors

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

  @doc """
  Returns the list of temporal/range operator keys this module handles.

      iex> EctoShorts.DynamicBuilders.Postgres.CommonExpr.operators()
      [:ids, :before, :after, :until, :since, :exists, :start_date, :end_date, :since_date, :until_date]
  """
  def operators, do: @operators

  def dynamic_expr(selected_binding, field, negated, expr, _opts) do
    if FieldAccessors.known_binding?(selected_binding) do
      {operator, term} = expr

      selected_binding
      |> dispatch_expr(operator, field, term)
      |> maybe_negate(negated)
    else
      nil
    end
  end

  defp dispatch_expr(binding, :ids, field, term) do
    dyn = FieldAccessors.field_dyn(binding, field)
    Query.dynamic([], ^dyn in ^term)
  end

  defp dispatch_expr(binding, :after, field, term) do
    dyn = FieldAccessors.field_dyn(binding, field)
    Query.dynamic([], ^dyn > ^term)
  end

  defp dispatch_expr(binding, :before, field, term) do
    dyn = FieldAccessors.field_dyn(binding, field)
    Query.dynamic([], ^dyn < ^term)
  end

  defp dispatch_expr(binding, :since, field, term) do
    dyn = FieldAccessors.field_dyn(binding, field)
    Query.dynamic([], ^dyn >= ^term)
  end

  defp dispatch_expr(binding, :until, field, term) do
    dyn = FieldAccessors.field_dyn(binding, field)
    Query.dynamic([], ^dyn <= ^term)
  end

  defp dispatch_expr(binding, operator, field, term) when operator in [:start_date, :since_date] do
    dyn = FieldAccessors.field_dyn(binding, field)
    Query.dynamic([], ^dyn >= ^term)
  end

  defp dispatch_expr(binding, operator, field, term) when operator in [:end_date, :until_date] do
    dyn = FieldAccessors.field_dyn(binding, field)
    Query.dynamic([], ^dyn <= ^term)
  end

  defp dispatch_expr(_binding, :exists, _field, nil), do: nil

  defp dispatch_expr(_binding, :exists, _field, term) do
    Query.dynamic([], exists(term))
  end

  defp dispatch_expr(_binding, _operator, _field, _term), do: nil

  defp maybe_negate(nil, _negated), do: nil
  defp maybe_negate(expr, :not), do: Query.dynamic([], not (^expr))
  defp maybe_negate(expr, _negated), do: expr
end
