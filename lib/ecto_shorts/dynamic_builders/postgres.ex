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
    DynamicBuilders.Postgres.Normalizer,
    DynamicBuilders.Postgres.ScalarExpr,
    Types
  }

  @behaviour EctoShorts.Adapter.DynamicBuilder

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
      params
      |> then(&Normalizer.normalize_params(source, &1, opts))
      |> Enum.reduce(nil, fn entry, acc ->
        dyn = apply_expr(source, selected_binding, entry, opts)
        merge_dynamic(acc, quantifier_op, dyn)
      end)

    merge_dynamic(nil, :and, expr)
  end

  def build_dynamic(source, selected_binding, {key, params}, opts) do
    field_types = Keyword.get(opts, :field_types, [])

    field_type =
      Keyword.get(field_types, key) || CommonSchema.get_schema_reflection(source, :type, key)

    expr =
      params
      |> then(&Normalizer.normalize_params(source, &1, opts))
      |> Enum.map(&cast_value(field_type, &1))
      |> Enum.reduce(nil, fn entry, acc ->
        {merge_op, expr_entry} = expr_entry(key, entry)
        dyn = apply_expr(source, selected_binding, expr_entry, opts)
        merge_dynamic(acc, merge_op, dyn)
      end)

    merge_dynamic(nil, :and, expr)
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
        build_expr(source, selected_binding, key, term, opts)
    end
  end

  defp expr_entry(key, {merge_op, term}) when merge_op in [:and, :or] do
    {merge_op, {key, term}}
  end

  defp expr_entry(key, term) do
    {:and, {key, term}}
  end

  defp build_expr(source, selected_binding, key, term, opts) do
    if binding_selector?(selected_binding) do
      {negated, term} = normalize_negation_term(term)
      term = normalize_quantified_term(key, term, opts)
      dispatch_expr(source, selected_binding, key, negated, term, opts)
    end
  end

  defp dispatch_expr(_source, selected_binding, key, negated, term, opts)
       when key in @common_expr_operators do
    CommonExpr.dynamic_expr(selected_binding, key, negated, term, opts)
  end

  defp dispatch_expr(_source, selected_binding, key, negated, {:elements, inner_entries}, opts) do
    Enum.reduce(inner_entries, nil, fn inner_entry, dyn_acc ->
      dyn = ArrayExpr.dynamic_expr(selected_binding, key, negated, inner_entry, opts)
      merge_dynamic(dyn_acc, :and, dyn)
    end)
  end

  defp dispatch_expr(source, selected_binding, key, negated, term, opts) do
    cond do
      invalid_schema_field?(source, key) ->
        EctoShorts.Logger.warning(
          @logger_prefix,
          "Field \"#{key}\" does not exist on schema #{inspect(CommonSchema.get_schema(source))}, skipping field reference"
        )

        nil

      map_field?(source, key, opts) ->
        MapExpr.dynamic_expr(selected_binding, key, negated, term, opts)

      array_field?(source, key, opts) ->
        ArrayExpr.dynamic_expr(selected_binding, key, negated, term, opts)

      true ->
        ScalarExpr.dynamic_expr(selected_binding, key, negated, term, opts)
    end
  end

  defp normalize_negation_term({:not, term}), do: {:not, term}
  defp normalize_negation_term(term), do: {nil, term}

  defp normalize_quantified_term(key, {quantifier, payload}, opts)
       when quantifier in @quantifier_operators do
    if quantified_query_payload?(payload) do
      {:==, {quantifier, build_quantified_query(key, payload, opts)}}
    else
      {quantifier, payload}
    end
  end

  defp normalize_quantified_term(key, {op, {quantifier, payload}}, opts)
       when quantifier in @quantifier_operators do
    if quantified_query_payload?(payload) do
      {op, {quantifier, build_quantified_query(key, payload, opts)}}
    else
      {op, {quantifier, payload}}
    end
  end

  defp normalize_quantified_term(_key, term, _opts), do: term

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
            normalize_field_name(source, field, opts) || outer_key

          params ->
            if (is_map(params) and not is_struct(params)) or Keyword.keyword?(params) do
              normalize_field_name(source, params[:field], opts) || outer_key
            else
              outer_key
            end
        end

      inner_query = CommonFilters.convert_params_to_filter(source, where_params, opts)

      Select.build_query(:select, source, inner_query, {:as, nil}, select_term, opts)
    else
      EctoShorts.Logger.warning(
        @logger_prefix,
        "Expected a map or keyword list, got: #{inspect(params)}"
      )

      params
    end
  end

  defp normalize_field_name(source, field_name, opts) when is_binary(field_name) do
    case {CommonSchema.get_schema(source), opts[:allowed_keys]} do
      {schema, _} when schema !== nil ->
        string_fields =
          source
          |> CommonSchema.get_schema_reflection(:fields)
          |> MapSet.new(&Atom.to_string/1)

        if MapSet.member?(string_fields, field_name) do
          String.to_existing_atom(field_name)
        else
          EctoShorts.Logger.warning(
            @logger_prefix,
            "Field \"#{field_name}\" does not exist on schema #{inspect(schema)}, skipping field reference"
          )

          nil
        end

      {_, allowed_keys} when is_list(allowed_keys) ->
        allowed_set = MapSet.new(allowed_keys)

        if MapSet.member?(allowed_set, field_name) do
          String.to_atom(field_name)
        else
          EctoShorts.Logger.warning(
            @logger_prefix,
            "Field \"#{field_name}\" is not in the :allowed_keys list, skipping field reference"
          )

          nil
        end

      _ ->
        EctoShorts.Logger.warning(
          @logger_prefix,
          "Field \"#{field_name}\" cannot be resolved: no schema or :allowed_keys available, skipping field reference"
        )

        nil
    end
  end

  defp quantified_query_payload?(payload) when is_map(payload) and not is_struct(payload) do
    Map.has_key?(payload, :from)
  end

  defp quantified_query_payload?(payload) when is_list(payload) do
    Keyword.keyword?(payload) and Keyword.has_key?(payload, :from)
  end

  defp quantified_query_payload?(_payload), do: false

  defp invalid_schema_field?(source, key) when is_atom(key) do
    case CommonSchema.get_schema_reflection(source, :fields) do
      fields when is_list(fields) -> key not in fields
      _ -> false
    end
  end

  defp invalid_schema_field?(_source, _key), do: false

  defp array_field?(source, key, opts) do
    field_types = Keyword.get(opts, :field_types, [])

    resolved =
      Keyword.get(field_types, key) || CommonSchema.get_schema_reflection(source, :type, key)

    match?({:array, _}, resolved)
  end

  defp map_field?(source, key, opts) do
    field_types = Keyword.get(opts, :field_types, [])

    resolved =
      Keyword.get(field_types, key) || CommonSchema.get_schema_reflection(source, :type, key)

    case resolved do
      :map -> true
      {:map, _} -> true
      _ -> false
    end
  end

  @short_ops [:eq, :ne, :gt, :gte, :lt, :lte]

  defp cast_value(nil, entry), do: entry

  defp cast_value(field_type, {op, entry}) when op in @short_ops do
    cast_value(field_type, {Normalizer.normalize_operator(op), entry})
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
    if Keyword.keyword?(value) do
      value
    else
      Types.cast(field_type, value)
    end
  end

  defp cast_value(field_type, value) when is_list(value) do
    Enum.map(value, &Types.cast(field_type, &1))
  end

  defp cast_value(field_type, value) when not is_tuple(value) do
    Types.cast(field_type, value)
  end

  defp cast_value(_field_type, entry), do: entry

  defp binding_selector?({:as, nil}), do: true
  defp binding_selector?({:as, name}) when is_atom(name), do: true
  defp binding_selector?({:at, position}) when is_integer(position) and position >= 1, do: true
  defp binding_selector?(_), do: false

  defp merge_dynamic(nil, _, b), do: b
  defp merge_dynamic(a, _, nil), do: a
  defp merge_dynamic(a, :and, b), do: dynamic(^a and ^b)
  defp merge_dynamic(a, :or, b), do: dynamic(^a or ^b)
end
