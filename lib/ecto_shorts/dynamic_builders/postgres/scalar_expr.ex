defmodule EctoShorts.DynamicBuilders.Postgres.ScalarExpr do
  @moduledoc since: "3.0.0"
  @moduledoc false

  alias EctoShorts.QueryBinding

  import Ecto.Query

  @aggregate_helpers [:avg, :count, :max, :min, :sum]
  @operators [:membership, :comparison, :string_transform, :string]
  @comparison_operators [:>, :>=, :<, :<=, :==, :!=]
  @equality_operators [:==, :!=]
  @string_operators [:like, :ilike]

  context = __MODULE__
  key_var = Macro.var(:key, context)

  def operators, do: @operators

  {target_binding_var, binding_patterns} = QueryBinding.query_binding_contracts(__MODULE__)

  for {quoted_binding_head, quoted_binding_body} <- binding_patterns do
    # Thin entry shim - delegates entirely to non-generated dispatch_expr
    def dynamic_expr(unquote(quoted_binding_head) = selected_binding, key, negated, term, _opts) do
      dispatch_expr(selected_binding, key, negated, term)
    end

    # Binding-specific field accessor functions (one dynamic/2 call each, no logic)
    defp field_dyn(unquote(quoted_binding_head), unquote(key_var)) do
      dynamic(
        [unquote_splicing(quoted_binding_body)],
        field(unquote(target_binding_var), ^unquote(key_var))
      )
    end

    defp nil_field_dyn?(unquote(quoted_binding_head), unquote(key_var)) do
      dynamic(
        [unquote_splicing(quoted_binding_body)],
        is_nil(field(unquote(target_binding_var), ^unquote(key_var)))
      )
    end

    defp not_nil_dyn(unquote(quoted_binding_head), unquote(key_var)) do
      dynamic(
        [unquote_splicing(quoted_binding_body)],
        not is_nil(field(unquote(target_binding_var), ^unquote(key_var)))
      )
    end

    defp date_field_dyn(unquote(quoted_binding_head), unquote(key_var)) do
      dynamic(
        [unquote_splicing(quoted_binding_body)],
        fragment("date(?)", field(unquote(target_binding_var), ^unquote(key_var)))
      )
    end

    defp lower_field_dyn(unquote(quoted_binding_head), unquote(key_var)) do
      dynamic(
        [unquote_splicing(quoted_binding_body)],
        fragment("lower(?)", field(unquote(target_binding_var), ^unquote(key_var)))
      )
    end

    defp upper_field_dyn(unquote(quoted_binding_head), unquote(key_var)) do
      dynamic(
        [unquote_splicing(quoted_binding_body)],
        fragment("upper(?)", field(unquote(target_binding_var), ^unquote(key_var)))
      )
    end

    defp avg_field_dyn(unquote(quoted_binding_head), unquote(key_var)) do
      dynamic(
        [unquote_splicing(quoted_binding_body)],
        avg(field(unquote(target_binding_var), ^unquote(key_var)))
      )
    end

    defp count_field_dyn(unquote(quoted_binding_head), unquote(key_var)) do
      dynamic(
        [unquote_splicing(quoted_binding_body)],
        count(field(unquote(target_binding_var), ^unquote(key_var)))
      )
    end

    defp max_field_dyn(unquote(quoted_binding_head), unquote(key_var)) do
      dynamic(
        [unquote_splicing(quoted_binding_body)],
        max(field(unquote(target_binding_var), ^unquote(key_var)))
      )
    end

    defp min_field_dyn(unquote(quoted_binding_head), unquote(key_var)) do
      dynamic(
        [unquote_splicing(quoted_binding_body)],
        min(field(unquote(target_binding_var), ^unquote(key_var)))
      )
    end

    defp sum_field_dyn(unquote(quoted_binding_head), unquote(key_var)) do
      dynamic(
        [unquote_splicing(quoted_binding_body)],
        sum(field(unquote(target_binding_var), ^unquote(key_var)))
      )
    end

    defp membership_in_dyn(unquote(quoted_binding_head), unquote(key_var), values) do
      dynamic(
        [unquote_splicing(quoted_binding_body)],
        field(unquote(target_binding_var), ^unquote(key_var)) in ^values
      )
    end

    defp membership_not_in_dyn(unquote(quoted_binding_head), unquote(key_var), values) do
      dynamic(
        [unquote_splicing(quoted_binding_body)],
        is_nil(field(unquote(target_binding_var), ^unquote(key_var))) or
          field(unquote(target_binding_var), ^unquote(key_var)) not in ^values
      )
    end

    defp membership_nil_aware_in_dyn(unquote(quoted_binding_head), unquote(key_var), values) do
      dynamic(
        [unquote_splicing(quoted_binding_body)],
        not is_nil(field(unquote(target_binding_var), ^unquote(key_var))) and
          field(unquote(target_binding_var), ^unquote(key_var)) in ^values
      )
    end
  end

  # ── Non-generated dispatch: compiled once regardless of binding count ──────

  defp dispatch_expr(binding, key, negated, {op, value}) do
    case family_for(op, value) do
      :membership -> membership_impl(binding, key, negated, {op, value})
      :string_transform -> string_transform_impl(binding, key, negated, {op, value})
      :string -> string_impl(binding, key, negated, {op, value})
      :comparison -> comparison_impl(binding, key, negated, {op, value})
    end
  end

  defp membership_impl(binding, key, negated, {op, value}) do
    term = if negated === :not, do: {:not, {op, value}}, else: {op, value}

    case term do
      {:not, {:in, values}} when is_list(values) ->
        membership_not_in_dyn(binding, key, values)

      {:in, values} when is_list(values) ->
        membership_in_dyn(binding, key, values)

      {:not, {:==, values}} when is_list(values) ->
        membership_not_in_dyn(binding, key, values)

      {:==, values} when is_list(values) ->
        membership_in_dyn(binding, key, values)

      {:not, {:!=, values}} when is_list(values) ->
        membership_nil_aware_in_dyn(binding, key, values)

      {:!=, values} when is_list(values) ->
        membership_not_in_dyn(binding, key, values)

      _ ->
        nil
    end
  end

  defp string_transform_impl(binding, key, negated, {op, value}) do
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

      _ ->
        nil
    end
  end

  defp string_impl(binding, key, negated, {op, value}) do
    term = if negated === :not, do: {:not, {op, value}}, else: {op, value}

    case term do
      {:not, {:like, values}} when is_list(values) ->
        patterns = Enum.map(values, &preserve_or_wrap_pattern/1)
        f = field_dyn(binding, key)
        dynamic([], not fragment("? LIKE ANY(?)", ^f, ^patterns))

      {:like, values} when is_list(values) ->
        patterns = Enum.map(values, &preserve_or_wrap_pattern/1)
        f = field_dyn(binding, key)
        dynamic([], fragment("? LIKE ANY(?)", ^f, ^patterns))

      {:not, {:ilike, values}} when is_list(values) ->
        patterns = Enum.map(values, &preserve_or_wrap_pattern/1)
        f = field_dyn(binding, key)
        dynamic([], not fragment("? ILIKE ANY(?)", ^f, ^patterns))

      {:ilike, values} when is_list(values) ->
        patterns = Enum.map(values, &preserve_or_wrap_pattern/1)
        f = field_dyn(binding, key)
        dynamic([], fragment("? ILIKE ANY(?)", ^f, ^patterns))

      {:not, {:like, v}} ->
        f = field_dyn(binding, key)
        dynamic([], not like(^f, ^preserve_or_wrap_pattern(v)))

      {:like, v} ->
        f = field_dyn(binding, key)
        dynamic([], like(^f, ^preserve_or_wrap_pattern(v)))

      {:not, {:ilike, v}} ->
        f = field_dyn(binding, key)
        dynamic([], not ilike(^f, ^preserve_or_wrap_pattern(v)))

      {:ilike, v} ->
        f = field_dyn(binding, key)
        dynamic([], ilike(^f, ^preserve_or_wrap_pattern(v)))
    end
  end

  # All comparison cases in one function - compiled once, not 12×
  defp comparison_impl(binding, key, negated, {op, value}) do
    term = if negated === :not, do: {:not, {op, value}}, else: {op, value}

    case term do
      # Nil checks
      {:==, nil} ->
        nil_field_dyn?(binding, key)

      {:not, {:==, nil}} ->
        not_nil_dyn(binding, key)

      {:!=, nil} ->
        not_nil_dyn(binding, key)

      {:not, {:!=, nil}} ->
        nil_field_dyn?(binding, key)

      # Scalar comparisons
      {:==, v} when not is_tuple(v) ->
        f = field_dyn(binding, key)
        dynamic([], ^f == ^v)

      {:not, {:==, v}} when not is_tuple(v) ->
        f = field_dyn(binding, key)
        dynamic([], ^f != ^v)

      {:!=, v} when not is_tuple(v) ->
        f = field_dyn(binding, key)
        dynamic([], ^f != ^v)

      {:not, {:!=, v}} when not is_tuple(v) ->
        f = field_dyn(binding, key)
        dynamic([], ^f == ^v)

      {:>, v} when not is_tuple(v) ->
        f = field_dyn(binding, key)
        dynamic([], ^f > ^v)

      {:not, {:>, v}} when not is_tuple(v) ->
        f = field_dyn(binding, key)
        dynamic([], not (^f > ^v))

      {:>=, v} when not is_tuple(v) ->
        f = field_dyn(binding, key)
        dynamic([], ^f >= ^v)

      {:not, {:>=, v}} when not is_tuple(v) ->
        f = field_dyn(binding, key)
        dynamic([], not (^f >= ^v))

      {:<, v} when not is_tuple(v) ->
        f = field_dyn(binding, key)
        dynamic([], ^f < ^v)

      {:not, {:<, v}} when not is_tuple(v) ->
        f = field_dyn(binding, key)
        dynamic([], not (^f < ^v))

      {:<=, v} when not is_tuple(v) ->
        f = field_dyn(binding, key)
        dynamic([], ^f <= ^v)

      {:not, {:<=, v}} when not is_tuple(v) ->
        f = field_dyn(binding, key)
        dynamic([], not (^f <= ^v))

      # Quantified comparisons (all / any)
      {:==, {:all, qv}} ->
        f = field_dyn(binding, key)
        dynamic([], ^f == all(qv))

      {:not, {:==, {:all, qv}}} ->
        f = field_dyn(binding, key)
        dynamic([], not (^f == all(qv)))

      {:==, {:any, qv}} ->
        f = field_dyn(binding, key)
        dynamic([], ^f == any(qv))

      {:not, {:==, {:any, qv}}} ->
        f = field_dyn(binding, key)
        dynamic([], not (^f == any(qv)))

      {:!=, {:all, qv}} ->
        f = field_dyn(binding, key)
        dynamic([], ^f != all(qv))

      {:not, {:!=, {:all, qv}}} ->
        f = field_dyn(binding, key)
        dynamic([], not (^f != all(qv)))

      {:!=, {:any, qv}} ->
        f = field_dyn(binding, key)
        dynamic([], ^f != any(qv))

      {:not, {:!=, {:any, qv}}} ->
        f = field_dyn(binding, key)
        dynamic([], not (^f != any(qv)))

      {:>, {:all, qv}} ->
        f = field_dyn(binding, key)
        dynamic([], ^f > all(qv))

      {:not, {:>, {:all, qv}}} ->
        f = field_dyn(binding, key)
        dynamic([], not (^f > all(qv)))

      {:>, {:any, qv}} ->
        f = field_dyn(binding, key)
        dynamic([], ^f > any(qv))

      {:not, {:>, {:any, qv}}} ->
        f = field_dyn(binding, key)
        dynamic([], not (^f > any(qv)))

      {:>=, {:all, qv}} ->
        f = field_dyn(binding, key)
        dynamic([], ^f >= all(qv))

      {:not, {:>=, {:all, qv}}} ->
        f = field_dyn(binding, key)
        dynamic([], not (^f >= all(qv)))

      {:>=, {:any, qv}} ->
        f = field_dyn(binding, key)
        dynamic([], ^f >= any(qv))

      {:not, {:>=, {:any, qv}}} ->
        f = field_dyn(binding, key)
        dynamic([], not (^f >= any(qv)))

      {:<, {:all, qv}} ->
        f = field_dyn(binding, key)
        dynamic([], ^f < all(qv))

      {:not, {:<, {:all, qv}}} ->
        f = field_dyn(binding, key)
        dynamic([], not (^f < all(qv)))

      {:<, {:any, qv}} ->
        f = field_dyn(binding, key)
        dynamic([], ^f < any(qv))

      {:not, {:<, {:any, qv}}} ->
        f = field_dyn(binding, key)
        dynamic([], not (^f < any(qv)))

      {:<=, {:all, qv}} ->
        f = field_dyn(binding, key)
        dynamic([], ^f <= all(qv))

      {:not, {:<=, {:all, qv}}} ->
        f = field_dyn(binding, key)
        dynamic([], not (^f <= all(qv)))

      {:<=, {:any, qv}} ->
        f = field_dyn(binding, key)
        dynamic([], ^f <= any(qv))

      {:not, {:<=, {:any, qv}}} ->
        f = field_dyn(binding, key)
        dynamic([], not (^f <= any(qv)))

      # Aggregate: nil checks
      {helper, {:==, nil}} when helper in @aggregate_helpers ->
        f = agg_field_dyn(binding, key, helper)
        dynamic([], is_nil(^f))

      {:not, {helper, {:==, nil}}} when helper in @aggregate_helpers ->
        f = agg_field_dyn(binding, key, helper)
        dynamic([], not is_nil(^f))

      {helper, {:!=, nil}} when helper in @aggregate_helpers ->
        f = agg_field_dyn(binding, key, helper)
        dynamic([], not is_nil(^f))

      {:not, {helper, {:!=, nil}}} when helper in @aggregate_helpers ->
        f = agg_field_dyn(binding, key, helper)
        dynamic([], is_nil(^f))

      # Aggregate: value comparisons
      {helper, {:==, v}} when helper in @aggregate_helpers ->
        f = agg_field_dyn(binding, key, helper)
        dynamic([], ^f == ^v)

      {:not, {helper, {:==, v}}} when helper in @aggregate_helpers ->
        f = agg_field_dyn(binding, key, helper)
        dynamic([], ^f != ^v)

      {helper, {:!=, v}} when helper in @aggregate_helpers ->
        f = agg_field_dyn(binding, key, helper)
        dynamic([], ^f != ^v)

      {:not, {helper, {:!=, v}}} when helper in @aggregate_helpers ->
        f = agg_field_dyn(binding, key, helper)
        dynamic([], ^f == ^v)

      {helper, {:>, v}} when helper in @aggregate_helpers ->
        f = agg_field_dyn(binding, key, helper)
        dynamic([], ^f > ^v)

      {:not, {helper, {:>, v}}} when helper in @aggregate_helpers ->
        f = agg_field_dyn(binding, key, helper)
        dynamic([], not (^f > ^v))

      {helper, {:>=, v}} when helper in @aggregate_helpers ->
        f = agg_field_dyn(binding, key, helper)
        dynamic([], ^f >= ^v)

      {:not, {helper, {:>=, v}}} when helper in @aggregate_helpers ->
        f = agg_field_dyn(binding, key, helper)
        dynamic([], not (^f >= ^v))

      {helper, {:<, v}} when helper in @aggregate_helpers ->
        f = agg_field_dyn(binding, key, helper)
        dynamic([], ^f < ^v)

      {:not, {helper, {:<, v}}} when helper in @aggregate_helpers ->
        f = agg_field_dyn(binding, key, helper)
        dynamic([], not (^f < ^v))

      {helper, {:<=, v}} when helper in @aggregate_helpers ->
        f = agg_field_dyn(binding, key, helper)
        dynamic([], ^f <= ^v)

      {:not, {helper, {:<=, v}}} when helper in @aggregate_helpers ->
        f = agg_field_dyn(binding, key, helper)
        dynamic([], not (^f <= ^v))

      # Datetime comparisons - interval is already a ^-pinned runtime var after Phase 1
      {:==, {:date, {:ago, params}}} ->
        count = Keyword.fetch!(params, :count)
        interval = Keyword.fetch!(params, :interval)
        f = date_field_dyn(binding, key)
        dynamic([], ^f == fragment("date(?)", ago(^count, ^interval)))

      {:!=, {:date, {:from_now, params}}} ->
        count = Keyword.fetch!(params, :count)
        interval = Keyword.fetch!(params, :interval)
        f = date_field_dyn(binding, key)
        dynamic([], ^f != fragment("date(?)", from_now(^count, ^interval)))

      {:not, {:>, {:date, {:from_now, params}}}} ->
        count = Keyword.fetch!(params, :count)
        interval = Keyword.fetch!(params, :interval)
        f = date_field_dyn(binding, key)
        dynamic([], not (^f > fragment("date(?)", from_now(^count, ^interval))))

      {:>=, {:date, {:add, params}}} ->
        field_name = Keyword.get(params, :field)
        count = Keyword.fetch!(params, :count)
        interval = Keyword.fetch!(params, :interval)
        f = date_field_dyn(binding, key)
        f2 = field_dyn(binding, field_name)
        dynamic([], ^f >= fragment("date(?)", datetime_add(^f2, ^count, ^interval)))

      {:>=, {:datetime, {:add, params}}} ->
        field_name = Keyword.get(params, :field)
        count = Keyword.fetch!(params, :count)
        interval = Keyword.fetch!(params, :interval)
        f = field_dyn(binding, key)
        f2 = field_dyn(binding, field_name)
        dynamic([], ^f >= datetime_add(^f2, ^count, ^interval))

      {:not, {:>=, {:datetime, {:add, params}}}} ->
        field_name = Keyword.get(params, :field)
        count = Keyword.fetch!(params, :count)
        interval = Keyword.fetch!(params, :interval)
        f = field_dyn(binding, key)
        f2 = field_dyn(binding, field_name)
        dynamic([], not (^f >= datetime_add(^f2, ^count, ^interval)))

      {:>, {:datetime, {:ago, params}}} ->
        count = Keyword.fetch!(params, :count)
        interval = Keyword.fetch!(params, :interval)
        f = field_dyn(binding, key)
        dynamic([], ^f > ago(^count, ^interval))

      {:>, {:datetime, {:from_now, params}}} ->
        count = Keyword.fetch!(params, :count)
        interval = Keyword.fetch!(params, :interval)
        f = field_dyn(binding, key)
        dynamic([], ^f > from_now(^count, ^interval))

      {:not, {:<, {:datetime, {:ago, params}}}} ->
        count = Keyword.fetch!(params, :count)
        interval = Keyword.fetch!(params, :interval)
        f = field_dyn(binding, key)
        dynamic([], not (^f < ago(^count, ^interval)))

      {:<, {:datetime, {:ago, params}}} ->
        count = Keyword.fetch!(params, :count)
        interval = Keyword.fetch!(params, :interval)
        f = field_dyn(binding, key)
        dynamic([], ^f < ago(^count, ^interval))

      {:<=, {:datetime, {:from_now, params}}} ->
        count = Keyword.fetch!(params, :count)
        interval = Keyword.fetch!(params, :interval)
        f = field_dyn(binding, key)
        dynamic([], ^f <= from_now(^count, ^interval))

      {:<, {:date, {:ago, params}}} ->
        count = Keyword.fetch!(params, :count)
        interval = Keyword.fetch!(params, :interval)
        f = date_field_dyn(binding, key)
        dynamic([], ^f < fragment("date(?)", ago(^count, ^interval)))

      # Generic datetime - all ops × {datetime,date} × {ago,from_now,add}
      {op_d, {wrapper, {datetime_op, params}}}
      when op_d in @comparison_operators and wrapper in [:datetime, :date] and
             datetime_op in [:ago, :from_now, :add] ->
        apply_datetime_comparison(binding, key, op_d, wrapper, datetime_op, params, :plain)

      {:not, {op_d, {wrapper, {datetime_op, params}}}}
      when op_d in @comparison_operators and wrapper in [:datetime, :date] and
             datetime_op in [:ago, :from_now, :add] ->
        apply_datetime_comparison(binding, key, op_d, wrapper, datetime_op, params, :negated)

      # Arithmetic: field OP field ARITH_OP value
      {op_a, {:value, {arith_op, {{:field, af}, {:value, av}}}}}
      when op_a in @comparison_operators and arith_op in [:+, :-, :*, :/] and is_atom(af) and
             af !== nil ->
        f = field_dyn(binding, key)
        f2 = field_dyn(binding, af)
        apply_arith_comparison(op_a, f, f2, arith_op, av, :plain)

      {:not, {op_a, {:value, {arith_op, {{:field, af}, {:value, av}}}}}}
      when op_a in @comparison_operators and arith_op in [:+, :-, :*, :/] and is_atom(af) and
             af !== nil ->
        f = field_dyn(binding, key)
        f2 = field_dyn(binding, af)
        apply_arith_comparison(op_a, f, f2, arith_op, av, :negated)

      # Value wrapper (unwraps plain scalar/field references)
      {:not, {op_v, {:value, v}}} when op_v in @comparison_operators ->
        f = field_dyn(binding, key)
        apply_scalar_comparison(op_v, f, v, :negated)

      {op_v, {:value, v}} when op_v in @comparison_operators ->
        f = field_dyn(binding, key)
        apply_scalar_comparison(op_v, f, v, :plain)

      # parent_as: compare current binding field against a field on a named parent binding
      {:parent_as, {pb, pf}} ->
        f = field_dyn(binding, key)
        dynamic([], ^f == field(parent_as(^pb), ^pf))

      {:not, {:parent_as, {pb, pf}}} ->
        f = field_dyn(binding, key)
        dynamic([], ^f != field(parent_as(^pb), ^pf))

      {op_g, {:parent_as, {pb, pf}}} when op_g in @comparison_operators ->
        f = field_dyn(binding, key)
        apply_parent_as_comparison(op_g, f, pb, pf, :plain)

      {:not, {op_g, {:parent_as, {pb, pf}}}} when op_g in @comparison_operators ->
        f = field_dyn(binding, key)
        apply_parent_as_comparison(op_g, f, pb, pf, :negated)

      # Generic scalar fallback (catches any remaining value)
      {:not, {op_g, v}} when op_g in @comparison_operators ->
        f = field_dyn(binding, key)
        apply_scalar_comparison(op_g, f, v, :negated)

      {op_g, v} when op_g in @comparison_operators ->
        f = field_dyn(binding, key)
        apply_scalar_comparison(op_g, f, v, :plain)

      _ ->
        nil
    end
  end

  defp agg_field_dyn(binding, key, :avg), do: avg_field_dyn(binding, key)
  defp agg_field_dyn(binding, key, :count), do: count_field_dyn(binding, key)
  defp agg_field_dyn(binding, key, :max), do: max_field_dyn(binding, key)
  defp agg_field_dyn(binding, key, :min), do: min_field_dyn(binding, key)
  defp agg_field_dyn(binding, key, :sum), do: sum_field_dyn(binding, key)

  defp apply_scalar_comparison(:==, f, v, :plain), do: dynamic([], ^f == ^v)
  defp apply_scalar_comparison(:==, f, v, :negated), do: dynamic([], ^f != ^v)
  defp apply_scalar_comparison(:!=, f, v, :plain), do: dynamic([], ^f != ^v)
  defp apply_scalar_comparison(:!=, f, v, :negated), do: dynamic([], ^f == ^v)
  defp apply_scalar_comparison(:>, f, v, :plain), do: dynamic([], ^f > ^v)
  defp apply_scalar_comparison(:>, f, v, :negated), do: dynamic([], not (^f > ^v))
  defp apply_scalar_comparison(:>=, f, v, :plain), do: dynamic([], ^f >= ^v)
  defp apply_scalar_comparison(:>=, f, v, :negated), do: dynamic([], not (^f >= ^v))
  defp apply_scalar_comparison(:<, f, v, :plain), do: dynamic([], ^f < ^v)
  defp apply_scalar_comparison(:<, f, v, :negated), do: dynamic([], not (^f < ^v))
  defp apply_scalar_comparison(:<=, f, v, :plain), do: dynamic([], ^f <= ^v)
  defp apply_scalar_comparison(:<=, f, v, :negated), do: dynamic([], not (^f <= ^v))

  defp apply_parent_as_comparison(:==, f, pb, pf, :plain),
    do: dynamic([], ^f == field(parent_as(^pb), ^pf))

  defp apply_parent_as_comparison(:==, f, pb, pf, :negated),
    do: dynamic([], ^f != field(parent_as(^pb), ^pf))

  defp apply_parent_as_comparison(:!=, f, pb, pf, :plain),
    do: dynamic([], ^f != field(parent_as(^pb), ^pf))

  defp apply_parent_as_comparison(:!=, f, pb, pf, :negated),
    do: dynamic([], ^f == field(parent_as(^pb), ^pf))

  defp apply_parent_as_comparison(:>, f, pb, pf, :plain),
    do: dynamic([], ^f > field(parent_as(^pb), ^pf))

  defp apply_parent_as_comparison(:>, f, pb, pf, :negated),
    do: dynamic([], not (^f > field(parent_as(^pb), ^pf)))

  defp apply_parent_as_comparison(:>=, f, pb, pf, :plain),
    do: dynamic([], ^f >= field(parent_as(^pb), ^pf))

  defp apply_parent_as_comparison(:>=, f, pb, pf, :negated),
    do: dynamic([], not (^f >= field(parent_as(^pb), ^pf)))

  defp apply_parent_as_comparison(:<, f, pb, pf, :plain),
    do: dynamic([], ^f < field(parent_as(^pb), ^pf))

  defp apply_parent_as_comparison(:<, f, pb, pf, :negated),
    do: dynamic([], not (^f < field(parent_as(^pb), ^pf)))

  defp apply_parent_as_comparison(:<=, f, pb, pf, :plain),
    do: dynamic([], ^f <= field(parent_as(^pb), ^pf))

  defp apply_parent_as_comparison(:<=, f, pb, pf, :negated),
    do: dynamic([], not (^f <= field(parent_as(^pb), ^pf)))

  defp apply_arith_comparison(:==, f, f2, :+, v, :plain), do: dynamic([], ^f == ^f2 + ^v)
  defp apply_arith_comparison(:==, f, f2, :+, v, :negated), do: dynamic([], not (^f == ^f2 + ^v))
  defp apply_arith_comparison(:!=, f, f2, :+, v, :plain), do: dynamic([], ^f != ^f2 + ^v)
  defp apply_arith_comparison(:!=, f, f2, :+, v, :negated), do: dynamic([], not (^f != ^f2 + ^v))
  defp apply_arith_comparison(:>, f, f2, :+, v, :plain), do: dynamic([], ^f > ^f2 + ^v)
  defp apply_arith_comparison(:>, f, f2, :+, v, :negated), do: dynamic([], not (^f > ^f2 + ^v))
  defp apply_arith_comparison(:>=, f, f2, :+, v, :plain), do: dynamic([], ^f >= ^f2 + ^v)
  defp apply_arith_comparison(:>=, f, f2, :+, v, :negated), do: dynamic([], not (^f >= ^f2 + ^v))
  defp apply_arith_comparison(:<, f, f2, :+, v, :plain), do: dynamic([], ^f < ^f2 + ^v)
  defp apply_arith_comparison(:<, f, f2, :+, v, :negated), do: dynamic([], not (^f < ^f2 + ^v))
  defp apply_arith_comparison(:<=, f, f2, :+, v, :plain), do: dynamic([], ^f <= ^f2 + ^v)
  defp apply_arith_comparison(:<=, f, f2, :+, v, :negated), do: dynamic([], not (^f <= ^f2 + ^v))
  defp apply_arith_comparison(:==, f, f2, :-, v, :plain), do: dynamic([], ^f == ^f2 - ^v)
  defp apply_arith_comparison(:==, f, f2, :-, v, :negated), do: dynamic([], not (^f == ^f2 - ^v))
  defp apply_arith_comparison(:!=, f, f2, :-, v, :plain), do: dynamic([], ^f != ^f2 - ^v)
  defp apply_arith_comparison(:!=, f, f2, :-, v, :negated), do: dynamic([], not (^f != ^f2 - ^v))
  defp apply_arith_comparison(:>, f, f2, :-, v, :plain), do: dynamic([], ^f > ^f2 - ^v)
  defp apply_arith_comparison(:>, f, f2, :-, v, :negated), do: dynamic([], not (^f > ^f2 - ^v))
  defp apply_arith_comparison(:>=, f, f2, :-, v, :plain), do: dynamic([], ^f >= ^f2 - ^v)
  defp apply_arith_comparison(:>=, f, f2, :-, v, :negated), do: dynamic([], not (^f >= ^f2 - ^v))
  defp apply_arith_comparison(:<, f, f2, :-, v, :plain), do: dynamic([], ^f < ^f2 - ^v)
  defp apply_arith_comparison(:<, f, f2, :-, v, :negated), do: dynamic([], not (^f < ^f2 - ^v))
  defp apply_arith_comparison(:<=, f, f2, :-, v, :plain), do: dynamic([], ^f <= ^f2 - ^v)
  defp apply_arith_comparison(:<=, f, f2, :-, v, :negated), do: dynamic([], not (^f <= ^f2 - ^v))
  defp apply_arith_comparison(:==, f, f2, :*, v, :plain), do: dynamic([], ^f == ^f2 * ^v)
  defp apply_arith_comparison(:==, f, f2, :*, v, :negated), do: dynamic([], not (^f == ^f2 * ^v))
  defp apply_arith_comparison(:!=, f, f2, :*, v, :plain), do: dynamic([], ^f != ^f2 * ^v)
  defp apply_arith_comparison(:!=, f, f2, :*, v, :negated), do: dynamic([], not (^f != ^f2 * ^v))
  defp apply_arith_comparison(:>, f, f2, :*, v, :plain), do: dynamic([], ^f > ^f2 * ^v)
  defp apply_arith_comparison(:>, f, f2, :*, v, :negated), do: dynamic([], not (^f > ^f2 * ^v))
  defp apply_arith_comparison(:>=, f, f2, :*, v, :plain), do: dynamic([], ^f >= ^f2 * ^v)
  defp apply_arith_comparison(:>=, f, f2, :*, v, :negated), do: dynamic([], not (^f >= ^f2 * ^v))
  defp apply_arith_comparison(:<, f, f2, :*, v, :plain), do: dynamic([], ^f < ^f2 * ^v)
  defp apply_arith_comparison(:<, f, f2, :*, v, :negated), do: dynamic([], not (^f < ^f2 * ^v))
  defp apply_arith_comparison(:<=, f, f2, :*, v, :plain), do: dynamic([], ^f <= ^f2 * ^v)
  defp apply_arith_comparison(:<=, f, f2, :*, v, :negated), do: dynamic([], not (^f <= ^f2 * ^v))
  defp apply_arith_comparison(:==, f, f2, :/, v, :plain), do: dynamic([], ^f == ^f2 / ^v)
  defp apply_arith_comparison(:==, f, f2, :/, v, :negated), do: dynamic([], not (^f == ^f2 / ^v))
  defp apply_arith_comparison(:!=, f, f2, :/, v, :plain), do: dynamic([], ^f != ^f2 / ^v)
  defp apply_arith_comparison(:!=, f, f2, :/, v, :negated), do: dynamic([], not (^f != ^f2 / ^v))
  defp apply_arith_comparison(:>, f, f2, :/, v, :plain), do: dynamic([], ^f > ^f2 / ^v)
  defp apply_arith_comparison(:>, f, f2, :/, v, :negated), do: dynamic([], not (^f > ^f2 / ^v))
  defp apply_arith_comparison(:>=, f, f2, :/, v, :plain), do: dynamic([], ^f >= ^f2 / ^v)
  defp apply_arith_comparison(:>=, f, f2, :/, v, :negated), do: dynamic([], not (^f >= ^f2 / ^v))
  defp apply_arith_comparison(:<, f, f2, :/, v, :plain), do: dynamic([], ^f < ^f2 / ^v)
  defp apply_arith_comparison(:<, f, f2, :/, v, :negated), do: dynamic([], not (^f < ^f2 / ^v))
  defp apply_arith_comparison(:<=, f, f2, :/, v, :plain), do: dynamic([], ^f <= ^f2 / ^v)
  defp apply_arith_comparison(:<=, f, f2, :/, v, :negated), do: dynamic([], not (^f <= ^f2 / ^v))

  defp apply_datetime_comparison(binding, key, op, :datetime, :ago, params, mode) do
    count = Keyword.fetch!(params, :count)
    interval = Keyword.fetch!(params, :interval)
    f = field_dyn(binding, key)
    expr = dynamic([], ^f)
    rhs = dynamic([], ago(^count, ^interval))
    apply_dyn_comparison(op, expr, rhs, mode)
  end

  defp apply_datetime_comparison(binding, key, op, :datetime, :from_now, params, mode) do
    count = Keyword.fetch!(params, :count)
    interval = Keyword.fetch!(params, :interval)
    f = field_dyn(binding, key)
    expr = dynamic([], ^f)
    rhs = dynamic([], from_now(^count, ^interval))
    apply_dyn_comparison(op, expr, rhs, mode)
  end

  defp apply_datetime_comparison(binding, key, op, :datetime, :add, params, mode) do
    field_name = Keyword.get(params, :field)
    count = Keyword.fetch!(params, :count)
    interval = Keyword.fetch!(params, :interval)
    f = field_dyn(binding, key)
    f2 = field_dyn(binding, field_name)
    rhs = dynamic([], datetime_add(^f2, ^count, ^interval))
    apply_dyn_comparison(op, dynamic([], ^f), rhs, mode)
  end

  defp apply_datetime_comparison(binding, key, op, :date, :ago, params, mode) do
    count = Keyword.fetch!(params, :count)
    interval = Keyword.fetch!(params, :interval)
    f = date_field_dyn(binding, key)
    rhs = dynamic([], fragment("date(?)", ago(^count, ^interval)))
    apply_dyn_comparison(op, dynamic([], ^f), rhs, mode)
  end

  defp apply_datetime_comparison(binding, key, op, :date, :from_now, params, mode) do
    count = Keyword.fetch!(params, :count)
    interval = Keyword.fetch!(params, :interval)
    f = date_field_dyn(binding, key)
    rhs = dynamic([], fragment("date(?)", from_now(^count, ^interval)))
    apply_dyn_comparison(op, dynamic([], ^f), rhs, mode)
  end

  defp apply_datetime_comparison(binding, key, op, :date, :add, params, mode) do
    field_name = Keyword.get(params, :field)
    count = Keyword.fetch!(params, :count)
    interval = Keyword.fetch!(params, :interval)
    f = date_field_dyn(binding, key)
    f2 = field_dyn(binding, field_name)
    rhs = dynamic([], fragment("date(?)", datetime_add(^f2, ^count, ^interval)))
    apply_dyn_comparison(op, dynamic([], ^f), rhs, mode)
  end

  defp apply_dyn_comparison(:==, lhs, rhs, :plain), do: dynamic([], ^lhs == ^rhs)
  defp apply_dyn_comparison(:==, lhs, rhs, :negated), do: dynamic([], ^lhs != ^rhs)
  defp apply_dyn_comparison(:!=, lhs, rhs, :plain), do: dynamic([], ^lhs != ^rhs)
  defp apply_dyn_comparison(:!=, lhs, rhs, :negated), do: dynamic([], ^lhs == ^rhs)
  defp apply_dyn_comparison(:>, lhs, rhs, :plain), do: dynamic([], ^lhs > ^rhs)
  defp apply_dyn_comparison(:>, lhs, rhs, :negated), do: dynamic([], not (^lhs > ^rhs))
  defp apply_dyn_comparison(:>=, lhs, rhs, :plain), do: dynamic([], ^lhs >= ^rhs)
  defp apply_dyn_comparison(:>=, lhs, rhs, :negated), do: dynamic([], not (^lhs >= ^rhs))
  defp apply_dyn_comparison(:<, lhs, rhs, :plain), do: dynamic([], ^lhs < ^rhs)
  defp apply_dyn_comparison(:<, lhs, rhs, :negated), do: dynamic([], not (^lhs < ^rhs))
  defp apply_dyn_comparison(:<=, lhs, rhs, :plain), do: dynamic([], ^lhs <= ^rhs)
  defp apply_dyn_comparison(:<=, lhs, rhs, :negated), do: dynamic([], not (^lhs <= ^rhs))

  def dynamic_expr(_selected_binding, _key, _negated, _term, _opts), do: nil

  defp family_for(:in, _term), do: :membership

  defp family_for(op, value) when op in @equality_operators and is_list(value) do
    :membership
  end

  defp family_for(op, {transform, _term})
       when op in @comparison_operators and transform in [:lower, :upper] do
    :string_transform
  end

  defp family_for(op, term) when op in @string_operators do
    case term do
      {transform, _term} when transform in [:lower, :upper] ->
        :string_transform

      _ ->
        :string
    end
  end

  defp family_for(_op, _term), do: :comparison

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
