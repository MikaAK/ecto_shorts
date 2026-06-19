defmodule EctoShorts.CommonFilters.Schemaless.LockTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing
  @moduletag adapter: :postgres
  @moduletag schema_mode: :schemaless
  @moduletag feature: :lock

  alias EctoShorts.CommonFilters

  import Ecto.Query

  describe "lock shapes (schemaless)" do
    test "matches Ecto.Query for a root for_update alias lock" do
      expected = lock("posts", "FOR UPDATE")

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{lock: %{name: :for_update}},
          []
        )

      assert_query(expected, actual)
    end

    test "raises for a direct raw string lock (D-RAISE)" do
      assert_raise EctoShorts.FilterError, ~r/:name key/, fn ->
        CommonFilters.convert_params_to_filter("posts", %{lock: "FOR SHARE NOWAIT"}, [])
      end
    end
  end
end
