defmodule EctoShorts.CommonFilters.Schemaless.JoinTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing
  @moduletag adapter: :postgres
  @moduletag schema_mode: :schemaless
  @moduletag feature: :join

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
  end
end
