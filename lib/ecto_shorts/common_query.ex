defmodule EctoShorts.CommonQuery do
  alias Ecto.Queryable
  alias EctoShorts.SchemaHelpers

  @doc """
  ...
  """
  def lookup_base_expr_source(query) do
    with %{source: source} <- lookup_base_expr(query) do
      source
    end
  end

  @doc false
  def lookup_base_expr(%{source: {_, _}} = expr), do: expr
  def lookup_base_expr(%{source: source}), do: lookup_base_expr(source)
  def lookup_base_expr(%{query: query}), do: lookup_base_expr(query)
  def lookup_base_expr(%{from: from_expr}), do: lookup_base_expr(from_expr)

  @doc """
  ...
  """
  def lookup_binding_expr_source(query, alias_or_position) do
    case lookup_binding_expr(query, alias_or_position) do
      %{on: _} = join_expr ->
        lookup_join_source(query, join_expr)

      %{source: _} = from_expr ->
        lookup_base_expr_source(from_expr)

      value ->
        value
    end
  end

  defp lookup_join_source(%{from: from_expr} = _query, %{assoc: {0, key}} = _join_expr) do
    with {_, parent_schema} <- lookup_base_expr_source(from_expr) do
      if parent_schema !== nil do
        {nil, SchemaHelpers.get_related_schema(parent_schema, key)}
      end
    end
  end

  defp lookup_join_source(%{joins: joins} = query, %{assoc: {pos, key}} = join_expr) do
    case get_in(joins, [Access.at(pos)]) do
      nil ->
        if has_subquery?(query) do
          query
          |> get_inner_query()
          |> lookup_join_source(join_expr)
        end

      %{assoc: {^pos, ^key}} = _join_expr ->
        ref_join_expr = get_in(joins, [Access.at!(pos - 1)])

        with {_, parent_schema} <- lookup_join_source(query, ref_join_expr) do
          if parent_schema !== nil do
            {nil, SchemaHelpers.get_related_schema(parent_schema, key)}
          end
        end
    end
  end

  defp lookup_join_source(_query, join_expr) do
    lookup_base_expr_source(join_expr)
  end

  defp has_subquery?(%{from: %{source: %{query: _}}}), do: true
  defp has_subquery?(%{source: %{query: _}}), do: true
  defp has_subquery?(_), do: false

  defp get_inner_query(%{from: %{source: %{query: inner_query}}}), do: inner_query
  defp get_inner_query(%{query: query}), do: get_inner_query(query)
  defp get_inner_query(_), do: nil

  @doc """
  ...
  """
  def lookup_binding_expr(%_{} = query, pos) when is_integer(pos) do
    lookup_binding_at(query, pos)
  end

  def lookup_binding_expr(%_{} = query, binding_alias) do
    get_schema_binding(query, binding_alias)
  end

  def lookup_binding_expr(source, alias_or_position) do
    source
    |> Queryable.to_query()
    |> lookup_binding_expr(alias_or_position)
  end

  defp lookup_binding_at(%_{from: from_expr} = _query, 0) do
    from_expr
  end

  defp lookup_binding_at(%_{joins: joins} = _query, pos) when pos < 0 do
    Enum.at(joins, pos)
  end

  defp lookup_binding_at(%_{joins: joins} = _query, pos) when pos > 0 do
    Enum.at(joins, pos - 1)
  end

  defp get_schema_binding(query, binding_alias) do
    with from_expr when is_struct(from_expr, Ecto.Query.FromExpr) <-
           find_binding_expr(query, binding_alias) do
      lookup_base_expr(from_expr)
    end
  end

  defp find_binding_expr(%{from: from_expr, joins: joins} = query, binding_alias)
       when is_struct(query, Ecto.Query) do
    if is_nil(binding_alias) do
      lookup_base_expr(from_expr)
    else
      with nil <- find_binding_expr(from_expr, binding_alias) do
        find_binding_expr(joins, binding_alias)
      end
    end
  end

  defp find_binding_expr(%{query: query} = _subquery, binding_alias) do
    find_binding_expr(query, binding_alias)
  end

  defp find_binding_expr(%{as: as, source: source} = join_expr, binding_alias)
       when is_struct(join_expr, Ecto.Query.JoinExpr) do
    if as === binding_alias do
      join_expr
    else
      find_binding_expr(source, binding_alias)
    end
  end

  defp find_binding_expr(%{as: as, source: source} = from_expr, binding_alias)
       when is_struct(from_expr, Ecto.Query.FromExpr) do
    if as === binding_alias do
      from_expr
    else
      find_binding_expr(source, binding_alias)
    end
  end

  defp find_binding_expr([], _), do: nil

  defp find_binding_expr([join_expr | joins], binding_alias) do
    with nil <- find_binding_expr(join_expr, binding_alias) do
      find_binding_expr(joins, binding_alias)
    end
  end

  defp find_binding_expr(_, _), do: nil
end
