defmodule EctoShorts.CommonFilters.SchemalessHavingTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing

  alias EctoShorts.CommonFilters

  import Ecto.Query

  describe "having shapes (schemaless)" do
    test "matches Ecto.Query for a root aggregate having" do
      source = from(p in "posts", group_by: p.author_id)
      expected = from(p in "posts", group_by: p.author_id, having: avg(p.views) > ^100)

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{having: %{views: %{avg: %{>: 100}}}},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for a root negated having" do
      source = from(p in "posts", group_by: [p.title, p.views])
      expected = from(p in "posts", group_by: [p.title, p.views], having: not (p.views > ^10))

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{having: %{views: %{not: %{>: 10}}}},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for a root dynamic having" do
      source = from(p in "posts", group_by: p.author_id)
      dynamic_expr = dynamic([p], avg(p.views) > 10)
      expected = from(p in "posts", group_by: p.author_id, having: ^dynamic_expr)

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{having: dynamic_expr},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for a root or_having" do
      source = from(p in "posts", group_by: [p.title, p.views])
      expected = from(p in "posts", group_by: [p.title, p.views], or_having: p.views < ^5)

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{or_having: %{views: %{<: 5}}},
          []
        )

      assert_query(expected, actual)
    end
  end
end
