defmodule EctoShorts.CommonFilters.Schemaless.LastTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing
  @moduletag adapter: :postgres
  @moduletag schema_mode: :schemaless
  @moduletag feature: :last

  alias EctoShorts.CommonFilters

  import Ecto.Query

  describe "last shapes (schemaless)" do
    test "matches Ecto.Query for a root integer last payload" do
      expected =
        "posts"
        |> exclude(:order_by)
        |> order_by([], desc: :id)
        |> limit(^2)
        |> subquery()
        |> order_by([], asc: :id)

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{last: 2},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for terminal last wrapping after local filters" do
      expected =
        "posts"
        |> where([p], p.published == ^true)
        |> exclude(:order_by)
        |> order_by([], desc: :id)
        |> limit(^2)
        |> subquery()
        |> order_by([], asc: :id)

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          [last: 2, published: true],
          []
        )

      assert_query(expected, actual)
    end
  end
end
