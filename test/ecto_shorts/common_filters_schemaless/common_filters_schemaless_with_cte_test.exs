defmodule EctoShorts.CommonFilters.SchemalessWithCteTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing

  alias EctoShorts.CommonFilters

  import Ecto.Query
  import ExUnit.CaptureLog

  describe "with_cte shapes (schemaless)" do
    test "matches Ecto.Query for with_cte with a prebuilt query" do
      cte_query = from(p in "posts", where: p.published == ^true)
      expected = with_cte("posts", "published_posts", as: ^cte_query)

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{with_cte: [published_posts: [as: cte_query]]},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for with_cte with a prebuilt subquery" do
      cte_query =
        "posts"
        |> where([p], p.published == ^true)
        |> subquery()

      expected = with_cte("posts", "published_posts", as: ^cte_query)

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{with_cte: [published_posts: [as: cte_query]]},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for with_cte with filter params using the default source" do
      cte_query = from(p in "posts", where: p.published == ^true)
      expected = with_cte("posts", "published_posts", as: ^cte_query)

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{with_cte: [published_posts: [as: [published: true]]]},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for with_cte with materialized false" do
      cte_query = from(p in "posts", where: p.published == ^true)
      expected = with_cte("posts", "published_posts", as: ^cte_query, materialized: false)

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{with_cte: %{published_posts: %{as: [published: true], materialized: false}}},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query when recursive_ctes is applied before with_cte" do
      cte_query = from(p in "posts", where: p.published == ^true)
      expected = "posts" |> recursive_ctes(true) |> with_cte("published_posts", as: ^cte_query)

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          [recursive_ctes: true, with_cte: [published_posts: [as: cte_query]]],
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for ordered keyword-list CTE dependencies" do
      published_posts_query = from(p in "posts", where: p.published == ^true)
      recent_posts_query = from(p in "published_posts", where: p.title == ^"recent")

      expected =
        "posts"
        |> with_cte("published_posts", as: ^published_posts_query)
        |> with_cte("recent_published_posts", as: ^recent_posts_query)

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          [
            with_cte: [
              published_posts: [as: [published: true]],
              recent_published_posts: [as: recent_posts_query]
            ]
          ],
          []
        )

      assert_query(expected, actual)
    end

    test "keeps the query unchanged when with_cte params are invalid" do
      expected = from(p in "posts")

      log =
        capture_log(fn ->
          actual =
            CommonFilters.convert_params_to_filter(
              "posts",
              %{with_cte: "invalid"},
              []
            )

          assert_query(expected, actual)
        end)

      assert log =~ "Expected :with_cte params to be a map or keyword list"
    end
  end
end
