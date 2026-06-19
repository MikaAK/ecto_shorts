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

  # Canonical operator atoms recognized from the wire (as strings).
  @operator_atoms @comparison_ops ++
                    @aggregate_ops ++
                    @text_transforms ++
                    @string_ops ++
                    @list_ops

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
        routing = routing_family(source, field, opts)
        type = field_type(source, field, opts)
        {negated, inner} = lift_negation(raw_term)

        exprs = build_terms(inner, type)
        {:ok, Enum.map(exprs, &%Predicate{field: field, routing: routing, negated: negated, expr: &1})}
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

  # text transforms on the value side: %{lower: v} (reduced, in case of several)
  defp build_one(op, %{} = inner, _type) when op in [:==, :!=] do
    Enum.reduce(inner, [], fn {raw_t, v}, acc ->
      case canonical_op(raw_t) do
        t when t in @text_transforms -> acc ++ [{op, {t, v}}]
        _ -> (warn_skip("Unknown transform, skipping"); acc)
      end
    end)
  end

  # like/ilike with auto-wrap
  defp build_one(op, pattern, _type) when op in @string_ops and is_binary(pattern),
    do: [{op, wrap_like(pattern)}]

  defp build_one(op, patterns, _type) when op in @string_ops and is_list(patterns),
    do: [{op, Enum.map(patterns, &wrap_like/1)}]

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

  defp wrap_like(pattern) when is_binary(pattern) do
    if String.contains?(pattern, ["%", "_"]), do: pattern, else: "%#{pattern}%"
  end
end
