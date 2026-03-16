defmodule EctoShorts.CommonFilters.SchemalessSelectTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing

  alias EctoShorts.CommonFilters

  import Ecto.Query
  import ExUnit.CaptureLog

  describe "convert_params_to_filter/3 select shapes (schemaless)" do
    test "matches Ecto.Query for a root select field atom" do
      expected = from(p in "posts", select: p.title)

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{select: :title},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for selecting the full root binding" do
      expected = from(p in "posts", select: p)

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{select: true},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for a root select map field list" do
      expected = from(p in "posts", select: map(p, [:id, :title]))

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{select: {:map, [:id, :title]}},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for a root select map alias mapping" do
      expected =
        from(p in "posts",
          select: %{post_id: p.id, post_title: p.title}
        )

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{select: {:map, %{post_id: :id, post_title: :title}}},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query when select overwrites an existing select" do
      source = from(p in "posts", select: p.title)
      expected = from(p in "posts", select: p.id)

      log =
        capture_log(fn ->
          actual =
            CommonFilters.convert_params_to_filter(
              source,
              %{select: :id},
              []
            )

          assert_query(expected, actual)
        end)

      assert log =~ "Query already has a :select expression"
    end
  end
end
