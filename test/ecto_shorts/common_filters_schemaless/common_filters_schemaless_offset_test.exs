defmodule EctoShorts.CommonFilters.SchemalessOffsetTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing

  alias EctoShorts.CommonFilters

  import Ecto.Query

  describe "offset shapes (schemaless)" do
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
