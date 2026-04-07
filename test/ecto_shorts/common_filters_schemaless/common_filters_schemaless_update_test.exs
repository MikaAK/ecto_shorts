defmodule EctoShorts.CommonFilters.SchemalessUpdateTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing

  alias EctoShorts.CommonFilters

  import Ecto.Query

  describe "update shapes (schemaless)" do
    test "matches Ecto.Query for a root update set payload" do
      updates = [set: [title: "After"]]
      expected = update("posts", [], ^updates)

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{update: [set: [title: "After"]]},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for a root update inc payload" do
      updates = [inc: [views: 1]]
      expected = update("posts", [], ^updates)

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{update: [inc: [views: 1]]},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for a root combined update payload" do
      updates = [set: [title: "After"], inc: [views: 1]]
      expected = update("posts", [], ^updates)

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{update: [set: [title: "After"], inc: [views: 1]]},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for a root update map payload" do
      updates = [set: [title: "After"]]
      expected = update("posts", [], ^updates)

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{update: %{set: %{title: "After"}}},
          []
        )

      assert_query(expected, actual)
    end
  end
end
