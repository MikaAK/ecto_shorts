defmodule EctoShorts.CommonFilters.SchemalessFirstTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing

  alias EctoShorts.CommonFilters

  import Ecto.Query

  describe "convert_params_to_filter/3 first shapes (schemaless)" do
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
  end
end
