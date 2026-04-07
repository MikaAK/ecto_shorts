defmodule EctoShorts.CommonFilters.SchemalessWithNamedBindingTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing

  alias EctoShorts.CommonFilters

  import Ecto.Query

  describe "with_named_binding shapes (schemaless)" do
    test "matches Ecto.Query for the documented with_named_binding workflow" do
      expected =
        from(p in "posts",
          join: u in "users",
          as: :users,
          on: p.author_id == ^1
        )

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{
            with_named_binding: [
              users: %{join: [table: [source: "users", as: :users, on: %{author_id: 1}]]}
            ]
          },
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query when with_named_binding no-ops on an existing binding" do
      source =
        from(p in "posts",
          join: u in "users",
          as: :users,
          on: p.author_id == ^1
        )

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{
            with_named_binding: %{
              users: %{join: [table: [source: "users", as: :users, on: %{author_id: 1}]]}
            }
          },
          []
        )

      assert_query(source, actual)
    end
  end
end
