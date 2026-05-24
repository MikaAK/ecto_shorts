defmodule EctoShorts.CommonFiltersTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing

  import Ecto.Query

  alias EctoShorts.CommonFilters
  alias EctoShorts.Schema.Post

  describe "filters/0" do
    test "returns the list of supported filter keys" do
      filters = CommonFilters.filters()

      assert is_list(filters)
      assert :where in filters
      assert :limit in filters
      assert :offset in filters
    end
  end

  describe "convert_params_to_filter/3 custom sorter" do
    test "uses the provided sorter function to order params before applying" do
      # A sorter that reverses the params order — still produces a valid query
      sorter = fn params -> Enum.reverse(params) end

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          [limit: 5, offset: 10],
          sorter: sorter
        )

      assert %Ecto.Query{} = actual
    end
  end

  describe "convert_params_to_filter/3 where with empty list" do
    test "returns query unchanged when where params is an empty list" do
      expected = from(p in Post)

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{where: []},
          []
        )

      assert_query(expected, actual)
    end
  end
end
