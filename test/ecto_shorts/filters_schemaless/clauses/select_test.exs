defmodule EctoShorts.CommonFilters.Schemaless.SelectTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing
  @moduletag adapter: :postgres
  @moduletag schema_mode: :schemaless
  @moduletag feature: :select

  alias EctoShorts.CommonFilters

  import Ecto.Query

  describe "select shapes (schemaless)" do
    test "matches Ecto.Query for a root select field atom" do
      expected = from(p in "posts", select: p.title)

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{select: :title},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for a root select map alias mapping" do
      expected =
        from(p in "posts",
          select: %{post_id: p.id, post_title: p.title}
        )

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{select: [post_id: :id, post_title: :title]},
          []
        )

      assert_query(expected, actual)
    end
  end
end
