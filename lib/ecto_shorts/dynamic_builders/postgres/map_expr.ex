defmodule EctoShorts.DynamicBuilders.Postgres.MapExpr do
  @moduledoc since: "3.0.0"
  @moduledoc """
  Builds Postgres JSONB dynamic expressions for map-typed fields.

  Supports equality (`==`, `!=`), nil checks, JSONB containment (`@>` via
  `:contains`), contained-by (`<@` via `:contained_by`), and key existence
  (`jsonb_exists` / `jsonb_exists_any` / `jsonb_exists_all`). This module is
  part of the `Ecto.Adapters.Postgres` dynamic-builder pipeline (the only
  adapter that ships) and is reached when a map/JSONB field appears in
  `EctoShorts.CommonFilters` params, for example:

      EctoShorts.Actions.all(Event, %{metadata: %{contains: %{"source" => "api"}}})

  rather than being called directly.
  """

  alias Ecto.Query
  alias EctoShorts.DynamicBuilders.Postgres.FieldAccessors

  require Ecto.Query

  def dynamic_expr(selected_binding, key, negated, term, _opts) do
    if FieldAccessors.known_binding?(selected_binding) do
      selected_binding
      |> dispatch_expr(key, term)
      |> maybe_negate(negated)
    else
      nil
    end
  end

  # Nil checks
  defp dispatch_expr(binding, key, {:==, nil}) do
    f = FieldAccessors.field_dyn(binding, key)
    Query.dynamic([], is_nil(^f))
  end

  defp dispatch_expr(binding, key, {:!=, nil}) do
    f = FieldAccessors.field_dyn(binding, key)
    Query.dynamic([], not is_nil(^f))
  end

  # Scalar equality/inequality
  defp dispatch_expr(binding, key, {:==, value}) do
    f = FieldAccessors.field_dyn(binding, key)
    # credo:disable-for-next-line
    Query.dynamic([], ^f == ^value)
  end

  defp dispatch_expr(binding, key, {:!=, value}) do
    f = FieldAccessors.field_dyn(binding, key)
    # credo:disable-for-next-line
    Query.dynamic([], ^f != ^value)
  end

  # JSONB containment — @>
  # Tuple form: produced by Normalizer from a single-entry map value.
  # e.g. %{contains: %{key: "value"}} → {:contains, {:key, "value"}}
  defp dispatch_expr(binding, key, {:contains, {k, v}}) do
    f = FieldAccessors.field_dyn(binding, key)
    Query.dynamic([], fragment("? @> ?::jsonb", ^f, ^%{k => v}))
  end

  # String form: caller-provided raw JSON string passed through unchanged.
  defp dispatch_expr(binding, key, {:contains, value}) when is_binary(value) do
    f = FieldAccessors.field_dyn(binding, key)
    Query.dynamic([], fragment("? @> ?::jsonb", ^f, ^value))
  end

  # List form: for array-typed JSONB values (e.g. JSON arrays).
  defp dispatch_expr(binding, key, {:contains, value}) when is_list(value) do
    f = FieldAccessors.field_dyn(binding, key)
    Query.dynamic([], fragment("? @> ?::jsonb", ^f, ^value))
  end

  # JSONB contained-by — <@
  defp dispatch_expr(binding, key, {:contained_by, {k, v}}) do
    f = FieldAccessors.field_dyn(binding, key)
    Query.dynamic([], fragment("? <@ ?::jsonb", ^f, ^%{k => v}))
  end

  defp dispatch_expr(binding, key, {:contained_by, value}) when is_binary(value) do
    f = FieldAccessors.field_dyn(binding, key)
    Query.dynamic([], fragment("? <@ ?::jsonb", ^f, ^value))
  end

  defp dispatch_expr(binding, key, {:contained_by, value}) when is_list(value) do
    f = FieldAccessors.field_dyn(binding, key)
    Query.dynamic([], fragment("? <@ ?::jsonb", ^f, ^value))
  end

  # JSONB key existence — jsonb_exists(field, key)
  # Avoids the ? operator which conflicts with Ecto fragment placeholder syntax.
  defp dispatch_expr(binding, key, {:has_key, value}) do
    f = FieldAccessors.field_dyn(binding, key)
    Query.dynamic([], fragment("jsonb_exists(?, ?)", ^f, ^value))
  end

  # JSONB any-key existence — jsonb_exists_any(field, keys)
  defp dispatch_expr(binding, key, {:has_any_key, values}) when is_list(values) do
    f = FieldAccessors.field_dyn(binding, key)
    Query.dynamic([], fragment("jsonb_exists_any(?, ?)", ^f, ^values))
  end

  # JSONB all-keys existence — jsonb_exists_all(field, keys)
  defp dispatch_expr(binding, key, {:has_all_keys, values}) when is_list(values) do
    f = FieldAccessors.field_dyn(binding, key)
    Query.dynamic([], fragment("jsonb_exists_all(?, ?)", ^f, ^values))
  end

  defp dispatch_expr(_binding, _key, _term), do: nil

  defp maybe_negate(nil, _negated), do: nil
  defp maybe_negate(expr, :not), do: Query.dynamic([], not (^expr))
  defp maybe_negate(expr, _negated), do: expr
end
