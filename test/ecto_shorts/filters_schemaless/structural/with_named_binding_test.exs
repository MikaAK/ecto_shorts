defmodule EctoShorts.CommonFilters.Schemaless.WithNamedBindingTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing
  @moduletag adapter: :postgres
  @moduletag schema_mode: :schemaless
  @moduletag feature: :with_named_binding

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
  end
end
