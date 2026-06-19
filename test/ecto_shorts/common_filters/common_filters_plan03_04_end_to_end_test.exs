defmodule EctoShorts.CommonFilters.Plan03And04EndToEndTest do
  @moduledoc """
  End-to-end coverage for the Plan 03/04 operators and behaviours, now that the
  whole language flows through `PredicateBuilder` + the thin adapter (Plan 05).
  These assert the full `convert_params_to_filter` pipeline output.
  """
  use ExUnit.Case, async: true
  use EctoShorts.Testing

  alias EctoShorts.CommonFilters
  alias EctoShorts.Schema.Post

  import Ecto.Query

  describe "Plan 03 operators end-to-end" do
    test "overlaps on an array field produces &&" do
      expected = from(p in "posts", where: fragment("? && ?", p.tags, ^["a", "b"]))

      actual =
        CommonFilters.convert_params_to_filter("posts", %{tags: %{overlaps: ["a", "b"]}},
          field_types: [tags: {:array, :string}]
        )

      assert_query(expected, actual)
    end

    test "trim transform on a scalar field" do
      expected = from(p in Post, where: fragment("trim(?)", p.title) == ^"hello")
      actual = CommonFilters.convert_params_to_filter(Post, %{title: %{==: %{trim: "hello"}}}, [])

      assert_query(expected, actual)
    end

    test "shift date-math produces datetime_add" do
      expected =
        from(p in Post,
          where: p.published_at >= datetime_add(p.published_at, ^7, "day")
        )

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{published_at: %{>=: %{datetime: %{shift: %{field: "published_at", count: 7, unit: "day"}}}}},
          []
        )

      assert_query(expected, actual)
    end

    test "column (sibling) compare against another field on the same binding" do
      expected = from(p in Post, where: p.views == p.id)
      actual = CommonFilters.convert_params_to_filter(Post, %{views: %{==: %{field: "id"}}}, [])

      assert_query(expected, actual)
    end

    test "binary arithmetic compare (field + value)" do
      expected = from(p in Post, where: p.views > p.views + ^10)

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{views: %{>: %{value: %{+: [%{field: "views"}, %{value: 10}]}}}},
          []
        )

      assert_query(expected, actual)
    end
  end

  describe "Plan 04 behaviours end-to-end" do
    test "not-in over a list (D-NULL: plain NOT IN, no null guard added)" do
      expected = from(p in Post, where: p.views not in ^[1, 2, 3])
      actual = CommonFilters.convert_params_to_filter(Post, %{views: %{nin: [1, 2, 3]}}, [])

      assert_query(expected, actual)
    end

    test "an ordering comparison against nil raises a FilterError" do
      assert_raise EctoShorts.FilterError, ~r/cannot be compared to nil/, fn ->
        CommonFilters.convert_params_to_filter(Post, %{views: %{gt: nil}}, [])
      end
    end
  end
end
