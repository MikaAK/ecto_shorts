defmodule EctoShorts.CommonFilters.Schemaless.FirstLimitOffsetTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing
  @moduletag adapter: :postgres
  @moduletag schema_mode: :schemaless
  @moduletag feature: :first_limit_offset

  alias EctoShorts.CommonFilters

  import Ecto.Query

  describe "first, limit, offset shapes (schemaless)" do
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
