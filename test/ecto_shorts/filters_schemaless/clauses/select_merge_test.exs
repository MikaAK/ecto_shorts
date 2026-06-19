defmodule EctoShorts.CommonFilters.Schemaless.SelectMergeTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing
  @moduletag adapter: :postgres
  @moduletag schema_mode: :schemaless
  @moduletag feature: :select_merge

  alias EctoShorts.CommonFilters

  import Ecto.Query

  describe "select_merge shapes (schemaless)" do
    test "matches Ecto.Query for a root select_merge map alias mapping" do
      source = from(p in "posts", select: %{})

      expected =
        from(p in "posts",
          select: %{},
          select_merge: %{post_id: p.id, post_title: p.title}
        )

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{select_merge: %{post_id: :id, post_title: :title}},
          []
        )

      assert_query(expected, actual)
    end
  end
end
