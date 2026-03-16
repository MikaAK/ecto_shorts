defmodule EctoShorts.CommonFilters.SchemalessSetOperationTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing

  alias EctoShorts.CommonFilters

  import Ecto.Query

  describe "convert_params_to_filter/3 set operation shapes (schemaless)" do
    test "matches Ecto.Query for union with a prebuilt query" do
      other_query = from(p in "posts", where: p.published == ^false)
      expected = union("posts", ^other_query)

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{union: other_query},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for union_all with a prebuilt query" do
      other_query = from(p in "posts", where: p.published == ^false)
      expected = union_all("posts", ^other_query)

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{union_all: other_query},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for intersect with a prebuilt query" do
      other_query = from(p in "posts", where: p.published == ^false)
      expected = intersect("posts", ^other_query)

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{intersect: other_query},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for intersect_all with a prebuilt query" do
      other_query = from(p in "posts", where: p.published == ^false)
      expected = intersect_all("posts", ^other_query)

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{intersect_all: other_query},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for except with a prebuilt query" do
      other_query = from(p in "posts", where: p.published == ^false)
      expected = except("posts", ^other_query)

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{except: other_query},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for except_all with a prebuilt query" do
      other_query = from(p in "posts", where: p.published == ^false)
      expected = except_all("posts", ^other_query)

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{except_all: other_query},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for union with filter params" do
      other_query = from(p in "posts", where: p.published == ^false)
      expected = union("posts", ^other_query)

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{union: %{published: false}},
          []
        )

      assert_query(expected, actual)
    end
  end
end
