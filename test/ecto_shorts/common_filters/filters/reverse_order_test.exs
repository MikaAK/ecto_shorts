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

  describe "reverse_order false is a no-op" do
    test "returns query unchanged when reverse_order is false" do
      expected = from(p in Post, order_by: [asc: p.title])

      actual =
        CommonFilters.convert_params_to_filter(expected, %{reverse_order: false}, [])

      assert_query(expected, actual)
    end
  end

  describe "reverse_order invalid scalar guard" do
    import ExUnit.CaptureLog

    test "returns query unchanged and warns when reverse_order is a non-boolean scalar" do
      expected = from(p in Post, order_by: [asc: p.title])

      log =
        capture_log(fn ->
          actual =
            CommonFilters.convert_params_to_filter(expected, %{reverse_order: 0}, [])

          assert_query(expected, actual)
        end)

      assert log =~ "Expected"
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
