defmodule EctoShorts.CommonFilters.SchemalessLastTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing

  alias EctoShorts.CommonFilters

  import Ecto.Query

  describe "last shapes (schemaless)" do
    test "matches Ecto.Query for a root integer last payload" do
      expected =
        "posts"
        |> exclude(:order_by)
        |> order_by([], desc: :id)
        |> limit(^2)
        |> subquery()
        |> order_by([], asc: :id)

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{last: 2},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for a root keyword last payload" do
      expected =
        "posts"
        |> exclude(:order_by)
        |> order_by([], desc: :title)
        |> limit(^2)
        |> subquery()
        |> order_by([], asc: :title)

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{last: [title: 2]},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for an explicit id last payload" do
      expected =
        "posts"
        |> exclude(:order_by)
        |> order_by([], desc: :id)
        |> limit(^2)
        |> subquery()
        |> order_by([], asc: :id)

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{last: %{id: 2}},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for terminal last wrapping after local filters" do
      expected =
        "posts"
        |> where([p], p.published == ^true)
        |> exclude(:order_by)
        |> order_by([], desc: :id)
        |> limit(^2)
        |> subquery()
        |> order_by([], asc: :id)

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          [last: 2, published: true],
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query when last replaces a previous order_by" do
      expected =
        "posts"
        |> order_by([], desc: :title)
        |> exclude(:order_by)
        |> order_by([], desc: :id)
        |> limit(^2)
        |> subquery()
        |> order_by([], asc: :id)

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          [last: 2, order_by: :title],
          []
        )

      assert_query(expected, actual)
    end
  end
end
