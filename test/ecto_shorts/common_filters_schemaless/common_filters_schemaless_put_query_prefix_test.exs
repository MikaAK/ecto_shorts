defmodule EctoShorts.CommonFilters.SchemalessPutQueryPrefixTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing

  alias EctoShorts.CommonFilters

  import Ecto.Query

  describe "put_query_prefix shapes (schemaless)" do
    test "matches Ecto.Query for a root string prefix" do
      expected = put_query_prefix("posts", "tenant_1")

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{put_query_prefix: "tenant_1"},
          []
        )

      assert_query(expected, actual)
    end
  end
end
