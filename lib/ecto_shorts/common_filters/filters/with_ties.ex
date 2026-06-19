defmodule EctoShorts.CommonFilters.WithTies do
  @moduledoc since: "3.0.0"
  @moduledoc false

  alias EctoShorts.{
    CommonFilters.Limit,
    CommonFilters.OrderBy,
    CommonSchema,
    QueryBinding,
    Types
  }

  alias EctoShorts.LogUtils

  alias Ecto.Query
  require Ecto.Query

  @logger_prefix "EctoShorts.CommonFilters.WithTies"
  @default_limit 1000

  def build_query(:with_ties, source, query, selected_binding, map, opts)
      when is_map(map) and not is_struct(map) do
    build_query(:with_ties, source, query, selected_binding, Map.to_list(map), opts)
  end

  def build_query(:with_ties, source, query, selected_binding, params, opts) do
    params = Types.cast(:boolean, params)

    if Keyword.keyword?(params) or is_boolean(params) do
      apply_params(source, query, selected_binding, params, opts)
    else
      LogUtils.warning(
        @logger_prefix,
        "Expected :with_ties value to be a boolean or keyword/map payload, got: #{inspect(params)}"
      )

      query
    end
  end

  defp apply_params(source, query, selected_binding, bool, opts) when is_boolean(bool) do
    query =
      if bool,
        do: prepare_query(query, source, selected_binding, @default_limit, opts),
        else: query

    if has_limit?(query), do: with_ties_expr(query, selected_binding, bool), else: query
  end

  defp apply_params(source, query, selected_binding, params, opts) do
    unknown_keys = params |> Keyword.keys() |> Enum.reject(&(&1 === :limit))

    if unknown_keys !== [] do
      LogUtils.warning(
        @logger_prefix,
        "Expected :with_ties params to only include :limit, got unsupported keys: #{inspect(unknown_keys)}"
      )

      query
    else
      apply_limit_param(source, query, selected_binding, params[:limit], opts)
    end
  end

  defp apply_limit_param(source, query, selected_binding, nil, opts) do
    query
    |> prepare_query(source, selected_binding, @default_limit, opts)
    |> with_ties_expr(selected_binding, true)
  end

  defp apply_limit_param(source, query, selected_binding, limit, opts) do
    case Types.cast(:integer, limit) do
      value when is_integer(value) ->
        limited_query = Limit.build_query(:limit, source, query, selected_binding, value, opts)

        limited_query
        |> ensure_order(source, selected_binding, opts)
        |> with_ties_expr(selected_binding, true)

      other ->
        LogUtils.warning(
          @logger_prefix,
          "Expected :with_ties :limit to be an integer or nil, got: #{inspect(other)}"
        )

        query
    end
  end

  defp prepare_query(query, source, selected_binding, limit, opts) do
    query
    |> ensure_limit(source, selected_binding, limit, opts)
    |> ensure_order(source, selected_binding, opts)
  end

  defp ensure_limit(query, source, selected_binding, limit, opts) do
    if has_limit?(query) do
      query
    else
      Limit.build_query(:limit, source, query, selected_binding, limit, opts)
    end
  end

  defp ensure_order(query, source, selected_binding, opts) do
    if has_order?(query) do
      query
    else
      sort_keys =
        source
        |> CommonSchema.get_schema_reflection(:primary_key)
        |> Kernel.||(:id)
        |> List.wrap()

      order_entries = Enum.map(sort_keys, &{:asc, &1})

      OrderBy.build_query(:order_by, source, query, selected_binding, order_entries, opts)
    end
  end

  defp has_limit?(%{limit: nil}), do: false
  defp has_limit?(%{limit: _}), do: true

  defp has_order?(%{order_bys: []}), do: false
  defp has_order?(%{order_bys: _}), do: true

  ## Generated Functions

  {_, binding_patterns} = QueryBinding.query_binding_contracts(__MODULE__)

  for {quoted_binding_head, quoted_binding_body} <- binding_patterns do
    defp with_ties_expr(query, unquote(quoted_binding_head), value) do
      Query.with_ties(
        query,
        [unquote_splicing(quoted_binding_body)],
        ^value
      )
    end
  end
end
