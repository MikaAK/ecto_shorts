defmodule EctoShorts.CommonFilters.Schemaless.HavingTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing
  @moduletag adapter: :postgres
  @moduletag schema_mode: :schemaless
  @moduletag feature: :having

  alias EctoShorts.CommonFilters

  import Ecto.Query

  describe "having shapes (schemaless)" do
    test "matches Ecto.Query for a root aggregate having" do
      source = from(p in "posts", group_by: p.author_id)
      expected = from(p in "posts", group_by: p.author_id, having: avg(p.views) > ^100)

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{having: %{views: %{avg: %{>: 100}}}},
          []
        )

      assert_query(expected, actual)
    end
  end
end
