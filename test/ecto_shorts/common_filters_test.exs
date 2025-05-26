defmodule EctoShorts.CommonFiltersTest do
  use ExUnit.Case, async: true
  doctest EctoShorts.CommonFilters

  alias EctoShorts.{
    CommonFilters,
    Schemas.PostAbstract,
    Schemas.Post
  }

  import Ecto.Query, only: [from: 2]
  import EctoShorts.Testing, only: [assert_query: 2]

  describe "&convert_params_to_filter/3" do
    test "1" do
      expected_query =
        from p in {"posts", PostAbstract},
          join: a in assoc(p, :author),
          as: :ecto_shorts_author,
          where: a.id == ^1

      actual_query =
        CommonFilters.convert_params_to_filter({"posts", PostAbstract}, %{author: %{id: 1}})

      assert_query actual_query, expected_query
    end

    test "2" do
      expected_query =
        from p in {"posts", PostAbstract},
          join: a in assoc(p, :authors),
          as: :ecto_shorts_authors,
          where: a.id == ^1

      actual_query =
        CommonFilters.convert_params_to_filter({"posts", PostAbstract}, %{authors: %{id: 1}})

      assert_query actual_query, expected_query
    end

    test "3" do
      expected_query =
        from p in {"posts", PostAbstract},
          join: a in assoc(p, :comments),
          as: :ecto_shorts_comments,
          where: a.id == ^1

      actual_query =
        CommonFilters.convert_params_to_filter({"posts", PostAbstract}, %{comments: %{id: 1}})

      assert_query actual_query, expected_query
    end

    test "4" do
      expected_query =
        from p in {"posts", PostAbstract},
          join: a in assoc(p, :comments_authors),
          as: :ecto_shorts_comments_authors,
          where: a.id == ^1

      actual_query =
        CommonFilters.convert_params_to_filter({"posts", PostAbstract}, %{
          comments_authors: %{id: 1}
        })

      assert_query actual_query, expected_query
    end

    # ---
    test "belongs_to relationship" do
      expected_query =
        from p in Post, join: a in assoc(p, :author), as: :ecto_shorts_author, where: a.id == ^1

      actual_query = CommonFilters.convert_params_to_filter(Post, %{author: %{id: 1}})
      assert_query actual_query, expected_query
    end

    test "many_to_many relationship" do
      expected_query =
        from p in Post, join: a in assoc(p, :authors), as: :ecto_shorts_authors, where: a.id == ^1

      actual_query = CommonFilters.convert_params_to_filter(Post, %{authors: %{id: 1}})
      assert_query actual_query, expected_query
    end

    test "has_many relationship" do
      expected_query =
        from p in Post,
          join: a in assoc(p, :comments),
          as: :ecto_shorts_comments,
          where: a.id == ^1

      actual_query = CommonFilters.convert_params_to_filter(Post, %{comments: %{id: 1}})
      assert_query actual_query, expected_query
    end

    test "has_through relationship" do
      expected_query =
        from p in Post,
          join: a in assoc(p, :comments_authors),
          as: :ecto_shorts_comments_authors,
          where: a.id == ^1

      actual_query = CommonFilters.convert_params_to_filter(Post, %{comments_authors: %{id: 1}})
      assert_query actual_query, expected_query
    end

    #
    # Base cases
    #

    test "returns the base query when params are empty" do
      expected_query = Post
      actual_query = CommonFilters.convert_params_to_filter(Post, %{})
      assert_query actual_query, expected_query
    end

    #
    # Equality tests
    #

    # integer

    test "builds a query with == on integer field using direct value" do
      expected_query = from p in Post, where: p.id == ^1
      actual_query = CommonFilters.convert_params_to_filter(Post, %{id: 1})
      assert_query actual_query, expected_query
    end

    test "builds a query with == on integer field using explicit :== operator" do
      expected_query = from p in Post, where: p.id == ^1
      actual_query = CommonFilters.convert_params_to_filter(Post, %{id: %{==: 1}})
      assert_query actual_query, expected_query
    end

    test "builds a query with != on integer field" do
      expected_query = from p in Post, where: p.id != ^1
      actual_query = CommonFilters.convert_params_to_filter(Post, %{id: %{!=: 1}})
      assert_query actual_query, expected_query
    end

    test "builds a query with > on integer field" do
      expected_query = from p in Post, where: p.id > ^1
      actual_query = CommonFilters.convert_params_to_filter(Post, %{id: %{>: 1}})
      assert_query actual_query, expected_query
    end

    test "builds a query with < on integer field" do
      expected_query = from p in Post, where: p.id < ^1
      actual_query = CommonFilters.convert_params_to_filter(Post, %{id: %{<: 1}})
      assert_query actual_query, expected_query
    end

    test "builds a query with >= on integer field" do
      expected_query = from p in Post, where: p.id >= ^1
      actual_query = CommonFilters.convert_params_to_filter(Post, %{id: %{>=: 1}})
      assert_query actual_query, expected_query
    end

    test "builds a query with <= on integer field" do
      expected_query = from p in Post, where: p.id <= ^1
      actual_query = CommonFilters.convert_params_to_filter(Post, %{id: %{<=: 1}})
      assert_query actual_query, expected_query
    end

    #
    # String matching
    #

    test "builds a query with like on string field" do
      expected_query = from p in Post, where: like(p.title, ^"%example%")

      actual_query =
        CommonFilters.convert_params_to_filter(Post, %{title: %{like: "example"}})

      assert_query actual_query, expected_query
    end

    test "builds a query with ilike on string field" do
      expected_query = from p in Post, where: ilike(p.title, ^"%example%")

      actual_query =
        CommonFilters.convert_params_to_filter(Post, %{title: %{ilike: "example"}})

      assert_query actual_query, expected_query
    end

    #
    # Array field
    #

    test "builds a query where string is checked as 'in' against array field" do
      expected_query = from p in Post, where: ^"example" in p.tags
      actual_query = CommonFilters.convert_params_to_filter(Post, %{tags: "example"})
      assert_query actual_query, expected_query
    end

    test "builds a query where list matches exactly against array field" do
      expected_query = from p in Post, where: p.tags == ^["example"]
      actual_query = CommonFilters.convert_params_to_filter(Post, %{tags: ["example"]})
      assert_query actual_query, expected_query
    end

    #
    # Association join
    #

    test "builds a query that joins association and filters nested value" do
      expected_query =
        from p in Post,
          join: c in assoc(p, :comments),
          as: :ecto_shorts_comments,
          where: c.id == ^1

      actual_query = CommonFilters.convert_params_to_filter(Post, %{comments: %{id: 1}})
      assert_query actual_query, expected_query
    end

    #
    # Query Shaping
    #

    test "builds a query with preload" do
      expected_query = from p in Post, preload: [:comments]
      actual_query = CommonFilters.convert_params_to_filter(Post, %{preload: [:comments]})
      assert_query actual_query, expected_query
    end

    test "builds a query with select using map syntax" do
      expected_query = from p in Post, select: map(p, [:id])
      actual_query = CommonFilters.convert_params_to_filter(Post, %{select: %{map: [:id]}})
      assert_query actual_query, expected_query
    end

    test "builds a query with select_merge on an existing select" do
      expected_query = from p in Post, select: map(p, [:id, :title])

      base_query = from p in Post, select: map(p, [:id])

      actual_query =
        CommonFilters.convert_params_to_filter(base_query, %{select_merge: [:title]})

      assert_query actual_query, expected_query
    end
  end
end
