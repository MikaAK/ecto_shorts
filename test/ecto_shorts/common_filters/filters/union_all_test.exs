defmodule EctoShorts.CommonFilters.UnionAllTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing
  @moduletag adapter: :postgres
  @moduletag feature: :union_all

  alias EctoShorts.CommonFilters
  alias EctoShorts.Schema.Post

  import Ecto.Query

  describe "set operation shapes" do
    test "matches Ecto.Query for union_all with filter params" do
      other_query = from(p in Post, where: p.published == ^false)
      expected = union_all(Post, ^other_query)

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{union_all: %{published: false}},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for union_all with a prebuilt query" do
      other_query = from(p in Post, where: p.published == ^false)
      expected = union_all(Post, ^other_query)

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{union_all: other_query},
          []
        )

      assert_query(expected, actual)
    end

    test "returns query unchanged when union_all is nil" do
      expected = from(p in Post)
      actual = CommonFilters.convert_params_to_filter(expected, %{union_all: nil}, [])
      assert_query(expected, actual)
    end
  end
end
