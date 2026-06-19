defmodule EctoShorts.CommonFilters.SubqueryTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing
  @moduletag adapter: :postgres
  @moduletag feature: :subquery

  alias EctoShorts.CommonFilters
  alias EctoShorts.Schema.Post

  import Ecto.Query

  describe "subquery shapes" do
    test "matches Ecto.Query for a root subquery map payload" do
      expected =
        Post
        |> where([p], p.id == ^2)
        |> subquery()

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{subquery: %{id: 2}},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for a root subquery keyword payload" do
      expected =
        Post
        |> where([p], p.id == ^2)
        |> where([p], p.title == ^"Hello")
        |> subquery()

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{subquery: [id: 2, title: "Hello"]},
          []
        )

      assert_query(expected, actual)
    end

    # `subquery:` runs after all other filter params in the same call. Params that
    # appear alongside it are applied to the inner query before it is wrapped.
    test "matches Ecto.Query for terminal subquery wrapping after local filters" do
      expected =
        Post
        |> order_by([], asc: :title)
        |> where([p], p.id == ^2)
        |> subquery()

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{order_by: :title, subquery: %{id: 2}},
          []
        )

      assert_query(expected, actual)
    end
  end
end
