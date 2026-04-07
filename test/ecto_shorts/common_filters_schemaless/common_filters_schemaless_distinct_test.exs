defmodule EctoShorts.CommonFilters.SchemalessDistinctTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing

  alias EctoShorts.CommonFilters

  import Ecto.Query

  describe "distinct shapes (schemaless)" do
    test "matches Ecto.Query for a root boolean distinct" do
      expected = from(p in "posts", distinct: true)

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{distinct: true},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for a root distinct atom" do
      expected = from(p in "posts", distinct: :title)

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{distinct: :title},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for a root distinct ordered keyword list" do
      expected = from(p in "posts", distinct: [desc: :title])

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{distinct: [desc: :title]},
          []
        )

      assert_query(expected, actual)
    end
  end
end
