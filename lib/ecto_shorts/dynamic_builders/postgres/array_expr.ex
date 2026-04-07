defmodule EctoShorts.DynamicBuilders.Postgres.ArrayExpr do
  @moduledoc since: "3.0.0"
  @moduledoc false

  alias Ecto.Query
  alias EctoShorts.QueryBinding
  alias EctoShorts.DynamicBuilders.Postgres.Normalizer

  require Ecto.Query

  @logger_prefix "EctoShorts.DynamicBuilders.Postgres.ArrayExpr"

  {target_binding_var, binding_patterns} = QueryBinding.query_binding_contracts(__MODULE__)

  for {quoted_binding_head, quoted_binding_body} <- binding_patterns do
    def dynamic_expr(unquote(quoted_binding_head) = selected_binding, key, negated, term, _opts) do
      selected_binding
      |> dispatch_expr(key, normalize_term(term))
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

    defp lower_exists_dyn(unquote(quoted_binding_head), key, value) do
      Query.dynamic(
        [unquote_splicing(quoted_binding_body)],
        fragment(
          "EXISTS (SELECT 1 FROM unnest(?) AS t WHERE lower(t) = ?)",
          field(unquote(target_binding_var), ^key),
          ^value
        )
      )
    end

    defp upper_exists_dyn(unquote(quoted_binding_head), key, value) do
      Query.dynamic(
        [unquote_splicing(quoted_binding_body)],
        fragment(
          "EXISTS (SELECT 1 FROM unnest(?) AS t WHERE upper(t) = ?)",
          field(unquote(target_binding_var), ^key),
          ^value
        )
      )
    end

    defp lower_not_exists_dyn(unquote(quoted_binding_head), key, value) do
      Query.dynamic(
        [unquote_splicing(quoted_binding_body)],
        fragment(
          "NOT EXISTS (SELECT 1 FROM unnest(?) AS t WHERE lower(t) = ?)",
          field(unquote(target_binding_var), ^key),
          ^value
        )
      )
    end

    defp upper_not_exists_dyn(unquote(quoted_binding_head), key, value) do
      Query.dynamic(
        [unquote_splicing(quoted_binding_body)],
        fragment(
          "NOT EXISTS (SELECT 1 FROM unnest(?) AS t WHERE upper(t) = ?)",
          field(unquote(target_binding_var), ^key),
          ^value
        )
      )
    end
  end

  def dynamic_expr(_selected_binding, _key, _negated, _term, _opts), do: nil

  defp dispatch_expr(binding, key, {:==, nil}) do
    nil_field_dyn?(binding, key)
  end

  defp dispatch_expr(binding, key, {:!=, nil}) do
    field = field_dyn(binding, key)
    Query.dynamic([], not is_nil(^field))
  end

  defp dispatch_expr(binding, key, {:==, values}) when is_list(values) do
    field = field_dyn(binding, key)
    # credo:disable-for-next-line
    Query.dynamic([], ^field == ^values)
  end

  defp dispatch_expr(binding, key, {:!=, values}) when is_list(values) do
    field = field_dyn(binding, key)
    # credo:disable-for-next-line
    Query.dynamic([], ^field != ^values)
  end

  defp dispatch_expr(binding, key, {:==, {:lower, value}}) do
    lower_exists_dyn(binding, key, value)
  end

  defp dispatch_expr(binding, key, {:==, {:upper, value}}) do
    upper_exists_dyn(binding, key, value)
  end

  defp dispatch_expr(binding, key, {:!=, {:lower, value}}) do
    lower_not_exists_dyn(binding, key, value)
  end

  defp dispatch_expr(binding, key, {:!=, {:upper, value}}) do
    upper_not_exists_dyn(binding, key, value)
  end

  defp dispatch_expr(_binding, key, {op, {:value, {arith_op, _}}})
       when op in [:==, :!=, :>, :>=, :<, :<=] and arith_op in [:+, :-, :*, :/] do
    EctoShorts.Logger.warning(
      @logger_prefix,
      "arithmetic comparison (#{arith_op}) is not supported on array field #{inspect(key)}, skipping"
    )

    nil
  end

  defp dispatch_expr(binding, key, {op, {:value, v}}) when op in [:==, :!=, :>, :>=, :<, :<=] do
    dispatch_expr(binding, key, {op, v})
  end

  defp dispatch_expr(binding, key, {:==, {:any, qv}}) do
    field = field_dyn(binding, key)
    Query.dynamic([], ^field == any(qv))
  end

  defp dispatch_expr(binding, key, {:!=, {:any, qv}}) do
    field = field_dyn(binding, key)
    Query.dynamic([], ^field != any(qv))
  end

  defp dispatch_expr(binding, key, {:>, {:any, qv}}) do
    field = field_dyn(binding, key)
    Query.dynamic([], ^field > any(qv))
  end

  defp dispatch_expr(binding, key, {:>=, {:any, qv}}) do
    field = field_dyn(binding, key)
    Query.dynamic([], ^field >= any(qv))
  end

  defp dispatch_expr(binding, key, {:<, {:any, qv}}) do
    field = field_dyn(binding, key)
    Query.dynamic([], ^field < any(qv))
  end

  defp dispatch_expr(binding, key, {:<=, {:any, qv}}) do
    field = field_dyn(binding, key)
    Query.dynamic([], ^field <= any(qv))
  end

  defp dispatch_expr(binding, key, {:parent_as, {pb, pf}}) do
    field = field_dyn(binding, key)
    Query.dynamic([], ^field == field(parent_as(^pb), ^pf))
  end

  defp dispatch_expr(binding, key, {:==, {:parent_as, {pb, pf}}}) do
    field = field_dyn(binding, key)
    Query.dynamic([], ^field == field(parent_as(^pb), ^pf))
  end

  defp dispatch_expr(binding, key, {:!=, {:parent_as, {pb, pf}}}) do
    field = field_dyn(binding, key)
    Query.dynamic([], ^field != field(parent_as(^pb), ^pf))
  end

  defp dispatch_expr(binding, key, {:>, {:parent_as, {pb, pf}}}) do
    field = field_dyn(binding, key)
    Query.dynamic([], ^field > field(parent_as(^pb), ^pf))
  end

  defp dispatch_expr(binding, key, {:>=, {:parent_as, {pb, pf}}}) do
    field = field_dyn(binding, key)
    Query.dynamic([], ^field >= field(parent_as(^pb), ^pf))
  end

  defp dispatch_expr(binding, key, {:<, {:parent_as, {pb, pf}}}) do
    field = field_dyn(binding, key)
    Query.dynamic([], ^field < field(parent_as(^pb), ^pf))
  end

  defp dispatch_expr(binding, key, {:<=, {:parent_as, {pb, pf}}}) do
    field = field_dyn(binding, key)
    Query.dynamic([], ^field <= field(parent_as(^pb), ^pf))
  end

  defp dispatch_expr(binding, key, {:==, value}) do
    field = field_dyn(binding, key)
    Query.dynamic([], ^value in ^field)
  end

  defp dispatch_expr(binding, key, {:!=, value}) do
    field = field_dyn(binding, key)
    Query.dynamic([], ^value not in ^field)
  end

  defp dispatch_expr(binding, key, {:in, values}) when is_list(values) do
    field = field_dyn(binding, key)
    Query.dynamic([], fragment("? && ?", ^field, ^values))
  end

  defp dispatch_expr(binding, key, {:in, value}) do
    field = field_dyn(binding, key)
    Query.dynamic([], ^value in ^field)
  end

  defp dispatch_expr(binding, key, {:count, {:==, 0}}) do
    field = field_dyn(binding, key)
    # credo:disable-for-next-line
    Query.dynamic([], fragment("coalesce(array_length(?, 1), 0)", ^field) == ^0)
  end

  defp dispatch_expr(binding, key, {:count, {:==, value}}) do
    field = field_dyn(binding, key)
    # credo:disable-for-next-line
    Query.dynamic([], fragment("array_length(?, 1)", ^field) == ^value)
  end

  defp dispatch_expr(binding, key, {:count, {:!=, value}}) do
    field = field_dyn(binding, key)
    # credo:disable-for-next-line
    Query.dynamic([], fragment("array_length(?, 1)", ^field) != ^value)
  end

  defp dispatch_expr(binding, key, {:count, {:>, value}}) do
    field = field_dyn(binding, key)
    Query.dynamic([], fragment("array_length(?, 1)", ^field) > ^value)
  end

  defp dispatch_expr(binding, key, {:count, {:>=, value}}) do
    field = field_dyn(binding, key)
    Query.dynamic([], fragment("array_length(?, 1)", ^field) >= ^value)
  end

  defp dispatch_expr(binding, key, {:count, {:<, value}}) do
    field = field_dyn(binding, key)
    Query.dynamic([], fragment("array_length(?, 1)", ^field) < ^value)
  end

  defp dispatch_expr(binding, key, {:count, {:<=, value}}) do
    field = field_dyn(binding, key)
    Query.dynamic([], fragment("array_length(?, 1)", ^field) <= ^value)
  end

  defp dispatch_expr(binding, key, {:all, {:==, value}}) do
    field = field_dyn(binding, key)
    Query.dynamic([], fragment("? = ALL(?)", ^value, ^field))
  end

  defp dispatch_expr(binding, key, {:all, {:!=, value}}) do
    field = field_dyn(binding, key)
    Query.dynamic([], fragment("? != ALL(?)", ^value, ^field))
  end

  defp dispatch_expr(binding, key, {:all, {:>, value}}) do
    field = field_dyn(binding, key)
    Query.dynamic([], fragment("? < ALL(?)", ^value, ^field))
  end

  defp dispatch_expr(binding, key, {:all, {:>=, value}}) do
    field = field_dyn(binding, key)
    Query.dynamic([], fragment("? <= ALL(?)", ^value, ^field))
  end

  defp dispatch_expr(binding, key, {:all, {:<, value}}) do
    field = field_dyn(binding, key)
    Query.dynamic([], fragment("? > ALL(?)", ^value, ^field))
  end

  defp dispatch_expr(binding, key, {:all, {:<=, value}}) do
    field = field_dyn(binding, key)
    Query.dynamic([], fragment("? >= ALL(?)", ^value, ^field))
  end

  defp dispatch_expr(binding, key, {:all, {:in, values}}) when is_list(values) do
    field = field_dyn(binding, key)
    Query.dynamic([], fragment("? <@ ?", ^field, ^values))
  end

  defp dispatch_expr(binding, key, {:>, value}) do
    field = field_dyn(binding, key)
    Query.dynamic([], fragment("? < ANY(?)", ^value, ^field))
  end

  defp dispatch_expr(binding, key, {:>=, value}) do
    field = field_dyn(binding, key)
    Query.dynamic([], fragment("? <= ANY(?)", ^value, ^field))
  end

  defp dispatch_expr(binding, key, {:<, value}) do
    field = field_dyn(binding, key)
    Query.dynamic([], fragment("? > ANY(?)", ^value, ^field))
  end

  defp dispatch_expr(binding, key, {:<=, value}) do
    field = field_dyn(binding, key)
    Query.dynamic([], fragment("? >= ANY(?)", ^value, ^field))
  end

  defp dispatch_expr(binding, key, {:lower, value}) do
    lower_exists_dyn(binding, key, value)
  end

  defp dispatch_expr(binding, key, {:upper, value}) do
    upper_exists_dyn(binding, key, value)
  end

  defp dispatch_expr(binding, key, {:like, value}) do
    field = field_dyn(binding, key)
    patterns = normalize_patterns(value)

    Query.dynamic(
      [],
      fragment("EXISTS (SELECT 1 FROM unnest(?) AS t WHERE t LIKE ANY (?))", ^field, ^patterns)
    )
  end

  defp dispatch_expr(binding, key, {:ilike, value}) do
    field = field_dyn(binding, key)
    patterns = normalize_patterns(value)

    Query.dynamic(
      [],
      fragment("EXISTS (SELECT 1 FROM unnest(?) AS t WHERE t ILIKE ANY (?))", ^field, ^patterns)
    )
  end

  defp dispatch_expr(_binding, key, {op, _}) when op in [:avg, :sum, :max, :min] do
    EctoShorts.Logger.warning(
      @logger_prefix,
      "#{op} aggregate is not supported on array field #{inspect(key)}, skipping"
    )

    nil
  end

  defp dispatch_expr(_binding, key, {:any, _}) do
    EctoShorts.Logger.warning(
      @logger_prefix,
      ":any subquery quantifier is not supported on array field #{inspect(key)}, skipping"
    )

    nil
  end

  defp dispatch_expr(_binding, key, {wrapper, _}) when wrapper in [:datetime, :date] do
    EctoShorts.Logger.warning(
      @logger_prefix,
      "#{wrapper} comparison is not supported on array field #{inspect(key)}, skipping"
    )

    nil
  end

  defp dispatch_expr(_binding, key, {:parent_as, _}) do
    EctoShorts.Logger.warning(
      @logger_prefix,
      ":parent_as requires a {binding, field} payload, got unexpected form for field #{inspect(key)}, skipping"
    )

    nil
  end

  defp dispatch_expr(_binding, _key, _term), do: nil

  defp maybe_negate(nil, _negated), do: nil
  defp maybe_negate(expr, :not), do: Query.dynamic([], not (^expr))
  defp maybe_negate(expr, _negated), do: expr

  defp normalize_term({:all, payload}) do
    {:all, normalize_all_payload(payload)}
  end

  defp normalize_term({op, value}) do
    {Normalizer.normalize_operator(op), value}
  end

  defp normalize_term(nil) do
    {:==, nil}
  end

  defp normalize_term(value) when is_list(value) do
    {:==, value}
  end

  defp normalize_term(value) do
    {:in, value}
  end

  defp normalize_all_payload(payload) when is_map(payload) and not is_struct(payload) do
    payload
    |> Map.to_list()
    |> normalize_all_payload()
  end

  defp normalize_all_payload(payload) when is_list(payload) do
    payload
    |> Enum.reduce([], &normalize_all_payload_entry/2)
    |> Enum.reverse()
    |> collapse_all_payload()
  end

  defp normalize_all_payload({op, value}) do
    {Normalizer.normalize_operator(op), value}
  end

  defp normalize_all_payload(payload), do: payload

  defp normalize_all_payload_entry({op, value}, payload) do
    [{Normalizer.normalize_operator(op), value} | payload]
  end

  defp normalize_all_payload_entry(value, payload) do
    [value | payload]
  end

  defp collapse_all_payload([payload]), do: payload
  defp collapse_all_payload(payload), do: payload

  defp normalize_patterns(values) when is_list(values) do
    Enum.map(values, &preserve_or_wrap_pattern/1)
  end

  defp normalize_patterns(value) do
    [preserve_or_wrap_pattern(value)]
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
