defmodule EctoShorts.CommonFilters.Builder do
  @moduledoc since: "3.0.0"
  @moduledoc false

  alias Ecto.Query
  alias EctoShorts.CommonQuery
  alias EctoShorts.DynamicBuilders

  alias EctoShorts.CommonFilters.{
    Distinct,
    Except,
    ExceptAll,
    GroupBy,
    Having,
    Intersect,
    IntersectAll,
    OrHaving,
    Join,
    Last,
    Limit,
    Lock,
    Offset,
    OrderBy,
    PrependOrderBy,
    Preload,
    PutQueryPrefix,
    RecursiveCtes,
    ReverseOrder,
    Select,
    SelectMerge,
    SubQuery,
    Union,
    UnionAll,
    Update,
    Windows,
    WithCte,
    WithTies,
    WithNamedBinding
  }

  require Ecto.Query

  @behaviour EctoShorts.Adapter.QueryBuilder

  @impl EctoShorts.Adapter.QueryBuilder
  def build_query(filter, source, query, selected_binding, term, opts) do
    apply_filter(filter, source, query, selected_binding, term, opts)
  end

  defp apply_filter(:distinct, source, query, selected_binding, term, opts) do
    Distinct.build_query(:distinct, source, query, selected_binding, term, opts)
  end

  defp apply_filter(:last, source, query, selected_binding, term, opts) do
    Last.build_query(:last, source, query, selected_binding, term, opts)
  end

  defp apply_filter(:join, source, query, selected_binding, term, opts) do
    Join.build_query(:join, source, query, selected_binding, term, opts)
  end

  defp apply_filter(:group_by, source, query, selected_binding, term, opts) do
    GroupBy.build_query(:group_by, source, query, selected_binding, term, opts)
  end

  defp apply_filter(:having, source, query, selected_binding, term, opts) do
    Having.build_query(:having, source, query, selected_binding, term, opts)
  end

  defp apply_filter(:or_having, source, query, selected_binding, term, opts) do
    OrHaving.build_query(:or_having, source, query, selected_binding, term, opts)
  end

  defp apply_filter(:order_by, source, query, selected_binding, term, opts) do
    OrderBy.build_query(:order_by, source, query, selected_binding, term, opts)
  end

  defp apply_filter(:prepend_order_by, source, query, selected_binding, term, opts) do
    PrependOrderBy.build_query(:prepend_order_by, source, query, selected_binding, term, opts)
  end

  defp apply_filter(:reverse_order, source, query, selected_binding, term, opts) do
    ReverseOrder.build_query(:reverse_order, source, query, selected_binding, term, opts)
  end

  defp apply_filter(:preload, source, query, selected_binding, term, opts) do
    Preload.build_query(:preload, source, query, selected_binding, term, opts)
  end

  defp apply_filter(:subquery, source, query, selected_binding, term, opts) do
    SubQuery.build_query(:subquery, source, query, selected_binding, term, opts)
  end

  defp apply_filter(:put_query_prefix, source, query, selected_binding, prefix, opts) do
    PutQueryPrefix.build_query(:put_query_prefix, source, query, selected_binding, prefix, opts)
  end

  defp apply_filter(:recursive_ctes, source, query, selected_binding, value, opts) do
    RecursiveCtes.build_query(:recursive_ctes, source, query, selected_binding, value, opts)
  end

  defp apply_filter(:windows, source, query, selected_binding, term, opts) do
    Windows.build_query(:windows, source, query, selected_binding, term, opts)
  end

  defp apply_filter(:with_cte, source, query, selected_binding, term, opts) do
    WithCte.build_query(:with_cte, source, query, selected_binding, term, opts)
  end

  defp apply_filter(:with_ties, source, query, selected_binding, term, opts) do
    WithTies.build_query(:with_ties, source, query, selected_binding, term, opts)
  end

  defp apply_filter(:select, source, query, selected_binding, term, opts) do
    Select.build_query(:select, source, query, selected_binding, term, opts)
  end

  defp apply_filter(:select_merge, source, query, selected_binding, term, opts) do
    SelectMerge.build_query(:select_merge, source, query, selected_binding, term, opts)
  end

  defp apply_filter(:except, source, query, selected_binding, term, opts) do
    Except.build_query(:except, source, query, selected_binding, term, opts)
  end

  defp apply_filter(:except_all, source, query, selected_binding, term, opts) do
    ExceptAll.build_query(:except_all, source, query, selected_binding, term, opts)
  end

  defp apply_filter(:intersect, source, query, selected_binding, term, opts) do
    Intersect.build_query(:intersect, source, query, selected_binding, term, opts)
  end

  defp apply_filter(:intersect_all, source, query, selected_binding, term, opts) do
    IntersectAll.build_query(:intersect_all, source, query, selected_binding, term, opts)
  end

  defp apply_filter(:union, source, query, selected_binding, term, opts) do
    Union.build_query(:union, source, query, selected_binding, term, opts)
  end

  defp apply_filter(:union_all, source, query, selected_binding, term, opts) do
    UnionAll.build_query(:union_all, source, query, selected_binding, term, opts)
  end

  defp apply_filter(:exclude, _source, query, _selected_binding, term, _opts) do
    term
    |> List.wrap()
    |> Enum.reduce(query, fn field, query_acc ->
      Query.exclude(query_acc, field)
    end)
  end

  defp apply_filter(:lock, source, query, selected_binding, term, opts) do
    Lock.build_query(:lock, source, query, selected_binding, term, opts)
  end

  defp apply_filter(:first, source, query, selected_binding, term, opts) do
    Limit.build_query(:limit, source, query, selected_binding, term, opts)
  end

  defp apply_filter(:limit, source, query, selected_binding, term, opts) do
    Limit.build_query(:limit, source, query, selected_binding, term, opts)
  end

  defp apply_filter(:offset, source, query, selected_binding, term, opts) do
    Offset.build_query(:offset, source, query, selected_binding, term, opts)
  end

  defp apply_filter(:update, source, query, selected_binding, term, opts) do
    Update.build_query(:update, source, query, selected_binding, term, opts)
  end

  defp apply_filter(:with_named_binding, source, query, selected_binding, term, opts) do
    WithNamedBinding.build_query(:with_named_binding, source, query, selected_binding, term, opts)
  end

  defp apply_filter(:where, source, query, selected_binding, term, opts) do
    effective_source = resolve_source(source, query, selected_binding)

    case DynamicBuilders.build_dynamic(effective_source, selected_binding, term, opts) do
      nil -> query
      dyn -> Query.where(query, ^dyn)
    end
  end

  defp apply_filter(:or_where, source, query, selected_binding, term, opts) do
    effective_source = resolve_source(source, query, selected_binding)

    case DynamicBuilders.build_dynamic(effective_source, selected_binding, term, opts) do
      nil -> query
      dyn -> Query.or_where(query, ^dyn)
    end
  end

  defp resolve_source(source, _query, {:as, nil}), do: source

  defp resolve_source(source, query, {:as, name}) when is_atom(name) do
    CommonQuery.get_query_binding_source(query, name) || source
  end

  defp resolve_source(source, query, {:at, pos}) when is_integer(pos) do
    CommonQuery.get_query_binding_source(query, pos) || source
  end

  defp resolve_source(source, _query, _selected_binding), do: source
end
