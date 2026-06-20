defmodule EctoShorts.DynamicBuilders.Postgres.ScalarExpr.StringTransform do
  @moduledoc """
  Builds dynamic expressions that apply a SQL string transform to a field before
  an equality comparison.

  Supports `:lower`, `:upper`, `:trim`, `:ltrim`, and `:rtrim` applied to the
  field, then compared with `==` / `!=` — useful for case-insensitive or
  whitespace-normalized equality checks. This module is part of the
  `Ecto.Adapters.Postgres` dynamic-builder pipeline (the only adapter that
  ships) and is reached via `EctoShorts.CommonFilters` params, for example:

      EctoShorts.Actions.all(User, %{email: %{==: %{lower: "ada@example.com"}}})

  rather than being called directly.
  """
  @moduledoc since: "3.0.0"

  alias EctoShorts.DynamicBuilders.Postgres.FieldAccessors

  import Ecto.Query

  def build(binding, key, negated, {op, value}) do
    term = if negated === :not, do: {:not, {op, value}}, else: {op, value}

    case term do
      {:not, {:==, {:lower, v}}} ->
        f = lower_field_dyn(binding, key)
        dynamic([], ^f != ^v)

      {:==, {:lower, v}} ->
        f = lower_field_dyn(binding, key)
        dynamic([], ^f == ^v)

      {:not, {:!=, {:lower, v}}} ->
        f = lower_field_dyn(binding, key)
        dynamic([], ^f == ^v)

      {:!=, {:lower, v}} ->
        f = lower_field_dyn(binding, key)
        dynamic([], ^f != ^v)

      {:not, {:==, {:upper, v}}} ->
        f = upper_field_dyn(binding, key)
        dynamic([], ^f != ^v)

      {:==, {:upper, v}} ->
        f = upper_field_dyn(binding, key)
        dynamic([], ^f == ^v)

      {:not, {:!=, {:upper, v}}} ->
        f = upper_field_dyn(binding, key)
        dynamic([], ^f == ^v)

      {:!=, {:upper, v}} ->
        f = upper_field_dyn(binding, key)
        dynamic([], ^f != ^v)

      {:not, {:==, {transform, v}}} when transform in [:trim, :ltrim, :rtrim] ->
        f = transform_field_dyn(binding, key, transform)
        dynamic([], ^f != ^v)

      {:==, {transform, v}} when transform in [:trim, :ltrim, :rtrim] ->
        f = transform_field_dyn(binding, key, transform)
        dynamic([], ^f == ^v)

      {:not, {:!=, {transform, v}}} when transform in [:trim, :ltrim, :rtrim] ->
        f = transform_field_dyn(binding, key, transform)
        dynamic([], ^f == ^v)

      {:!=, {transform, v}} when transform in [:trim, :ltrim, :rtrim] ->
        f = transform_field_dyn(binding, key, transform)
        dynamic([], ^f != ^v)

      _ ->
        nil
    end
  end

  defp transform_field_dyn(binding, key, :trim), do: trim_field_dyn(binding, key)
  defp transform_field_dyn(binding, key, :ltrim), do: ltrim_field_dyn(binding, key)
  defp transform_field_dyn(binding, key, :rtrim), do: rtrim_field_dyn(binding, key)

  defp lower_field_dyn(binding, key) do
    f = FieldAccessors.field_dyn(binding, key)
    dynamic([], fragment("lower(?)", ^f))
  end

  defp upper_field_dyn(binding, key) do
    f = FieldAccessors.field_dyn(binding, key)
    dynamic([], fragment("upper(?)", ^f))
  end

  defp trim_field_dyn(binding, key) do
    f = FieldAccessors.field_dyn(binding, key)
    dynamic([], fragment("trim(?)", ^f))
  end

  defp ltrim_field_dyn(binding, key) do
    f = FieldAccessors.field_dyn(binding, key)
    dynamic([], fragment("ltrim(?)", ^f))
  end

  defp rtrim_field_dyn(binding, key) do
    f = FieldAccessors.field_dyn(binding, key)
    dynamic([], fragment("rtrim(?)", ^f))
  end
end
