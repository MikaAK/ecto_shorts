defmodule EctoShorts.CommonFilters.SchemalessParentAsTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing

  alias EctoShorts.CommonFilters

  import Ecto.Query

  describe "parent_as equality (schemaless)" do
    test "matches Ecto.Query for a root binding equality" do
      expected = from(c in "comments", where: c.post_id == field(parent_as(:post), :id))

      actual =
        CommonFilters.convert_params_to_filter(
          "comments",
          %{post_id: %{parent_as: %{post: :id}}},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for a negated root binding equality" do
      expected = from(c in "comments", where: c.post_id != field(parent_as(:post), :id))

      actual =
        CommonFilters.convert_params_to_filter(
          "comments",
          %{post_id: %{not: %{parent_as: %{post: :id}}}},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for a greater-than comparison" do
      expected = from(c in "comments", where: c.id > field(parent_as(:post), :id))

      actual =
        CommonFilters.convert_params_to_filter(
          "comments",
          %{id: %{>: %{parent_as: %{post: :id}}}},
          []
        )

      assert_query(expected, actual)
    end
  end
end
