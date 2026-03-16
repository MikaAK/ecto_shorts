defmodule EctoShorts.CommonFilters.SchemalessNegationTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing

  alias EctoShorts.CommonFilters

  import Ecto.Query

  describe "convert_params_to_filter/3 negation (schemaless)" do
    test "excludes records where the field is in the given list" do
      expected =
        from(p in "posts", where: is_nil(p.published) or p.published not in ^[true, false])

      q2 =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{published: %{not: %{in: [true, false]}}},
          []
        )

      assert_query(expected, q2)
    end

    test "excludes records when == with a list is wrapped in not" do
      expected =
        from(p in "posts", where: is_nil(p.published) or p.published not in ^[true, false])

      q2 =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{published: %{not: %{==: [true, false]}}},
          []
        )

      assert_query(expected, q2)
    end

    test "includes records when != with a list is wrapped in not" do
      expected =
        from(p in "posts", where: not is_nil(p.published) and p.published in ^[true, false])

      q2 =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{published: %{not: %{!=: [true, false]}}},
          []
        )

      assert_query(expected, q2)
    end

    test "excludes records where the field is greater than the value" do
      expected = from(p in "posts", where: not (p.views > ^10))
      q2 = CommonFilters.convert_params_to_filter("posts", %{views: %{not: %{>: 10}}}, [])

      assert_query(expected, q2)
    end

    test "excludes records where the field is greater than or equal to the value" do
      expected = from(p in "posts", where: not (p.views >= ^10))
      q2 = CommonFilters.convert_params_to_filter("posts", %{views: %{not: %{>=: 10}}}, [])

      assert_query(expected, q2)
    end

    test "excludes records where the field is less than the value" do
      expected = from(p in "posts", where: not (p.views < ^10))
      q2 = CommonFilters.convert_params_to_filter("posts", %{views: %{not: %{<: 10}}}, [])

      assert_query(expected, q2)
    end

    test "excludes records where the field is less than or equal to the value" do
      expected = from(p in "posts", where: not (p.views <= ^10))
      q2 = CommonFilters.convert_params_to_filter("posts", %{views: %{not: %{<=: 10}}}, [])

      assert_query(expected, q2)
    end

    test "excludes records where the field equals the value" do
      expected = from(p in "posts", where: p.views != ^10)
      q2 = CommonFilters.convert_params_to_filter("posts", %{views: %{not: %{==: 10}}}, [])

      assert_query(expected, q2)
    end

    test "includes records where the field equals the value using double negation" do
      expected = from(p in "posts", where: p.views == ^10)
      q2 = CommonFilters.convert_params_to_filter("posts", %{views: %{not: %{!=: 10}}}, [])

      assert_query(expected, q2)
    end

    test "includes records where the field equals the value using negated ne alias" do
      expected = from(p in "posts", where: p.views == ^10)
      q2 = CommonFilters.convert_params_to_filter("posts", %{views: %{not: %{ne: 10}}}, [])

      assert_query(expected, q2)
    end

    test "excludes records using negated gt alias" do
      expected = from(p in "posts", where: not (p.views > ^10))
      q2 = CommonFilters.convert_params_to_filter("posts", %{views: %{not: %{gt: 10}}}, [])

      assert_query(expected, q2)
    end

    test "excludes records using negated gte alias" do
      expected = from(p in "posts", where: not (p.views >= ^10))
      q2 = CommonFilters.convert_params_to_filter("posts", %{views: %{not: %{gte: 10}}}, [])

      assert_query(expected, q2)
    end

    test "excludes records using negated lt alias" do
      expected = from(p in "posts", where: not (p.views < ^10))
      q2 = CommonFilters.convert_params_to_filter("posts", %{views: %{not: %{lt: 10}}}, [])

      assert_query(expected, q2)
    end

    test "excludes records using negated lte alias" do
      expected = from(p in "posts", where: not (p.views <= ^10))
      q2 = CommonFilters.convert_params_to_filter("posts", %{views: %{not: %{lte: 10}}}, [])

      assert_query(expected, q2)
    end
  end
end
