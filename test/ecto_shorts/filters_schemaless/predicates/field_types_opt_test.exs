defmodule EctoShorts.CommonFilters.Schemaless.FieldTypesOptTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing
  @moduletag adapter: :postgres
  @moduletag schema_mode: :schemaless
  @moduletag feature: :field_types_opt

  alias EctoShorts.CommonFilters

  import Ecto.Query

  describe "field_types: opt (schemaless)" do
    test "with field_types :map, has_key uses jsonb_exists" do
      expected =
        from(p in "data_stores",
          where: fragment("jsonb_exists(?, ?)", p.data, ^"role")
        )

      actual =
        CommonFilters.convert_params_to_filter(
          "data_stores",
          %{data: %{has_key: "role"}},
          field_types: [data: :map]
        )

      assert_query(expected, actual)
    end

    test "with field_types :map, containment uses @>" do
      expected =
        from(p in "data_stores",
          where: fragment("? @> ?::jsonb", p.data, ^%{role: "admin"})
        )

      actual =
        CommonFilters.convert_params_to_filter(
          "data_stores",
          %{data: %{contains: %{role: "admin"}}},
          field_types: [data: :map]
        )

      assert_query(expected, actual)
    end

    test "without field_types, fields use scalar semantics regardless of name" do
      expected = from(p in "posts", where: p.tags in ^["elixir", "ecto"])

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{tags: ["elixir", "ecto"]},
          []
        )

      assert_query(expected, actual)
    end
  end
end
