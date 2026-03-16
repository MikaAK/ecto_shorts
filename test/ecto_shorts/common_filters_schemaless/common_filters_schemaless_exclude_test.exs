defmodule EctoShorts.CommonFilters.SchemalessExcludeTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing

  alias EctoShorts.CommonFilters

  import Ecto.Query

  describe "convert_params_to_filter/3 exclude shapes (schemaless)" do
    test "matches Ecto.Query for excluding where" do
      source = from(p in "posts", where: p.published == ^true)
      expected = exclude(source, :where)

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{exclude: :where},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for excluding order_by" do
      source = from(p in "posts", order_by: [desc: p.title])
      expected = exclude(source, :order_by)

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{exclude: :order_by},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for excluding group_by" do
      source = from(p in "posts", group_by: p.author_id)
      expected = exclude(source, :group_by)

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{exclude: :group_by},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for excluding having" do
      source = from(p in "posts", group_by: p.author_id, having: avg(p.views) > ^10)
      expected = exclude(source, :having)

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{exclude: :having},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for excluding distinct" do
      source = from(p in "posts", distinct: p.title)
      expected = exclude(source, :distinct)

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{exclude: :distinct},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for excluding select" do
      source = from(p in "posts", select: p.title)
      expected = exclude(source, :select)

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{exclude: :select},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for excluding combinations" do
      other_query = from(p in "posts", where: p.published == ^false)
      source = union("posts", ^other_query)
      expected = exclude(source, :combinations)

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{exclude: :combinations},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for excluding limit" do
      source = limit("posts", ^10)
      expected = exclude(source, :limit)

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{exclude: :limit},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for excluding offset" do
      source = offset("posts", ^5)
      expected = exclude(source, :offset)

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{exclude: :offset},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for excluding lock" do
      source = lock("posts", "FOR UPDATE")
      expected = exclude(source, :lock)

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{exclude: :lock},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for excluding update" do
      updates = [set: [title: "After"]]
      source = update("posts", [], ^updates)
      expected = exclude(source, :update)

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{exclude: :update},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for excluding multiple fields with a list payload" do
      source =
        "posts"
        |> limit(^10)
        |> offset(^5)

      expected = exclude(source, [:limit, :offset])

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{exclude: [:limit, :offset]},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for excluding joins" do
      source = from(p in "posts", join: u in "users", on: true)
      expected = exclude(source, :join)

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{exclude: :join},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for excluding cross_join" do
      source = from(p in "posts", cross_join: u in "users")
      expected = exclude(source, :cross_join)

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{exclude: :cross_join},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for excluding left_join" do
      source = from(p in "posts", left_join: u in "users", on: true)
      expected = exclude(source, :left_join)

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{exclude: :left_join},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for excluding right_join" do
      source = from(p in "posts", right_join: u in "users", on: true)
      expected = exclude(source, :right_join)

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{exclude: :right_join},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for excluding full_join" do
      source = from(p in "posts", full_join: u in "users", on: true)
      expected = exclude(source, :full_join)

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{exclude: :full_join},
          []
        )

      assert_query(expected, actual)
    end
  end
end
