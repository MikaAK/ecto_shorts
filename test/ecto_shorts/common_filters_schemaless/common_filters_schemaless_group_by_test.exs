defmodule EctoShorts.CommonFilters.SchemalessGroupByTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing

  alias EctoShorts.CommonFilters

  import Ecto.Query

  describe "convert_params_to_filter/3 group_by shapes (schemaless)" do
    test "matches Ecto.Query for a root group_by atom" do
      expected = from(p in "posts", group_by: :author_id)

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{group_by: :author_id},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for a root group_by list" do
      expected = from(p in "posts", group_by: [:author_id, :title])

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{group_by: [:author_id, :title]},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for a root group_by dynamic list" do
      dynamic_expr = dynamic([p], fragment("lower(?)", p.title))
      expected = from(p in "posts", group_by: ^[:author_id, dynamic_expr])

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{group_by: [:author_id, dynamic_expr]},
          []
        )

      assert_query(expected, actual)
    end
  end
end
