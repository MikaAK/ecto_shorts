defmodule EctoShorts.DynamicBuilders.Postgres.ScalarExpr.Aggregate do
  @moduledoc false
  @moduledoc since: "3.0.0"

  alias EctoShorts.DynamicBuilders.Postgres.FieldAccessors

  import Ecto.Query

  @aggregate_helpers [:avg, :count, :max, :min, :sum]

  def build(binding, key, term) do
    aggregate_comparison(binding, key, term)
  end

  # Aggregate: nil checks
  defp aggregate_comparison(binding, key, {helper, {:==, nil}}) when helper in @aggregate_helpers do
    f = agg_field_dyn(binding, key, helper)
    dynamic([], is_nil(^f))
  end

  defp aggregate_comparison(binding, key, {:not, {helper, {:==, nil}}})
       when helper in @aggregate_helpers do
    f = agg_field_dyn(binding, key, helper)
    dynamic([], not is_nil(^f))
  end

  defp aggregate_comparison(binding, key, {helper, {:!=, nil}}) when helper in @aggregate_helpers do
    f = agg_field_dyn(binding, key, helper)
    dynamic([], not is_nil(^f))
  end

  defp aggregate_comparison(binding, key, {:not, {helper, {:!=, nil}}})
       when helper in @aggregate_helpers do
    f = agg_field_dyn(binding, key, helper)
    dynamic([], is_nil(^f))
  end

  # Aggregate: value comparisons
  defp aggregate_comparison(binding, key, {helper, {:==, v}}) when helper in @aggregate_helpers do
    f = agg_field_dyn(binding, key, helper)
    dynamic([], ^f == ^v)
  end

  defp aggregate_comparison(binding, key, {:not, {helper, {:==, v}}})
       when helper in @aggregate_helpers do
    f = agg_field_dyn(binding, key, helper)
    dynamic([], ^f != ^v)
  end

  defp aggregate_comparison(binding, key, {helper, {:!=, v}}) when helper in @aggregate_helpers do
    f = agg_field_dyn(binding, key, helper)
    dynamic([], ^f != ^v)
  end

  defp aggregate_comparison(binding, key, {:not, {helper, {:!=, v}}})
       when helper in @aggregate_helpers do
    f = agg_field_dyn(binding, key, helper)
    dynamic([], ^f == ^v)
  end

  defp aggregate_comparison(binding, key, {helper, {:>, v}}) when helper in @aggregate_helpers do
    f = agg_field_dyn(binding, key, helper)
    dynamic([], ^f > ^v)
  end

  defp aggregate_comparison(binding, key, {:not, {helper, {:>, v}}})
       when helper in @aggregate_helpers do
    f = agg_field_dyn(binding, key, helper)
    dynamic([], not (^f > ^v))
  end

  defp aggregate_comparison(binding, key, {helper, {:>=, v}}) when helper in @aggregate_helpers do
    f = agg_field_dyn(binding, key, helper)
    dynamic([], ^f >= ^v)
  end

  defp aggregate_comparison(binding, key, {:not, {helper, {:>=, v}}})
       when helper in @aggregate_helpers do
    f = agg_field_dyn(binding, key, helper)
    dynamic([], not (^f >= ^v))
  end

  defp aggregate_comparison(binding, key, {helper, {:<, v}}) when helper in @aggregate_helpers do
    f = agg_field_dyn(binding, key, helper)
    dynamic([], ^f < ^v)
  end

  defp aggregate_comparison(binding, key, {:not, {helper, {:<, v}}})
       when helper in @aggregate_helpers do
    f = agg_field_dyn(binding, key, helper)
    dynamic([], not (^f < ^v))
  end

  defp aggregate_comparison(binding, key, {helper, {:<=, v}}) when helper in @aggregate_helpers do
    f = agg_field_dyn(binding, key, helper)
    dynamic([], ^f <= ^v)
  end

  defp aggregate_comparison(binding, key, {:not, {helper, {:<=, v}}})
       when helper in @aggregate_helpers do
    f = agg_field_dyn(binding, key, helper)
    dynamic([], not (^f <= ^v))
  end

  defp agg_field_dyn(binding, key, :avg), do: avg_field_dyn(binding, key)
  defp agg_field_dyn(binding, key, :count), do: count_field_dyn(binding, key)
  defp agg_field_dyn(binding, key, :max), do: max_field_dyn(binding, key)
  defp agg_field_dyn(binding, key, :min), do: min_field_dyn(binding, key)
  defp agg_field_dyn(binding, key, :sum), do: sum_field_dyn(binding, key)

  defp avg_field_dyn(binding, key) do
    f = FieldAccessors.field_dyn(binding, key)
    dynamic([], avg(^f))
  end

  defp count_field_dyn(binding, key) do
    f = FieldAccessors.field_dyn(binding, key)
    dynamic([], count(^f))
  end

  defp max_field_dyn(binding, key) do
    f = FieldAccessors.field_dyn(binding, key)
    dynamic([], max(^f))
  end

  defp min_field_dyn(binding, key) do
    f = FieldAccessors.field_dyn(binding, key)
    dynamic([], min(^f))
  end

  defp sum_field_dyn(binding, key) do
    f = FieldAccessors.field_dyn(binding, key)
    dynamic([], sum(^f))
  end
end
