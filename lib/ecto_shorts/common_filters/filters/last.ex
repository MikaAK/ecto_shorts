defmodule EctoShorts.CommonFilters.Last do
  @moduledoc since: "3.0.0"
  @moduledoc false

  alias EctoShorts.CommonSchema
  alias EctoShorts.Types

  alias Ecto.Query
  require Ecto.Query

  @logger_prefix "EctoShorts.CommonFilters.Last"

  def build_query(:last, source, query, _selected_binding, {sort_key, limit}, _opts)
      when is_integer(limit) do
    sort_keys =
      if is_nil(sort_key) do
        source
        |> CommonSchema.get_schema_reflection(:primary_key)
        |> Kernel.||(:id)
        |> List.wrap()
      else
        List.wrap(sort_key)
      end

    excluded = Query.exclude(query, :order_by)

    subquery =
      sort_keys
      |> Enum.reduce(excluded, &Query.order_by(&2, desc: ^&1))
      |> Query.limit(^limit)
      |> Query.subquery()

    Enum.reduce(sort_keys, subquery, &Query.order_by(&2, asc: ^&1))
  end

  def build_query(:last, source, query, selected_binding, limit, opts)
      when is_integer(limit) or is_binary(limit) do
    build_query(:last, source, query, selected_binding, {nil, limit}, opts)
  end

  def build_query(:last, source, query, selected_binding, {sort_key, limit}, opts) do
    build_query(
      :last,
      source,
      query,
      selected_binding,
      {sort_key, Types.cast(:integer, limit)},
      opts
    )
  end

  def build_query(:last, source, query, selected_binding, term, opts)
      when (is_map(term) and not is_struct(term)) or is_list(term) do
    if is_map(term) or Keyword.keyword?(term) do
      Enum.reduce(term, query, fn entry, query_acc ->
        build_query(:last, source, query_acc, selected_binding, entry, opts)
      end)
    else
      EctoShorts.LogUtils.warning(
        @logger_prefix,
        "Expected :last value to be an integer, a {sort_key, limit} tuple, or a map/keyword list of such pairs, got: #{inspect(term)}"
      )

      query
    end
  end
end
