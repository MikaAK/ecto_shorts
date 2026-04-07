defmodule EctoShorts.CommonFilters.PutQueryPrefixTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing

  alias EctoShorts.CommonFilters
  alias EctoShorts.Schema.Post

  import Ecto.Query

  describe "put_query_prefix shapes" do
    test "matches Ecto.Query for a root string prefix" do
      expected = put_query_prefix(Post, "tenant_1")

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{put_query_prefix: "tenant_1"},
          []
        )

      assert_query(expected, actual)
    end
  end
end
