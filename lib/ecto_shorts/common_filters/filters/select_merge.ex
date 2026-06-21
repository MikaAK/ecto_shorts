defmodule EctoShorts.CommonFilters.SelectMerge do
  @moduledoc since: "3.0.0"
  @moduledoc """
  Implements the `:select_merge` structural filter for `EctoShorts.CommonFilters`.

  Merges additional fields into an existing `SELECT` clause without replacing
  it. Accepts a map, keyword list, `{field_alias, field_name}` tuple,
  `{field_alias, DynamicExpr}` tuple, or a dynamic expression. Used via params,
  not called directly:

      EctoShorts.Actions.all(Post, %{select_merge: %{title_upper: :title}})

  See `EctoShorts.QueryBuilder` for the `build_query/6` callback contract.
  """

  alias EctoShorts.{LogUtils, QueryBinding}

  alias Ecto.Query
  require Ecto.Query

  @logger_prefix "EctoShorts.CommonFilters.SelectMerge"

  def build_query(:select_merge, _source, query, _selected_binding, nil, _opts), do: query

  def build_query(:select_merge, source, query, selected_binding, term, opts) do
    apply_select_merge(query, source, selected_binding, term, opts)
  end

  defp apply_select_merge(query, source, selected_binding, term, opts)
       when is_map(term) and not is_struct(term) do
    apply_select_merge(
      query,
      source,
      selected_binding,
      Map.to_list(term),
      opts
    )
  end

  defp apply_select_merge(query, _source, selected_binding, entries, _opts)
       when is_list(entries) do
    if Keyword.keyword?(entries) do
      reduce_params(query, selected_binding, entries)
    else
      select_merge_expr(query, selected_binding, entries)
    end
  end

  defp apply_select_merge(query, _source, selected_binding, {field_alias, field_name}, _opts)
       when is_atom(field_alias) and is_atom(field_name) do
    select_merge_field_expr(query, selected_binding, field_alias, field_name)
  end

  defp apply_select_merge(
         query,
         _source,
         selected_binding,
         {field_alias, %Ecto.Query.DynamicExpr{} = dynamic_expr},
         _opts
       )
       when is_atom(field_alias) do
    select_merge_expr(query, selected_binding, field_alias, dynamic_expr)
  end

  defp apply_select_merge(query, _source, selected_binding, {field_alias, value}, _opts)
       when is_atom(field_alias) do
    select_merge_expr(query, selected_binding, field_alias, value)
  end

  defp apply_select_merge(query, _source, _selected_binding, %Ecto.Query.DynamicExpr{} = value, _opts) do
    Query.select_merge(query, ^value)
  end

  defp apply_select_merge(query, _source, _selected_binding, value, _opts) do
    LogUtils.warning(
      @logger_prefix,
      "Expected :select_merge to be a map, keyword list, tuple, or DynamicExpr, got: #{inspect(value)}"
    )

    query
  end

  defp reduce_params(query, selected_binding, params) do
    Enum.reduce(params, query, fn
      {field_alias, %Ecto.Query.DynamicExpr{} = dyn}, acc ->
        select_merge_expr(acc, selected_binding, field_alias, dyn)

      {field_alias, field_name}, acc when is_atom(field_name) ->
        select_merge_field_expr(acc, selected_binding, field_alias, field_name)

      {field_alias, value}, acc ->
        select_merge_expr(acc, selected_binding, field_alias, value)
    end)
  end

  ## Generated Functions

  {target_binding_var, binding_patterns} = QueryBinding.query_binding_contracts(__MODULE__)

  for {quoted_binding_head, quoted_binding_body} <- binding_patterns do
    defp select_struct_expr(query, unquote(quoted_binding_head), fields) do
      Query.select(
        query,
        [unquote_splicing(quoted_binding_body)],
        struct(unquote(target_binding_var), ^fields)
      )
    end

    defp select_merge_map_expr(query, unquote(quoted_binding_head), list) do
      Query.select_merge(
        query,
        [unquote_splicing(quoted_binding_body)],
        map(unquote(target_binding_var), ^list)
      )
    end

    defp select_merge_expr(query, unquote(quoted_binding_head), value) do
      Query.select_merge(
        query,
        [unquote_splicing(quoted_binding_body)],
        ^value
      )
    end

    defp select_merge_field_expr(query, unquote(quoted_binding_head), field_alias, field_name) do
      Query.select_merge(
        query,
        [unquote_splicing(quoted_binding_body)],
        %{^field_alias => field(unquote(target_binding_var), ^field_name)}
      )
    end

    defp select_merge_expr(query, unquote(quoted_binding_head), field_alias, value) do
      Query.select_merge(
        query,
        [unquote_splicing(quoted_binding_body)],
        %{^field_alias => ^value}
      )
    end
  end
end
