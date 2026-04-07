defmodule EctoShorts.CommonFilters.FieldTypesOptTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing

  alias EctoShorts.CommonFilters
  alias EctoShorts.Schema.Post

  import Ecto.Query

  describe "field_types: opt for array fields" do
    # Without field_types, a schemaless query treats all fields as scalars.
    # A list value produces membership (field IN ^list), not array overlap.
    test "without field_types, schemaless list value uses scalar membership semantics" do
      expected = from(p in "posts", where: p.tags in ^["elixir", "ecto"])

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{tags: ["elixir", "ecto"]},
          []
        )

      assert_query(expected, actual)
    end

    test "with field_types array, list value uses array membership semantics" do
      expected = from(p in "posts", where: ^"elixir" in p.tags)

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{tags: "elixir"},
          field_types: [tags: {:array, :string}]
        )

      assert_query(expected, actual)
    end

    test "with field_types array, explicit in: list uses array overlap semantics" do
      expected = from(p in "posts", where: fragment("? && ?", p.tags, ^["elixir", "ecto"]))

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{tags: %{in: ["elixir", "ecto"]}},
          field_types: [tags: {:array, :string}]
        )

      assert_query(expected, actual)
    end

    test "field_types also works with schema-backed sources (overrides reflection)" do
      expected = from(p in Post, where: ^"elixir" in p.tags)

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{tags: "elixir"},
          field_types: [tags: {:array, :string}]
        )

      assert_query(expected, actual)
    end
  end

  describe "field_types: opt for map fields" do
    test "with field_types :map, uses JSONB containment semantics" do
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

    test "with field_types {:map, :string}, uses JSONB containment semantics" do
      expected =
        from(p in "data_stores",
          where: fragment("? @> ?::jsonb", p.data, ^%{role: "admin"})
        )

      actual =
        CommonFilters.convert_params_to_filter(
          "data_stores",
          %{data: %{contains: %{role: "admin"}}},
          field_types: [data: {:map, :string}]
        )

      assert_query(expected, actual)
    end

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
  end
end
