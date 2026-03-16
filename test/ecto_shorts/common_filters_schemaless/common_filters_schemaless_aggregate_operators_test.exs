defmodule EctoShorts.CommonFilters.SchemalessAggregateOperatorsTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing

  alias EctoShorts.CommonFilters

  import Ecto.Query

  describe "convert_params_to_filter/3 aggregate operators (schemaless)" do
    test "avg views greater than" do
      expected = from(p in "posts", where: avg(p.views) > ^10)
      actual = CommonFilters.convert_params_to_filter("posts", %{views: %{avg: %{>: 10}}}, [])

      assert_query(expected, actual)
    end

    test "avg views greater than negated" do
      expected = from(p in "posts", where: not (avg(p.views) > ^10))

      actual =
        CommonFilters.convert_params_to_filter("posts", %{views: %{not: %{avg: %{>: 10}}}}, [])

      assert_query(expected, actual)
    end

    test "count views greater than zero" do
      expected = from(p in "posts", where: count(p.views) > ^0)
      actual = CommonFilters.convert_params_to_filter("posts", %{views: %{count: %{>: 0}}}, [])

      assert_query(expected, actual)
    end

    test "max views greater than or equal" do
      expected = from(p in "posts", where: max(p.views) >= ^100)
      actual = CommonFilters.convert_params_to_filter("posts", %{views: %{max: %{>=: 100}}}, [])

      assert_query(expected, actual)
    end

    test "min views less than" do
      expected = from(p in "posts", where: min(p.views) < ^5)
      actual = CommonFilters.convert_params_to_filter("posts", %{views: %{min: %{<: 5}}}, [])

      assert_query(expected, actual)
    end

    test "sum views equals" do
      expected = from(p in "posts", where: sum(p.views) == ^1000)
      actual = CommonFilters.convert_params_to_filter("posts", %{views: %{sum: %{==: 1000}}}, [])

      assert_query(expected, actual)
    end

    test "avg views not equals" do
      expected = from(p in "posts", where: avg(p.views) != ^50)
      actual = CommonFilters.convert_params_to_filter("posts", %{views: %{avg: %{!=: 50}}}, [])

      assert_query(expected, actual)
    end

    test "count views equals zero" do
      expected = from(p in "posts", where: count(p.views) == ^0)
      actual = CommonFilters.convert_params_to_filter("posts", %{views: %{count: %{==: 0}}}, [])

      assert_query(expected, actual)
    end

    test "count views greater than zero negated" do
      expected = from(p in "posts", where: not (count(p.views) > ^0))

      actual =
        CommonFilters.convert_params_to_filter("posts", %{views: %{not: %{count: %{>: 0}}}}, [])

      assert_query(expected, actual)
    end

    test "max views greater than or equal negated" do
      expected = from(p in "posts", where: not (max(p.views) >= ^100))

      actual =
        CommonFilters.convert_params_to_filter("posts", %{views: %{not: %{max: %{>=: 100}}}}, [])

      assert_query(expected, actual)
    end

    test "avg views less than or equal" do
      expected = from(p in "posts", where: avg(p.views) <= ^10)
      actual = CommonFilters.convert_params_to_filter("posts", %{views: %{avg: %{<=: 10}}}, [])

      assert_query(expected, actual)
    end

    test "sum views greater than" do
      expected = from(p in "posts", where: sum(p.views) > ^500)
      actual = CommonFilters.convert_params_to_filter("posts", %{views: %{sum: %{>: 500}}}, [])

      assert_query(expected, actual)
    end

    test "min views equals zero" do
      expected = from(p in "posts", where: min(p.views) == ^0)
      actual = CommonFilters.convert_params_to_filter("posts", %{views: %{min: %{==: 0}}}, [])

      assert_query(expected, actual)
    end

    test "sum views not equals zero" do
      expected = from(p in "posts", where: sum(p.views) != ^0)
      actual = CommonFilters.convert_params_to_filter("posts", %{views: %{sum: %{!=: 0}}}, [])

      assert_query(expected, actual)
    end

    test "min views less than negated" do
      expected = from(p in "posts", where: not (min(p.views) < ^5))

      actual =
        CommonFilters.convert_params_to_filter("posts", %{views: %{not: %{min: %{<: 5}}}}, [])

      assert_query(expected, actual)
    end

    test "sum views greater than negated" do
      expected = from(p in "posts", where: not (sum(p.views) > ^500))

      actual =
        CommonFilters.convert_params_to_filter("posts", %{views: %{not: %{sum: %{>: 500}}}}, [])

      assert_query(expected, actual)
    end
  end
end
