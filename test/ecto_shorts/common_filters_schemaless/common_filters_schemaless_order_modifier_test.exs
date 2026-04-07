defmodule EctoShorts.CommonFilters.SchemalessOrderModifierTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing

  alias EctoShorts.CommonFilters

  import Ecto.Query

  describe "order modifier shapes (schemaless)" do
    test "matches Ecto.Query for a root order_by atom" do
      expected = from(p in "posts", order_by: [asc: :title])

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{order_by: :title},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for a root order_by ordered keyword list" do
      expected = from(p in "posts", order_by: [asc: :title, desc: :id])

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{order_by: [asc: :title, desc: :id]},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for a root prepend_order_by atom" do
      expected = prepend_order_by("posts", [], desc: :title)

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{prepend_order_by: :title},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for a root prepend_order_by ordered keyword list" do
      expected =
        prepend_order_by(
          "posts",
          [],
          asc: :id,
          desc: :title
        )

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{prepend_order_by: [asc: :id, desc: :title]},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for reverse_order on an existing ordered query" do
      source = from(p in "posts", order_by: [asc: p.title])
      expected = reverse_order(source)

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{reverse_order: true},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for reverse_order after local order_by params" do
      expected =
        "posts"
        |> order_by([], asc: :title)
        |> reverse_order()

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{order_by: :title, reverse_order: true},
          []
        )

      assert_query(expected, actual)
    end
  end
end
