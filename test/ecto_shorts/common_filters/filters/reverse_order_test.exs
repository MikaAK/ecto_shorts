defmodule EctoShorts.CommonFilters.ReverseOrderTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing
  @moduletag adapter: :postgres
  @moduletag feature: :reverse_order

  alias EctoShorts.CommonFilters
  alias EctoShorts.Schema.Post

  import Ecto.Query

  describe "reverse_order nil" do
    test "reverses the query order when reverse_order is nil" do
      source = from(p in Post, order_by: [asc: p.title])
      expected = reverse_order(source)

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{reverse_order: nil},
          []
        )

      assert_query(expected, actual)
    end
  end

  describe "reverse_order raises on non-true value (D-RAISE)" do
    test "raises when reverse_order is not true" do
      base = from(p in Post, order_by: [asc: p.title])

      assert_raise EctoShorts.FilterError, ~r/reverse_order/, fn ->
        CommonFilters.convert_params_to_filter(base, %{reverse_order: false}, [])
      end
    end
  end

  describe "order modifier shapes (schemaless)" do
    @describetag schema_mode: :schemaless
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
