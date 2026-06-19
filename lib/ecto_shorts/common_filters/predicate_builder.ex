defmodule EctoShorts.CommonFilters.PredicateBuilder do
  @moduledoc """
  Dialect-agnostic translator: turns one caller value-test into one or more
  `%EctoShorts.CommonFilters.Predicate{}`. Pure — no SQL, no query building.
  See the spec §2.2/§2.3.
  """

  alias EctoShorts.{CommonSchema, LogUtils, Types}
  alias EctoShorts.CommonFilters.Predicate

  @logger_prefix "EctoShorts.CommonFilters.PredicateBuilder"

  @comparison_ops [:==, :!=, :>, :>=, :<, :<=]
  @aggregate_ops [:avg, :count, :max, :min, :sum]
  @text_transforms [:lower, :upper, :trim, :ltrim, :rtrim]
  @string_ops [:like, :ilike]
  @list_ops [:in, :nin, :overlaps]
  @date_math_ops [:ago, :from_now, :shift, :add]
  @map_ops [:contains, :contained_by, :has_key, :has_any_key, :has_all_keys]
  @quantifier_ops [:all, :any]
  # Both word forms (:add) and symbol forms (:+) name an arithmetic operand.
  @arith_keys %{
    add: :+,
    subtract: :-,
    multiply: :*,
    divide: :/,
    +: :+,
    -: :-,
    *: :*,
    /: :/
  }

  # Canonical operator atoms recognized from the wire (as strings).
  @operator_atoms @comparison_ops ++
                    @aggregate_ops ++
                    @text_transforms ++
                    @string_ops ++
                    @list_ops ++
                    @date_math_ops ++
                    @map_ops

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
  def resolve_field(source, field, _opts) when is_atom(field) and not is_nil(field) do
    case CommonSchema.get_schema_reflection(source, :fields) do
      fields when is_list(fields) ->
        if field in fields do
          {:ok, field}
        else
          warn_skip(
            "Field #{inspect(Atom.to_string(field))} does not exist on schema #{inspect(CommonSchema.get_schema(source))}, skipping"
          )
        end

      _ ->
        {:ok, field}
    end
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
        # No schema and no :allowed_keys to validate against. Best-effort: only
        # resolve to an atom that already exists (so untrusted input can never
        # mint a new atom), and skip if it does not.
        try do
          {:ok, String.to_existing_atom(field)}
        rescue
          ArgumentError ->
            warn_skip(
              "Field #{inspect(field)} cannot be resolved: no schema or :allowed_keys, skipping"
            )
        end
    end
  end

  defp warn_skip(message) do
    LogUtils.warning(@logger_prefix, message)
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
  # Shorthand keys are the *operator* (top-level key), not a value-map operator.
  # They resolve to an implied column and route to the :common family. The
  # implied-column map lives here so the dialect Expr modules stay pure.
  @id_shorthands [:ids, :before, :after, :since, :until]
  @date_shorthands [:start_date, :end_date, :since_date, :until_date]

  @spec build(term(), atom() | binary(), term(), keyword()) ::
          {:ok, [Predicate.t()]} | :skip
  def build(_source, key, value, _opts) when key in @id_shorthands do
    {:ok, [%Predicate{field: :id, routing: :common, negated: false, expr: {key, value}}]}
  end

  def build(_source, key, value, _opts) when key in @date_shorthands do
    {:ok, [%Predicate{field: :inserted_at, routing: :common, negated: false, expr: {key, value}}]}
  end

  def build(_source, :exists, value, _opts) do
    {:ok, [%Predicate{field: nil, routing: :common, negated: false, expr: {:exists, value}}]}
  end

  def build(source, key, raw_term, opts) do
    case resolve_field(source, key, opts) do
      :skip ->
        :skip

      {:ok, field} ->
        routing = operator_routing(raw_term) || routing_family(source, field, opts)
        type = field_type(source, field, opts)
        {negated, inner} = lift_negation(raw_term)

        exprs = build_terms(inner, type)

        predicates =
          exprs
          |> Enum.map(&resolve_expr_fields(&1, source, opts))
          |> Enum.reject(&(&1 === :skip))
          |> Enum.map(&%Predicate{field: field, routing: routing, negated: negated, expr: &1})

        {:ok, predicates}
    end
  end

  # Operator-driven routing: a few operators force the :array family regardless
  # of the known column type (spec §2.3). `overlaps` is array-overlap; list
  # `count` and array quantifiers are added with their operators.
  @array_operators [:overlaps]

  defp operator_routing(raw_term) do
    {_negated, inner} = lift_negation(raw_term)

    if (is_map(inner) and not is_struct(inner)) or Keyword.keyword?(inner) do
      if Enum.any?(inner, fn {raw_op, _v} ->
           raw_op === :array or canonical_op(raw_op) in @array_operators
         end),
         do: :array,
         else: nil
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
  defp lift_negation({:not, inner}), do: toggle(lift_negation(inner))
  defp lift_negation(term), do: {false, term}
  defp toggle({negated, term}), do: {not negated, term}

  # --- term building: reduce a value into a LIST of tidied terms -----------
  # Each operator entry contributes one (or more) tidied term; we fold over all
  # of them. Bare scalar/list/nil are single terms.
  defp build_terms(nil, _type), do: [{:==, nil}]

  # A bare operator tuple, e.g. `{:>, 18}` or `{:in, [..]}`, is one operator
  # entry (the keyword-list form de-sugared to a single pair).
  defp build_terms({raw_op, val}, type) when is_atom(raw_op) do
    case canonical_op(raw_op) do
      :__unknown__ -> [{:==, cast(type, {raw_op, val})}]
      op -> build_one(op, val, type)
    end
  end

  defp build_terms(term, type) do
    cond do
      is_map(term) and not is_struct(term) -> reduce_ops(term, type)
      Keyword.keyword?(term) and term !== [] -> reduce_ops(term, type)
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
    inner
    |> compares(type)
    |> Enum.map(fn cmp -> {agg, cmp} end)
  end

  # Top-level text transform: %{lower: "x"} means equality against the
  # transformed column. Emit {:==, {:lower, "x"}} — ScalarExpr does
  # `lower(col) == x`; ArrayExpr unnests and lower()-compares each element.
  defp build_one(t, value, _type) when t in [:lower, :upper] and is_binary(value),
    do: [{:==, {t, value}}]

  # `:array` wrapper forces array semantics (used on schemaless sources with
  # no type info). It unwraps to the inner operator term(s) consumed by ArrayExpr.
  defp build_one(:array, nil, _type), do: [{:==, nil}]

  defp build_one(:array, %{} = inner, type) when not is_struct(inner) do
    Enum.reduce(inner, [], fn {raw_op, v}, acc -> acc ++ elements_term(canonical_op(raw_op), v, type) end)
  end

  defp build_one(:array, list, type) when is_list(list), do: [{:==, cast(type, list)}]
  defp build_one(:array, scalar, type), do: [{:in, cast(type, scalar)}]

  # Quantified subquery, default equality: %{all: %{from: Src, where: ...}} →
  # {:==, {:all, {:subquery, src, select, where}}}. Select defaults to the outer
  # column (filled by the adapter from the predicate field) unless overridden.
  defp build_one(q, %{from: src} = spec, _type) when q in @quantifier_ops do
    [{:==, {q, subquery_spec(src, spec)}}]
  end

  # Quantified subquery under a comparison: %{>: %{all: %{from: ...}}}.
  defp build_one(op, %{all: %{from: src} = spec}, _type) when op in @comparison_ops do
    [{op, {:all, subquery_spec(src, spec)}}]
  end

  defp build_one(op, %{any: %{from: src} = spec}, _type) when op in @comparison_ops do
    [{op, {:any, subquery_spec(src, spec)}}]
  end

  # Array quantifier operators: %{all: %{>: "a"}} / %{all: %{in: [...]}} →
  # {:all, {op, value}} consumed by ArrayExpr. Reduce the inner comparison map.
  defp build_one(q, inner, type) when q in @quantifier_ops do
    if (is_map(inner) and not is_struct(inner)) or Keyword.keyword?(inner) do
      Enum.reduce(inner, [], fn {raw_op, v}, acc ->
        op = canonical_op(raw_op)
        cond do
          op in @comparison_ops -> acc ++ [{q, {op, cast(type, v)}}]
          op === :in and is_list(v) -> acc ++ [{q, {:in, cast(type, v)}}]
          true ->
            warn_skip("Unknown quantifier comparison, skipping")
            acc
        end
      end)
    else
      [{q, inner}]
    end
  end

  # JSONB containment from a single-key map → {:contains, {k, v}}; a multi-key
  # map / keyword list ANDs into one tuple per pair (consumed by MapExpr).
  defp build_one(op, %{} = m, _type)
       when op in [:contains, :contained_by] and not is_struct(m) do
    Enum.map(m, fn {k, v} -> {op, {k, v}} end)
  end

  defp build_one(op, kw, _type) when op in [:contains, :contained_by] and is_list(kw) do
    if Keyword.keyword?(kw) do
      Enum.map(kw, fn {k, v} -> {op, {k, v}} end)
    else
      [{op, kw}]
    end
  end

  defp build_one(op, value, _type) when op in [:contains, :contained_by] and is_binary(value),
    do: [{op, value}]

  # JSONB key-existence operators pass their key(s) straight through.
  defp build_one(:has_key, value, _type), do: [{:has_key, value}]
  defp build_one(:has_any_key, values, _type) when is_list(values), do: [{:has_any_key, values}]
  defp build_one(:has_all_keys, values, _type) when is_list(values), do: [{:has_all_keys, values}]

  # bare parent-binding field reference: %{parent_as: %{binding: field}}
  defp build_one(:parent_as, %{} = m, _type) when not is_struct(m) do
    Enum.map(m, fn {b, f} -> {:parent_as, {b, f}} end)
  end

  # comparison against a parent-binding field: %{>: %{parent_as: %{b: f}}}
  defp build_one(op, %{parent_as: %{} = pb}, _type) when op in @comparison_ops do
    Enum.map(pb, fn {b, f} -> {op, {:parent_as, {b, f}}} end)
  end

  # date-math RHS: a wrapper map carrying :date or :datetime. Recognize by key
  # access (not a singleton Map.to_list match) and reduce the inner op map.
  defp build_one(op, %{date: w}, _type) when op in @comparison_ops, do: dt_term(op, :date, w)

  defp build_one(op, %{datetime: w}, _type) when op in @comparison_ops,
    do: dt_term(op, :datetime, w)

  # Bare date-math op (no date/datetime wrapper) defaults to :datetime.
  defp build_one(op, %{} = w, _type)
       when op in @comparison_ops and not is_struct(w) and is_map_key(w, :ago)
       when op in @comparison_ops and not is_struct(w) and is_map_key(w, :from_now)
       when op in @comparison_ops and not is_struct(w) and is_map_key(w, :shift),
       do: dt_term(op, :datetime, w)

  # operand maps on the RHS of a comparison (recognized by key, not a singleton
  # match): a literal value, or a field reference (optionally on a sibling
  # binding via `as:`). See spec §1.5a/§3.11.
  # A `value:` wrapper whose contents is itself an arithmetic operand map
  # (e.g. `%{value: %{+: [%{field: "views"}, %{value: 10}]}}`) is a computed RHS,
  # not a literal — recurse so the arithmetic clause builds it.
  defp build_one(op, %{value: %{} = v}, type)
       when op in @comparison_ops and not is_struct(v) do
    if @arith_keys |> Map.keys() |> Enum.any?(&Map.has_key?(v, &1)) do
      build_one(op, v, type)
    else
      [{op, {:value, cast(type, v)}}]
    end
  end

  defp build_one(op, %{value: v}, type) when op in @comparison_ops do
    [{op, {:value, cast(type, v)}}]
  end

  # explicit {:value, v} / {:field, name} operand tuples
  defp build_one(op, {:value, v}, type) when op in @comparison_ops do
    [{op, {:value, cast(type, v)}}]
  end

  defp build_one(op, {:field, name}, _type) when op in @comparison_ops do
    [{op, {:field, name}}]
  end

  defp build_one(op, %{field: _} = m, _type) when op in @comparison_ops do
    [{op, {:field, field_ref(m)}}]
  end

  # arithmetic operand: exactly one arith key whose value is a 2-element operand
  # list. Recognized by an explicit Enum.filter over the known arith keys (never
  # a singleton Map.to_list match). Falls through to the transform branch when no
  # arith key is present. Placed after value/field/date-math, before scalar.
  defp build_one(op, %{} = m, type) when op in @comparison_ops and not is_struct(m) do
    case @arith_keys |> Map.keys() |> Enum.filter(&Map.has_key?(m, &1)) do
      [arith] ->
        sym = Map.fetch!(@arith_keys, arith)

        case Map.fetch!(m, arith) do
          [a, b] ->
            [arith_term(op, sym, operand(a, type), operand(b, type))]

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

  # scalar :in (e.g. element-membership against an array field): keep as
  # {:in, value}; ArrayExpr turns it into `value in field`.
  defp build_one(:in, value, type), do: [{:in, cast(type, value)}]

  # scalar comparison
  defp build_one(op, value, type) when op in @comparison_ops,
    do: [{op, cast(type, value)}]

  # :aggregate wrapper: normalizes %{aggregate: %{fn: F, compare: C, value: V}} or
  # keyword form into the same canonical term as the shorthand {F, {C, V}}.
  defp build_one(:aggregate, params, type) when is_map(params) and not is_struct(params) do
    agg_fn = Map.fetch!(params, :fn)
    compare_op = Map.fetch!(params, :compare)
    value = Map.fetch!(params, :value)
    build_one(agg_fn, %{compare_op => value}, type)
  end

  defp build_one(:aggregate, params, type) when is_list(params) do
    if Keyword.keyword?(params) do
      agg_fn = Keyword.fetch!(params, :fn)
      compare_op = Keyword.fetch!(params, :compare)
      value = Keyword.fetch!(params, :value)
      build_one(agg_fn, %{compare_op => value}, type)
    else
      warn_skip("Unsupported operator/value, skipping")
      []
    end
  end

  defp build_one(_op, _value, _type) do
    warn_skip("Unsupported operator/value, skipping")
    []
  end

  # text transforms on the value side: %{lower: v} (reduced, in case of several).
  defp build_one_transform(op, %{} = inner, _type) when op in [:==, :!=] do
    Enum.reduce(inner, [], fn {raw_t, v}, acc ->
      case canonical_op(raw_t) do
        t when t in @text_transforms -> acc ++ [{op, {t, v}}]
        _ ->
          warn_skip("Unknown transform, skipping")
          acc
      end
    end)
  end

  defp build_one_transform(_op, _inner, _type) do
    warn_skip("Unsupported operator/value, skipping")
    []
  end

  # Reduce a comparison value (map/keyword) into a list of {canonical_op, value}.
  defp compares(value, type) do
    if (is_map(value) and not is_struct(value)) or Keyword.keyword?(value) do
      Enum.reduce(value, [], fn {raw_op, v}, acc ->
        case canonical_op(raw_op) do
          op when op in @comparison_ops and is_nil(v) -> acc ++ [{op, nil}]
          op when op in @comparison_ops -> acc ++ [{op, cast(type, v)}]
          _ ->
            warn_skip("Unknown comparison in aggregate, skipping")
            acc
        end
      end)
    else
      warn_skip("Aggregate expects a comparison map, skipping")
      []
    end
  end

  # One inner :array operator entry → an ArrayExpr-consumable term.
  defp elements_term(:in, list, type) when is_list(list), do: [{:in, cast(type, list)}]
  defp elements_term(:in, scalar, type), do: [{:in, cast(type, scalar)}]

  defp elements_term(:count, inner, type) do
    inner
    |> compares(type)
    |> Enum.map(&{:count, &1})
  end

  defp elements_term(op, list, type) when op in [:==, :!=] and is_list(list),
    do: [{op, cast(type, list)}]

  defp elements_term(op, v, type) when op in @comparison_ops, do: [{op, cast(type, v)}]

  defp elements_term(_op, _v, _type) do
    warn_skip("Unsupported :array operator, skipping")
    []
  end

  # Carry a quantified-subquery spec for the adapter to build. The select field
  # may be overridden (`select: %{field: "x"}` or `select: :x`); otherwise it is
  # left nil and the adapter defaults it to the outer column.
  defp subquery_spec(src, spec) do
    where_params = Map.drop(spec, [:from, :select])
    {:subquery, src, select_field(Map.get(spec, :select)), where_params}
  end

  defp select_field(nil), do: nil
  defp select_field(field) when is_atom(field), do: field
  defp select_field(field) when is_binary(field), do: field
  defp select_field(%{field: f}), do: f
  defp select_field(%{} = m), do: m[:field]
  defp select_field(_), do: nil

  # `field SYM value` uses the value-wrapped arithmetic shape consumed by the
  # ScalarExpr `arithmetic?` clause (so negation emits NOT(...)); any other
  # operand combination uses the generic binary-operand list form.
  defp arith_term(op, sym, {:field, _} = a, {:value, _} = b),
    do: {op, {:value, {sym, {a, b}}}}

  defp arith_term(op, sym, a, b), do: {op, {sym, [a, b]}}

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

  defp dt_keyword(p) when is_list(p), do: dt_keyword(Map.new(p))

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

  # Resolve any string field-reference operands inside a tidied expr to checked
  # atoms (using the source schema / :allowed_keys). Returns :skip if any
  # referenced field cannot be resolved. Pure walk over the known operand shapes.
  defp resolve_expr_fields(expr, source, opts) do
    walk_fields(expr, source, opts)
  catch
    :skip -> :skip
  end

  defp walk_fields({:field, name}, source, opts) when is_binary(name) do
    {:field, resolve_ref!(source, name, opts)}
  end

  defp walk_fields({:field, {b, name}}, source, opts) when is_binary(name) do
    {:field, {b, resolve_ref!(source, name, opts)}}
  end

  # Subquery specs reference the inner source; leave them untouched here (the
  # adapter recurses through CommonFilters with the inner source).
  defp walk_fields({:subquery, _src, _select, _where} = sq, _source, _opts), do: sq

  defp walk_fields(list, source, opts) when is_list(list) do
    Enum.map(list, &walk_fields(&1, source, opts))
  end

  defp walk_fields(tuple, source, opts) when is_tuple(tuple) do
    tuple
    |> Tuple.to_list()
    |> Enum.map(&walk_fields(&1, source, opts))
    |> List.to_tuple()
  end

  defp walk_fields(other, _source, _opts), do: other

  defp resolve_ref!(source, name, opts) do
    case resolve_field(source, name, opts) do
      {:ok, atom} -> atom
      :skip -> throw(:skip)
    end
  end

  defp wrap_like(pattern) when is_binary(pattern) do
    if String.contains?(pattern, ["%", "_"]), do: pattern, else: "%#{pattern}%"
  end
end
