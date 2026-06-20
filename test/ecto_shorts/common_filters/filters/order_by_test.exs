defmodule EctoShorts.CommonFilters.OrderByTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing
  @moduletag adapter: :postgres
  @moduletag feature: :order_by

  alias EctoShorts.CommonFilters
  alias EctoShorts.Schema.Post

  import Ecto.Query
  import ExUnit.CaptureLog

  describe "order_by list shapes" do
    test "orders by a list of direction-field tuples" do
      expected = from(p in Post, order_by: [asc: p.title, desc: p.views])

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{order_by: [asc: :title, desc: :views]},
          []
        )

      assert_query(expected, actual)
    end

    test "orders by a list of bare atoms defaulting to asc" do
      expected = from(p in Post, order_by: [asc: p.title, asc: p.views])

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{order_by: [:title, :views]},
          []
        )

      assert_query(expected, actual)
    end
  end

  describe "order_by DynamicExpr and fallthrough paths" do
    test "order_by passes a DynamicExpr entry through unchanged in a list" do
      dyn = dynamic([p], p.views > ^0)

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{order_by: [dyn]},
          []
        )

      refute is_nil(actual)
    end

    test "order_by passes a non-atom non-dynamic list entry through as-is (other branch)" do
      dyn = dynamic([p], p.views > ^0)

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{order_by: [asc: dyn]},
          []
        )

      assert %Ecto.Query{} = actual
    end

    test "order_by accepts a keyword list of direction-field pairs" do
      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{order_by: [asc: :title, desc: :views]},
          []
        )

      assert %Ecto.Query{} = actual
    end
  end

  describe "order_by edge cases" do
    test "accepts a map input for order_by" do
      # Map.to_list(%{asc: :title}) = [{:asc, :title}] — valid direction-field tuple
      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{order_by: %{asc: :title}},
          []
        )

      assert %Ecto.Query{} = actual
    end

    test "skips invalid schema field in order_by list and returns query unchanged" do
      expected = from(p in Post)

      log =
        capture_log(fn ->
          actual =
            CommonFilters.convert_params_to_filter(
              Post,
              %{order_by: [{:asc, :nonexistent_field}]},
              []
            )

          assert_query(expected, actual)
        end)

      assert log =~ "nonexistent_field"
    end
  end

  describe "order_by fallback for non-standard expr" do
    test "accepts a bare DynamicExpr as an order_by value" do
      dyn = dynamic([p], p.id)
      expected = from(p in Post, order_by: ^dyn)

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{order_by: dyn},
          []
        )

      assert_query(expected, actual)
    end
  end

  describe "order modifier shapes (schemaless)" do
    @describetag schema_mode: :schemaless
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
  end

  describe "order_by invalid scalar guard" do

    test "returns query unchanged and warns when order_by is a non-atom scalar" do
      expected = from(p in Post)

      log =
        capture_log(fn ->
          actual = CommonFilters.convert_params_to_filter(Post, %{order_by: 5}, [])
          assert_query(expected, actual)
        end)

      assert log =~ "Expected"
    end
  end
end
