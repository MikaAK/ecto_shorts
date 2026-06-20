defmodule EctoShorts.CommonFilters.IntersectAllTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing
  @moduletag adapter: :postgres
  @moduletag feature: :intersect_all

  alias EctoShorts.CommonFilters
  alias EctoShorts.Schema.Post

  import Ecto.Query

  import ExUnit.CaptureLog

  describe "set operation shapes" do
    test "matches Ecto.Query for intersect_all with filter params" do
      other_query = from(p in Post, where: p.published == ^false)
      expected = intersect_all(Post, ^other_query)

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{intersect_all: %{published: false}},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for intersect_all with a prebuilt query" do
      other_query = from(p in Post, where: p.published == ^false)
      expected = intersect_all(Post, ^other_query)

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{intersect_all: other_query},
          []
        )

      assert_query(expected, actual)
    end

    test "returns query unchanged when intersect_all is nil" do
      expected = from(p in Post)
      actual = CommonFilters.convert_params_to_filter(expected, %{intersect_all: nil}, [])
      assert_query(expected, actual)
    end
  end
  describe "intersect_all invalid scalar guard" do

    test "returns query unchanged and warns when intersect_all value is a non-map, non-list scalar" do
      expected = from(p in Post)

      log =
        capture_log(fn ->
          actual = CommonFilters.convert_params_to_filter(Post, %{intersect_all: 5}, [])
          assert_query(expected, actual)
        end)

      assert log =~ "Expected"
    end
  end
end