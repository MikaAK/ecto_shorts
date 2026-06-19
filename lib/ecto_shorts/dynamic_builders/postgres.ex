defmodule EctoShorts.DynamicBuilders.Postgres do
  @moduledoc """
  Build Postgres-specific dynamic filter expressions.

  Use this module when you want to call the Postgres dynamic adapter
  directly. If you want adapter resolution or adapter-agnostic dynamic
  building, start with `EctoShorts.DynamicBuilders.build_dynamic/4` instead.

  `build_dynamic/4` is the only public entry point. It accepts a queryable
  `source`, a binding selector, and one filter entry, and returns a dynamic
  expression value for use in Ecto query macros.

  ## Binding selectors

  The accepted binding selectors are:

    * `{:as, nil}` - the default binding
    * `{:as, name}` - a named binding
    * `{:at, position}` - a one-based positional binding

  ## Filter entry families

  `build_dynamic/4` accepts two high-level entry families:

    * `{key, term}` - an ordinary field or operator entry
    * `{:all, params}` and `{:any, params}` - top-level quantified groups

  The module handles Postgres-specific translation for common operators,
  scalar comparisons, array and map-backed fields, negation, and quantified
  subquery forms. Callers should rely on the public entry point and returned
  dynamic expression rather than the current private helper layout.

  ## Examples

      iex> EctoShorts.DynamicBuilders.Postgres.build_dynamic(Post, {:as, nil}, {:views, 5})
      #Ecto.Query.DynamicExpr<...>

      iex> EctoShorts.DynamicBuilders.Postgres.build_dynamic(
      ...>   Post,
      ...>   {:as, nil},
      ...>   {:any, [published: true, archived: false]}
      ...> )
      #Ecto.Query.DynamicExpr<...>
  """

  import Ecto.Query, only: [dynamic: 1]

  alias EctoShorts.{
    CommonFilters,
    CommonSchema,
    CommonFilters.Select,
    DynamicBuilders.Postgres.ArrayExpr,
    DynamicBuilders.Postgres.CommonExpr,
    DynamicBuilders.Postgres.MapExpr,
    DynamicBuilders.Postgres.ScalarExpr,
    Types
  }

  @behaviour EctoShorts.DynamicBuilder

  @logger_prefix "EctoShorts.DynamicBuilders.Postgres"

  @quantifier_operators [:all, :any]
  @common_expr_operators CommonExpr.operators()

  @impl true
  @doc """
  Builds a Postgres dynamic expression for one filter entry and selected
  binding.

  ## Arguments

    * `source` - the schema module, queryable source, or query used for
      field reflection and quantified-query construction
    * `selected_binding` - one of `{:as, nil}`, `{:as, atom()}`, or
      `{:at, pos_integer()}`
    * `args` - either `{key, term}` for an ordinary field or operator
      entry, or a top-level quantified group `{:all, params}` or
      `{:any, params}`
    * `opts` - keyword options forwarded through the dynamic-building
      pipeline. Defaults to `[]`

  When `args` is `{key, params}`, the function normalizes nested map and
  keyword operator forms and builds the corresponding Postgres expression
  for that key.

  When `args` is `{:all, params}` or `{:any, params}`, the function
  normalizes `params`, builds each child predicate, and merges the
  resulting expressions with the selected quantifier.

  ## Preconditions

  This function documents the valid call contract. Invalid binding
  selectors and unsupported entry shapes are outside the documented
  guarantee.

  ## Returns

  A dynamic expression suitable for `Ecto.Query.where/3`,
  `Ecto.Query.or_where/3`, `Ecto.Query.having/3`, and related macros.

  ## Examples

      iex> EctoShorts.DynamicBuilders.Postgres.build_dynamic(Post, {:as, nil}, {:views, 5})
      #Ecto.Query.DynamicExpr<...>

      iex> EctoShorts.DynamicBuilders.Postgres.build_dynamic(
      ...>   Post,
      ...>   {:as, nil},
      ...>   {:views, [>: 1, <: 10]}
      ...> )
      #Ecto.Query.DynamicExpr<...>

      iex> EctoShorts.DynamicBuilders.Postgres.build_dynamic(
      ...>   Post,
      ...>   {:as, nil},
      ...>   {:all, [published: true, archived: false]}
      ...> )
      #Ecto.Query.DynamicExpr<...>
  """
  @spec build_dynamic(term(), {:as, nil | atom()} | {:at, pos_integer()}, term(), keyword()) ::
          Ecto.Query.dynamic_expr()
  def build_dynamic(source, selected_binding, args, opts \\ [])

  def build_dynamic(source, selected_binding, {quantifier_op, params}, opts)
      when quantifier_op in @quantifier_operators do
    expr =
      Enum.reduce(params, nil, fn {key, term}, acc ->
        dyn = build_dynamic(source, selected_binding, {key, term}, opts)
        merge_dynamic(acc, quantifier_op, dyn)
      end)

    merge_dynamic(nil, :and, expr)
  end

  def build_dynamic(source, selected_binding, {key, params}, opts)
      when is_map(params) and not is_struct(params) do
    build_dynamic(source, selected_binding, {key, Map.to_list(params)}, opts)
  end

  def build_dynamic(source, selected_binding, {key, params}, opts) when is_list(params) do
    field_types = Keyword.get(opts, :field_types, [])

    field_type =
      Keyword.get(field_types, key) || CommonSchema.get_schema_reflection(source, :type, key)

    if Keyword.keyword?(params) do
      params
      |> Enum.map(&cast_value(field_type, &1))
      |> Enum.reduce(nil, fn entry, acc ->
        {merge_op, keyed_entry} =
          case entry do
            {op, term} when op in [:and, :or] -> {op, {key, term}}
            term -> {:and, {key, term}}
          end

        dyn = apply_expr(source, selected_binding, keyed_entry, opts)
        merge_dynamic(acc, merge_op, dyn)
      end)
      |> then(&merge_dynamic(nil, :and, &1))
    else
      casted = cast_value(field_type, params)
      dyn = apply_expr(source, selected_binding, {key, casted}, opts)
      merge_dynamic(nil, :and, dyn)
    end
  end

  def build_dynamic(source, selected_binding, {key, params}, opts) do
    field_types = Keyword.get(opts, :field_types, [])

    field_type =
      Keyword.get(field_types, key) || CommonSchema.get_schema_reflection(source, :type, key)

    casted = cast_value(field_type, params)
    dyn = apply_expr(source, selected_binding, {key, casted}, opts)
    merge_dynamic(nil, :and, dyn)
  end

  defp apply_expr(source, selected_binding, {key, term}, opts) do
    cond do
      is_map(term) and not is_struct(term) ->
        apply_expr(source, selected_binding, {key, Map.to_list(term)}, opts)

      Keyword.keyword?(term) ->
        Enum.reduce(term, nil, fn {inner_key, inner_value}, acc ->
          dyn = apply_expr(source, selected_binding, {key, {inner_key, inner_value}}, opts)
          merge_dynamic(acc, :and, dyn)
        end)

      true ->
        dispatch_expr(source, selected_binding, key, nil, term, opts)
    end
  end

  defp dispatch_expr(source, selected_binding, key, _negated, {:not, term}, opts) do
    dispatch_expr(source, selected_binding, key, :not, term, opts)
  end

  # Bare map term (e.g. after :not stripping or as a keyword-list value) —
  # expand each entry as an op-value pair and dispatch individually.
  # Example: %{avg: %{>: 10}} → dispatch {:avg, %{>: 10}} which hits the agg shorthand clause.
  # Example: %{>=: %{value: 5}} → dispatch {:>=, %{value: 5}} which hits {op, rhs_params} clause.
  defp dispatch_expr(source, selected_binding, key, negated, term, opts)
       when is_map(term) and not is_struct(term) do
    term
    |> Map.to_list()
    |> Enum.map(fn {inner_op, inner_value} ->
      dispatch_expr(source, selected_binding, key, negated, {inner_op, inner_value}, opts)
    end)
    |> Enum.reduce(nil, &merge_dynamic(&2, :and, &1))
  end

  @short_ops [:eq, :ne, :gt, :gte, :lt, :lte]

  defp dispatch_expr(source, selected_binding, key, negated, {quantifier, payload}, opts)
       when quantifier in @quantifier_operators do
    if subquery_spec?(payload) do
      subquery = build_quantified_query(key, payload, opts)

      dispatch_field_expr(
        source,
        selected_binding,
        key,
        negated,
        {:==, {quantifier, subquery}},
        opts
      )
    else
      canonical_payload =
        if is_map(payload) and not is_struct(payload) and not subquery_spec?(payload) do
          case Map.to_list(payload) do
            [{op, val}] ->
              canonical_op = if op in @short_ops, do: op_alias(op), else: op
              {canonical_op, val}

            _ ->
              payload
          end
        else
          payload
        end

      dispatch_field_expr(
        source,
        selected_binding,
        key,
        negated,
        {quantifier, canonical_payload},
        opts
      )
    end
  end

  defp dispatch_expr(source, selected_binding, key, negated, {op, {quantifier, payload}}, opts)
       when quantifier in @quantifier_operators do
    if subquery_spec?(payload) do
      subquery = build_quantified_query(key, payload, opts)

      dispatch_field_expr(
        source,
        selected_binding,
        key,
        negated,
        {op, {quantifier, subquery}},
        opts
      )
    else
      dispatch_field_expr(
        source,
        selected_binding,
        key,
        negated,
        {op, {quantifier, payload}},
        opts
      )
    end
  end

  # Short-form operator aliases (:eq, :ne, :gt, :gte, :lt, :lte) — normalize to canonical form.
  defp dispatch_expr(source, selected_binding, key, negated, {short_op, term}, opts)
       when short_op in @short_ops do
    dispatch_expr(source, selected_binding, key, negated, {op_alias(short_op), term}, opts)
  end

  # Common expression operators (:before, :after, :since, :until, :exists, etc.) —
  # route directly to CommonExpr regardless of term shape.
  defp dispatch_expr(_source, selected_binding, key, negated, term, opts)
       when key in @common_expr_operators do
    CommonExpr.dynamic_expr(selected_binding, common_field_for(key), negated, {key, term}, opts)
  end

  # Scalar (non-tuple, non-list) — the bare value shape means equality.
  defp dispatch_expr(source, selected_binding, key, negated, term, opts)
       when not is_tuple(term) and not is_list(term) do
    dispatch_field_expr(source, selected_binding, key, negated, {:==, term}, opts)
  end

  defp dispatch_expr(source, selected_binding, key, negated, {transform, value}, opts)
       when transform in [:lower, :upper, :downcase, :upcase] do
    op = if transform in [:lower, :downcase], do: :lower, else: :upper
    dispatch_field_expr(source, selected_binding, key, negated, {:==, {op, value}}, opts)
  end

  defp dispatch_expr(source, selected_binding, key, negated, {:arithmetic, params}, opts)
       when is_map(params) do
    dispatch_expr(
      source,
      selected_binding,
      key,
      negated,
      {:arithmetic, Map.to_list(params)},
      opts
    )
  end

  defp dispatch_expr(_source, selected_binding, key, negated, {:arithmetic, params}, opts)
       when is_list(params) do
    compare_op = Keyword.fetch!(params, :compare)

    {arith_key, operand} =
      Enum.find_value(params, fn
        {op, v} when op in [:add, :subtract, :multiply, :divide, :ago, :from_now] -> {op, v}
        _ -> nil
      end)

    operand =
      if is_map(operand) and not is_struct(operand), do: Map.to_list(operand), else: operand

    canonical =
      if Keyword.keyword?(operand) and Keyword.has_key?(operand, :interval) do
        cast = Keyword.get(operand, :cast, :datetime)
        {compare_op, {cast, {arith_key, Keyword.delete(operand, :cast)}}}
      else
        arith_op =
          case arith_key do
            :add -> :+
            :subtract -> :-
            :multiply -> :*
            :divide -> :/
          end

        field = operand[:field]
        value = operand[:value]
        {compare_op, {:value, {arith_op, {{:field, field}, {:value, value}}}}}
      end

    ScalarExpr.dynamic_expr(selected_binding, key, negated, canonical, opts)
  end

  # Shorthand aggregate form: {agg_fn, map_or_keyword} where agg_fn is one of
  # :avg, :sum, :max, :min, :count and the payload is a single-entry map or
  # keyword list mapping a comparison operator to its value.
  # Example: {:avg, %{>: 10}} → ScalarExpr with {:avg, {:>, 10}}
  @agg_fns [:avg, :sum, :max, :min, :count]

  defp dispatch_expr(source, selected_binding, key, negated, {agg_fn, params}, opts)
       when agg_fn in @agg_fns and is_map(params) and not is_struct(params) do
    dispatch_expr(source, selected_binding, key, negated, {agg_fn, Map.to_list(params)}, opts)
  end

  defp dispatch_expr(source, selected_binding, key, negated, {agg_fn, params}, opts)
       when agg_fn in @agg_fns and is_list(params) do
    [{compare_op, value}] = params

    dispatch_field_expr(
      source,
      selected_binding,
      key,
      negated,
      {agg_fn, {compare_op, value}},
      opts
    )
  end

  defp dispatch_expr(_source, selected_binding, key, negated, {:elements, params}, opts)
       when is_map(params) and not is_struct(params) do
    Enum.reduce(params, nil, fn {op, value}, acc ->
      dyn =
        ArrayExpr.dynamic_expr(
          selected_binding,
          key,
          negated,
          {op, resolve_elements_value(value)},
          opts
        )

      merge_dynamic(acc, :and, dyn)
    end)
  end

  defp dispatch_expr(_source, selected_binding, key, negated, {:elements, params}, opts)
       when is_list(params) do
    if Keyword.keyword?(params) do
      Enum.reduce(params, nil, fn {op, value}, acc ->
        dyn =
          ArrayExpr.dynamic_expr(
            selected_binding,
            key,
            negated,
            {op, resolve_elements_value(value)},
            opts
          )

        merge_dynamic(acc, :and, dyn)
      end)
    else
      ArrayExpr.dynamic_expr(selected_binding, key, negated, {:==, params}, opts)
    end
  end

  defp dispatch_expr(_source, selected_binding, key, negated, {:elements, nil}, opts) do
    ArrayExpr.dynamic_expr(selected_binding, key, negated, {:==, nil}, opts)
  end

  defp dispatch_expr(_source, selected_binding, key, negated, {:elements, term}, opts)
       when is_tuple(term) do
    ArrayExpr.dynamic_expr(selected_binding, key, negated, term, opts)
  end

  defp dispatch_expr(_source, selected_binding, key, negated, {:elements, term}, opts) do
    ArrayExpr.dynamic_expr(selected_binding, key, negated, {:in, term}, opts)
  end

  # {op, rhs_params} where rhs_params is a map — walk entries to build the RHS expression.
  # Meaning is assigned at each {key, value} entry boundary, not at the container level.
  # After building the RHS, re-dispatch so that quantifier clauses ({op, {all/any, payload}})
  # can fire if the RHS resolved to a quantified-query tuple.
  defp dispatch_expr(source, selected_binding, key, negated, {op, rhs_params}, opts)
       when is_map(rhs_params) and not is_struct(rhs_params) do
    rhs =
      Enum.reduce(rhs_params, nil, fn {rhs_key, rhs_val}, _acc ->
        build_rhs_entry(source, rhs_key, rhs_val, opts)
      end)

    case rhs do
      {quantifier, _payload} when quantifier in @quantifier_operators ->
        dispatch_expr(source, selected_binding, key, negated, {op, rhs}, opts)

      _ ->
        dispatch_field_expr(source, selected_binding, key, negated, {op, rhs}, opts)
    end
  end

  defp dispatch_expr(source, selected_binding, key, negated, term, opts) do
    dispatch_field_expr(source, selected_binding, key, negated, term, opts)
  end

  defp common_field_for(op) when op in [:ids, :before, :after, :since, :until], do: :id

  defp common_field_for(op) when op in [:start_date, :end_date, :since_date, :until_date],
    do: :inserted_at

  defp common_field_for(:exists), do: nil

  defp dispatch_field_expr(source, selected_binding, key, negated, term, opts) do
    cond do
      invalid_schema_field?(source, key) ->
        EctoShorts.LogUtils.warning(
          @logger_prefix,
          "Field \"#{key}\" does not exist on schema #{inspect(CommonSchema.get_schema(source))}, skipping field reference"
        )

        nil

      map_field?(source, key, opts) ->
        # A keyword list value for JSONB ops expands into multiple AND-combined clauses.
        # e.g. {:contains, [role: "admin", active: "true"]} → two separate @> conditions.
        case term do
          {op, values} when is_list(values) and values !== [] ->
            if Keyword.keyword?(values) do
              values
              |> Enum.map(fn kv ->
                MapExpr.dynamic_expr(selected_binding, key, negated, {op, kv}, opts)
              end)
              |> Enum.reduce(nil, &merge_dynamic(&2, :and, &1))
            else
              MapExpr.dynamic_expr(selected_binding, key, negated, term, opts)
            end

          _ ->
            MapExpr.dynamic_expr(selected_binding, key, negated, term, opts)
        end

      array_field?(source, key, opts) ->
        canonical =
          cond do
            is_list(term) and not Keyword.keyword?(term) -> {:==, term}
            is_nil(term) -> {:==, nil}
            is_tuple(term) -> term
            true -> {:==, term}
          end

        ArrayExpr.dynamic_expr(selected_binding, key, negated, canonical, opts)

      true ->
        canonical =
          if is_tuple(term) do
            term
          else
            {:==, term}
          end

        ScalarExpr.dynamic_expr(selected_binding, key, negated, canonical, opts)
    end
  end

  def build_quantified_query(outer_key, params, opts)
      when is_map(params) and not is_struct(params) do
    build_quantified_query(outer_key, Map.to_list(params), opts)
  end

  def build_quantified_query(outer_key, params, opts) do
    if Keyword.keyword?(params) do
      {source, params_without_from} = Keyword.pop(params, :from, [])
      {select_spec, where_params} = Keyword.pop(params_without_from, :select)

      select_term =
        case select_spec || outer_key do
          field when is_atom(field) and field !== nil ->
            field

          field when is_binary(field) ->
            field_name_to_atom(source, field, opts) || outer_key

          params ->
            if (is_map(params) and not is_struct(params)) or Keyword.keyword?(params) do
              field_name_to_atom(source, params[:field], opts) || outer_key
            else
              outer_key
            end
        end

      inner_query = CommonFilters.convert_params_to_filter(source, where_params, opts)

      Select.build_query(:select, source, inner_query, {:as, nil}, select_term, opts)
    else
      EctoShorts.LogUtils.warning(
        @logger_prefix,
        "Expected a map or keyword list, got: #{inspect(params)}"
      )

      params
    end
  end

  defp subquery_spec?(payload) when is_map(payload) and not is_struct(payload) do
    Map.has_key?(payload, :from)
  end

  defp subquery_spec?(payload) when is_list(payload) do
    Keyword.keyword?(payload) and Keyword.has_key?(payload, :from)
  end

  defp subquery_spec?(_payload), do: false

  defp invalid_schema_field?(source, key) when is_atom(key) do
    case CommonSchema.get_schema_reflection(source, :fields) do
      fields when is_list(fields) -> key not in fields
      _ -> false
    end
  end

  defp array_field?(source, key, opts) do
    case opts[:field_types] || CommonSchema.get_schema_reflection(source, :type, key) do
      {:array, _} -> true
      _ -> false
    end
  end

  defp map_field?(source, key, opts) do
    case opts[:field_types] || CommonSchema.get_schema_reflection(source, :type, key) do
      :map -> true
      {:map, _} -> true
      _ -> false
    end
  end

  defp cast_value(nil, entry), do: entry

  defp cast_value(field_type, {op, entry}) when op in @short_ops do
    cast_value(field_type, {op_alias(op), entry})
  end

  defp cast_value(field_type, {:and, entry}), do: {:and, cast_value(field_type, entry)}
  defp cast_value(field_type, {:or, entry}), do: {:or, cast_value(field_type, entry)}

  defp cast_value({:array, _} = field_type, {:==, values}) when is_list(values) do
    {:==, Types.cast(field_type, values)}
  end

  defp cast_value({:array, _} = field_type, {:!=, values}) when is_list(values) do
    {:!=, Types.cast(field_type, values)}
  end

  defp cast_value({:array, inner_type}, {:in, values}) when is_list(values) do
    {:in, Enum.map(values, &Types.cast(inner_type, &1))}
  end

  defp cast_value({:array, _}, {:count, {op, value}})
       when op in [:>, :>=, :<, :<=, :==, :!=] do
    {:count, {op, Types.cast(:integer, value)}}
  end

  defp cast_value({:array, inner_type}, {:all, {op, value}})
       when op in [:>, :>=, :<, :<=] do
    {:all, {op, Types.cast(inner_type, value)}}
  end

  defp cast_value({:array, inner_type}, {op, value})
       when op in [:==, :!=, :in, :>, :>=, :<, :<=, :lower, :upper, :like, :ilike] do
    {op, Types.cast(inner_type, value)}
  end

  defp cast_value(field_type, {op, values})
       when op in [:==, :!=, :in] and is_list(values) do
    {op, Enum.map(values, &Types.cast(field_type, &1))}
  end

  defp cast_value(field_type, {op, {:value, value}})
       when op in [:==, :!=, :>, :>=, :<, :<=] do
    {op, {:value, Types.cast(field_type, value)}}
  end

  defp cast_value(field_type, {op, value})
       when op in [:==, :!=, :>, :>=, :<, :<=] do
    {op, Types.cast(field_type, value)}
  end

  defp cast_value({:array, _} = field_type, value) when is_list(value) do
    Types.cast(field_type, value)
  end

  defp cast_value(field_type, value) when is_list(value) do
    Enum.map(value, &Types.cast(field_type, &1))
  end

  defp cast_value(field_type, value) when not is_tuple(value) do
    Types.cast(field_type, value)
  end

  defp cast_value(_field_type, entry), do: entry

  # Builds one piece of a right-hand side expression from a single {key, value} entry.
  # Called from the explicit reducer walk in dispatch_expr {op, rhs_params} and build_rhs_expr.

  defp build_rhs_entry(source, :field, name, opts) do
    {:field, field_name_to_atom(source, name, opts)}
  end

  defp build_rhs_entry(source, :value, inner, opts) do
    {:value, build_rhs_expr(source, inner, opts)}
  end

  defp build_rhs_entry(source, op, [left, right], opts) when op in [:+, :-, :*, :/] do
    {op, {build_rhs_expr(source, left, opts), build_rhs_expr(source, right, opts)}}
  end

  defp build_rhs_entry(_source, :parent_as, pb_map, _opts)
       when is_map(pb_map) and not is_struct(pb_map) do
    [{pb, pf}] = Map.to_list(pb_map)
    {:parent_as, {pb, pf}}
  end

  defp build_rhs_entry(source, :date, term, opts) do
    {dt_op, dt_term} = resolve_datetime_wrapper(source, term, opts)
    {:date, {dt_op, dt_term}}
  end

  defp build_rhs_entry(source, :datetime, term, opts) do
    {dt_op, dt_term} = resolve_datetime_wrapper(source, term, opts)
    {:datetime, {dt_op, dt_term}}
  end

  defp build_rhs_entry(_source, key, value, _opts), do: {key, value}

  # Walks a nested value container (map) entry by entry; scalars pass through unchanged.
  defp build_rhs_expr(source, term, opts) when is_map(term) and not is_struct(term) do
    Enum.reduce(term, nil, fn {key, value}, _acc ->
      build_rhs_entry(source, key, value, opts)
    end)
  end

  defp build_rhs_expr(_source, term, _opts), do: term

  defp resolve_datetime_wrapper(source, term, opts) when is_map(term) and not is_struct(term) do
    resolve_datetime_wrapper(source, Map.to_list(term), opts)
  end

  defp resolve_datetime_wrapper(source, term, opts) when is_list(term) do
    if Keyword.keyword?(term) do
      case term do
        [{datetime_op, datetime_term}] when datetime_op in [:add, :ago, :from_now] ->
          {datetime_op, resolve_datetime_node(source, datetime_term, opts)}

        _ ->
          raise ArgumentError,
                "Expected datetime wrapper payload to be a single-key keyword list, got: #{inspect(term)}"
      end
    else
      raise ArgumentError,
            "Expected datetime wrapper payload to be a keyword list or map, got: #{inspect(term)}"
    end
  end

  defp resolve_datetime_node(source, term, opts) when is_map(term) and not is_struct(term) do
    resolve_datetime_node(source, Map.to_list(term), opts)
  end

  defp resolve_datetime_node(source, term, opts) when is_list(term) do
    if Keyword.keyword?(term) do
      field_name = Keyword.get(term, :field)
      count = Keyword.fetch!(term, :count)
      interval = Keyword.fetch!(term, :interval)
      base = if field_name, do: [{:field, field_name_to_atom(source, field_name, opts)}], else: []
      base ++ [count: count, interval: interval]
    else
      raise ArgumentError,
            "Expected datetime params to be a keyword list or map, got: #{inspect(term)}"
    end
  end

  # Resolves the value side of a single :elements entry.
  defp resolve_elements_value(value) when is_map(value) and not is_struct(value) do
    Enum.reduce(value, nil, fn {op, inner}, _acc ->
      {op, resolve_elements_value(inner)}
    end)
  end

  defp resolve_elements_value(value), do: value

  defp op_alias(:eq), do: :==
  defp op_alias(:ne), do: :!=
  defp op_alias(:gt), do: :>
  defp op_alias(:gte), do: :>=
  defp op_alias(:lt), do: :<
  defp op_alias(:lte), do: :<=

  defp field_name_to_atom(_source, field_name, _opts) when is_atom(field_name), do: field_name

  defp field_name_to_atom(source, field_name, opts) when is_binary(field_name) do
    case (source !== nil && CommonSchema.get_schema(source) !== nil &&
            CommonSchema.get_schema_reflection(source, :fields)) || nil do
      fields when is_list(fields) ->
        string_fields = MapSet.new(fields, &Atom.to_string/1)

        if MapSet.member?(string_fields, field_name) do
          String.to_existing_atom(field_name)
        else
          EctoShorts.LogUtils.warning(
            @logger_prefix,
            "Field \"#{field_name}\" does not exist on schema #{inspect(CommonSchema.get_schema(source))}, skipping field reference"
          )

          nil
        end

      _ ->
        allowed_keys = opts[:allowed_keys]

        if allowed_keys do
          allowed_set = MapSet.new(allowed_keys)

          if MapSet.member?(allowed_set, field_name) do
            String.to_atom(field_name)
          else
            EctoShorts.LogUtils.warning(
              @logger_prefix,
              "Field \"#{field_name}\" is not in the :allowed_keys list, skipping field reference"
            )

            nil
          end
        else
          EctoShorts.LogUtils.warning(
            @logger_prefix,
            "Field \"#{field_name}\" cannot be resolved: no schema or :allowed_keys available, skipping field reference"
          )

          nil
        end
    end
  end

  defp merge_dynamic(nil, _, b), do: b
  defp merge_dynamic(a, _, nil), do: a
  defp merge_dynamic(a, :and, b), do: dynamic(^a and ^b)
  defp merge_dynamic(a, :or, b), do: dynamic(^a or ^b)
end
