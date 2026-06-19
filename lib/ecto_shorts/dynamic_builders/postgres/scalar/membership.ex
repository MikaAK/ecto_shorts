defmodule EctoShorts.DynamicBuilders.Postgres.Scalar.Membership do
  @moduledoc false
  @moduledoc since: "3.0.0"

  alias EctoShorts.DynamicBuilders.Postgres.FieldAccessors

  import Ecto.Query

  def build(binding, key, negated, {op, value}) do
    term = if negated === :not, do: {:not, {op, value}}, else: {op, value}

    case term do
      {:not, {:in, values}} when is_list(values) ->
        membership_not_in_dyn(binding, key, values)

      {:in, values} when is_list(values) ->
        membership_in_dyn(binding, key, values)

      # :nin is the explicit not-in operator (D-NULL: plain NOT IN, no null guard).
      {:not, {:nin, values}} when is_list(values) ->
        membership_in_dyn(binding, key, values)

      {:nin, values} when is_list(values) ->
        membership_not_in_dyn(binding, key, values)

      {:not, {:==, values}} when is_list(values) ->
        membership_not_in_dyn(binding, key, values)

      {:==, values} when is_list(values) ->
        membership_in_dyn(binding, key, values)

      {:not, {:!=, values}} when is_list(values) ->
        membership_in_dyn(binding, key, values)

      {:!=, values} when is_list(values) ->
        membership_not_in_dyn(binding, key, values)

      _ ->
        nil
    end
  end

  defp membership_in_dyn(binding, key, values) do
    f = FieldAccessors.field_dyn(binding, key)
    dynamic([], ^f in ^values)
  end

  defp membership_not_in_dyn(binding, key, values) do
    f = FieldAccessors.field_dyn(binding, key)
    dynamic([], ^f not in ^values)
  end
end
