defmodule EctoShorts.CommonFilters.ParentAsTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing
  @moduletag adapter: :postgres
  @moduletag feature: :parent_as

  alias EctoShorts.CommonFilters
  alias EctoShorts.Schema.Comment
  alias EctoShorts.Schema.Post

  import Ecto.Query

  describe "parent_as equality" do
    test "matches Ecto.Query for a root binding equality" do
      expected = from(c in Comment, where: c.post_id == field(parent_as(:post), :id))

      actual =
        CommonFilters.convert_params_to_filter(
          Comment,
          %{post_id: %{parent_as: %{post: :id}}},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for a negated root binding equality" do
      expected = from(c in Comment, where: c.post_id != field(parent_as(:post), :id))

      actual =
        CommonFilters.convert_params_to_filter(
          Comment,
          %{post_id: %{not: %{parent_as: %{post: :id}}}},
          []
        )

      assert_query(expected, actual)
    end
  end

  describe "parent_as comparison operators" do
    test "matches Ecto.Query for a greater-than comparison" do
      expected = from(p in Post, where: p.views > field(parent_as(:post), :views))

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{views: %{>: %{parent_as: %{post: :views}}}},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for a negated greater-than comparison" do
      expected = from(p in Post, where: not (p.views > field(parent_as(:post), :views)))

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{views: %{not: %{>: %{parent_as: %{post: :views}}}}},
          []
        )

      assert_query(expected, actual)
    end
  end

  describe "parent_as named binding" do
    test "matches Ecto.Query for a named binding equality" do
      source = from(c in Comment, join: p in assoc(c, :post), as: :post_join)

      expected =
        from(c in Comment,
          join: p in assoc(c, :post),
          as: :post_join,
          where: p.id == field(parent_as(:post), :id)
        )

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{as: %{post_join: %{id: %{parent_as: %{post: :id}}}}},
          []
        )

      assert_query(expected, actual)
    end
  end
end
