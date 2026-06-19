defmodule EctoShorts.CommonFilters.LimitTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing
  @moduletag adapter: :postgres
  @moduletag feature: :limit

  alias EctoShorts.CommonFilters
  alias EctoShorts.CommonFilters.Limit
  alias EctoShorts.Schema.Post

  import Ecto.Query


  describe "fallthrough binding" do
    test "applies limit with no binding when selector is unrecognized" do
      expected = limit(Post, ^5)
      q = from(p in Post)

      actual = Limit.build_query(:limit, Post, q, {:unknown_binding, :foo}, 5, [])

      assert_query(expected, actual)
    end
  end

  # ---- merged from first_limit_offset (schemaless) ----
  describe "first, limit, offset shapes (schemaless)" do
    @describetag feature: :first_limit_offset
    @describetag schema_mode: :schemaless
    test "matches Ecto.Query for a root integer first" do
      expected = limit("posts", ^10)

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{first: 10},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for a root integer limit" do
      expected = limit("posts", ^10)

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{limit: 10},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for a root integer offset" do
      expected = offset("posts", ^5)

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{offset: 5},
          []
        )

      assert_query(expected, actual)
    end
  end
end
