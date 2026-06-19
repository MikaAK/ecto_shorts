defmodule EctoShorts.CommonFilters.Schemaless.ExcludeTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing
  @moduletag adapter: :postgres
  @moduletag schema_mode: :schemaless
  @moduletag feature: :exclude

  alias EctoShorts.CommonFilters

  import Ecto.Query

  describe "exclude shapes (schemaless)" do
    test "matches Ecto.Query for excluding where" do
      source = from(p in "posts", where: p.published == ^true)
      expected = exclude(source, :where)

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{exclude: :where},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for excluding multiple fields with a list payload" do
      source =
        "posts"
        |> limit(^10)
        |> offset(^5)

      expected = exclude(source, [:limit, :offset])

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{exclude: [:limit, :offset]},
          []
        )

      assert_query(expected, actual)
    end
  end
end
