defmodule EctoShorts.CommonFilters.SetOperationTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing

  alias EctoShorts.CommonFilters
  alias EctoShorts.Schema.Post

  import Ecto.Query

  describe "convert_params_to_filter/3 set operation shapes" do
    # Set operation values accept two shapes: a filter params map/keyword (which is
    # built into a query using the same source schema as the outer query), or a
    # pre-built `%Ecto.Query{}`. Both forms are live for all six set operations.
    test "matches Ecto.Query for union with filter params" do
      other_query = from(p in Post, where: p.published == ^false)
      expected = union(Post, ^other_query)

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{union: %{published: false}},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for union with a prebuilt query" do
      other_query = from(p in Post, where: p.published == ^false)
      expected = union(Post, ^other_query)

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{union: other_query},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for union_all with filter params" do
      other_query = from(p in Post, where: p.published == ^false)
      expected = union_all(Post, ^other_query)

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{union_all: %{published: false}},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for union_all with a prebuilt query" do
      other_query = from(p in Post, where: p.published == ^false)
      expected = union_all(Post, ^other_query)

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{union_all: other_query},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for intersect with filter params" do
      other_query = from(p in Post, where: p.published == ^false)
      expected = intersect(Post, ^other_query)

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{intersect: %{published: false}},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for intersect with a prebuilt query" do
      other_query = from(p in Post, where: p.published == ^false)
      expected = intersect(Post, ^other_query)

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{intersect: other_query},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for intersect_all with filter params" do
      other_query = from(p in Post, where: p.published == ^false)
      expected = intersect_all(Post, ^other_query)

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{intersect_all: %{published: false}},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for intersect_all with a prebuilt query" do
      other_query = from(p in Post, where: p.published == ^false)
      expected = intersect_all(Post, ^other_query)

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{intersect_all: other_query},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for except with filter params" do
      other_query = from(p in Post, where: p.published == ^false)
      expected = except(Post, ^other_query)

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{except: %{published: false}},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for except with a prebuilt query" do
      other_query = from(p in Post, where: p.published == ^false)
      expected = except(Post, ^other_query)

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{except: other_query},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for except_all with filter params" do
      other_query = from(p in Post, where: p.published == ^false)
      expected = except_all(Post, ^other_query)

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{except_all: %{published: false}},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for except_all with a prebuilt query" do
      other_query = from(p in Post, where: p.published == ^false)
      expected = except_all(Post, ^other_query)

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{except_all: other_query},
          []
        )

      assert_query(expected, actual)
    end
  end
end
