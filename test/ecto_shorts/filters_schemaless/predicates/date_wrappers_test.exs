defmodule EctoShorts.CommonFilters.Schemaless.DateWrappersTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing
  @moduletag adapter: :postgres
  @moduletag schema_mode: :schemaless
  @moduletag feature: :date_wrappers

  alias EctoShorts.CommonFilters

  import Ecto.Query

  describe "date wrappers (schemaless)" do
    test "inserted_at >= datetime_add 7 days using date wrapper" do
      expected =
        from(p in "posts",
          where:
            fragment("date(?)", p.inserted_at) >=
              fragment("date(?)", datetime_add(p.inserted_at, ^7, "day"))
        )

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{
            inserted_at: %{
              >=: %{date: %{add: %{field: :inserted_at, count: 7, interval: "day"}}}
            }
          },
          []
        )

      assert_query(expected, actual)
    end
  end
end
