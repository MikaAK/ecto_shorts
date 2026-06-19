defmodule EctoShorts.CommonFilters.Schemaless.DatetimeWrappersTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing
  @moduletag adapter: :postgres
  @moduletag schema_mode: :schemaless
  @moduletag feature: :datetime_wrappers

  alias EctoShorts.CommonFilters

  import Ecto.Query

  describe "datetime wrappers (schemaless)" do
    test "matches records using datetime_add before comparison" do
      expected =
        from(p in "posts", where: p.inserted_at >= datetime_add(p.inserted_at, ^1, "day"))

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{
            inserted_at: %{
              >=: %{datetime: %{add: %{field: :inserted_at, count: 1, interval: "day"}}}
            }
          },
          []
        )

      assert_query(expected, actual)
    end
  end
end
