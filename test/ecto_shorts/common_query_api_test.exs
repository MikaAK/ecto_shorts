defmodule EctoShorts.CommonQueryAPITest do
  use ExUnit.Case, async: true
  doctest EctoShorts.CommonQueryAPI

  alias EctoShorts.{
    CommonQueryAPI,
    Schemas.Comment,
    Schemas.Post,
    Testing
  }

  import Ecto.Query, only: [from: 1, from: 2]
  import Testing, only: [assert_query: 2]

  describe "join/6" do
    test "0" do
      query = from p in Post, join: assoc(p, :comments)
      assert_query query, CommonQueryAPI.join(Post, :association, {nil, nil}, :comments)
    end

    test "1" do
      query = from p in Post, join: assoc(p, :comments), as: :comments
      assert_query query, CommonQueryAPI.join(Post, :association, {nil, :comments}, :comments)
    end

    test "2" do
      expected_query = from p in Post, as: :post, join: assoc(p, :comments), as: :comments
      base_query = from p in Post, as: :post

      assert_query expected_query,
                   CommonQueryAPI.join(base_query, :association, {:post, :comments}, :comments)
    end

    test "3" do
      # checks if single value is in array when schema detected
      query = from c in Comment, join: p in assoc(c, :post), as: :post, on: ^"example" in p.tags

      assert_query query,
                   CommonQueryAPI.join(Comment, :association, {nil, :post}, :post, %{
                     on: %{tags: "example"}
                   })

      # when the source does not contain a schema, fallback to field comparison
      query = from c in Comment, join: p in assoc(c, :post), as: :post, on: p.tags == ^"example"

      assert_query query,
                   CommonQueryAPI.join(Comment, :association, {nil, :post}, :post, %{
                     source: "posts",
                     on: %{tags: "example"}
                   })
    end

    test "4" do
      query =
        from p in Post, left_join: assoc(p, :comments), as: :comments, prefix: "example_prefix"

      assert_query query,
                   CommonQueryAPI.join(Post, :association, {nil, :comments}, :comments, %{
                     qualifier: :left,
                     prefix: "example_prefix"
                   })
    end

    test "5" do
      query = from p in Post, join: c in assoc(p, :comments), as: :comments, on: c.id >= ^5

      assert_query query, CommonQueryAPI.join(Post, :association, {nil, :comments}, :comments, %{on: %{id: %{>=: 5}}})
    end

    test "6" do
      expected_query = from p in Post, join: c in subquery(from c in Comment), as: :comments, on: c.id == ^1
      inner_query = from c in Comment

      assert_query expected_query, CommonQueryAPI.join(Post, :subquery, {nil, :comments}, inner_query, %{on: %{id: 1}})
    end

    test "7" do
      expected_query = from p in Post, left_join: c in subquery(from c in Comment), prefix: "example_prefix", on: true
      inner_query = from c in Comment

      assert_query expected_query, CommonQueryAPI.join(Post, :subquery, {nil, nil}, inner_query, %{qualifier: :left, prefix: "example_prefix"})
    end
  end

  describe "where" do
    # base

    test "1" do
      query = from p in Post, where: p.views == ^1

      assert_query query, CommonQueryAPI.where(Post, nil, %{views: 1})
    end

    # integer (non-array field)

    test "2" do
      query = from p in Post, where: p.views == ^1

      assert_query query, CommonQueryAPI.where(Post, nil, %{views: %{==: 1}})
    end

    test "3" do
      query = from p in Post, where: p.views > ^1

      assert_query query, CommonQueryAPI.where(Post, nil, %{views: %{>: 1}})
    end

    test "4" do
      query = from p in Post, where: p.views < ^1

      assert_query query, CommonQueryAPI.where(Post, nil, %{views: %{<: 1}})
    end

    test "5" do
      query = from p in Post, where: p.views >= ^1

      assert_query query, CommonQueryAPI.where(Post, nil, %{views: %{>=: 1}})
    end

    test "6" do
      query = from p in Post, where: p.views <= ^1

      assert_query query, CommonQueryAPI.where(Post, nil, %{views: %{<=: 1}})
    end

    # string (non-array field)

    test "7" do
      query = from p in Post, where: like(field(p, :title), ^"%example%")

      assert_query query, CommonQueryAPI.where(Post, nil, %{title: %{like: "example"}})
    end

    test "8" do
      query = from p in Post, where: ilike(field(p, :title), ^"%example%")

      assert_query query, CommonQueryAPI.where(Post, nil, %{title: %{ilike: "example"}})
    end

    # integer (array field)

    test "9" do
      query = from p in Post, where: ^"example" in p.tags

      assert_query query, CommonQueryAPI.where(Post, nil, %{tags: %{==: "example"}})
    end

    test "10" do
      query = from p in Post, where: fragment("? > ANY(?)", ^"a", p.tags)

      assert_query query, CommonQueryAPI.where(Post, nil, %{tags: %{>: "a"}})
    end

    test "11" do
      query = from p in Post, where: fragment("? < ANY(?)", ^"a", p.tags)

      assert_query query, CommonQueryAPI.where(Post, nil, %{tags: %{<: "a"}})
    end

    test "12" do
      query = from p in Post, where: fragment("? >= ANY(?)", ^"a", p.tags)

      assert_query query, CommonQueryAPI.where(Post, nil, %{tags: %{>=: "a"}})
    end

    test "13" do
      query = from p in Post, where: fragment("? <= ANY(?)", ^"a", p.tags)

      assert_query query, CommonQueryAPI.where(Post, nil, %{tags: %{<=: "a"}})
    end

    # string (non-array field)

    test "14" do
      query = from p in Post, where: fragment("? LIKE ANY(?)", ^"%a%", p.tags)

      assert_query query, CommonQueryAPI.where(Post, nil, %{tags: %{like: "a"}})
    end

    test "15" do
      query = from p in Post, where: fragment("? ILIKE ANY(?)", ^"%a%", p.tags)

      assert_query query, CommonQueryAPI.where(Post, nil, %{tags: %{ilike: "a"}})
    end
  end
end
