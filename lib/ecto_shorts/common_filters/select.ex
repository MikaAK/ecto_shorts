defmodule EctoShorts.CommonFilters.Select do
  alias Ecto.Query
  alias EctoShorts.Logger
  alias EctoShorts.QueryBinding

  require Ecto.Query

  @logger_prefix "EctoShorts.CommonFilters.Select"

  {target_binding_var, binding_patterns} =
    QueryBinding.query_binding_contracts(__MODULE__)

  def build_query(:select, _source, query, selected_binding, term, _opts) do
    reduced_term = normalize_select_term(term)

    query
    |> drop_existing_select()
    |> apply_select_expr(selected_binding, reduced_term)
  end

  def build_query(:select_merge, _source, query, selected_binding, term, _opts) do
    apply_select_merge_expr(query, selected_binding, term)
  end

  for {quoted_binding_head, quoted_binding_body} <- binding_patterns do
    defp initialize_select_map(query, unquote(quoted_binding_head)) do
      Query.select(query, [unquote_splicing(quoted_binding_body)], %{})
    end

    defp select_all(query, unquote(quoted_binding_head)) do
      Query.select(query, [unquote_splicing(quoted_binding_body)], unquote(target_binding_var))
    end

    defp select_map_fields(query, unquote(quoted_binding_head), term) do
      Query.select(
        query,
        [unquote_splicing(quoted_binding_body)],
        map(unquote(target_binding_var), ^term)
      )
    end

    defp select_struct_fields(query, unquote(quoted_binding_head), fields) do
      Query.select(
        query,
        [unquote_splicing(quoted_binding_body)],
        struct(unquote(target_binding_var), ^fields)
      )
    end

    defp select_raw(query, unquote(quoted_binding_head), term) do
      Query.select(
        query,
        [unquote_splicing(quoted_binding_body)],
        ^term
      )
    end

    defp select_field(query, unquote(quoted_binding_head), field_name) do
      Query.select(
        query,
        [unquote_splicing(quoted_binding_body)],
        field(unquote(target_binding_var), ^field_name)
      )
    end

    defp select_merge_map_fields(query, unquote(quoted_binding_head), list) do
      Query.select_merge(
        query,
        [unquote_splicing(quoted_binding_body)],
        map(unquote(target_binding_var), ^list)
      )
    end

    defp select_merge_raw(query, unquote(quoted_binding_head), term) do
      Query.select_merge(
        query,
        [unquote_splicing(quoted_binding_body)],
        ^term
      )
    end

    defp select_merge_field(query, unquote(quoted_binding_head), field_alias, field_name) do
      Query.select_merge(
        query,
        [unquote_splicing(quoted_binding_body)],
        %{^field_alias => field(unquote(target_binding_var), ^field_name)}
      )
    end

    defp select_merge_dynamic(query, unquote(quoted_binding_head), field_alias, dynamic_expr) do
      Query.select_merge(
        query,
        [unquote_splicing(quoted_binding_body)],
        %{^field_alias => ^dynamic_expr}
      )
    end

    defp select_merge_value(query, unquote(quoted_binding_head), field_alias, value) do
      Query.select_merge(
        query,
        [unquote_splicing(quoted_binding_body)],
        %{^field_alias => ^value}
      )
    end
  end

  defp apply_select_expr(query, selected_binding, {:map, params})
       when is_map(params) do
    apply_select_expr(query, selected_binding, {:map, Map.to_list(params)})
  end

  defp apply_select_expr(query, selected_binding, true) do
    select_all(query, selected_binding)
  end

  defp apply_select_expr(query, selected_binding, {:map, term}) do
    if Keyword.keyword?(term) do
      apply_select_alias_entries(query, selected_binding, term)
    else
      select_map_fields(query, selected_binding, term)
    end
  end

  defp apply_select_expr(query, selected_binding, {:struct, fields})
       when is_list(fields) do
    select_struct_fields(query, selected_binding, fields)
  end

  defp apply_select_expr(query, selected_binding, term)
       when is_map(term) and not is_struct(term) do
    apply_select_expr(query, selected_binding, Map.to_list(term))
  end

  defp apply_select_expr(query, selected_binding, term) when is_list(term) do
    if Keyword.keyword?(term) do
      apply_select_alias_entries(query, selected_binding, term)
    else
      select_raw(query, selected_binding, term)
    end
  end

  defp apply_select_expr(query, selected_binding, field_name)
       when is_atom(field_name) do
    select_field(query, selected_binding, field_name)
  end

  defp apply_select_expr(query, _selected_binding, term) do
    Query.select(query, ^term)
  end

  defp apply_select_merge_expr(query, selected_binding, {:map, params})
       when is_map(params) do
    apply_select_merge_expr(query, selected_binding, {:map, Map.to_list(params)})
  end

  defp apply_select_merge_expr(query, selected_binding, {:map, list})
       when is_list(list) do
    if Keyword.keyword?(list) do
      apply_select_merge_entries(query, selected_binding, list)
    else
      select_merge_map_fields(query, selected_binding, list)
    end
  end

  defp apply_select_merge_expr(query, selected_binding, term) when is_list(term) do
    if Keyword.keyword?(term) do
      apply_select_merge_entries(query, selected_binding, term)
    else
      select_merge_raw(query, selected_binding, term)
    end
  end

  defp apply_select_merge_expr(query, selected_binding, {field_alias, field_name})
       when is_atom(field_alias) do
    apply_select_merge_entry(query, selected_binding, field_alias, field_name)
  end

  defp apply_select_merge_expr(query, _selected_binding, term) do
    Query.select_merge(query, ^term)
  end

  defp apply_select_merge_entry(query, selected_binding, field_alias, field_name)
       when is_atom(field_name) do
    select_merge_field(query, selected_binding, field_alias, field_name)
  end

  defp apply_select_merge_entry(
         query,
         selected_binding,
         field_alias,
         %Ecto.Query.DynamicExpr{} = dynamic_expr
       ) do
    select_merge_dynamic(query, selected_binding, field_alias, dynamic_expr)
  end

  defp apply_select_merge_entry(query, selected_binding, field_alias, value) do
    select_merge_value(query, selected_binding, field_alias, value)
  end

  defp apply_select_merge_entries(query, selected_binding, entries) do
    Enum.reduce(entries, query, fn {field_alias, field}, query_acc ->
      apply_select_merge_entry(query_acc, selected_binding, field_alias, field)
    end)
  end

  defp apply_select_alias_entries(query, selected_binding, entries) do
    query
    |> initialize_select_map(selected_binding)
    |> apply_select_merge_entries(selected_binding, entries)
  end

  defp drop_existing_select(%Ecto.Query{select: nil} = query), do: query

  defp drop_existing_select(query) do
    Logger.warning(
      @logger_prefix,
      "Query already has a :select expression - dropping it before applying the new :select filter. Pass a query without an existing select to avoid this."
    )

    Query.exclude(query, :select)
  end

  defp normalize_select_term({:map, params}), do: {:map, params}
  defp normalize_select_term({:struct, fields}), do: {:struct, fields}
  defp normalize_select_term(map: params), do: {:map, params}
  defp normalize_select_term(struct: fields), do: {:struct, fields}
  defp normalize_select_term(term), do: term
end
