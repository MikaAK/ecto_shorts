defmodule EctoShorts.CommonFilters.Page do
  @moduledoc since: "3.0.0"
  @moduledoc false

  alias EctoShorts.CommonFilters.{Limit, Offset, OrderBy}
  alias EctoShorts.QueryBinding
  alias EctoShorts.Types

  alias Ecto.Query
  require Ecto.Query

  # Shape 1 — offset-based: %{index: N, size: M}
  def build_query(:page, source, query, selected_binding, %{index: index, size: size}, opts) do
    offset = (Types.cast(:integer, index) - 1) * Types.cast(:integer, size)
    limit = Types.cast(:integer, size)

    query
    |> then(&Limit.build_query(:limit, source, &1, selected_binding, limit, opts))
    |> then(&Offset.build_query(:offset, source, &1, selected_binding, offset, opts))
  end

  # Shape 2a — cursor forward: %{after: cursor, by: field, size: N}
  def build_query(
        :page,
        source,
        query,
        selected_binding,
        %{after: nil, by: field, size: size},
        opts
      ) do
    limit = Types.cast(:integer, size)

    query
    |> then(&OrderBy.build_query(:order_by, source, &1, selected_binding, {:asc, field}, opts))
    |> Query.limit(^limit)
  end

  def build_query(
        :page,
        source,
        query,
        selected_binding,
        %{after: cursor, by: field, size: size},
        opts
      ) do
    dyn = cursor_gt_dynamic(selected_binding, field, cursor)
    limit = Types.cast(:integer, size)

    query
    |> Query.where(^dyn)
    |> then(&OrderBy.build_query(:order_by, source, &1, selected_binding, {:asc, field}, opts))
    |> Query.limit(^limit)
  end

  # Shape 2b — cursor backward: %{before: cursor, by: field, size: N}
  def build_query(
        :page,
        source,
        query,
        selected_binding,
        %{before: nil, by: field, size: size},
        opts
      ) do
    limit = Types.cast(:integer, size)

    query
    |> then(&OrderBy.build_query(:order_by, source, &1, selected_binding, {:desc, field}, opts))
    |> Query.limit(^limit)
  end

  def build_query(
        :page,
        source,
        query,
        selected_binding,
        %{before: cursor, by: field, size: size},
        opts
      ) do
    dyn = cursor_lt_dynamic(selected_binding, field, cursor)
    limit = Types.cast(:integer, size)

    query
    |> Query.where(^dyn)
    |> then(&OrderBy.build_query(:order_by, source, &1, selected_binding, {:desc, field}, opts))
    |> Query.limit(^limit)
  end

  ## Generated Functions

  {target_binding_var, binding_patterns} = QueryBinding.query_binding_contracts(__MODULE__)

  for {quoted_binding_head, quoted_binding_body} <- binding_patterns do
    defp cursor_gt_dynamic(unquote(quoted_binding_head), field, cursor) do
      Query.dynamic(
        [unquote_splicing(quoted_binding_body)],
        field(unquote(target_binding_var), ^field) > ^cursor
      )
    end

    defp cursor_lt_dynamic(unquote(quoted_binding_head), field, cursor) do
      Query.dynamic(
        [unquote_splicing(quoted_binding_body)],
        field(unquote(target_binding_var), ^field) < ^cursor
      )
    end
  end
end
