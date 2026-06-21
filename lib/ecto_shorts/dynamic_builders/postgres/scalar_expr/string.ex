defmodule EctoShorts.DynamicBuilders.Postgres.ScalarExpr.String do
  @moduledoc """
  Builds `LIKE` / `ILIKE` dynamic expressions for scalar string fields.

  Accepts a single pattern or a list (using `LIKE ANY` / `ILIKE ANY`), and
  automatically wraps a bare value in `%…%` unless it already contains a `%` or
  `_` wildcard. This module is part of the `Ecto.Adapters.Postgres`
  dynamic-builder pipeline (the only adapter that ships) and is reached when a
  `:like`/`:ilike` operator appears in `EctoShorts.CommonFilters` params, for
  example:

      EctoShorts.Actions.all(User, %{name: %{ilike: "ada"}})

  rather than being called directly.
  """
  @moduledoc since: "3.0.0"

  alias EctoShorts.DynamicBuilders.Postgres.FieldAccessors

  import Ecto.Query

  def build(binding, key, negated, {op, value}) do
    term = if negated === :not, do: {:not, {op, value}}, else: {op, value}

    case term do
      {:not, {:like, values}} when is_list(values) ->
        patterns = Enum.map(values, &preserve_or_wrap_pattern/1)
        f = FieldAccessors.field_dyn(binding, key)
        dynamic([], not fragment("? LIKE ANY(?)", ^f, ^patterns))

      {:like, values} when is_list(values) ->
        patterns = Enum.map(values, &preserve_or_wrap_pattern/1)
        f = FieldAccessors.field_dyn(binding, key)
        dynamic([], fragment("? LIKE ANY(?)", ^f, ^patterns))

      {:not, {:ilike, values}} when is_list(values) ->
        patterns = Enum.map(values, &preserve_or_wrap_pattern/1)
        f = FieldAccessors.field_dyn(binding, key)
        dynamic([], not fragment("? ILIKE ANY(?)", ^f, ^patterns))

      {:ilike, values} when is_list(values) ->
        patterns = Enum.map(values, &preserve_or_wrap_pattern/1)
        f = FieldAccessors.field_dyn(binding, key)
        dynamic([], fragment("? ILIKE ANY(?)", ^f, ^patterns))

      {:not, {:like, v}} ->
        f = FieldAccessors.field_dyn(binding, key)
        dynamic([], not like(^f, ^preserve_or_wrap_pattern(v)))

      {:like, v} ->
        f = FieldAccessors.field_dyn(binding, key)
        dynamic([], like(^f, ^preserve_or_wrap_pattern(v)))

      {:not, {:ilike, v}} ->
        f = FieldAccessors.field_dyn(binding, key)
        dynamic([], not ilike(^f, ^preserve_or_wrap_pattern(v)))

      {:ilike, v} ->
        f = FieldAccessors.field_dyn(binding, key)
        dynamic([], ilike(^f, ^preserve_or_wrap_pattern(v)))
    end
  end

  defp preserve_or_wrap_pattern(value) when is_binary(value) do
    if String.contains?(value, ["%", "_"]) do
      value
    else
      "%#{value}%"
    end
  end

  defp preserve_or_wrap_pattern(value) do
    "%#{value}%"
  end
end
