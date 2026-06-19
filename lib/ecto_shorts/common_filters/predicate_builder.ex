defmodule EctoShorts.CommonFilters.PredicateBuilder do
  @moduledoc """
  Dialect-agnostic translator: turns one caller value-test into one or more
  `%EctoShorts.CommonFilters.Predicate{}`. Pure — no SQL, no query building.
  See the spec §2.2/§2.3.
  """

  require Logger
  alias EctoShorts.{CommonSchema, Types}
  alias EctoShorts.CommonFilters.Predicate

  @comparison_ops [:==, :!=, :>, :>=, :<, :<=]
  @aggregate_ops [:avg, :count, :max, :min, :sum]
  @text_transforms [:lower, :upper, :trim, :ltrim, :rtrim]
  @string_ops [:like, :ilike]
  @list_ops [:in, :nin, :overlaps]
  @date_math_ops [:ago, :from_now, :shift]
  @arith %{add: :+, subtract: :-, multiply: :*, divide: :/}

  # Canonical operator atoms recognized from the wire (as strings).
  @operator_atoms @comparison_ops ++
                    @aggregate_ops ++
                    @text_transforms ++
                    @string_ops ++
                    @list_ops ++
                    @date_math_ops

  @op_aliases %{
    eq: :==,
    ne: :!=,
    gt: :>,
    gte: :>=,
    lt: :<,
    lte: :<=,
    downcase: :lower,
    upcase: :upper
  }

  # Compile-time closed map: operator string -> canonical atom.
  @string_to_op (for(op <- @operator_atoms, into: %{}, do: {Atom.to_string(op), op}))
                |> Map.merge(for {a, c} <- @op_aliases, into: %{}, do: {Atom.to_string(a), c})

  @doc "Canonicalize an operator from an atom (nickname or canonical) or a wire string."
  @spec canonical_op(atom() | binary()) :: atom()
  def canonical_op(op) when is_atom(op), do: Map.get(@op_aliases, op, op)
  def canonical_op(op) when is_binary(op), do: Map.get(@string_to_op, op, :__unknown__)

  @doc "Resolve a column name to a checked atom, or :skip (with a warning)."
  @spec resolve_field(term(), atom() | binary(), keyword()) :: {:ok, atom()} | :skip
  def resolve_field(_source, field, _opts) when is_atom(field) and not is_nil(field) do
    {:ok, field}
  end

  def resolve_field(source, field, opts) when is_binary(field) do
    schema = CommonSchema.get_schema(source)

    cond do
      not is_nil(schema) ->
        fields = CommonSchema.get_schema_reflection(source, :fields) || []

        if field in Enum.map(fields, &Atom.to_string/1) do
          {:ok, String.to_existing_atom(field)}
        else
          warn_skip("Field #{inspect(field)} does not exist on schema #{inspect(schema)}, skipping")
        end

      allowed = opts[:allowed_keys] ->
        if field in Enum.map(allowed, &to_string/1) do
          {:ok, String.to_atom(field)}
        else
          warn_skip("Field #{inspect(field)} is not in the :allowed_keys list, skipping")
        end

      true ->
        warn_skip("Field #{inspect(field)} cannot be resolved: no schema or :allowed_keys, skipping")
    end
  end

  defp warn_skip(message) do
    Logger.warning(message)
    :skip
  end

  @doc "Decide which SQL helper handles a field: :scalar | :array | :map."
  @spec routing_family(term(), atom(), keyword()) :: :scalar | :array | :map
  def routing_family(source, field, opts) do
    type =
      get_in(opts, [:field_types, field]) ||
        field_types_lookup(opts[:field_types], field) ||
        CommonSchema.get_schema_reflection(source, :type, field)

    case type do
      {:array, _} -> :array
      :map -> :map
      {:map, _} -> :map
      _ -> :scalar
    end
  end

  defp field_types_lookup(nil, _field), do: nil
  defp field_types_lookup(types, field) when is_list(types), do: Keyword.get(types, field)
  defp field_types_lookup(types, field) when is_map(types), do: Map.get(types, field)

  @doc "Convert a value (or list of values) to the column's type. Values only."
  @spec cast(term() | nil, term()) :: term()
  def cast(nil, value), do: value
  def cast(_type, nil), do: nil
  def cast({:array, inner}, values) when is_list(values), do: Enum.map(values, &Types.cast(inner, &1))
  def cast(type, values) when is_list(values), do: Enum.map(values, &Types.cast(type, &1))
  def cast(type, value), do: Types.cast(type, value)

  @doc """
  Turn one field's value-test into a LIST of canonical tidied terms (the caller
  ANDs them), or :skip if the field can't be used.

  A value map may carry several operator entries — `%{gt: 21, lte: 65}` means two
  conditions — so we **reduce over the entries** (Enum.reduce works directly on a
  map or keyword list) and never assume a single pair.
  """
  @spec build(term(), atom() | binary(), term(), keyword()) ::
          {:ok, [%Predicate{field: atom(), routing: atom(), negated: boolean(), expr: term()}]} | :skip
  def build(source, key, raw_term, opts) do
    case resolve_field(source, key, opts) do
      :skip ->
        :skip

      {:ok, field} ->
        routing = operator_routing(raw_term) || routing_family(source, field, opts)
        type = field_type(source, field, opts)
        {negated, inner} = lift_negation(raw_term)

        exprs = build_terms(inner, type)
        {:ok, Enum.map(exprs, &%Predicate{field: field, routing: routing, negated: negated, expr: &1})}
    end
  end

  # Operator-driven routing: a few operators force the :array family regardless
  # of the known column type (spec §2.3). `overlaps` is array-overlap; list
  # `count` and array quantifiers are added with their operators.
  @array_operators [:overlaps]

  defp operator_routing(raw_term) do
    {_negated, inner} = lift_negation(raw_term)

    cond do
      (is_map(inner) and not is_struct(inner)) or Keyword.keyword?(inner) ->
        if Enum.any?(inner, fn {raw_op, _v} -> canonical_op(raw_op) in @array_operators end),
          do: :array,
          else: nil

      true ->
        nil
    end
  end

  defp field_type(source, field, opts) do
    field_types_lookup(opts[:field_types], field) ||
      CommonSchema.get_schema_reflection(source, :type, field)
  end

  # --- negation -----------------------------------------------------------
  # `not` wraps a single inner test. (A `not` over a multi-operator map needs
  # De Morgan — flagged for §3.11/Plan 04; the common case is one operator.)
  defp lift_negation(%{not: inner}), do: toggle(lift_negation(inner))
  defp lift_negation(term), do: {false, term}
  defp toggle({negated, term}), do: {not negated, term}

  # --- term building: reduce a value into a LIST of tidied terms -----------
  # Each operator entry contributes one (or more) tidied term; we fold over all
  # of them. Bare scalar/list/nil are single terms.
  defp build_terms(nil, _type), do: [{:==, nil}]

  defp build_terms(term, type) do
    cond do
      is_map(term) and not is_struct(term) -> reduce_ops(term, type)
      Keyword.keyword?(term) and term != [] -> reduce_ops(term, type)
      is_list(term) -> [{:==, cast(type, term)}]   # bare list = eq (D-LIST)
      true -> [{:==, cast(type, term)}]             # bare scalar = eq
    end
  end

  # Enum.reduce works directly on a map or a keyword list — no Map.to_list.
  defp reduce_ops(entries, type) do
    Enum.reduce(entries, [], fn {raw_op, val}, acc ->
      acc ++ build_one(canonical_op(raw_op), val, type)
    end)
  end

  # build_one returns a LIST (usually one term, [] to skip).
  defp build_one(:__unknown__, _val, _type) do
    warn_skip("Unknown operator, skipping")
    []
  end

  # nil checks (no cast)
  defp build_one(op, nil, _type) when op in [:==, :!=], do: [{op, nil}]

  # aggregates: each inner comparison becomes {agg, {op, value}}
  defp build_one(agg, inner, type) when agg in @aggregate_ops do
    Enum.map(compares(inner, type), fn cmp -> {agg, cmp} end)
  end

  # date-math RHS: a wrapper map carrying :date or :datetime. Recognize by key
  # access (not a singleton Map.to_list match) and reduce the inner op map.
  defp build_one(op, %{date: w}, _type) when op in @comparison_ops, do: dt_term(op, :date, w)

  defp build_one(op, %{datetime: w}, _type) when op in @comparison_ops,
    do: dt_term(op, :datetime, w)

  # Bare date-math op (no date/datetime wrapper) defaults to :datetime.
  defp build_one(op, %{} = w, _type)
       when op in @comparison_ops and is_map_key(w, :ago)
       when op in @comparison_ops and is_map_key(w, :from_now)
       when op in @comparison_ops and is_map_key(w, :shift),
       do: dt_term(op, :datetime, w)

  # operand maps on the RHS of a comparison (recognized by key, not a singleton
  # match): a literal value, or a field reference (optionally on a sibling
  # binding via `as:`). See spec §1.5a/§3.11.
  defp build_one(op, %{value: v}, type) when op in @comparison_ops do
    [{op, {:value, cast(type, v)}}]
  end

  defp build_one(op, %{field: _} = m, _type) when op in @comparison_ops do
    [{op, {:field, field_ref(m)}}]
  end

  # arithmetic operand: exactly one arith key whose value is a 2-element operand
  # list. Recognized by an explicit Enum.filter over the known arith keys (never
  # a singleton Map.to_list match). Falls through to the transform branch when no
  # arith key is present. Placed after value/field/date-math, before scalar.
  defp build_one(op, %{} = m, type) when op in @comparison_ops do
    case Enum.filter(Map.keys(@arith), &Map.has_key?(m, &1)) do
      [arith] ->
        case Map.fetch!(m, arith) do
          [a, b] ->
            [{op, {Map.fetch!(@arith, arith), [operand(a, type), operand(b, type)]}}]

          _ ->
            raise EctoShorts.FilterError, "arithmetic takes exactly two operands"
        end

      [] ->
        build_one_transform(op, m, type)

      _many ->
        raise EctoShorts.FilterError,
              "expected a single arithmetic operator, got: #{inspect(Map.keys(m))}"
    end
  end

  # like/ilike with auto-wrap
  defp build_one(op, pattern, _type) when op in @string_ops and is_binary(pattern),
    do: [{op, wrap_like(pattern)}]

  defp build_one(op, patterns, _type) when op in @string_ops and is_list(patterns),
    do: [{op, Enum.map(patterns, &wrap_like/1)}]

  # overlaps: explicit array-overlap operator (D-LIST)
  defp build_one(:overlaps, list, type) when is_list(list),
    do: [{:overlaps, cast(type, list)}]

  # membership / eq-ne with a list (routing decides meaning downstream)
  defp build_one(op, list, type) when op in [:in, :nin, :==, :!=] and is_list(list),
    do: [{op, cast(type, list)}]

  # scalar comparison
  defp build_one(op, value, type) when op in @comparison_ops,
    do: [{op, cast(type, value)}]

  defp build_one(_op, _value, _type) do
    warn_skip("Unsupported operator/value, skipping")
    []
  end

  # text transforms on the value side: %{lower: v} (reduced, in case of several).
  defp build_one_transform(op, %{} = inner, _type) when op in [:==, :!=] do
    Enum.reduce(inner, [], fn {raw_t, v}, acc ->
      case canonical_op(raw_t) do
        t when t in @text_transforms -> acc ++ [{op, {t, v}}]
        _ -> (warn_skip("Unknown transform, skipping"); acc)
      end
    end)
  end

  defp build_one_transform(_op, _inner, _type) do
    warn_skip("Unsupported operator/value, skipping")
    []
  end

  # Reduce a comparison value (map/keyword) into a list of {canonical_op, value}.
  defp compares(value, type) do
    cond do
      (is_map(value) and not is_struct(value)) or Keyword.keyword?(value) ->
        Enum.reduce(value, [], fn {raw_op, v}, acc ->
          case canonical_op(raw_op) do
            op when op in @comparison_ops and is_nil(v) -> acc ++ [{op, nil}]
            op when op in @comparison_ops -> acc ++ [{op, cast(type, v)}]
            _ -> (warn_skip("Unknown comparison in aggregate, skipping"); acc)
          end
        end)

      true ->
        warn_skip("Aggregate expects a comparison map, skipping")
        []
    end
  end

  # A field operand may target the current binding (an atom) or a sibling
  # binding (`as:` — recorded as {binding, field}; validated later, §3.11).
  defp field_ref(%{field: f, as: b}), do: {b, f}
  defp field_ref(%{field: f}), do: f

  # operand of an arithmetic expression: a field reference or a literal value.
  defp operand(%{field: _} = m, _type), do: {:field, field_ref(m)}
  defp operand(%{value: v}, type), do: {:value, cast(type, v)}

  @date_units ~w(second minute hour day week month year)

  # w is %{ago | from_now | shift => params}; reduce so multiple/zero entries
  # don't crash — each recognized date-math op yields one tidied term.
  defp dt_term(op, wrapper, w) do
    Enum.reduce(w, [], fn {raw_dt_op, params}, acc ->
      case canonical_op(raw_dt_op) do
        dt_op when dt_op in @date_math_ops ->
          acc ++ [{op, {wrapper, {dt_op, dt_keyword(params)}}}]

        _ ->
          warn_skip("Unknown date-math op, skipping")
          acc
      end
    end)
  end

  defp dt_keyword(%{} = p) do
    unit = p[:unit] || p["unit"] || p[:interval] || p["interval"]

    unless to_string(unit) in @date_units do
      raise EctoShorts.FilterError, "unknown date unit #{inspect(unit)}"
    end

    kw = [count: p[:count] || p["count"], interval: to_string(unit)]

    case p[:field] || p["field"] do
      nil -> kw
      f -> kw ++ [field: f]
    end
  end

  defp wrap_like(pattern) when is_binary(pattern) do
    if String.contains?(pattern, ["%", "_"]), do: pattern, else: "%#{pattern}%"
  end
end
