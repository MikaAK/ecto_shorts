defmodule EctoShorts.CommonFilters.RecursiveCtesTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing

  alias EctoShorts.CommonFilters
  alias EctoShorts.Schema.Post

  import Ecto.Query

  describe "recursive_ctes shapes" do
    test "matches Ecto.Query for recursive_ctes true" do
      expected = recursive_ctes(Post, true)

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{recursive_ctes: true},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for recursive_ctes false" do
      expected = recursive_ctes(Post, false)

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{recursive_ctes: false},
          []
        )

      assert_query(expected, actual)
    end

    test "casts a string boolean recursive_ctes payload" do
      expected = recursive_ctes(Post, true)

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{recursive_ctes: "true"},
          []
        )

      assert_query(expected, actual)
    end
  end
end
