defmodule EctoShorts.DynamicBuilders.Postgres.MapExpr do
  @moduledoc since: "3.0.0"
  @moduledoc false

  alias Ecto.Query
  alias EctoShorts.QueryBinding

  require Ecto.Query

  {target_binding_var, binding_patterns} =
    QueryBinding.query_binding_contracts(__MODULE__)

  for {quoted_binding_head, quoted_binding_body} <- binding_patterns do
    def dynamic_expr(unquote(quoted_binding_head) = selected_binding, key, negated, term, _opts) do
      selected_binding
      |> dispatch_expr(key, term)
      |> maybe_negate(negated)
    end

    defp field_dyn(unquote(quoted_binding_head), key) do
      Query.dynamic(
        [unquote_splicing(quoted_binding_body)],
        field(unquote(target_binding_var), ^key)
      )
    end

    defp nil_field_dyn?(unquote(quoted_binding_head), key) do
      Query.dynamic(
        [unquote_splicing(quoted_binding_body)],
        is_nil(field(unquote(target_binding_var), ^key))
      )
    end
  end

  def dynamic_expr(_selected_binding, _key, _negated, _term, _opts), do: nil

  # Nil checks
  defp dispatch_expr(binding, key, {:==, nil}) do
    nil_field_dyn?(binding, key)
  end

  defp dispatch_expr(binding, key, {:!=, nil}) do
    f = field_dyn(binding, key)
    Query.dynamic([], not is_nil(^f))
  end

  # Scalar equality/inequality
  defp dispatch_expr(binding, key, {:==, value}) do
    f = field_dyn(binding, key)
    # credo:disable-for-next-line
    Query.dynamic([], ^f == ^value)
  end

  defp dispatch_expr(binding, key, {:!=, value}) do
    f = field_dyn(binding, key)
    # credo:disable-for-next-line
    Query.dynamic([], ^f != ^value)
  end

  # JSONB containment — @>
  # Tuple form: produced by Normalizer from a single-entry map value.
  # e.g. %{contains: %{key: "value"}} → {:contains, {:key, "value"}}
  defp dispatch_expr(binding, key, {:contains, {k, v}}) do
    f = field_dyn(binding, key)
    Query.dynamic([], fragment("? @> ?::jsonb", ^f, ^%{k => v}))
  end

  # String form: caller-provided raw JSON string passed through unchanged.
  defp dispatch_expr(binding, key, {:contains, value}) when is_binary(value) do
    f = field_dyn(binding, key)
    Query.dynamic([], fragment("? @> ?::jsonb", ^f, ^value))
  end

  # List form: for array-typed JSONB values (e.g. JSON arrays).
  defp dispatch_expr(binding, key, {:contains, value}) when is_list(value) do
    f = field_dyn(binding, key)
    Query.dynamic([], fragment("? @> ?::jsonb", ^f, ^value))
  end

  # JSONB contained-by — <@
  defp dispatch_expr(binding, key, {:contained_by, {k, v}}) do
    f = field_dyn(binding, key)
    Query.dynamic([], fragment("? <@ ?::jsonb", ^f, ^%{k => v}))
  end

  defp dispatch_expr(binding, key, {:contained_by, value}) when is_binary(value) do
    f = field_dyn(binding, key)
    Query.dynamic([], fragment("? <@ ?::jsonb", ^f, ^value))
  end

  defp dispatch_expr(binding, key, {:contained_by, value}) when is_list(value) do
    f = field_dyn(binding, key)
    Query.dynamic([], fragment("? <@ ?::jsonb", ^f, ^value))
  end

  # JSONB key existence — jsonb_exists(field, key)
  # Avoids the ? operator which conflicts with Ecto fragment placeholder syntax.
  defp dispatch_expr(binding, key, {:has_key, value}) do
    f = field_dyn(binding, key)
    Query.dynamic([], fragment("jsonb_exists(?, ?)", ^f, ^value))
  end

  # JSONB any-key existence — jsonb_exists_any(field, keys)
  defp dispatch_expr(binding, key, {:has_any_key, values}) when is_list(values) do
    f = field_dyn(binding, key)
    Query.dynamic([], fragment("jsonb_exists_any(?, ?)", ^f, ^values))
  end

  # JSONB all-keys existence — jsonb_exists_all(field, keys)
  defp dispatch_expr(binding, key, {:has_all_keys, values}) when is_list(values) do
    f = field_dyn(binding, key)
    Query.dynamic([], fragment("jsonb_exists_all(?, ?)", ^f, ^values))
  end

  defp dispatch_expr(_binding, _key, _term), do: nil

  defp maybe_negate(nil, _negated), do: nil
  defp maybe_negate(expr, :not), do: Query.dynamic([], not (^expr))
  defp maybe_negate(expr, _negated), do: expr
end
