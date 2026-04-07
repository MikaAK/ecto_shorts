defmodule EctoShorts.CommonFilters.Select do
  @moduledoc since: "3.0.0"
  @moduledoc false

  alias EctoShorts.QueryBinding
  alias EctoShorts.CommonFilters.SelectMerge

  alias Ecto.Query
  require Ecto.Query

  def build_query(:select, source, query, selected_binding, term, opts) do
    query
    |> Query.exclude(:select)
    |> apply_select(source, selected_binding, term, opts)
  end

  defp apply_select(query, _source, selected_binding, {:map, params}, _opts) do
    params =
      if is_map(params) and not is_struct(params) do
        Map.to_list(params)
      else
        params
      end

    if Keyword.keyword?(params) do
      apply_select_merge(query, selected_binding, params)
    else
      select_map_expr(query, selected_binding, params)
    end
  end

  defp apply_select(query, _source, selected_binding, {:struct, fields}, _opts)
       when is_list(fields) do
    select_struct_expr(query, selected_binding, fields)
  end

  defp apply_select(query, source, selected_binding, term, opts)
       when is_map(term) and not is_struct(term) do
    term
    |> Map.to_list()
    |> Enum.reduce(
      init_select_map(query, selected_binding),
      fn {k, v}, acc ->
        SelectMerge.build_query(:select_merge, source, acc, selected_binding, {k, v}, opts)
      end
    )
  end

  defp apply_select(query, _source, selected_binding, entries, _opts) when is_list(entries) do
    if Keyword.keyword?(entries) do
      apply_select_merge(query, selected_binding, entries)
    else
      select_expr(query, selected_binding, entries)
    end
  end

  defp apply_select(query, _source, selected_binding, true, _opts) do
    select_expr(query, selected_binding, true)
  end

  defp apply_select(query, _source, selected_binding, field_name, _opts)
       when is_atom(field_name) do
    select_field_expr(query, selected_binding, field_name)
  end

  defp apply_select(query, _source, _selected_binding, term, _opts) do
    Query.select(query, ^term)
  end

  defp apply_select_merge(query, selected_binding, entries) do
    base = init_select_map(query, selected_binding)
    SelectMerge.build_query(:select_merge, nil, base, selected_binding, entries, [])
  end

  ## Generated Functions

  {target_binding_var, binding_patterns} = QueryBinding.query_binding_contracts(__MODULE__)

  for {quoted_binding_head, quoted_binding_body} <- binding_patterns do
    defp init_select_map(query, unquote(quoted_binding_head)) do
      Query.select(query, [unquote_splicing(quoted_binding_body)], %{})
    end

    defp select_map_expr(query, unquote(quoted_binding_head), term) do
      Query.select(
        query,
        [unquote_splicing(quoted_binding_body)],
        map(unquote(target_binding_var), ^term)
      )
    end

    defp select_struct_expr(query, unquote(quoted_binding_head), fields) do
      Query.select(
        query,
        [unquote_splicing(quoted_binding_body)],
        struct(unquote(target_binding_var), ^fields)
      )
    end

    defp select_field_expr(query, unquote(quoted_binding_head), field_name) do
      Query.select(
        query,
        [unquote_splicing(quoted_binding_body)],
        field(unquote(target_binding_var), ^field_name)
      )
    end

    defp select_expr(query, unquote(quoted_binding_head), value) do
      case value do
        true ->
          Query.select(
            query,
            [unquote_splicing(quoted_binding_body)],
            unquote(target_binding_var)
          )

        _ ->
          Query.select(query, [unquote_splicing(quoted_binding_body)], ^value)
      end
    end
  end
end
