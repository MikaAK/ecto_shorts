defmodule EctoShorts.CommonFilters.SetOperation do
  @moduledoc false

  alias Ecto.Query
  alias EctoShorts.CommonFilters

  require Ecto.Query

  @set_operation_filters [:except, :except_all, :intersect, :intersect_all, :union, :union_all]

  def build_query(filter, source, query, _selected_binding, term, opts)
      when filter in @set_operation_filters do
    source
    |> to_query(term, opts)
    |> apply_set_operation(filter, query)
  end

  defp to_query(_source, %Ecto.Query{} = query, _opts) do
    query
  end

  defp to_query(source, term, opts) do
    CommonFilters.convert_params_to_filter(source, term, opts)
  end

  for filter <- @set_operation_filters do
    defp apply_set_operation(expr, unquote(filter), query) do
      Query.unquote(filter)(query, ^expr)
    end
  end
end
