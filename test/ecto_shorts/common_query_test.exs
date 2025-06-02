defmodule EctoShorts.CommonQueryTest do
  use ExUnit.Case, async: true
  doctest EctoShorts.CommonQuery

  alias EctoShorts.CommonQuery
  alias EctoShorts.Schemas.{Comment, Post, User}

  alias Ecto.Query.{FromExpr, JoinExpr}
  import Ecto.Query, only: [from: 1, from: 2, subquery: 1]

  describe "&get_base_expr" do
    test "returns FromExpr for schema-backed query" do
      query = from p in Post
      assert %FromExpr{source: {"posts", Post}} = CommonQuery.get_base_expr(query)
    end

    test "returns FromExpr for table namequery" do
      query = from p in "posts"
      assert %FromExpr{source: {"posts", nil}} = CommonQuery.get_base_expr(query)
    end

    test "returns FromExpr for explicit source tuple" do
      query = from p in {"custom_source", Post}
      assert %FromExpr{source: {"custom_source", Post}} = CommonQuery.get_base_expr(query)
    end

    test "resolves FromExpr from composed query" do
      first_query = from p in Post
      second_query = from p in first_query
      assert %FromExpr{source: {"posts", Post}} = CommonQuery.get_base_expr(second_query)
    end

    test "resolves FromExpr from 1-level subquery" do
      inner_query = from p in Post
      outer_query = from p in subquery(inner_query)
      assert %FromExpr{source: {"posts", Post}} = CommonQuery.get_base_expr(outer_query)
    end

    test "resolves FromExpr from 2-level subquery" do
      inner_query = from p in Post
      mid_query = from p in subquery(inner_query)
      outer_query = from p in subquery(mid_query)
      assert %FromExpr{source: {"posts", Post}} = CommonQuery.get_base_expr(outer_query)
    end

    test "returns base FromExpr from main schema" do
      subquery = from c in "comments", where: c.approved == true
      query = from p in Post, join: c in subquery(subquery), as: :comments, on: c.post_id == p.id
      assert %FromExpr{source: {"posts", Post}} = CommonQuery.get_base_expr(query)
    end

    test "resolves base from multi-level query composition" do
      query = from p in Post
      query = from p in query, where: not is_nil(p.title)
      query = from p in query, select: p.id
      assert %FromExpr{source: {"posts", Post}} = CommonQuery.get_base_expr(query)
    end
  end

  describe "get_binding/2" do
    test "resolves binding from schema query with no alias" do
      query = from p in Post

      assert {%FromExpr{as: nil, source: {"posts", Post}}, 0} =
               CommonQuery.get_binding_expr(query, nil)
    end

    test "resolves binding from schema query with alias" do
      query = from p in Post, as: :post

      assert {%FromExpr{as: :post, source: {"posts", Post}}, 0} =
               CommonQuery.get_binding_expr(query, nil)
    end

    test "resolves binding from composed query" do
      first_query = from p in Post, where: p.published == true
      second_query = from p in first_query, where: p.id == 1

      assert {%FromExpr{as: nil, source: {"posts", Post}}, 0} =
               CommonQuery.get_binding_expr(second_query, nil)
    end

    test "resolves binding from 1-level subquery" do
      inner_query = from p in Post
      outer_query = from p in subquery(inner_query)

      assert {%FromExpr{as: nil, source: {"posts", Post}}, 0} =
               CommonQuery.get_binding_expr(outer_query, nil)
    end

    test "resolves alias from subquery" do
      inner_query = from p in Post, as: :post
      outer_query = from p in subquery(inner_query)

      assert {%FromExpr{as: :post, source: {"posts", Post}}, 0} =
               CommonQuery.get_binding_expr(outer_query, nil)
    end

    test "finds aliased binding by name in subquery" do
      inner_query = from p in Post, as: :post
      outer_query = from p in subquery(inner_query)

      assert {%FromExpr{as: :post, source: {"posts", Post}}, 0} =
               CommonQuery.get_binding_expr(outer_query, :post)
    end

    test "finds nested join binding by alias" do
      query =
        from p in Post,
          join: c in assoc(p, :comments),
          as: :comments,
          on: c.post_id == p.id,
          join: a in assoc(c, :author),
          as: :author,
          on: a.id == c.author_id

      assert {%JoinExpr{as: :author}, 2} = CommonQuery.get_binding_expr(query, :author)
    end

    test "resolves join binding from 1-level subquery" do
      inner =
        from p in Post,
          join: c in assoc(p, :comments),
          as: :comments,
          on: c.post_id == p.id,
          join: a in assoc(c, :author),
          as: :author,
          on: a.id == c.author_id

      outer = from p in subquery(inner)

      assert {%JoinExpr{as: :author}, 2} = CommonQuery.get_binding_expr(outer, :author)
    end

    test "resolves join binding from 2-level subquery" do
      inner =
        from p in Post,
          join: c in assoc(p, :comments),
          as: :comments,
          on: c.post_id == p.id,
          join: a in assoc(c, :author),
          as: :author,
          on: a.id == c.author_id

      mid = from p in subquery(inner)
      outer = from p in subquery(mid)

      assert {%JoinExpr{as: :author}, 2} = CommonQuery.get_binding_expr(outer, :author)
    end

    test "resolves subquery join by alias" do
      subquery = from c in "comments", where: c.approved == true
      query = from p in Post, join: c in subquery(subquery), as: :comments, on: c.post_id == p.id

      assert {%JoinExpr{as: :comments, source: %Ecto.SubQuery{}}, 1} =
               CommonQuery.get_binding_expr(query, :comments)
    end

    test "resolves binding expression from nested subquery join where alias is defined in inner query" do
      inner = from c in "comments", as: :comments, where: c.approved == true
      subquery = from c in subquery(inner), where: c.replies > 1
      query = from p in Post, join: c in subquery(subquery), on: c.post_id == p.id

      assert {%FromExpr{as: :comments, source: {"comments", nil}}, 0} =
               CommonQuery.get_binding_expr(query, :comments)
    end

    test "raises when attempting to resolve binding alias not explicitly defined with as: in join" do
      query = from p in Post, join: c in assoc(p, :comments), on: c.post_id == p.id

      assert_raise ArgumentError, fn -> CommonQuery.get_binding_expr(query, :comments) end
    end
  end

  describe "get_binding_source/2" do
    test "returns source from schema query with no alias" do
      query = from p in Post
      assert {"posts", Post} = CommonQuery.get_binding_expr_source(query, nil)
    end

    test "returns source from explicit custom tuple" do
      query = from p in {"custom_source", Post}
      assert {"custom_source", Post} = CommonQuery.get_binding_expr_source(query, nil)
    end

    test "returns source from table namequery" do
      query = from p in "posts"
      assert {"posts", nil} = CommonQuery.get_binding_expr_source(query, nil)
    end

    test "resolves aliased source from schema query" do
      query = from p in Post, as: :post
      assert {"posts", Post} = CommonQuery.get_binding_expr_source(query, nil)
    end

    test "resolves source by alias from base query" do
      query = from p in Post, as: :post
      assert {"posts", Post} = CommonQuery.get_binding_expr_source(query, :post)
    end

    test "resolves join source by alias" do
      query =
        from p in Post,
          join: c in assoc(p, :comments),
          as: :comments,
          on: c.post_id == p.id,
          join: a in assoc(c, :author),
          as: :author,
          on: a.id == c.author_id

      assert {nil, User} =
               CommonQuery.get_binding_expr_source(query, :author)
    end

    test "resolves join source after composition" do
      base =
        from p in Post,
          join: c in assoc(p, :comments),
          as: :comments,
          on: c.post_id == p.id,
          join: a in assoc(c, :author),
          as: :author,
          on: a.id == c.author_id

      outer = from p in base

      assert {nil, User} =
               CommonQuery.get_binding_expr_source(outer, :author)
    end

    test "resolves schema source from subquery (no alias)" do
      inner = from p in Post
      outer = from p in subquery(inner)
      assert {"posts", Post} = CommonQuery.get_binding_expr_source(outer, nil)
    end

    test "resolves schema source from subquery (with alias, no alias lookup)" do
      inner = from p in Post, as: :post
      outer = from p in subquery(inner), where: p.published_at == true
      assert {"posts", Post} = CommonQuery.get_binding_expr_source(outer, nil)
    end

    test "resolves schema source from subquery (with alias, with alias lookup)" do
      inner = from p in Post, as: :post
      outer = from p in subquery(inner), where: p.published_at == true
      assert {"posts", Post} = CommonQuery.get_binding_expr_source(outer, :post)
    end

    test "resolves join source from subquery by alias" do
      inner =
        from p in Post,
          join: c in assoc(p, :comments),
          as: :comments,
          on: c.post_id == p.id,
          join: a in assoc(c, :author),
          as: :author,
          on: a.id == c.author_id

      outer = from p in subquery(inner)

      assert {nil, User} =
               CommonQuery.get_binding_expr_source(outer, :author)
    end

    test "resolves nil schema from subquery join" do
      subquery = from c in "comments", where: c.approved == true
      query = from p in Post, join: c in subquery(subquery), as: :comments, on: c.post_id == p.id
      assert {"comments", nil} = CommonQuery.get_binding_expr_source(query, :comments)
    end

    test "resolves table name with nil schema from subquery join using alias" do
      subquery = from c in "comments", where: c.approved == true
      query = from p in Post, join: c in subquery(subquery), as: :comments, on: c.post_id == p.id
      assert {"comments", nil} = CommonQuery.get_binding_expr_source(query, :comments)
    end

    test "resolves source from nested subquery join using alias" do
      inner = from c in "comments", where: c.approved == true
      subquery = from c in subquery(inner), where: c.replies > 1
      query = from p in Post, join: c in subquery(subquery), as: :comments, on: c.post_id == p.id
      assert {"comments", nil} = CommonQuery.get_binding_expr_source(query, :comments)
    end

    test "resolves source from nested subquery join where alias is declared in inner query" do
      inner = from c in "comments", as: :comments, where: c.approved == true
      subquery = from c in subquery(inner), where: c.replies > 1
      query = from p in Post, join: c in subquery(subquery), on: c.post_id == p.id
      assert {"comments", nil} = CommonQuery.get_binding_expr_source(query, :comments)
    end

    test "11" do
      query =
        from p in Post,
          join: c in assoc(p, :comments),
          on: c.post_id == p.id,
          as: :comments,
          join: u in assoc(p, :author),
          as: :author,
          on: u.id == c.author_id

      assert {nil, User} = CommonQuery.get_binding_expr_source(query, :author)
    end

    test "12" do
      query =
        from p in Post,
          join: a in assoc(p, :author),
          as: :author,
          join: c in assoc(p, :comments),
          as: :comments,
          join: cp in assoc(c, :post),
          as: :post,
          join: a2 in assoc(p, :authors),
          as: :authors,
          where: a.id == ^1,
          where: cp.title == ^"example",
          where: a2.age >= ^0

      assert {nil, User} = CommonQuery.get_binding_expr_source(query, :author)
      assert {nil, User} = CommonQuery.get_binding_expr_source(query, :authors)
      assert {nil, Comment} = CommonQuery.get_binding_expr_source(query, :comments)
      assert {nil, Post} = CommonQuery.get_binding_expr_source(query, :post)
    end

    test "13" do
      published_comments_query = from c in Comment, where: c.published == true

      query =
        from p in Post,
          join: c in subquery(published_comments_query),
          as: :comments,
          on: c.post_id == p.id

      assert {"comments", Comment} = CommonQuery.get_binding_expr_source(query, :comments)
    end

    test "14" do
      published_comments_query = from c in Comment, as: :comments, where: c.published == true

      query =
        from p in Post,
          join: c in subquery(published_comments_query),
          on: c.post_id == p.id

      assert {"comments", Comment} = CommonQuery.get_binding_expr_source(query, :comments)
    end

    test "15" do
      published_comments_query =
        from c in Comment,
          as: :comments,
          join: u in User,
          as: :user,
          on: c.author_id == u.id,
          where: c.published == true

      query =
        from p in Post,
          join: c in subquery(published_comments_query),
          on: c.post_id == p.id

      assert {nil, EctoShorts.Schemas.User} = CommonQuery.get_binding_expr_source(query, :user)
    end
  end
end
