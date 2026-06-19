defmodule EctoShorts.CommonFilters.Schemaless.NegationTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing
  @moduletag adapter: :postgres
  @moduletag schema_mode: :schemaless
  @moduletag feature: :negation

  alias EctoShorts.CommonFilters

  import Ecto.Query

  describe "negation (schemaless)" do
    test "excludes records where the field is not in the given list" do
      expected =
        from(p in "posts", where: p.published not in ^[true, false])

      q2 =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{published: %{not: %{in: [true, false]}}},
          []
        )

      assert_query(expected, q2)
    end
  end
end
