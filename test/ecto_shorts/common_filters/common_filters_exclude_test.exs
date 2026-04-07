defmodule EctoShorts.CommonFilters.ExcludeTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing

  alias EctoShorts.CommonFilters
  alias EctoShorts.Schema.Post

  import Ecto.Query

  describe "exclude shapes" do
    test "matches Ecto.Query for excluding where" do
      source = from(p in Post, where: p.published == ^true)
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
      source = from(p in Post, order_by: [desc: p.title])
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
      source = from(p in Post, group_by: p.author_id)
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
      source = from(p in Post, group_by: p.author_id, having: avg(p.views) > ^10)
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
      source = from(p in Post, distinct: p.title)
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
      source = from(p in Post, select: p.title)
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
      other_query = from(p in Post, where: p.published == ^false)
      source = union(Post, ^other_query)
      expected = exclude(source, :combinations)

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{exclude: :combinations},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for excluding with_ctes" do
      cte_query = from(p in Post, where: p.published == ^true)
      source = with_cte(Post, "published_posts", as: ^cte_query)
      expected = exclude(source, :with_ctes)

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{exclude: :with_ctes},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for excluding limit" do
      source = limit(Post, ^10)
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
      source = offset(Post, ^5)
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
      source = lock(Post, "FOR UPDATE")
      expected = exclude(source, :lock)

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{exclude: :lock},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for excluding preload" do
      source = from(p in Post, preload: :author)
      expected = exclude(source, :preload)

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{exclude: :preload},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for excluding update" do
      updates = [set: [title: "After"]]
      source = update(Post, [], ^updates)
      expected = exclude(source, :update)

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{exclude: :update},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for excluding windows" do
      source =
        from(p in Post,
          windows: [
            post_window: [
              partition_by: p.author_id,
              order_by: [desc: p.inserted_at]
            ]
          ]
        )

      expected = exclude(source, :windows)

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{exclude: :windows},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for excluding multiple fields with a list payload" do
      source =
        Post
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
      source = from(p in Post, join: u in assoc(p, :author))
      expected = exclude(source, :join)

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{exclude: :join},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for excluding inner_join" do
      source = from(p in Post, inner_join: u in assoc(p, :author))
      expected = exclude(source, :inner_join)

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{exclude: :inner_join},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for excluding cross_join" do
      source = from(p in Post, cross_join: u in "users")
      expected = exclude(source, :cross_join)

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{exclude: :cross_join},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for excluding cross_lateral_join" do
      source = from(p in Post, cross_lateral_join: u in fragment("SELECT 1 AS id"))
      expected = exclude(source, :cross_lateral_join)

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{exclude: :cross_lateral_join},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for excluding left_join" do
      source = from(p in Post, left_join: u in assoc(p, :author))
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
      source = from(p in Post, right_join: u in "users", on: true)
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
      source = from(p in Post, full_join: u in "users", on: true)
      expected = exclude(source, :full_join)

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{exclude: :full_join},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for excluding inner_lateral_join" do
      source = from(p in Post, inner_lateral_join: u in fragment("SELECT 1 AS id"), on: true)
      expected = exclude(source, :inner_lateral_join)

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{exclude: :inner_lateral_join},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for excluding left_lateral_join" do
      source = from(p in Post, left_lateral_join: u in fragment("SELECT 1 AS id"), on: true)
      expected = exclude(source, :left_lateral_join)

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{exclude: :left_lateral_join},
          []
        )

      assert_query(expected, actual)
    end

    # `{:windows, [:name]}` removes only the named windows. The atom `:windows`
    # removes all windows.
    test "matches Ecto.Query for excluding specific windows by name" do
      source =
        from(p in Post,
          windows: [
            post_window: [partition_by: p.author_id],
            author_window: [order_by: [desc: p.inserted_at]]
          ]
        )

      expected = exclude(source, {:windows, [:post_window]})

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{exclude: {:windows, [:post_window]}},
          []
        )

      assert_query(expected, actual)
    end
  end
end
