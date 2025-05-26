defmodule EctoShorts.CommonQueryAPITest do
  use ExUnit.Case, async: true
  doctest EctoShorts.CommonQueryAPI

  alias EctoShorts.{
    CommonQueryAPI,
    Schemas.Comment,
    Schemas.PostAbstract,
    Schemas.Post,
    Testing
  }

  import Ecto.Query,
    only: [
      dynamic: 2,
      from: 1,
      from: 2
    ]

  import Testing,
    only: [
      assert_dynamic: 2,
      assert_query: 2
    ]

  describe "merge_dynamic/2" do
    test "merges a dynamic expression with another using AND when the first is nil" do
      dyn = dynamic([q], q.id == ^1)
      assert_dynamic dyn, CommonQueryAPI.merge_dynamic(nil, :and, dynamic([q], q.id == ^1))
    end

    test "merges two dynamic expressions using AND" do
      expected_dyn = dynamic([d], d.id == ^1 and d.published == true)
      dyn_a = dynamic([d], d.id == ^1)
      dyn_b = dynamic([d], d.published == true)
      assert_dynamic expected_dyn, CommonQueryAPI.merge_dynamic(dyn_a, :and, dyn_b)
    end

    test "merges two dynamic expressions using OR" do
      expected_dyn = dynamic([d], d.id == ^1 or d.published == true)
      dyn_a = dynamic([d], d.id == ^1)
      dyn_b = dynamic([d], d.published == true)
      assert_dynamic expected_dyn, CommonQueryAPI.merge_dynamic(dyn_a, :or, dyn_b)
    end
  end

  describe "dynamic/1" do
    test "wraps a dynamic expression as is" do
      dyn = dynamic([d], d.id == ^1)
      assert_dynamic dyn, CommonQueryAPI.dynamic(nil, dynamic([d], d.id == ^1))
    end
  end

  describe "dynamic/4" do
    test "builds a dynamic expression using default Field comparison when no schema module is present" do
      dyn = dynamic([d], d.tags == ^"example")
      assert_dynamic dyn, CommonQueryAPI.dynamic(nil, "posts", tags: "example")
    end

    test "builds a dynamic expression using schema-based type when a schema module is present" do
      dyn = dynamic([d], ^"example" in d.tags)
      assert_dynamic dyn, CommonQueryAPI.dynamic(nil, {"posts", Post}, tags: "example")
    end
  end

  describe "exclude/2" do
    test "excludes the given clause from the query" do
      expected_query = from p in Post
      base_query = from p in Post, order_by: [asc: p.id]
      assert_query expected_query, CommonQueryAPI.exclude(base_query, :order_by)
    end
  end

  describe "from/3" do
    test "builds a query from a schema with a given alias and prefix" do
      query = from p in Post, as: :post, prefix: "example_prefix"
      assert_query query, CommonQueryAPI.from(Post, :post, prefix: "example_prefix")
    end

    test "sets the query prefix using the query_prefix option" do
      assert %Ecto.Query{prefix: "example_prefix"} =
               CommonQueryAPI.from(Post, :post, query_prefix: "example_prefix")
    end
  end

  describe "group_by/3" do
    test "adds a group_by clause to a query without an alias" do
      query = from p in Post, group_by: p.published
      assert_query query, CommonQueryAPI.group_by(Post, nil, :published)
    end

    test "adds a group_by clause to a query with an alias" do
      expected_query = from p in Post, as: :post, group_by: p.published
      base_query = from p in Post, as: :post
      assert_query expected_query, CommonQueryAPI.group_by(base_query, :post, :published)
    end
  end

  describe "limit/3" do
    test "adds a limit to a query without an alias" do
      query = from p in Post, limit: ^5
      assert_query query, CommonQueryAPI.limit(Post, nil, 5)
    end

    test "adds a limit to a query with an alias" do
      expected_query = from p in Post, as: :post, limit: ^5
      base_query = from p in Post, as: :post
      assert_query expected_query, CommonQueryAPI.limit(base_query, :post, 5)
    end

    test "adds a limit to a join with an alias" do
      expected_query =
        from p in Post, join: c in Comment, as: :comments, on: c.post_id == p.id, limit: ^5

      base_query = from p in Post, join: c in Comment, as: :comments, on: c.post_id == p.id
      assert_query expected_query, CommonQueryAPI.limit(base_query, :comments, 5)
    end
  end

  describe "offset/3" do
    test "adds an offset to a query without an alias" do
      query = from p in Post, offset: ^5
      assert_query query, CommonQueryAPI.offset(Post, nil, 5)
    end

    test "adds an offset to a query with an alias" do
      expected_query = from p in Post, as: :post, offset: ^5
      base_query = from p in Post, as: :post
      assert_query expected_query, CommonQueryAPI.offset(base_query, :post, 5)
    end

    test "adds an offset to a join with an alias" do
      expected_query =
        from p in Post, join: c in Comment, as: :comments, on: c.post_id == p.id, offset: ^5

      base_query = from p in Post, join: c in Comment, as: :comments, on: c.post_id == p.id
      assert_query expected_query, CommonQueryAPI.offset(base_query, :comments, 5)
    end
  end

  describe "order_by/3" do
    test "adds an order_by to a query without an alias" do
      query = from p in Post, order_by: [asc: p.inserted_at]
      assert_query query, CommonQueryAPI.order_by(Post, nil, asc: :inserted_at)
    end

    test "adds an order_by to a query with an alias" do
      expected_query = from p in Post, as: :post, order_by: [asc: p.inserted_at]
      base_query = from p in Post, as: :post
      assert_query expected_query, CommonQueryAPI.order_by(base_query, :post, asc: :inserted_at)
    end
  end

  describe "join/6" do
    test "joins an association without aliasing" do
      query = from p in Post, join: assoc(p, :comments)
      assert_query query, CommonQueryAPI.join(Post, :association, {nil, nil}, :comments)
    end

    test "joins an association with aliasing" do
      query = from p in Post, join: assoc(p, :comments), as: :comments
      assert_query query, CommonQueryAPI.join(Post, :association, {nil, :comments}, :comments)
    end

    test "joins an association with base query aliasing" do
      expected_query = from p in Post, as: :post, join: assoc(p, :comments), as: :comments
      base_query = from p in Post, as: :post

      assert_query expected_query,
                   CommonQueryAPI.join(base_query, :association, {:post, :comments}, :comments)
    end

    test "joins with dynamic ON expressions and schema detection fallback" do
      # with schema-detected type
      query = from c in Comment, join: p in assoc(c, :post), as: :post, on: ^"example" in p.tags

      assert_query query,
                   CommonQueryAPI.join(Comment, :association, {nil, :post}, :post, %{
                     on: %{tags: "example"}
                   })

      # with source-specified fallback
      query = from c in Comment, join: p in assoc(c, :post), as: :post, on: p.tags == ^"example"

      assert_query query,
                   CommonQueryAPI.join(Comment, :association, {nil, :post}, :post, %{
                     source: "posts",
                     on: %{tags: "example"}
                   })
    end

    test "joins with a left join and prefix" do
      query =
        from p in Post, left_join: assoc(p, :comments), as: :comments, prefix: "example_prefix"

      assert_query query,
                   CommonQueryAPI.join(Post, :association, {nil, :comments}, :comments, %{
                     qualifier: :left,
                     prefix: "example_prefix"
                   })
    end

    test "joins with a custom ON condition using operator maps" do
      query = from p in Post, join: c in assoc(p, :comments), as: :comments, on: c.id >= ^5

      assert_query query,
                   CommonQueryAPI.join(Post, :association, {nil, :comments}, :comments, %{
                     on: %{id: %{>=: 5}}
                   })
    end

    test "joins a subquery with a basic ON condition" do
      inner_query = from c in Comment

      expected_query =
        from p in Post, join: c in subquery(inner_query), as: :comments, on: c.id == ^1

      assert_query expected_query,
                   CommonQueryAPI.join(Post, :subquery, {nil, :comments}, inner_query, %{
                     on: %{id: 1}
                   })
    end

    test "joins a subquery with left join and prefix, ON true" do
      inner_query = from c in Comment

      expected_query =
        from p in Post,
          left_join: c in subquery(inner_query),
          prefix: "example_prefix",
          on: true

      assert_query expected_query,
                   CommonQueryAPI.join(Post, :subquery, {nil, nil}, inner_query, %{
                     qualifier: :left,
                     prefix: "example_prefix"
                   })
    end

    test "joins with a named query source and custom ON condition" do
      query = from c in Comment, join: p in {"posts", PostAbstract}, as: :post, on: p.id >= ^5

      assert_query query,
                   CommonQueryAPI.join(Comment, :query, {nil, :post}, {"posts", PostAbstract}, %{
                     on: %{id: %{>=: 5}}
                   })
    end

    test "joins with a named query source and prefix, ON true" do
      query =
        from c in Comment,
          left_join: p in {"posts", PostAbstract},
          as: :post,
          prefix: "example_prefix",
          on: true

      assert_query query,
                   CommonQueryAPI.join(Comment, :query, {nil, :post}, {"posts", PostAbstract}, %{
                     qualifier: :left,
                     prefix: "example_prefix",
                     on: true
                   })
    end
  end

  describe "preload/2" do
    test "preloads associations without aliasing" do
      query = from p in Post, preload: [:comments]
      assert_query query, CommonQueryAPI.preload(Post, nil, [:comments])
    end
  end

  describe "put_query_prefix/2" do
    test "updates the query prefix" do
      assert %Ecto.Query{prefix: "example_prefix"} =
               CommonQueryAPI.put_query_prefix(Post, "example_prefix")
    end
  end

  describe "select/4" do
    test "selects the whole record when true" do
      query = from p in Post, select: p
      assert_query query, CommonQueryAPI.select(Post, nil, true)
    end

    test "selects specific fields as map" do
      query = from p in Post, select: map(p, [:id])
      assert_query query, CommonQueryAPI.select(Post, nil, %{map: [:id]})
    end

    test "selects specific fields as struct" do
      query = from p in Post, select: struct(p, [:id])
      assert_query query, CommonQueryAPI.select(Post, nil, %{struct: [:id]})
    end

    test "selects specific values directly" do
      query = from p in Post, select: [:id]
      assert_query query, CommonQueryAPI.select(Post, nil, %{value: [:id]})
    end
  end

  describe "select_merge/4" do
    test "merges additional fields into a map selection" do
      expected_query = from p in Post, select: [:published, :title]
      base_query = from p in Post, select: [:published]
      assert_query expected_query, CommonQueryAPI.select_merge(base_query, nil, [:title])
    end

    test "merges additional map fields in a join" do
      base_query =
        from p in Post, join: c in Comment, as: :comments, on: true, select: map(c, [:body])

      expected_query =
        from p in Post,
          join: c in Comment,
          as: :comments,
          on: true,
          select: map(c, [:body, :replies])

      assert_query expected_query,
                   CommonQueryAPI.select_merge(base_query, :comments, %{map: [:replies]})
    end

    test "merges additional struct fields in a join" do
      base_query =
        from p in Post, join: c in Comment, as: :comments, on: true, select: struct(c, [:body])

      expected_query =
        from p in Post,
          join: c in Comment,
          as: :comments,
          on: true,
          select: struct(c, [:body, :replies])

      assert_query expected_query,
                   CommonQueryAPI.select_merge(base_query, :comments, %{struct: [:replies]})
    end

    test "merges select with true to keep the base selection" do
      base_query =
        from p in Post, join: c in Comment, as: :comments, on: true, select: struct(c, [:body])

      expected_query =
        from p in Post, join: c in Comment, as: :comments, on: true, select: struct(c, [:body])

      assert_query expected_query, CommonQueryAPI.select_merge(base_query, :comments, true)
    end

    test "merges additional values into a direct value selection" do
      base_query = from p in Post, select: [:published]
      expected_query = from p in Post, select: [:published, :title]

      assert_query expected_query,
                   CommonQueryAPI.select_merge(base_query, nil, %{value: [:title]})
    end
  end

  describe "or_where/3" do
    test "adds an OR filter with a basic integer equality" do
      query = from p in Post, or_where: p.views == ^1
      assert_query query, CommonQueryAPI.or_where(Post, nil, %{views: 1})
    end

    test "adds an OR filter using operator map for equality" do
      query = from p in Post, or_where: p.views == ^1
      assert_query query, CommonQueryAPI.or_where(Post, nil, %{views: %{==: 1}})
    end

    test "adds an OR filter using operator map for greater than" do
      query = from p in Post, or_where: p.views > ^1
      assert_query query, CommonQueryAPI.or_where(Post, nil, %{views: %{>: 1}})
    end

    test "adds an OR filter using operator map for less than" do
      query = from p in Post, or_where: p.views < ^1
      assert_query query, CommonQueryAPI.or_where(Post, nil, %{views: %{<: 1}})
    end

    test "adds an OR filter using operator map for greater than or equal to" do
      query = from p in Post, or_where: p.views >= ^1
      assert_query query, CommonQueryAPI.or_where(Post, nil, %{views: %{>=: 1}})
    end

    test "adds an OR filter using operator map for less than or equal to" do
      query = from p in Post, or_where: p.views <= ^1
      assert_query query, CommonQueryAPI.or_where(Post, nil, %{views: %{<=: 1}})
    end

    test "adds an OR filter using LIKE on a string field" do
      query = from p in Post, or_where: like(field(p, :title), ^"%example%")
      assert_query query, CommonQueryAPI.or_where(Post, nil, %{title: %{like: "example"}})
    end

    test "adds an OR filter using ILIKE on a string field" do
      query = from p in Post, or_where: ilike(field(p, :title), ^"%example%")
      assert_query query, CommonQueryAPI.or_where(Post, nil, %{title: %{ilike: "example"}})
    end

    test "adds an OR filter checking if a string is in an array field" do
      query = from p in Post, or_where: ^"example" in p.tags
      assert_query query, CommonQueryAPI.or_where(Post, nil, %{tags: %{==: "example"}})
    end

    test "adds an OR filter with > ANY array comparison" do
      query = from p in Post, or_where: fragment("? > ANY(?)", ^"a", p.tags)
      assert_query query, CommonQueryAPI.or_where(Post, nil, %{tags: %{>: "a"}})
    end

    test "adds an OR filter with < ANY array comparison" do
      query = from p in Post, or_where: fragment("? < ANY(?)", ^"a", p.tags)
      assert_query query, CommonQueryAPI.or_where(Post, nil, %{tags: %{<: "a"}})
    end

    test "adds an OR filter with >= ANY array comparison" do
      query = from p in Post, or_where: fragment("? >= ANY(?)", ^"a", p.tags)
      assert_query query, CommonQueryAPI.or_where(Post, nil, %{tags: %{>=: "a"}})
    end

    test "adds an OR filter with <= ANY array comparison" do
      query = from p in Post, or_where: fragment("? <= ANY(?)", ^"a", p.tags)
      assert_query query, CommonQueryAPI.or_where(Post, nil, %{tags: %{<=: "a"}})
    end

    test "adds an OR filter with LIKE ANY array comparison" do
      query = from p in Post, or_where: fragment("? LIKE ANY(?)", ^"%a%", p.tags)
      assert_query query, CommonQueryAPI.or_where(Post, nil, %{tags: %{like: "a"}})
    end

    test "adds an OR filter with ILIKE ANY array comparison" do
      query = from p in Post, or_where: fragment("? ILIKE ANY(?)", ^"%a%", p.tags)
      assert_query query, CommonQueryAPI.or_where(Post, nil, %{tags: %{ilike: "a"}})
    end
  end

  describe "where/3" do
    test "adds a basic integer equality filter" do
      query = from p in Post, where: p.views == ^1
      assert_query query, CommonQueryAPI.where(Post, nil, %{views: 1})
    end

    test "adds an equality filter using operator map" do
      query = from p in Post, where: p.views == ^1
      assert_query query, CommonQueryAPI.where(Post, nil, %{views: %{==: 1}})
    end

    test "adds a greater than filter using operator map" do
      query = from p in Post, where: p.views > ^1
      assert_query query, CommonQueryAPI.where(Post, nil, %{views: %{>: 1}})
    end

    test "adds a less than filter using operator map" do
      query = from p in Post, where: p.views < ^1
      assert_query query, CommonQueryAPI.where(Post, nil, %{views: %{<: 1}})
    end

    test "adds a greater than or equal to filter using operator map" do
      query = from p in Post, where: p.views >= ^1
      assert_query query, CommonQueryAPI.where(Post, nil, %{views: %{>=: 1}})
    end

    test "adds a less than or equal to filter using operator map" do
      query = from p in Post, where: p.views <= ^1
      assert_query query, CommonQueryAPI.where(Post, nil, %{views: %{<=: 1}})
    end

    test "adds a LIKE filter on a string field" do
      query = from p in Post, where: like(field(p, :title), ^"%example%")
      assert_query query, CommonQueryAPI.where(Post, nil, %{title: %{like: "example"}})
    end

    test "adds an ILIKE filter on a string field" do
      query = from p in Post, where: ilike(field(p, :title), ^"%example%")
      assert_query query, CommonQueryAPI.where(Post, nil, %{title: %{ilike: "example"}})
    end

    test "adds a filter checking if a string is in an array field" do
      query = from p in Post, where: ^"example" in p.tags
      assert_query query, CommonQueryAPI.where(Post, nil, %{tags: %{==: "example"}})
    end

    test "adds a > ANY array filter using fragment" do
      query = from p in Post, where: fragment("? > ANY(?)", ^"a", p.tags)
      assert_query query, CommonQueryAPI.where(Post, nil, %{tags: %{>: "a"}})
    end

    test "adds a < ANY array filter using fragment" do
      query = from p in Post, where: fragment("? < ANY(?)", ^"a", p.tags)
      assert_query query, CommonQueryAPI.where(Post, nil, %{tags: %{<: "a"}})
    end

    test "adds a >= ANY array filter using fragment" do
      query = from p in Post, where: fragment("? >= ANY(?)", ^"a", p.tags)
      assert_query query, CommonQueryAPI.where(Post, nil, %{tags: %{>=: "a"}})
    end

    test "adds a <= ANY array filter using fragment" do
      query = from p in Post, where: fragment("? <= ANY(?)", ^"a", p.tags)
      assert_query query, CommonQueryAPI.where(Post, nil, %{tags: %{<=: "a"}})
    end

    test "adds a LIKE ANY array filter using fragment" do
      query = from p in Post, where: fragment("? LIKE ANY(?)", ^"%a%", p.tags)
      assert_query query, CommonQueryAPI.where(Post, nil, %{tags: %{like: "a"}})
    end

    test "adds an ILIKE ANY array filter using fragment" do
      query = from p in Post, where: fragment("? ILIKE ANY(?)", ^"%a%", p.tags)
      assert_query query, CommonQueryAPI.where(Post, nil, %{tags: %{ilike: "a"}})
    end
  end
end
