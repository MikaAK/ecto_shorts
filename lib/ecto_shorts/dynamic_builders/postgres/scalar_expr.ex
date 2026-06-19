defmodule EctoShorts.DynamicBuilders.Postgres.ScalarExpr do
  @moduledoc since: "3.0.0"
  @moduledoc false

  alias EctoShorts.DynamicBuilders.Postgres.FieldAccessors
  alias EctoShorts.DynamicBuilders.Postgres.ScalarExpr.{Comparison, Membership, String, StringTransform}

  @operators [:membership, :comparison, :string_transform, :string]
  @comparison_operators [:>, :>=, :<, :<=, :==, :!=]
  @equality_operators [:==, :!=]
  @string_operators [:like, :ilike]
  @string_transforms [:lower, :upper, :trim, :ltrim, :rtrim]

  def operators, do: @operators

  def dynamic_expr(selected_binding, key, negated, term, _opts) do
    if FieldAccessors.known_binding?(selected_binding) do
      dispatch_expr(selected_binding, key, negated, term)
    else
      nil
    end
  end

  # ── Non-generated dispatch: compiled once regardless of binding count ──────

  defp dispatch_expr(binding, key, negated, {op, value}) do
    case family_for(op, value) do
      :membership -> Membership.build(binding, key, negated, {op, value})
      :string_transform -> StringTransform.build(binding, key, negated, {op, value})
      :string -> String.build(binding, key, negated, {op, value})
      :comparison -> Comparison.build(binding, key, negated, {op, value})
    end
  end

  defp family_for(:in, _term), do: :membership
  defp family_for(:nin, _term), do: :membership

  defp family_for(op, value) when op in @equality_operators and is_list(value) do
    :membership
  end

  defp family_for(op, {transform, _term})
       when op in @comparison_operators and transform in @string_transforms do
    :string_transform
  end

  defp family_for(op, term) when op in @string_operators do
    case term do
      {transform, _term} when transform in @string_transforms ->
        :string_transform

      _ ->
        :string
    end
  end

  defp family_for(_op, _term), do: :comparison

end
