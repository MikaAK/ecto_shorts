defmodule EctoShorts.CommonFilters.UnionTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing
  @moduletag adapter: :postgres
  @moduletag feature: :union

  alias EctoShorts.CommonFilters
  alias EctoShorts.Schema.Post

  import Ecto.Query

  describe "set operation shapes" do
    test "matches Ecto.Query for union with filter params" do
      other_query = from(p in Post, where: p.published == ^false)
      expected = union(Post, ^other_query)

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{union: %{published: false}},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for union with a prebuilt query" do
      other_query = from(p in Post, where: p.published == ^false)
      expected = union(Post, ^other_query)

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{union: other_query},
          []
        )

      assert_query(expected, actual)
    end

    test "returns query unchanged when union is nil" do
      expected = from(p in Post)
      actual = CommonFilters.convert_params_to_filter(expected, %{union: nil}, [])
      assert_query(expected, actual)
    end
  end

  describe "union invalid scalar guard" do
    import ExUnit.CaptureLog

    test "returns query unchanged and warns when union value is a non-map, non-list scalar" do
      expected = from(p in Post)

      log =
        capture_log(fn ->
          actual = CommonFilters.convert_params_to_filter(Post, %{union: 5}, [])
          assert_query(expected, actual)
        end)

      assert log =~ "Expected"
    end
  end

  describe "set operation shapes (schemaless)" do
    @describetag schema_mode: :schemaless
    test "matches Ecto.Query for union with filter params" do
      other_query = from(p in "posts", where: p.published == ^false)
      expected = union("posts", ^other_query)

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{union: %{published: false}},
          []
        )

      assert_query(expected, actual)
    end
  end
end
