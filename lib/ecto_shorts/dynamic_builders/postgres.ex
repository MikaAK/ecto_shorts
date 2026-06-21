defmodule EctoShorts.DynamicBuilders.Postgres do
  @moduledoc """
  Build Postgres-specific dynamic filter expressions.

  Use this module when you want to call the Postgres dynamic adapter
  directly. If you want adapter resolution or adapter-agnostic dynamic
  building, start with `EctoShorts.DynamicBuilders.build_dynamic/3` instead.

  `build_dynamic/3` is the only public entry point. It implements the
  `EctoShorts.DynamicBuilder` behaviour: it accepts a resolved
  `EctoShorts.CommonFilters.Predicate` struct, a binding selector, and options,
  and returns a dynamic expression value for use in Ecto query macros (or `nil`
  when the predicate contributes no clause).

  ## Binding selectors

  The accepted binding selectors are:

    * `{:as, nil}` - the default binding
    * `{:as, name}` - a named binding
    * `{:at, position}` - a one-based positional binding

  ## Predicate input

  The `predicate` is a resolved `EctoShorts.CommonFilters.Predicate` struct
  produced upstream by `EctoShorts.CommonFilters.PredicateBuilder`. It carries a
  checked `:field` atom, a `:routing` family (`:scalar | :array | :map |
  :common`), a `:negated` boolean, and a tidied `:expr` operator-expression.

  Given that input, the module handles Postgres-specific translation for common
  operators, scalar comparisons, array and map-backed fields, negation, and
  quantified subquery forms. Callers should rely on the public entry point and
  returned dynamic expression rather than the current private helper layout.

  ## Examples

      iex> predicate = %EctoShorts.CommonFilters.Predicate{
      ...>   field: :views,
      ...>   routing: :scalar,
      ...>   negated: false,
      ...>   expr: {:==, 5}
      ...> }
      iex> EctoShorts.DynamicBuilders.Postgres.build_dynamic(predicate, {:as, nil}, [])
      #Ecto.Query.DynamicExpr<...>
  """

  alias EctoShorts.{
    CommonFilters,
    CommonFilters.Predicate,
    CommonFilters.Select,
    DynamicBuilders.Postgres.ArrayExpr,
    DynamicBuilders.Postgres.CommonExpr,
    DynamicBuilders.Postgres.MapExpr,
    DynamicBuilders.Postgres.ScalarExpr,
    LogUtils
  }

  @behaviour EctoShorts.DynamicBuilder

  @logger_prefix "EctoShorts.DynamicBuilders.Postgres"

  @doc since: "3.0.0"
  @doc """
  Thin adapter entry: turns one resolved `EctoShorts.CommonFilters.Predicate`
  into a dynamic expression by dispatching on its `:routing` family and applying
  `:negated`. Field resolution, casting and operator tidying already happened in
  `EctoShorts.CommonFilters.PredicateBuilder`.
  """
  @impl true
  def build_dynamic(%Predicate{routing: routing, field: field, negated: negated, expr: expr}, selected_binding, opts) do
    neg = if negated, do: :not, else: nil

    expr = build_subqueries(expr, field, opts)

    case routing do
      :scalar -> ScalarExpr.dynamic_expr(selected_binding, field, neg, expr, opts)
      :array -> ArrayExpr.dynamic_expr(selected_binding, field, neg, expr, opts)
      :map -> MapExpr.dynamic_expr(selected_binding, field, neg, expr, opts)
      :common -> CommonExpr.dynamic_expr(selected_binding, field, neg, expr, opts)
    end
  end

  # Replaces any {:subquery, source, select, where_params} operand carried inside
  # a tidied predicate expr with a built Ecto.SubQuery (the only place query
  # construction happens). `default_select` is the outer column used when the
  # spec gives no select override. Identity for exprs carrying no subquery spec.
  defp build_subqueries({:subquery, src, select, where_params}, default_select, opts) do
    inner_source = resolve_subquery_source(src, opts)
    inner_query = CommonFilters.convert_params_to_filter(inner_source, where_params, opts)
    select_term = resolve_subquery_select(inner_source, select, default_select, opts)
    Select.build_query(:select, inner_source, inner_query, {:as, nil}, select_term, opts)
  end

  defp build_subqueries(expr, default_select, opts) when is_tuple(expr) do
    expr
    |> Tuple.to_list()
    |> Enum.map(&build_subqueries(&1, default_select, opts))
    |> List.to_tuple()
  end

  defp build_subqueries(expr, default_select, opts) when is_list(expr) do
    Enum.map(expr, &build_subqueries(&1, default_select, opts))
  end

  defp build_subqueries(expr, _default_select, _opts), do: expr

  defp resolve_subquery_source(src, _opts) when is_atom(src) and not is_nil(src), do: src
  defp resolve_subquery_source({_source, _schema} = src, _opts), do: src

  defp resolve_subquery_source(src, opts) when is_binary(src) do
    aliases = opts[:source_aliases] || %{}

    case Map.get(aliases, src) do
      nil -> raise EctoShorts.FilterError, "unknown subquery source alias #{inspect(src)}"
      resolved -> resolved
    end
  end

  defp resolve_subquery_source(src, _opts) do
    raise EctoShorts.FilterError, "invalid subquery source #{inspect(src)}"
  end

  # Resolve the subquery's select column: an explicit override (atom or a string
  # checked against the inner schema), else the outer column.
  defp resolve_subquery_select(_source, field, _default, _opts) when is_atom(field) and not is_nil(field),
    do: field

  defp resolve_subquery_select(_source, field, default, _opts) when is_binary(field) do
    LogUtils.warning(
      @logger_prefix,
      "Subquery :select field arrived as a string (#{inspect(field)}) — expected atom after normalization. Using default #{inspect(default)}."
    )

    default
  end

  defp resolve_subquery_select(_source, _select, default, _opts), do: default

end
