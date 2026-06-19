defmodule EctoShorts.CommonFilters.Schemaless.UpdateTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing
  @moduletag adapter: :postgres
  @moduletag schema_mode: :schemaless
  @moduletag feature: :update

  alias EctoShorts.CommonFilters

  import Ecto.Query

  describe "update shapes (schemaless)" do
    test "matches Ecto.Query for a root update set payload" do
      updates = [set: [title: "After"]]
      expected = update("posts", [], ^updates)

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{update: [set: [title: "After"]]},
          []
        )

      assert_query(expected, actual)
    end
  end
end
