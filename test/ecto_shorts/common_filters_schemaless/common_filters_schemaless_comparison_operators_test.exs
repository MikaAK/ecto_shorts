defmodule EctoShorts.CommonFilters.SchemalessComparisonOperatorsTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing

  alias EctoShorts.CommonFilters

  import Ecto.Query

  describe "comparison operators (schemaless)" do
    test "matches records where the field equals the value using ==" do
      expected = from(p in "posts", where: p.id == ^1)
      q2 = CommonFilters.convert_params_to_filter("posts", %{id: %{==: 1}}, [])

      assert_query(expected, q2)
    end

    test "matches records where the field equals the value using the eq alias" do
      expected = from(p in "posts", where: p.id == ^1)
      q2 = CommonFilters.convert_params_to_filter("posts", %{id: %{eq: 1}}, [])

      assert_query(expected, q2)
    end

    test "matches records where the field is nil using == nil" do
      expected = from(p in "posts", where: is_nil(p.published_at))
      q2 = CommonFilters.convert_params_to_filter("posts", %{published_at: %{==: nil}}, [])

      assert_query(expected, q2)
    end

    test "matches records where the field is nil using the eq alias" do
      expected = from(p in "posts", where: is_nil(p.published_at))
      q2 = CommonFilters.convert_params_to_filter("posts", %{published_at: %{eq: nil}}, [])

      assert_query(expected, q2)
    end

    test "matches records where the field is not nil using != nil" do
      expected = from(p in "posts", where: not is_nil(p.published_at))
      q2 = CommonFilters.convert_params_to_filter("posts", %{published_at: %{!=: nil}}, [])

      assert_query(expected, q2)
    end

    test "matches records where the field is not nil using the ne alias" do
      expected = from(p in "posts", where: not is_nil(p.published_at))
      q2 = CommonFilters.convert_params_to_filter("posts", %{published_at: %{ne: nil}}, [])

      assert_query(expected, q2)
    end

    test "matches records where the field is greater than the value" do
      expected = from(p in "posts", where: p.views > ^10)
      q2 = CommonFilters.convert_params_to_filter("posts", %{views: %{>: 10}}, [])

      assert_query(expected, q2)
    end

    test "matches records where the field is greater than the value using the gt alias" do
      expected = from(p in "posts", where: p.views > ^10)
      q2 = CommonFilters.convert_params_to_filter("posts", %{views: %{gt: 10}}, [])

      assert_query(expected, q2)
    end

    test "matches records where the field is greater than or equal to the value" do
      expected = from(p in "posts", where: p.views >= ^10)
      q2 = CommonFilters.convert_params_to_filter("posts", %{views: %{>=: 10}}, [])

      assert_query(expected, q2)
    end

    test "matches records where the field is greater than or equal to the value using the gte alias" do
      expected = from(p in "posts", where: p.views >= ^10)
      q2 = CommonFilters.convert_params_to_filter("posts", %{views: %{gte: 10}}, [])

      assert_query(expected, q2)
    end

    test "matches records where the field is less than the value" do
      expected = from(p in "posts", where: p.views < ^10)
      q2 = CommonFilters.convert_params_to_filter("posts", %{views: %{<: 10}}, [])

      assert_query(expected, q2)
    end

    test "matches records where the field is less than the value using the lt alias" do
      expected = from(p in "posts", where: p.views < ^10)
      q2 = CommonFilters.convert_params_to_filter("posts", %{views: %{lt: 10}}, [])

      assert_query(expected, q2)
    end

    test "matches records where the field is less than or equal to the value" do
      expected = from(p in "posts", where: p.views <= ^10)
      q2 = CommonFilters.convert_params_to_filter("posts", %{views: %{<=: 10}}, [])

      assert_query(expected, q2)
    end

    test "matches records where the field is less than or equal to the value using the lte alias" do
      expected = from(p in "posts", where: p.views <= ^10)
      q2 = CommonFilters.convert_params_to_filter("posts", %{views: %{lte: 10}}, [])

      assert_query(expected, q2)
    end

    test "matches records where the field is in the given list" do
      expected = from(p in "posts", where: p.id in ^[1, 2, 3])
      q2 = CommonFilters.convert_params_to_filter("posts", %{id: %{in: [1, 2, 3]}}, [])

      assert_query(expected, q2)
    end

    test "matches records where the field is not in the given list" do
      expected = from(p in "posts", where: is_nil(p.id) or p.id not in ^[1, 2, 3])
      q2 = CommonFilters.convert_params_to_filter("posts", %{id: %{not: %{in: [1, 2, 3]}}}, [])

      assert_query(expected, q2)
    end

    test "matches records where the field equals the value using a plain map value" do
      expected = from(p in "posts", where: p.id == ^1)
      q2 = CommonFilters.convert_params_to_filter("posts", %{id: 1}, [])

      assert_query(expected, q2)
    end
  end
end
