defmodule EctoShorts.CommonFilters.SchemalessWindowsTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing

  alias EctoShorts.CommonFilters

  import Ecto.Query

  describe "windows shapes (schemaless)" do
    test "matches Ecto.Query for a root windows partition_by atom" do
      field_name = :author_id

      expected =
        windows("posts", [p], post_window: [partition_by: [field(p, ^field_name)], order_by: []])

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{windows: [post_window: [partition_by: :author_id]]},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for a root windows partition_by list and order_by keyword list" do
      partition_field = :author_id
      order_field = :inserted_at

      expected =
        windows("posts", [p],
          post_window: [
            partition_by: [field(p, ^partition_field), field(p, ^:title)],
            order_by: [desc: field(p, ^order_field)]
          ]
        )

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{
            windows: [
              post_window: [partition_by: [:author_id, :title], order_by: [desc: :inserted_at]]
            ]
          },
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for multiple windows in one payload" do
      author_field = :author_id
      inserted_at_field = :inserted_at

      expected =
        "posts"
        |> windows([p],
          post_window: [partition_by: [field(p, ^author_field)], order_by: []]
        )
        |> windows([p],
          recent_window: [partition_by: [], order_by: [desc: field(p, ^inserted_at_field)]]
        )

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          [
            windows: [
              post_window: [partition_by: :author_id],
              recent_window: [order_by: [desc: :inserted_at]]
            ]
          ],
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for a root window reference by name only" do
      author_field = :author_id

      expected =
        "posts"
        |> windows([p],
          base_window: [partition_by: [field(p, ^author_field)], order_by: []]
        )
        |> windows([p],
          child_window: [partition_by: [field(p, ^author_field)], order_by: []]
        )

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{
            windows: [
              base_window: [partition_by: :author_id],
              child_window: [window: :base_window]
            ]
          },
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for a root window reference with local overrides" do
      author_field = :author_id
      inserted_at_field = :inserted_at

      expected =
        "posts"
        |> windows([p],
          base_window: [partition_by: [field(p, ^author_field)], order_by: []]
        )
        |> windows([p],
          child_window: [
            partition_by: [field(p, ^author_field)],
            order_by: [desc: field(p, ^inserted_at_field)]
          ]
        )

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{
            windows: [
              base_window: [partition_by: :author_id],
              child_window: [window: :base_window, order_by: [desc: :inserted_at]]
            ]
          },
          []
        )

      assert_query(expected, actual)
    end
  end
end
