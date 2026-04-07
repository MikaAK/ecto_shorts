defmodule EctoShorts.CommonFilters.SchemalessSelectMergeTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing

  alias EctoShorts.CommonFilters

  import Ecto.Query

  describe "select_merge shapes (schemaless)" do
    test "matches Ecto.Query for a root select_merge keyword alias mapping" do
      source = from(p in "posts", select: %{})

      expected =
        from(p in "posts",
          select: %{},
          select_merge: %{post_title: p.title}
        )

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{select_merge: [post_title: :title]},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for a root select_merge map alias mapping" do
      source = from(p in "posts", select: %{})

      expected =
        from(p in "posts",
          select: %{},
          select_merge: %{post_id: p.id, post_title: p.title}
        )

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{select_merge: %{post_id: :id, post_title: :title}},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for a root select_merge map tuple alias mapping" do
      source = from(p in "posts", select: %{})

      expected =
        from(p in "posts",
          select: %{},
          select_merge: %{post_title: p.title}
        )

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{select_merge: {:map, %{post_title: :title}}},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query when select_merge merges onto an existing select" do
      source = from(p in "posts", select: %{post_id: p.id})

      expected =
        from(p in "posts",
          select: %{post_id: p.id},
          select_merge: %{post_title: p.title}
        )

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{select_merge: %{post_title: :title}},
          []
        )

      assert_query(expected, actual)
    end
  end
end
