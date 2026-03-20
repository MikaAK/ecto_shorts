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
    CommonSchema,
    CommonFilters.SetComparison,
    DynamicBuilders.Postgres.ArrayExpr,
    DynamicBuilders.Postgres.CommonExpr,
    DynamicBuilders.Postgres.Normalizer,
    DynamicBuilders.Postgres.ScalarExpr
  }

  @behaviour EctoShorts.Adapter.DynamicBuilder

  @quantifier_operators [:all, :any]

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
    params = maybe_dump_param(source, key, params)

    expr =
      params
      |> then(&Normalizer.normalize_params(source, &1, opts))
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

      cond do
        key in CommonExpr.operators() ->
          CommonExpr.dynamic_expr(selected_binding, key, negated, term, opts)

        array_field?(source, key) ->
          ArrayExpr.dynamic_expr(selected_binding, key, negated, term, opts)

        true ->
          ScalarExpr.dynamic_expr(
            selected_binding,
            key,
            negated,
            term,
            opts
          )
      end
    end
  end

  defp normalize_negation_term({:not, term}), do: {:not, term}
  defp normalize_negation_term(term), do: {nil, term}

  defp normalize_quantified_term(key, {quantifier, payload}, opts)
       when quantifier in @quantifier_operators do
    if quantified_query_payload?(payload) do
      {:==, {quantifier, SetComparison.build_quantified_query(key, payload, opts)}}
    else
      {quantifier, payload}
    end
  end

  defp normalize_quantified_term(key, {op, {quantifier, payload}}, opts)
       when quantifier in @quantifier_operators do
    if quantified_query_payload?(payload) do
      {op, {quantifier, SetComparison.build_quantified_query(key, payload, opts)}}
    else
      {op, {quantifier, payload}}
    end
  end

  defp normalize_quantified_term(_key, term, _opts), do: term

  defp quantified_query_payload?(payload) when is_map(payload) and not is_struct(payload) do
    Map.has_key?(payload, :from)
  end

  defp quantified_query_payload?(payload) when is_list(payload) do
    Keyword.keyword?(payload) and Keyword.has_key?(payload, :from)
  end

  defp quantified_query_payload?(_payload), do: false

  defp array_field?(source, key) do
    case CommonSchema.get_schema_reflection(source, :type, key) do
      {:array, _} -> true
      {:map, _} -> true
      _ -> false
    end
  end

  defp maybe_dump_param(source, key, params) do
    case CommonSchema.get_schema_reflection(source, :type, key) do
      nil -> params
      field_type -> dump_param(field_type, params)
    end
  end

  defp dump_param(field_type, {op, values}) when is_atom(op) and is_list(values) do
    {op, Enum.map(values, &dump_param(field_type, &1))}
  end

  defp dump_param(field_type, {op, value}) when is_atom(op) do
    {op, dump_param(field_type, value)}
  end

  defp dump_param(field_type, values) when is_list(values) do
    Enum.map(values, &dump_param(field_type, &1))
  end

  defp dump_param(field_type, value) do
    case Ecto.Type.dump(field_type, value) do
      {:ok, dumped} -> dumped
      :error -> value
    end
  end

  defp binding_selector?({:as, nil}), do: true
  defp binding_selector?({:as, name}) when is_atom(name), do: true
  defp binding_selector?({:at, position}) when is_integer(position) and position >= 1, do: true
  defp binding_selector?(_), do: false

  defp merge_dynamic(nil, _, b), do: b
  defp merge_dynamic(a, _, nil), do: a
  defp merge_dynamic(a, :and, b), do: dynamic(^a and ^b)
  defp merge_dynamic(a, :or, b), do: dynamic(^a or ^b)
end
