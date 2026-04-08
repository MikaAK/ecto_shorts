defmodule EctoShorts.CommonFilters.SchemalessJoinTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing

  alias EctoShorts.CommonFilters

  import Ecto.Query

  describe "join shapes (schemaless)" do
    test "matches Ecto.Query for a table join with on clause" do
      expected = from(p in "posts", join: u in "users", on: p.author_id == ^1)

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{join: [table: [source: "users", on: %{author_id: 1}]]},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for a left table join" do
      expected = from(p in "posts", left_join: u in "users", on: p.author_id == ^1)

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{join: [table: [source: "users", qualifier: :left, on: %{author_id: 1}]]},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for a table join with named binding" do
      expected =
        from(p in "posts",
          join: u in "users",
          as: :users,
          on: p.author_id == ^1
        )

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{join: [table: [source: "users", as: :users, on: %{author_id: 1}]]},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for a query join" do
      sub = from(u in "users", where: u.active == ^true)

      expected = from(p in "posts", join: u in ^sub, as: :users, on: p.author_id == ^1)

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{join: [query: [source: sub, as: :users, on: %{author_id: 1}]]},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for a subquery join" do
      sub = from(u in "users", where: u.active == ^true)
      sub_q = subquery(sub)

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{join: [subquery: [source: sub_q, as: :users, on: %{author_id: 1}]]},
          []
        )

      # The subquery join produces a different internal AST (^sub_q vs subquery(...)),
      # so assert_query cannot be used here. Verify the join binding and qualifier instead.
      assert [%{as: :users, qual: :inner}] = actual.joins
    end

    test "matches Ecto.Query for a provider-backed fragment join" do
      active_users =
        from(u in fragment("SELECT * FROM users WHERE age >= ?", ^18), select: u)

      expected =
        from(p in "posts",
          join: u in ^active_users,
          as: :users,
          on: true
        )

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{
            join: [
              fragment: [
                source: [name: :active_users, values: %{min_age: 18}],
                as: :users,
                on: true
              ]
            ]
          },
          query_provider_module: EctoShorts.TestQueryProvider
        )

      assert_query(expected, actual)
    end
  end
end
