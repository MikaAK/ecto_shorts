defmodule EctoShorts.CommonFilters.SortingTest do
  use ExUnit.Case, async: true

  test "orders where -> others -> or_where -> terminal, preserving within-group order" do
    params = [or_where: %{x: 1}, limit: 10, where: %{a: 1}, subquery: %{}, where: %{b: 2}, last: 5]

    assert EctoShorts.CommonFilters.sort_filter_params(params) ==
             [where: %{a: 1}, where: %{b: 2}, limit: 10, or_where: %{x: 1}, subquery: %{}, last: 5]
  end
end
