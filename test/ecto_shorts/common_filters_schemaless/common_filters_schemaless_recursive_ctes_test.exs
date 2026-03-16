defmodule EctoShorts.CommonFilters.SchemalessRecursiveCtesTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing

  alias EctoShorts.CommonFilters

  import Ecto.Query

  describe "convert_params_to_filter/3 recursive_ctes shapes (schemaless)" do
    test "matches Ecto.Query for recursive_ctes true" do
      expected = recursive_ctes("posts", true)

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{recursive_ctes: true},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for recursive_ctes false" do
      expected = recursive_ctes("posts", false)

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{recursive_ctes: false},
          []
        )

      assert_query(expected, actual)
    end
  end
end
