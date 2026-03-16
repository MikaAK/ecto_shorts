defmodule EctoShorts.CommonFilters.SchemalessPreloadTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing

  alias EctoShorts.CommonFilters

  import Ecto.Query

  # For schemaless sources, `preload:` compiles into the query AST correctly.
  # Resolving preloaded associations at runtime requires a schema; that is out of
  # scope for this test file. Only query-structure assertions are made here.
  describe "convert_params_to_filter/3 preload shapes (schemaless)" do
    test "matches Ecto.Query for a root preload atom" do
      expected = from(p in "posts", preload: :author)

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{preload: :author},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for a nested preload keyword list" do
      expected = from(p in "posts", preload: [comments: :author])

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{preload: [comments: :author]},
          []
        )

      assert_query(expected, actual)
    end
  end
end
