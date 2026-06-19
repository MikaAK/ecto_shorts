defmodule EctoShorts.CommonFilters.Schemaless.AggregateOperatorsTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing
  @moduletag adapter: :postgres
  @moduletag schema_mode: :schemaless
  @moduletag feature: :aggregate_operators

  alias EctoShorts.CommonFilters

  import Ecto.Query

  describe "aggregate operators (schemaless)" do
    test "avg views greater than" do
      # A schemaless source has no primary key to group by, so the aggregate
      # lands in HAVING without an auto GROUP BY.
      expected = from(p in "posts", having: avg(p.views) > ^10)
      actual = CommonFilters.convert_params_to_filter("posts", %{views: %{avg: %{>: 10}}}, [])

      assert_query(expected, actual)
    end
  end
end
