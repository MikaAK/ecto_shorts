defmodule EctoShorts.CommonFilters.Schemaless.OrderModifierTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing
  @moduletag adapter: :postgres
  @moduletag schema_mode: :schemaless
  @moduletag feature: :order_modifier

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
