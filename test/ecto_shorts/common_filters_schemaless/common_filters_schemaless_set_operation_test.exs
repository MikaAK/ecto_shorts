defmodule EctoShorts.CommonFilters.SchemalessSetOperationTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing

  alias EctoShorts.CommonFilters

  import Ecto.Query

  describe "set operation shapes (schemaless)" do
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
