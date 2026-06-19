defmodule EctoShorts.CommonFilters.Schemaless.ElementsTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing
  @moduletag adapter: :postgres
  @moduletag schema_mode: :schemaless
  @moduletag feature: :elements

  alias EctoShorts.CommonFilters

  import Ecto.Query

  describe ":elements wrapper (schemaless)" do
    test ":in with :elements produces array overlap (&&)" do
      expected = from(p in "posts", where: fragment("? && ?", p.tags, ^["elixir", "ecto"]))

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{tags: %{elements: %{in: ["elixir", "ecto"]}}},
          []
        )

      assert_query(expected, actual)
    end

    test ":in without :elements on schemaless source produces scalar IN" do
      expected = from(p in "posts", where: p.tags in ^["elixir", "ecto"])

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{tags: %{in: ["elixir", "ecto"]}},
          []
        )

      assert_query(expected, actual)
    end

    test "scalar value with :elements produces element membership" do
      expected = from(p in "posts", where: ^"elixir" in p.tags)

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{tags: %{elements: "elixir"}},
          []
        )

      assert_query(expected, actual)
    end

    test "nil with :elements produces IS NULL" do
      expected = from(p in "posts", where: is_nil(p.tags))

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{tags: %{elements: nil}},
          []
        )

      assert_query(expected, actual)
    end

    test "count with :elements produces array_length comparison" do
      expected = from(p in "posts", where: fragment("array_length(?, 1)", p.tags) > ^3)

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{tags: %{elements: %{count: %{>: 3}}}},
          []
        )

      assert_query(expected, actual)
    end

    test "list value with :elements produces array equality" do
      expected = from(p in "posts", where: p.tags == ^["elixir", "erlang"])

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{tags: %{elements: ["elixir", "erlang"]}},
          []
        )

      assert_query(expected, actual)
    end
  end
end
