defmodule EctoShorts.CommonFilters.SchemalessSubqueryTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing

  alias EctoShorts.CommonFilters

  import Ecto.Query

  describe "convert_params_to_filter/3 subquery shapes (schemaless)" do
    test "matches Ecto.Query for a root subquery map payload" do
      expected =
        "posts"
        |> where([p], p.id == ^2)
        |> subquery()

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{subquery: %{id: 2}},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for a root subquery keyword payload" do
      expected =
        "posts"
        |> where([p], p.id == ^2)
        |> where([p], p.title == ^"Hello")
        |> subquery()

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{subquery: [id: 2, title: "Hello"]},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for terminal subquery wrapping after local filters" do
      expected =
        "posts"
        |> order_by([], desc: :title)
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
