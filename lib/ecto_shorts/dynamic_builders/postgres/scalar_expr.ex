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
  @string_transforms [:lower, :upper, :trim, :ltrim, :rtrim]

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

    defp trim_field_dyn(unquote(quoted_binding_head), unquote(key_var)) do
      dynamic(
        [unquote_splicing(quoted_binding_body)],
        fragment("trim(?)", field(unquote(target_binding_var), ^unquote(key_var)))
      )
    end

    defp ltrim_field_dyn(unquote(quoted_binding_head), unquote(key_var)) do
      dynamic(
        [unquote_splicing(quoted_binding_body)],
        fragment("ltrim(?)", field(unquote(target_binding_var), ^unquote(key_var)))
      )
    end

    defp rtrim_field_dyn(unquote(quoted_binding_head), unquote(key_var)) do
      dynamic(
        [unquote_splicing(quoted_binding_body)],
        fragment("rtrim(?)", field(unquote(target_binding_var), ^unquote(key_var)))
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
        field(unquote(target_binding_var), ^unquote(key_var)) not in ^values
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
        membership_in_dyn(binding, key, values)

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

  # comparison_impl keeps the term-building, then routes by operand family.
  defp comparison_impl(binding, key, negated, {op, value}) do
    term = if negated === :not, do: {:not, {op, value}}, else: {op, value}

    cond do
      nil_or_scalar?(term) -> scalar_comparison(binding, key, term)
      quantified?(term) -> quantified_comparison(binding, key, term)
      aggregate?(term) -> aggregate_comparison(binding, key, term)
      datetime?(term) -> datetime_comparison(binding, key, term)
      arithmetic?(term) -> arithmetic_comparison(binding, key, term)
      operand?(term) -> operand_comparison(binding, key, term)
      parent_as?(term) -> parent_as_comparison(binding, key, term)
      true -> scalar_value_fallback(binding, key, term)
    end
  end

  defp datetime?({op, {wrapper, {datetime_op, _}}})
       when op in @comparison_operators and wrapper in [:datetime, :date] and
              datetime_op in [:ago, :from_now, :add, :shift],
       do: true

  defp datetime?({:not, {op, {wrapper, {datetime_op, _}}}})
       when op in @comparison_operators and wrapper in [:datetime, :date] and
              datetime_op in [:ago, :from_now, :add, :shift],
       do: true

  defp datetime?(_), do: false

  defp arithmetic?({op, {:value, {arith_op, {{:field, af}, {:value, _}}}}})
       when op in @comparison_operators and arith_op in [:+, :-, :*, :/] and is_atom(af) and
              af !== nil,
       do: true

  defp arithmetic?({:not, {op, {:value, {arith_op, {{:field, af}, {:value, _}}}}}})
       when op in @comparison_operators and arith_op in [:+, :-, :*, :/] and is_atom(af) and
              af !== nil,
       do: true

  defp arithmetic?(_), do: false

  # New operand shapes (spec §1.5a): a field/sibling reference, or a binary
  # arithmetic expression with ordered-array operands.
  defp operand?({op, rhs}) when op in @comparison_operators, do: operand_rhs?(rhs)
  defp operand?({:not, {op, rhs}}) when op in @comparison_operators, do: operand_rhs?(rhs)
  defp operand?(_), do: false

  defp operand_rhs?({:field, col}) when is_atom(col) and col !== nil, do: true
  defp operand_rhs?({:field, {_b, col}}) when is_atom(col) and col !== nil, do: true

  defp operand_rhs?({sym, [_a, _b]}) when sym in [:+, :-, :*, :/], do: true
  defp operand_rhs?(_), do: false

  defp parent_as?({:parent_as, {_pb, _pf}}), do: true
  defp parent_as?({:not, {:parent_as, {_pb, _pf}}}), do: true

  defp parent_as?({op, {:parent_as, {_pb, _pf}}}) when op in @comparison_operators, do: true

  defp parent_as?({:not, {op, {:parent_as, {_pb, _pf}}}}) when op in @comparison_operators,
    do: true

  defp parent_as?(_), do: false

  defp quantified?({_op, {q, _}}) when q in [:all, :any], do: true
  defp quantified?({:not, {_op, {q, _}}}) when q in [:all, :any], do: true
  defp quantified?(_), do: false

  defp aggregate?({h, {_op, _}}) when h in @aggregate_helpers, do: true
  defp aggregate?({:not, {h, {_op, _}}}) when h in @aggregate_helpers, do: true
  defp aggregate?(_), do: false

  # Family predicate: nil checks and scalar (non-tuple value) comparisons.
  defp nil_or_scalar?({op, v}) when op in [:==, :!=] and (is_nil(v) or not is_tuple(v)), do: true

  defp nil_or_scalar?({:not, {op, v}}) when op in [:==, :!=] and (is_nil(v) or not is_tuple(v)),
    do: true

  defp nil_or_scalar?({op, v}) when op in [:>, :>=, :<, :<=] and not is_tuple(v), do: true
  defp nil_or_scalar?({:not, {op, v}}) when op in [:>, :>=, :<, :<=] and not is_tuple(v), do: true
  defp nil_or_scalar?(_), do: false

  # scalar_comparison receives the already-negation-folded `term`.
  # Nil checks
  defp scalar_comparison(binding, key, {:==, nil}) do
    nil_field_dyn?(binding, key)
  end

  defp scalar_comparison(binding, key, {:not, {:==, nil}}) do
    not_nil_dyn(binding, key)
  end

  defp scalar_comparison(binding, key, {:!=, nil}) do
    not_nil_dyn(binding, key)
  end

  defp scalar_comparison(binding, key, {:not, {:!=, nil}}) do
    nil_field_dyn?(binding, key)
  end

  # Ordering operators cannot be compared to nil (only :== / :!= accept nil).
  defp scalar_comparison(_binding, _key, {op, nil}) when op in [:>, :>=, :<, :<=] do
    raise EctoShorts.FilterError, "#{op} cannot be compared to nil"
  end

  defp scalar_comparison(_binding, _key, {:not, {op, nil}}) when op in [:>, :>=, :<, :<=] do
    raise EctoShorts.FilterError, "#{op} cannot be compared to nil"
  end

  # Scalar comparisons
  defp scalar_comparison(binding, key, {:==, v}) when not is_tuple(v) do
    f = field_dyn(binding, key)
    dynamic([], ^f == ^v)
  end

  defp scalar_comparison(binding, key, {:not, {:==, v}}) when not is_tuple(v) do
    f = field_dyn(binding, key)
    dynamic([], ^f != ^v)
  end

  defp scalar_comparison(binding, key, {:!=, v}) when not is_tuple(v) do
    f = field_dyn(binding, key)
    dynamic([], ^f != ^v)
  end

  defp scalar_comparison(binding, key, {:not, {:!=, v}}) when not is_tuple(v) do
    f = field_dyn(binding, key)
    dynamic([], ^f == ^v)
  end

  defp scalar_comparison(binding, key, {:>, v}) when not is_tuple(v) do
    f = field_dyn(binding, key)
    dynamic([], ^f > ^v)
  end

  defp scalar_comparison(binding, key, {:not, {:>, v}}) when not is_tuple(v) do
    f = field_dyn(binding, key)
    dynamic([], not (^f > ^v))
  end

  defp scalar_comparison(binding, key, {:>=, v}) when not is_tuple(v) do
    f = field_dyn(binding, key)
    dynamic([], ^f >= ^v)
  end

  defp scalar_comparison(binding, key, {:not, {:>=, v}}) when not is_tuple(v) do
    f = field_dyn(binding, key)
    dynamic([], not (^f >= ^v))
  end

  defp scalar_comparison(binding, key, {:<, v}) when not is_tuple(v) do
    f = field_dyn(binding, key)
    dynamic([], ^f < ^v)
  end

  defp scalar_comparison(binding, key, {:not, {:<, v}}) when not is_tuple(v) do
    f = field_dyn(binding, key)
    dynamic([], not (^f < ^v))
  end

  defp scalar_comparison(binding, key, {:<=, v}) when not is_tuple(v) do
    f = field_dyn(binding, key)
    dynamic([], ^f <= ^v)
  end

  defp scalar_comparison(binding, key, {:not, {:<=, v}}) when not is_tuple(v) do
    f = field_dyn(binding, key)
    dynamic([], not (^f <= ^v))
  end

  # Quantified comparisons (all / any)
  defp quantified_comparison(binding, key, {:==, {:all, qv}}) do
    f = field_dyn(binding, key)
    dynamic([], ^f == all(qv))
  end

  defp quantified_comparison(binding, key, {:not, {:==, {:all, qv}}}) do
    f = field_dyn(binding, key)
    dynamic([], not (^f == all(qv)))
  end

  defp quantified_comparison(binding, key, {:==, {:any, qv}}) do
    f = field_dyn(binding, key)
    dynamic([], ^f == any(qv))
  end

  defp quantified_comparison(binding, key, {:not, {:==, {:any, qv}}}) do
    f = field_dyn(binding, key)
    dynamic([], not (^f == any(qv)))
  end

  defp quantified_comparison(binding, key, {:!=, {:all, qv}}) do
    f = field_dyn(binding, key)
    dynamic([], ^f != all(qv))
  end

  defp quantified_comparison(binding, key, {:not, {:!=, {:all, qv}}}) do
    f = field_dyn(binding, key)
    dynamic([], not (^f != all(qv)))
  end

  defp quantified_comparison(binding, key, {:!=, {:any, qv}}) do
    f = field_dyn(binding, key)
    dynamic([], ^f != any(qv))
  end

  defp quantified_comparison(binding, key, {:not, {:!=, {:any, qv}}}) do
    f = field_dyn(binding, key)
    dynamic([], not (^f != any(qv)))
  end

  defp quantified_comparison(binding, key, {:>, {:all, qv}}) do
    f = field_dyn(binding, key)
    dynamic([], ^f > all(qv))
  end

  defp quantified_comparison(binding, key, {:not, {:>, {:all, qv}}}) do
    f = field_dyn(binding, key)
    dynamic([], not (^f > all(qv)))
  end

  defp quantified_comparison(binding, key, {:>, {:any, qv}}) do
    f = field_dyn(binding, key)
    dynamic([], ^f > any(qv))
  end

  defp quantified_comparison(binding, key, {:not, {:>, {:any, qv}}}) do
    f = field_dyn(binding, key)
    dynamic([], not (^f > any(qv)))
  end

  defp quantified_comparison(binding, key, {:>=, {:all, qv}}) do
    f = field_dyn(binding, key)
    dynamic([], ^f >= all(qv))
  end

  defp quantified_comparison(binding, key, {:not, {:>=, {:all, qv}}}) do
    f = field_dyn(binding, key)
    dynamic([], not (^f >= all(qv)))
  end

  defp quantified_comparison(binding, key, {:>=, {:any, qv}}) do
    f = field_dyn(binding, key)
    dynamic([], ^f >= any(qv))
  end

  defp quantified_comparison(binding, key, {:not, {:>=, {:any, qv}}}) do
    f = field_dyn(binding, key)
    dynamic([], not (^f >= any(qv)))
  end

  defp quantified_comparison(binding, key, {:<, {:all, qv}}) do
    f = field_dyn(binding, key)
    dynamic([], ^f < all(qv))
  end

  defp quantified_comparison(binding, key, {:not, {:<, {:all, qv}}}) do
    f = field_dyn(binding, key)
    dynamic([], not (^f < all(qv)))
  end

  defp quantified_comparison(binding, key, {:<, {:any, qv}}) do
    f = field_dyn(binding, key)
    dynamic([], ^f < any(qv))
  end

  defp quantified_comparison(binding, key, {:not, {:<, {:any, qv}}}) do
    f = field_dyn(binding, key)
    dynamic([], not (^f < any(qv)))
  end

  defp quantified_comparison(binding, key, {:<=, {:all, qv}}) do
    f = field_dyn(binding, key)
    dynamic([], ^f <= all(qv))
  end

  defp quantified_comparison(binding, key, {:not, {:<=, {:all, qv}}}) do
    f = field_dyn(binding, key)
    dynamic([], not (^f <= all(qv)))
  end

  defp quantified_comparison(binding, key, {:<=, {:any, qv}}) do
    f = field_dyn(binding, key)
    dynamic([], ^f <= any(qv))
  end

  defp quantified_comparison(binding, key, {:not, {:<=, {:any, qv}}}) do
    f = field_dyn(binding, key)
    dynamic([], not (^f <= any(qv)))
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

  # Datetime comparisons - interval is already a ^-pinned runtime var after Phase 1
  defp datetime_comparison(binding, key, {:==, {:date, {:ago, params}}}) do
    count = Keyword.fetch!(params, :count)
    interval = Keyword.fetch!(params, :interval)
    f = date_field_dyn(binding, key)
    dynamic([], ^f == fragment("date(?)", ago(^count, ^interval)))
  end

  defp datetime_comparison(binding, key, {:!=, {:date, {:from_now, params}}}) do
    count = Keyword.fetch!(params, :count)
    interval = Keyword.fetch!(params, :interval)
    f = date_field_dyn(binding, key)
    dynamic([], ^f != fragment("date(?)", from_now(^count, ^interval)))
  end

  defp datetime_comparison(binding, key, {:not, {:>, {:date, {:from_now, params}}}}) do
    count = Keyword.fetch!(params, :count)
    interval = Keyword.fetch!(params, :interval)
    f = date_field_dyn(binding, key)
    dynamic([], not (^f > fragment("date(?)", from_now(^count, ^interval))))
  end

  defp datetime_comparison(binding, key, {:>=, {:date, {:add, params}}}) do
    field_name = Keyword.get(params, :field)
    count = Keyword.fetch!(params, :count)
    interval = Keyword.fetch!(params, :interval)
    f = date_field_dyn(binding, key)
    f2 = field_dyn(binding, field_name)
    dynamic([], ^f >= fragment("date(?)", datetime_add(^f2, ^count, ^interval)))
  end

  defp datetime_comparison(binding, key, {:>=, {:datetime, {:add, params}}}) do
    field_name = Keyword.get(params, :field)
    count = Keyword.fetch!(params, :count)
    interval = Keyword.fetch!(params, :interval)
    f = field_dyn(binding, key)
    f2 = field_dyn(binding, field_name)
    dynamic([], ^f >= datetime_add(^f2, ^count, ^interval))
  end

  defp datetime_comparison(binding, key, {:not, {:>=, {:datetime, {:add, params}}}}) do
    field_name = Keyword.get(params, :field)
    count = Keyword.fetch!(params, :count)
    interval = Keyword.fetch!(params, :interval)
    f = field_dyn(binding, key)
    f2 = field_dyn(binding, field_name)
    dynamic([], not (^f >= datetime_add(^f2, ^count, ^interval)))
  end

  defp datetime_comparison(binding, key, {:>, {:datetime, {:ago, params}}}) do
    count = Keyword.fetch!(params, :count)
    interval = Keyword.fetch!(params, :interval)
    f = field_dyn(binding, key)
    dynamic([], ^f > ago(^count, ^interval))
  end

  defp datetime_comparison(binding, key, {:>, {:datetime, {:from_now, params}}}) do
    count = Keyword.fetch!(params, :count)
    interval = Keyword.fetch!(params, :interval)
    f = field_dyn(binding, key)
    dynamic([], ^f > from_now(^count, ^interval))
  end

  defp datetime_comparison(binding, key, {:not, {:<, {:datetime, {:ago, params}}}}) do
    count = Keyword.fetch!(params, :count)
    interval = Keyword.fetch!(params, :interval)
    f = field_dyn(binding, key)
    dynamic([], not (^f < ago(^count, ^interval)))
  end

  defp datetime_comparison(binding, key, {:<, {:datetime, {:ago, params}}}) do
    count = Keyword.fetch!(params, :count)
    interval = Keyword.fetch!(params, :interval)
    f = field_dyn(binding, key)
    dynamic([], ^f < ago(^count, ^interval))
  end

  defp datetime_comparison(binding, key, {:<=, {:datetime, {:from_now, params}}}) do
    count = Keyword.fetch!(params, :count)
    interval = Keyword.fetch!(params, :interval)
    f = field_dyn(binding, key)
    dynamic([], ^f <= from_now(^count, ^interval))
  end

  defp datetime_comparison(binding, key, {:<, {:date, {:ago, params}}}) do
    count = Keyword.fetch!(params, :count)
    interval = Keyword.fetch!(params, :interval)
    f = date_field_dyn(binding, key)
    dynamic([], ^f < fragment("date(?)", ago(^count, ^interval)))
  end

  # Generic datetime - all ops × {datetime,date} × {ago,from_now,add}
  defp datetime_comparison(binding, key, {op_d, {wrapper, {datetime_op, params}}})
       when op_d in @comparison_operators and wrapper in [:datetime, :date] and
              datetime_op in [:ago, :from_now, :add, :shift] do
    apply_datetime_comparison(binding, key, op_d, wrapper, datetime_op, params, :plain)
  end

  defp datetime_comparison(binding, key, {:not, {op_d, {wrapper, {datetime_op, params}}}})
       when op_d in @comparison_operators and wrapper in [:datetime, :date] and
              datetime_op in [:ago, :from_now, :add, :shift] do
    apply_datetime_comparison(binding, key, op_d, wrapper, datetime_op, params, :negated)
  end

  # Arithmetic: field OP field ARITH_OP value
  defp arithmetic_comparison(binding, key, {op_a, {:value, {arith_op, {{:field, af}, {:value, av}}}}})
       when op_a in @comparison_operators and arith_op in [:+, :-, :*, :/] and is_atom(af) and
              af !== nil do
    f = field_dyn(binding, key)
    f2 = field_dyn(binding, af)
    apply_arith_comparison(op_a, f, f2, arith_op, av, :plain)
  end

  defp arithmetic_comparison(
         binding,
         key,
         {:not, {op_a, {:value, {arith_op, {{:field, af}, {:value, av}}}}}}
       )
       when op_a in @comparison_operators and arith_op in [:+, :-, :*, :/] and is_atom(af) and
              af !== nil do
    f = field_dyn(binding, key)
    f2 = field_dyn(binding, af)
    apply_arith_comparison(op_a, f, f2, arith_op, av, :negated)
  end

  # New operand comparisons: field/sibling reference and binary arithmetic.
  defp operand_comparison(binding, key, {op, rhs}) when op in @comparison_operators do
    lhs = field_dyn(binding, key)
    apply_dyn_comparison(op, lhs, comparison_rhs(binding, rhs), :plain)
  end

  defp operand_comparison(binding, key, {:not, {op, rhs}}) when op in @comparison_operators do
    lhs = field_dyn(binding, key)
    apply_dyn_comparison(op, lhs, comparison_rhs(binding, rhs), :negated)
  end

  defp operand_dyn(binding, {:field, {bind, col}}) when bind !== nil do
    _ = binding
    dynamic([], field(as(^bind), ^col))
  end

  defp operand_dyn(binding, {:field, col}), do: field_dyn(binding, col)
  defp operand_dyn(_binding, {:value, v}), do: dynamic([], ^v)

  defp comparison_rhs(binding, {:field, _} = f), do: operand_dyn(binding, f)

  defp comparison_rhs(binding, {sym, [a, b]}) when sym in [:+, :-, :*, :/] do
    da = operand_dyn(binding, a)
    db = operand_dyn(binding, b)

    case sym do
      :+ -> dynamic([], ^da + ^db)
      :- -> dynamic([], ^da - ^db)
      :* -> dynamic([], ^da * ^db)
      :/ -> dynamic([], ^da / ^db)
    end
  end

  # parent_as: compare current binding field against a field on a named parent binding
  defp parent_as_comparison(binding, key, {:parent_as, {pb, pf}}) do
    f = field_dyn(binding, key)
    dynamic([], ^f == field(parent_as(^pb), ^pf))
  end

  defp parent_as_comparison(binding, key, {:not, {:parent_as, {pb, pf}}}) do
    f = field_dyn(binding, key)
    dynamic([], ^f != field(parent_as(^pb), ^pf))
  end

  defp parent_as_comparison(binding, key, {op_g, {:parent_as, {pb, pf}}})
       when op_g in @comparison_operators do
    f = field_dyn(binding, key)
    apply_parent_as_comparison(op_g, f, pb, pf, :plain)
  end

  defp parent_as_comparison(binding, key, {:not, {op_g, {:parent_as, {pb, pf}}}})
       when op_g in @comparison_operators do
    f = field_dyn(binding, key)
    apply_parent_as_comparison(op_g, f, pb, pf, :negated)
  end

  # Value wrapper (unwraps plain scalar/field references)
  defp scalar_value_fallback(binding, key, {:not, {op_v, {:value, v}}})
       when op_v in @comparison_operators do
    f = field_dyn(binding, key)
    apply_scalar_comparison(op_v, f, v, :negated)
  end

  defp scalar_value_fallback(binding, key, {op_v, {:value, v}}) when op_v in @comparison_operators do
    f = field_dyn(binding, key)
    apply_scalar_comparison(op_v, f, v, :plain)
  end

  # Generic scalar fallback (catches any remaining value)
  defp scalar_value_fallback(binding, key, {:not, {op_g, v}}) when op_g in @comparison_operators do
    f = field_dyn(binding, key)
    apply_scalar_comparison(op_g, f, v, :negated)
  end

  defp scalar_value_fallback(binding, key, {op_g, v}) when op_g in @comparison_operators do
    f = field_dyn(binding, key)
    apply_scalar_comparison(op_g, f, v, :plain)
  end

  defp scalar_value_fallback(_binding, _key, _term), do: nil

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

  # :shift is the canonical date-math word — same datetime_add SQL as :add.
  defp apply_datetime_comparison(binding, key, op, :datetime, :shift, params, mode) do
    apply_datetime_comparison(binding, key, op, :datetime, :add, params, mode)
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

  defp apply_datetime_comparison(binding, key, op, :date, :shift, params, mode) do
    apply_datetime_comparison(binding, key, op, :date, :add, params, mode)
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
