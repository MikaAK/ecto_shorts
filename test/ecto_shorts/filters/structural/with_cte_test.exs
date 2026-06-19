defmodule EctoShorts.CommonFilters.WithCteTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing
  @moduletag adapter: :postgres
  @moduletag feature: :with_cte

  alias EctoShorts.CommonFilters
  alias EctoShorts.Schema.Post

  import Ecto.Query
  import ExUnit.CaptureLog

  describe "with_cte shapes" do
    test "accepts a map payload for with_cte (map→list conversion path)" do
      cte_query = from(p in Post, where: p.published == ^true)
      expected = with_cte(Post, "published_posts", as: ^cte_query)

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{with_cte: %{published_posts: %{as: cte_query}}},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for with_cte with a prebuilt query" do
      cte_query = from(p in Post, where: p.published == ^true)
      expected = with_cte(Post, "published_posts", as: ^cte_query)

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{with_cte: [published_posts: [as: cte_query]]},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for with_cte with a prebuilt subquery" do
      cte_query =
        Post
        |> where([p], p.published == ^true)
        |> subquery()

      expected = with_cte(Post, "published_posts", as: ^cte_query)

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{with_cte: [published_posts: [as: cte_query]]},
          []
        )

      assert_query(expected, actual)
    end

    test "accepts a map for the CTE filter params" do
      cte_query = from(p in Post, where: p.published == ^true)
      expected = with_cte(Post, "published_posts", as: ^cte_query)

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{with_cte: [published_posts: [as: %{published: true}]]},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for with_cte with filter params using the default source" do
      cte_query = from(p in Post, where: p.published == ^true)
      expected = with_cte(Post, "published_posts", as: ^cte_query)

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{with_cte: [published_posts: [as: [published: true]]]},
          []
        )

      assert_query(expected, actual)
    end

    # Including `from:` in the CTE filter params overrides the default source.
    # Without `from:`, the CTE query is built from the same schema as the outer query.
    test "matches Ecto.Query for with_cte with filter params using an explicit from source" do
      cte_source = from(p in Post)
      cte_query = from(p in Post, where: p.published == ^true)
      expected = with_cte(Post, "published_posts", as: ^cte_query)

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{with_cte: [published_posts: [as: [from: cte_source, published: true]]]},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for with_cte with materialized false" do
      cte_query = from(p in Post, where: p.published == ^true)
      expected = with_cte(Post, "published_posts", as: ^cte_query, materialized: false)

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{with_cte: %{published_posts: %{as: [published: true], materialized: false}}},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for with_cte with update_all operation" do
      cte_query =
        Post
        |> where([p], p.published == ^false)
        |> update([p], set: [published: true])
        |> select([p], p)

      expected = with_cte(Post, "published_posts", as: ^cte_query, operation: :update_all)

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{with_cte: %{published_posts: %{as: cte_query, operation: :update_all}}},
          []
        )

      assert_sql(expected, actual)
    end

    # `recursive_ctes:` and `with_cte:` can appear in either order in the keyword
    # list. Both orderings produce the same Ecto.Query structure.
    test "matches Ecto.Query when recursive_ctes is applied before with_cte" do
      cte_query = from(p in Post, where: p.published == ^true)
      expected = Post |> recursive_ctes(true) |> with_cte("published_posts", as: ^cte_query)

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          [recursive_ctes: true, with_cte: [published_posts: [as: cte_query]]],
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query when with_cte is applied before recursive_ctes" do
      cte_query = from(p in Post, where: p.published == ^true)
      expected = Post |> with_cte("published_posts", as: ^cte_query) |> recursive_ctes(true)

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          [with_cte: [published_posts: [as: cte_query]], recursive_ctes: true],
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for with_cte nested under a named binding" do
      source =
        from(p in Post,
          join: a in assoc(p, :author),
          as: :author
        )

      cte_query = from(p in Post, where: p.published == ^true)
      expected = with_cte(source, "published_posts", as: ^cte_query)

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{
            as: %{
              author: %{
                with_cte: [published_posts: [as: cte_query]]
              }
            }
          },
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for with_cte nested under a positional binding" do
      source =
        from(p in Post,
          join: a in assoc(p, :author)
        )

      cte_query = from(p in Post, where: p.published == ^true)
      expected = with_cte(source, "published_posts", as: ^cte_query)

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{
            at: %{
              2 => %{
                with_cte: [published_posts: [as: cte_query]]
              }
            }
          },
          []
        )

      assert_query(expected, actual)
    end

    # When CTEs reference each other, the referenced CTE must appear before the
    # referencing CTE in the params list. Use a keyword list to preserve this order.
    test "matches Ecto.Query for ordered keyword-list CTE dependencies" do
      published_posts_query = from(p in Post, where: p.published == ^true)
      recent_posts_query = from(p in "published_posts", where: p.title == ^"recent")

      expected =
        Post
        |> with_cte("published_posts", as: ^published_posts_query)
        |> with_cte("recent_published_posts", as: ^recent_posts_query)

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
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
      expected = from(p in Post)

      log =
        capture_log(fn ->
          actual =
            CommonFilters.convert_params_to_filter(
              Post,
              %{with_cte: "invalid"},
              []
            )

          assert_query(expected, actual)
        end)

      assert log =~ "Expected :with_cte params to be a map or keyword list"
    end

    test "keeps the query unchanged when a with_cte :as payload is invalid" do
      expected = from(p in Post)

      log =
        capture_log(fn ->
          actual =
            CommonFilters.convert_params_to_filter(
              Post,
              %{with_cte: [published_posts: [as: 123]]},
              []
            )

          assert_query(expected, actual)
        end)

      assert log =~
               "Expected CTE :as query params for \"published_posts\" to be a query, subquery, or keyword/map payload"
    end

    test "keeps the query unchanged when a with_cte :operation payload is invalid" do
      cte_query = from(p in Post, where: p.published == ^true)
      expected = from(p in Post)

      log =
        capture_log(fn ->
          actual =
            CommonFilters.convert_params_to_filter(
              Post,
              %{with_cte: [published_posts: [as: cte_query, operation: :invalid]]},
              []
            )

          assert_sql(expected, actual)
        end)

      assert log =~
               "Expected :operation for \"published_posts\" to be one of [:all, :update_all, :delete_all], got: :invalid"
    end
  end

  describe "with_cte extended paths" do
    test "applies with_cte from a list entry that is a string-keyed map" do
      cte_query = from(p in Post, where: p.published == ^true)

      expected =
        Post
        |> from()
        |> with_cte("published_posts", as: ^cte_query)

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{with_cte: [%{"published_posts" => [as: cte_query]}]},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for with_cte with both materialized and operation" do
      cte_query =
        Post
        |> where([p], p.published == ^false)
        |> update([p], set: [published: true])
        |> select([p], p)

      expected =
        with_cte(Post, "published_posts",
          as: ^cte_query,
          materialized: true,
          operation: :update_all
        )

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{
            with_cte: %{
              published_posts: %{as: cte_query, materialized: true, operation: :update_all}
            }
          },
          []
        )

      assert_sql(expected, actual)
    end

    test "keeps the query unchanged when a with_cte entry is not a pair" do
      expected = from(p in Post)

      log =
        capture_log(fn ->
          actual =
            CommonFilters.convert_params_to_filter(
              Post,
              %{with_cte: [:not_a_pair]},
              []
            )

          assert_query(expected, actual)
        end)

      assert log =~ "Expected :with_cte params to be a map or keyword list"
    end

    test "keeps the query unchanged when the with_cte name is invalid" do
      expected = from(p in Post)
      cte_query = from(p in Post, where: p.published == ^true)

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{with_cte: [%{123 => [as: cte_query]}]},
          []
        )

      assert_query(expected, actual)
    end

    test "keeps the query unchanged when a with_cte entry is missing :as key" do
      expected = from(p in Post)

      log =
        capture_log(fn ->
          actual =
            CommonFilters.convert_params_to_filter(
              Post,
              %{with_cte: [published_posts: [materialized: false]]},
              []
            )

          assert_query(expected, actual)
        end)

      assert log =~ "Expected :with_cte params for \"published_posts\" to include an :as key"
    end

    test "keeps the query unchanged when with_cte :materialized is invalid" do
      cte_query = from(p in Post, where: p.published == ^true)
      expected = from(p in Post)

      log =
        capture_log(fn ->
          actual =
            CommonFilters.convert_params_to_filter(
              Post,
              %{with_cte: [published_posts: [as: cte_query, materialized: "yes"]]},
              []
            )

          assert_query(expected, actual)
        end)

      assert log =~ "Expected :materialized for \"published_posts\" to be a boolean"
    end

    test "casts a string boolean with_cte :materialized payload" do
      cte_query = from(p in Post, where: p.published == ^true)
      expected = with_cte(Post, "published_posts", as: ^cte_query, materialized: false)

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{with_cte: [published_posts: [as: cte_query, materialized: "false"]]},
          []
        )

      assert_query(expected, actual)
    end
  end
end
