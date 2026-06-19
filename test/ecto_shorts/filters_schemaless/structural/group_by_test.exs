defmodule EctoShorts.CommonFilters.Schemaless.GroupByTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing
  @moduletag adapter: :postgres
  @moduletag schema_mode: :schemaless
  @moduletag feature: :group_by

  alias EctoShorts.CommonFilters

  import Ecto.Query

  describe "group_by shapes (schemaless)" do
    test "matches Ecto.Query for a root group_by atom" do
      expected = from(p in "posts", group_by: :author_id)

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{group_by: :author_id},
          []
        )

      assert_query(expected, actual)
    end
  end
end
