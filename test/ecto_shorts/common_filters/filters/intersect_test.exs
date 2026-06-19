defmodule EctoShorts.CommonFilters.IntersectTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing
  @moduletag adapter: :postgres
  @moduletag feature: :intersect

  alias EctoShorts.CommonFilters
  alias EctoShorts.Schema.Post

  import Ecto.Query

  describe "set operation shapes" do
    test "matches Ecto.Query for intersect with filter params" do
      other_query = from(p in Post, where: p.published == ^false)
      expected = intersect(Post, ^other_query)

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{intersect: %{published: false}},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for intersect with a prebuilt query" do
      other_query = from(p in Post, where: p.published == ^false)
      expected = intersect(Post, ^other_query)

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{intersect: other_query},
          []
        )

      assert_query(expected, actual)
    end

    test "returns query unchanged when intersect is nil" do
      expected = from(p in Post)
      actual = CommonFilters.convert_params_to_filter(expected, %{intersect: nil}, [])
      assert_query(expected, actual)
    end
  end
end
