defmodule EctoShorts.CommonFilters.Schemaless.SubqueryTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing
  @moduletag adapter: :postgres
  @moduletag schema_mode: :schemaless
  @moduletag feature: :subquery

  alias EctoShorts.CommonFilters

  import Ecto.Query

  describe "subquery shapes (schemaless)" do
    test "matches Ecto.Query for terminal subquery wrapping after local filters" do
      expected =
        "posts"
        |> order_by([], asc: :title)
        |> where([p], p.id == ^2)
        |> subquery()

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{order_by: :title, subquery: %{id: 2}},
          []
        )

      assert_query(expected, actual)
    end
  end
end
