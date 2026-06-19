defmodule EctoShorts.CommonFilters.AggregateOperatorsTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing

  alias EctoShorts.CommonFilters
  alias EctoShorts.Schema.Post

  import Ecto.Query

  # Aggregate operator shape: `%{field: %{agg_fn: %{comparator: value}}}`.
  # The aggregate function wraps the field; the comparator applies to the result.
  # Negated form: `%{field: %{not: %{agg_fn: %{comparator: value}}}}`.
  describe "aggregate operators" do
    test "rule statement 1: avg views greater than" do
      expected = from(p in Post, group_by: p.id, having: avg(p.views) > ^10)
      actual = CommonFilters.convert_params_to_filter(Post, %{views: %{avg: %{>: 10}}}, [])

      assert_sql(expected, actual)
    end

    # `not: %{avg: %{>: value}}` produces `not (avg(field) > value)`.
    test "rule statement 2: avg views greater than negated" do
      expected = from(p in Post, group_by: p.id, having: not (avg(p.views) > ^10))

      actual =
        CommonFilters.convert_params_to_filter(Post, %{views: %{not: %{avg: %{>: 10}}}}, [])

      assert_sql(expected, actual)
    end

    test "rule statement 3: count views greater than zero" do
      expected = from(p in Post, group_by: p.id, having: count(p.views) > ^0)
      actual = CommonFilters.convert_params_to_filter(Post, %{views: %{count: %{>: 0}}}, [])

      assert_sql(expected, actual)
    end

    test "rule statement 4: max views greater than or equal" do
      expected = from(p in Post, group_by: p.id, having: max(p.views) >= ^100)
      actual = CommonFilters.convert_params_to_filter(Post, %{views: %{max: %{>=: 100}}}, [])

      assert_sql(expected, actual)
    end

    test "rule statement 5: min views less than" do
      expected = from(p in Post, group_by: p.id, having: min(p.views) < ^5)
      actual = CommonFilters.convert_params_to_filter(Post, %{views: %{min: %{<: 5}}}, [])

      assert_sql(expected, actual)
    end

    test "rule statement 6: sum views equals" do
      expected = from(p in Post, group_by: p.id, having: sum(p.views) == ^1000)
      actual = CommonFilters.convert_params_to_filter(Post, %{views: %{sum: %{==: 1000}}}, [])

      assert_sql(expected, actual)
    end

    test "rule statement 7: avg views not equals" do
      expected = from(p in Post, group_by: p.id, having: avg(p.views) != ^50)
      actual = CommonFilters.convert_params_to_filter(Post, %{views: %{avg: %{!=: 50}}}, [])

      assert_sql(expected, actual)
    end

    test "rule statement 8: count views equals zero" do
      expected = from(p in Post, group_by: p.id, having: count(p.views) == ^0)
      actual = CommonFilters.convert_params_to_filter(Post, %{views: %{count: %{==: 0}}}, [])

      assert_sql(expected, actual)
    end

    test "rule statement 9: count views greater than zero negated" do
      expected = from(p in Post, group_by: p.id, having: not (count(p.views) > ^0))

      actual =
        CommonFilters.convert_params_to_filter(Post, %{views: %{not: %{count: %{>: 0}}}}, [])

      assert_sql(expected, actual)
    end

    test "rule statement 10: max views greater than or equal negated" do
      expected = from(p in Post, group_by: p.id, having: not (max(p.views) >= ^100))

      actual =
        CommonFilters.convert_params_to_filter(Post, %{views: %{not: %{max: %{>=: 100}}}}, [])

      assert_sql(expected, actual)
    end

    test "rule statement 11: avg views less than or equal" do
      expected = from(p in Post, group_by: p.id, having: avg(p.views) <= ^10)
      actual = CommonFilters.convert_params_to_filter(Post, %{views: %{avg: %{<=: 10}}}, [])

      assert_sql(expected, actual)
    end

    test "rule statement 12: sum views greater than" do
      expected = from(p in Post, group_by: p.id, having: sum(p.views) > ^500)
      actual = CommonFilters.convert_params_to_filter(Post, %{views: %{sum: %{>: 500}}}, [])

      assert_sql(expected, actual)
    end

    test "rule statement 13: min views equals zero" do
      expected = from(p in Post, group_by: p.id, having: min(p.views) == ^0)
      actual = CommonFilters.convert_params_to_filter(Post, %{views: %{min: %{==: 0}}}, [])

      assert_sql(expected, actual)
    end

    test "rule statement 14: sum views not equals zero" do
      expected = from(p in Post, group_by: p.id, having: sum(p.views) != ^0)
      actual = CommonFilters.convert_params_to_filter(Post, %{views: %{sum: %{!=: 0}}}, [])

      assert_sql(expected, actual)
    end

    test "rule statement 15: min views less than negated" do
      expected = from(p in Post, group_by: p.id, having: not (min(p.views) < ^5))
      actual = CommonFilters.convert_params_to_filter(Post, %{views: %{not: %{min: %{<: 5}}}}, [])

      assert_sql(expected, actual)
    end

    test "rule statement 16: sum views greater than negated" do
      expected = from(p in Post, group_by: p.id, having: not (sum(p.views) > ^500))

      actual =
        CommonFilters.convert_params_to_filter(Post, %{views: %{not: %{sum: %{>: 500}}}}, [])

      assert_sql(expected, actual)
    end
  end

  describe "aggregate placement (where -> having, auto group_by)" do
    test "an aggregate written under :where lands in HAVING with an auto GROUP BY" do
      actual = CommonFilters.convert_params_to_filter(Post, %{views: %{avg: %{gt: 5}}}, [])
      assert_sql(from(p in Post, group_by: p.id, having: avg(p.views) > ^5), actual)
    end

    test "an aggregate under :having on an explicitly grouped query keeps that grouping" do
      source = from(p in Post, group_by: p.author_id)
      actual = CommonFilters.convert_params_to_filter(source, %{having: %{views: %{avg: %{gt: 5}}}}, [])
      assert_sql(from(p in Post, group_by: p.author_id, having: avg(p.views) > ^5), actual)
    end
  end

  describe ":aggregate wrapper removed (D-ONE-WAY)" do
    test "the short aggregate spelling works (gt spelling, end-to-end)" do
      source = from(p in Post, group_by: p.author_id)

      actual =
        CommonFilters.convert_params_to_filter(source, %{having: %{views: %{avg: %{gt: 5}}}}, [])

      assert_sql(from(p in Post, group_by: p.author_id, having: avg(p.views) > ^5), actual)
    end

    test "the :aggregate wrapper is no longer supported (unrecognized operator is skipped)" do
      # With the wrapper clauses removed, an :aggregate key is an unrecognized
      # operator on a valid field, which resolves to no predicate and is skipped.
      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{views: %{aggregate: %{fn: :avg, compare: :>, value: 5}}},
          []
        )

      assert_sql(from(p in Post), actual)
    end
  end
end
