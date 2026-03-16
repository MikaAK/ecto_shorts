defmodule EctoShorts.CommonFilters.LimitTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing

  alias EctoShorts.CommonFilters
  alias EctoShorts.CommonFilters.Limit
  alias EctoShorts.Schema.Post

  import Ecto.Query

  describe "Limit.build_query/6 fallthrough binding" do
    test "applies limit with no binding when selector is unrecognized" do
      expected = limit(Post, ^5)
      q = from(p in Post)

      actual = Limit.build_query(:limit, Post, q, {:unknown_binding, :foo}, 5, [])

      assert_query(expected, actual)
    end
  end

  describe "convert_params_to_filter/3 limit shapes" do
    test "matches Ecto.Query for a root integer limit" do
      expected = limit(Post, ^10)

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{limit: 10},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query when limit overrides a previous limit" do
      expected = limit(Post, ^10)

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{limit: 10},
          []
        )

      assert_query(expected, actual)
    end
  end
end
