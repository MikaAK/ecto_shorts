defmodule EctoShorts.DynamicBuilders.Postgres.ScalarExpr.Comparison do
  @moduledoc false
  @moduledoc since: "3.0.0"

  alias EctoShorts.DynamicBuilders.Postgres.FieldAccessors
  alias EctoShorts.DynamicBuilders.Postgres.ScalarExpr.Aggregate

  import Ecto.Query

  @aggregate_helpers [:avg, :count, :max, :min, :sum]
  @comparison_operators [:>, :>=, :<, :<=, :==, :!=]

  # Entry point: receives the raw (negated, op, value) from dispatch_expr and
  # folds negation before routing to a comparison sub-family body.
  # The term-classification predicates live here alongside comparison_impl
  # because they are only used within the comparison family — keeping them in
  # ScalarExpr would require ScalarExpr to call back into this module for each
  # sub-family dispatch, adding indirection without benefit.
  def build(binding, key, negated, {op, value}) do
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

  # ── Term-classification predicates ─────────────────────────────────────────

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

  # ── Comparison bodies ───────────────────────────────────────────────────────

  # scalar_comparison receives the already-negation-folded `term`.
  # Nil checks
  defp scalar_comparison(binding, key, {:==, nil}) do
    f = FieldAccessors.field_dyn(binding, key)
    dynamic([], is_nil(^f))
  end

  defp scalar_comparison(binding, key, {:not, {:==, nil}}) do
    f = FieldAccessors.field_dyn(binding, key)
    dynamic([], not is_nil(^f))
  end

  defp scalar_comparison(binding, key, {:!=, nil}) do
    f = FieldAccessors.field_dyn(binding, key)
    dynamic([], not is_nil(^f))
  end

  defp scalar_comparison(binding, key, {:not, {:!=, nil}}) do
    f = FieldAccessors.field_dyn(binding, key)
    dynamic([], is_nil(^f))
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
    f = FieldAccessors.field_dyn(binding, key)
    dynamic([], ^f == ^v)
  end

  defp scalar_comparison(binding, key, {:not, {:==, v}}) when not is_tuple(v) do
    f = FieldAccessors.field_dyn(binding, key)
    dynamic([], ^f != ^v)
  end

  defp scalar_comparison(binding, key, {:!=, v}) when not is_tuple(v) do
    f = FieldAccessors.field_dyn(binding, key)
    dynamic([], ^f != ^v)
  end

  defp scalar_comparison(binding, key, {:not, {:!=, v}}) when not is_tuple(v) do
    f = FieldAccessors.field_dyn(binding, key)
    dynamic([], ^f == ^v)
  end

  defp scalar_comparison(binding, key, {:>, v}) when not is_tuple(v) do
    f = FieldAccessors.field_dyn(binding, key)
    dynamic([], ^f > ^v)
  end

  defp scalar_comparison(binding, key, {:not, {:>, v}}) when not is_tuple(v) do
    f = FieldAccessors.field_dyn(binding, key)
    dynamic([], not (^f > ^v))
  end

  defp scalar_comparison(binding, key, {:>=, v}) when not is_tuple(v) do
    f = FieldAccessors.field_dyn(binding, key)
    dynamic([], ^f >= ^v)
  end

  defp scalar_comparison(binding, key, {:not, {:>=, v}}) when not is_tuple(v) do
    f = FieldAccessors.field_dyn(binding, key)
    dynamic([], not (^f >= ^v))
  end

  defp scalar_comparison(binding, key, {:<, v}) when not is_tuple(v) do
    f = FieldAccessors.field_dyn(binding, key)
    dynamic([], ^f < ^v)
  end

  defp scalar_comparison(binding, key, {:not, {:<, v}}) when not is_tuple(v) do
    f = FieldAccessors.field_dyn(binding, key)
    dynamic([], not (^f < ^v))
  end

  defp scalar_comparison(binding, key, {:<=, v}) when not is_tuple(v) do
    f = FieldAccessors.field_dyn(binding, key)
    dynamic([], ^f <= ^v)
  end

  defp scalar_comparison(binding, key, {:not, {:<=, v}}) when not is_tuple(v) do
    f = FieldAccessors.field_dyn(binding, key)
    dynamic([], not (^f <= ^v))
  end

  # Quantified comparisons (all / any)
  defp quantified_comparison(binding, key, {:==, {:all, qv}}) do
    f = FieldAccessors.field_dyn(binding, key)
    dynamic([], ^f == all(qv))
  end

  defp quantified_comparison(binding, key, {:not, {:==, {:all, qv}}}) do
    f = FieldAccessors.field_dyn(binding, key)
    dynamic([], not (^f == all(qv)))
  end

  defp quantified_comparison(binding, key, {:==, {:any, qv}}) do
    f = FieldAccessors.field_dyn(binding, key)
    dynamic([], ^f == any(qv))
  end

  defp quantified_comparison(binding, key, {:not, {:==, {:any, qv}}}) do
    f = FieldAccessors.field_dyn(binding, key)
    dynamic([], not (^f == any(qv)))
  end

  defp quantified_comparison(binding, key, {:!=, {:all, qv}}) do
    f = FieldAccessors.field_dyn(binding, key)
    dynamic([], ^f != all(qv))
  end

  defp quantified_comparison(binding, key, {:not, {:!=, {:all, qv}}}) do
    f = FieldAccessors.field_dyn(binding, key)
    dynamic([], not (^f != all(qv)))
  end

  defp quantified_comparison(binding, key, {:!=, {:any, qv}}) do
    f = FieldAccessors.field_dyn(binding, key)
    dynamic([], ^f != any(qv))
  end

  defp quantified_comparison(binding, key, {:not, {:!=, {:any, qv}}}) do
    f = FieldAccessors.field_dyn(binding, key)
    dynamic([], not (^f != any(qv)))
  end

  defp quantified_comparison(binding, key, {:>, {:all, qv}}) do
    f = FieldAccessors.field_dyn(binding, key)
    dynamic([], ^f > all(qv))
  end

  defp quantified_comparison(binding, key, {:not, {:>, {:all, qv}}}) do
    f = FieldAccessors.field_dyn(binding, key)
    dynamic([], not (^f > all(qv)))
  end

  defp quantified_comparison(binding, key, {:>, {:any, qv}}) do
    f = FieldAccessors.field_dyn(binding, key)
    dynamic([], ^f > any(qv))
  end

  defp quantified_comparison(binding, key, {:not, {:>, {:any, qv}}}) do
    f = FieldAccessors.field_dyn(binding, key)
    dynamic([], not (^f > any(qv)))
  end

  defp quantified_comparison(binding, key, {:>=, {:all, qv}}) do
    f = FieldAccessors.field_dyn(binding, key)
    dynamic([], ^f >= all(qv))
  end

  defp quantified_comparison(binding, key, {:not, {:>=, {:all, qv}}}) do
    f = FieldAccessors.field_dyn(binding, key)
    dynamic([], not (^f >= all(qv)))
  end

  defp quantified_comparison(binding, key, {:>=, {:any, qv}}) do
    f = FieldAccessors.field_dyn(binding, key)
    dynamic([], ^f >= any(qv))
  end

  defp quantified_comparison(binding, key, {:not, {:>=, {:any, qv}}}) do
    f = FieldAccessors.field_dyn(binding, key)
    dynamic([], not (^f >= any(qv)))
  end

  defp quantified_comparison(binding, key, {:<, {:all, qv}}) do
    f = FieldAccessors.field_dyn(binding, key)
    dynamic([], ^f < all(qv))
  end

  defp quantified_comparison(binding, key, {:not, {:<, {:all, qv}}}) do
    f = FieldAccessors.field_dyn(binding, key)
    dynamic([], not (^f < all(qv)))
  end

  defp quantified_comparison(binding, key, {:<, {:any, qv}}) do
    f = FieldAccessors.field_dyn(binding, key)
    dynamic([], ^f < any(qv))
  end

  defp quantified_comparison(binding, key, {:not, {:<, {:any, qv}}}) do
    f = FieldAccessors.field_dyn(binding, key)
    dynamic([], not (^f < any(qv)))
  end

  defp quantified_comparison(binding, key, {:<=, {:all, qv}}) do
    f = FieldAccessors.field_dyn(binding, key)
    dynamic([], ^f <= all(qv))
  end

  defp quantified_comparison(binding, key, {:not, {:<=, {:all, qv}}}) do
    f = FieldAccessors.field_dyn(binding, key)
    dynamic([], not (^f <= all(qv)))
  end

  defp quantified_comparison(binding, key, {:<=, {:any, qv}}) do
    f = FieldAccessors.field_dyn(binding, key)
    dynamic([], ^f <= any(qv))
  end

  defp quantified_comparison(binding, key, {:not, {:<=, {:any, qv}}}) do
    f = FieldAccessors.field_dyn(binding, key)
    dynamic([], not (^f <= any(qv)))
  end

  # Aggregate comparisons — delegated to Scalar.Aggregate
  defp aggregate_comparison(binding, key, term) do
    Aggregate.build(binding, key, term)
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
    f2 = FieldAccessors.field_dyn(binding, field_name)
    dynamic([], ^f >= fragment("date(?)", datetime_add(^f2, ^count, ^interval)))
  end

  defp datetime_comparison(binding, key, {:>=, {:datetime, {:add, params}}}) do
    field_name = Keyword.get(params, :field)
    count = Keyword.fetch!(params, :count)
    interval = Keyword.fetch!(params, :interval)
    f = FieldAccessors.field_dyn(binding, key)
    f2 = FieldAccessors.field_dyn(binding, field_name)
    dynamic([], ^f >= datetime_add(^f2, ^count, ^interval))
  end

  defp datetime_comparison(binding, key, {:not, {:>=, {:datetime, {:add, params}}}}) do
    field_name = Keyword.get(params, :field)
    count = Keyword.fetch!(params, :count)
    interval = Keyword.fetch!(params, :interval)
    f = FieldAccessors.field_dyn(binding, key)
    f2 = FieldAccessors.field_dyn(binding, field_name)
    dynamic([], not (^f >= datetime_add(^f2, ^count, ^interval)))
  end

  defp datetime_comparison(binding, key, {:>, {:datetime, {:ago, params}}}) do
    count = Keyword.fetch!(params, :count)
    interval = Keyword.fetch!(params, :interval)
    f = FieldAccessors.field_dyn(binding, key)
    dynamic([], ^f > ago(^count, ^interval))
  end

  defp datetime_comparison(binding, key, {:>, {:datetime, {:from_now, params}}}) do
    count = Keyword.fetch!(params, :count)
    interval = Keyword.fetch!(params, :interval)
    f = FieldAccessors.field_dyn(binding, key)
    dynamic([], ^f > from_now(^count, ^interval))
  end

  defp datetime_comparison(binding, key, {:not, {:<, {:datetime, {:ago, params}}}}) do
    count = Keyword.fetch!(params, :count)
    interval = Keyword.fetch!(params, :interval)
    f = FieldAccessors.field_dyn(binding, key)
    dynamic([], not (^f < ago(^count, ^interval)))
  end

  defp datetime_comparison(binding, key, {:<, {:datetime, {:ago, params}}}) do
    count = Keyword.fetch!(params, :count)
    interval = Keyword.fetch!(params, :interval)
    f = FieldAccessors.field_dyn(binding, key)
    dynamic([], ^f < ago(^count, ^interval))
  end

  defp datetime_comparison(binding, key, {:<=, {:datetime, {:from_now, params}}}) do
    count = Keyword.fetch!(params, :count)
    interval = Keyword.fetch!(params, :interval)
    f = FieldAccessors.field_dyn(binding, key)
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
    f = FieldAccessors.field_dyn(binding, key)
    f2 = FieldAccessors.field_dyn(binding, af)
    apply_arith_comparison(op_a, f, f2, arith_op, av, :plain)
  end

  defp arithmetic_comparison(
         binding,
         key,
         {:not, {op_a, {:value, {arith_op, {{:field, af}, {:value, av}}}}}}
       )
       when op_a in @comparison_operators and arith_op in [:+, :-, :*, :/] and is_atom(af) and
              af !== nil do
    f = FieldAccessors.field_dyn(binding, key)
    f2 = FieldAccessors.field_dyn(binding, af)
    apply_arith_comparison(op_a, f, f2, arith_op, av, :negated)
  end

  # New operand comparisons: field/sibling reference and binary arithmetic.
  defp operand_comparison(binding, key, {op, rhs}) when op in @comparison_operators do
    lhs = FieldAccessors.field_dyn(binding, key)
    apply_dyn_comparison(op, lhs, comparison_rhs(binding, rhs), :plain)
  end

  defp operand_comparison(binding, key, {:not, {op, rhs}}) when op in @comparison_operators do
    lhs = FieldAccessors.field_dyn(binding, key)
    apply_dyn_comparison(op, lhs, comparison_rhs(binding, rhs), :negated)
  end

  defp operand_dyn(binding, {:field, {bind, col}}) when bind !== nil do
    _ = binding
    dynamic([], field(as(^bind), ^col))
  end

  defp operand_dyn(binding, {:field, col}), do: FieldAccessors.field_dyn(binding, col)
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
    f = FieldAccessors.field_dyn(binding, key)
    dynamic([], ^f == field(parent_as(^pb), ^pf))
  end

  defp parent_as_comparison(binding, key, {:not, {:parent_as, {pb, pf}}}) do
    f = FieldAccessors.field_dyn(binding, key)
    dynamic([], ^f != field(parent_as(^pb), ^pf))
  end

  defp parent_as_comparison(binding, key, {op_g, {:parent_as, {pb, pf}}})
       when op_g in @comparison_operators do
    f = FieldAccessors.field_dyn(binding, key)
    apply_parent_as_comparison(op_g, f, pb, pf, :plain)
  end

  defp parent_as_comparison(binding, key, {:not, {op_g, {:parent_as, {pb, pf}}}})
       when op_g in @comparison_operators do
    f = FieldAccessors.field_dyn(binding, key)
    apply_parent_as_comparison(op_g, f, pb, pf, :negated)
  end

  # Value wrapper (unwraps plain scalar/field references)
  defp scalar_value_fallback(binding, key, {:not, {op_v, {:value, v}}})
       when op_v in @comparison_operators do
    f = FieldAccessors.field_dyn(binding, key)
    apply_scalar_comparison(op_v, f, v, :negated)
  end

  defp scalar_value_fallback(binding, key, {op_v, {:value, v}}) when op_v in @comparison_operators do
    f = FieldAccessors.field_dyn(binding, key)
    apply_scalar_comparison(op_v, f, v, :plain)
  end

  # Generic scalar fallback (catches any remaining value)
  defp scalar_value_fallback(binding, key, {:not, {op_g, v}}) when op_g in @comparison_operators do
    f = FieldAccessors.field_dyn(binding, key)
    apply_scalar_comparison(op_g, f, v, :negated)
  end

  defp scalar_value_fallback(binding, key, {op_g, v}) when op_g in @comparison_operators do
    f = FieldAccessors.field_dyn(binding, key)
    apply_scalar_comparison(op_g, f, v, :plain)
  end

  defp scalar_value_fallback(_binding, _key, _term), do: nil

  defp date_field_dyn(binding, key) do
    f = FieldAccessors.field_dyn(binding, key)
    dynamic([], fragment("date(?)", ^f))
  end

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
    f = FieldAccessors.field_dyn(binding, key)
    expr = dynamic([], ^f)
    rhs = dynamic([], ago(^count, ^interval))
    apply_dyn_comparison(op, expr, rhs, mode)
  end

  defp apply_datetime_comparison(binding, key, op, :datetime, :from_now, params, mode) do
    count = Keyword.fetch!(params, :count)
    interval = Keyword.fetch!(params, :interval)
    f = FieldAccessors.field_dyn(binding, key)
    expr = dynamic([], ^f)
    rhs = dynamic([], from_now(^count, ^interval))
    apply_dyn_comparison(op, expr, rhs, mode)
  end

  defp apply_datetime_comparison(binding, key, op, :datetime, :add, params, mode) do
    field_name = Keyword.get(params, :field)
    count = Keyword.fetch!(params, :count)
    interval = Keyword.fetch!(params, :interval)
    f = FieldAccessors.field_dyn(binding, key)
    f2 = FieldAccessors.field_dyn(binding, field_name)
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
    f2 = FieldAccessors.field_dyn(binding, field_name)
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
end
