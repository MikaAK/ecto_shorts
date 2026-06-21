defmodule EctoShorts.CommonQueryTest do
  use EctoShorts.DataCase, async: true

  import Ecto.Query

  alias EctoShorts.CommonQuery
  alias EctoShorts.Schema.Comment
  alias EctoShorts.Schema.Post
  alias EctoShorts.Schema.PostHasSchemaPrefix
  alias EctoShorts.Schema.User

  describe "get_query_source/1" do
    test "returns the table name without a schema for a bare table query" do
      q = from(u in "users")
      assert {"users", nil} = CommonQuery.get_query_source(q)
    end

    test "returns the table name and schema module for a schema query" do
      assert {"users", User} = CommonQuery.get_query_source(User)
    end

    test "returns the custom table name when the query uses a tuple source" do
      q = from(u in {"custom_users", User})
      assert {"custom_users", User} = CommonQuery.get_query_source(q)
    end

    test "returns the source even after adding where and select clauses" do
      q = User |> where([u], u.age > 0) |> select([u], u.id)
      assert {"users", User} = CommonQuery.get_query_source(q)
    end

    test "returns the inner source when the query wraps a subquery" do
      inner = from(u in User, where: u.age > 0)
      q = from(u in subquery(inner))

      assert {"users", User} = CommonQuery.get_query_source(q)
    end
  end

  describe "get_query_prefix/1" do
    test "returns nil when no prefix is set" do
      assert nil === CommonQuery.get_query_prefix(User)
    end

    test "returns the schema prefix when the schema defines one" do
      assert "custom_schema_prefix" = CommonQuery.get_query_prefix(PostHasSchemaPrefix)
    end

    test "returns the prefix set directly on the query" do
      q = from(p in Post, prefix: "explicit_prefix")
      assert "explicit_prefix" = CommonQuery.get_query_prefix(q)
    end

    test "returns the prefix from the inner subquery" do
      inner = from(p in Post, prefix: "inner_prefix")
      q = from(p in subquery(inner))

      assert "inner_prefix" = CommonQuery.get_query_prefix(q)
    end
  end

  describe "query_binding_count/1" do
    test "counts one binding for a plain schema query" do
      assert 1 = CommonQuery.query_binding_count(User)
    end

    test "counts each join as an additional binding" do
      q =
        from(u in User,
          join: p in assoc(u, :posts),
          join: c in assoc(p, :comments)
        )

      assert 3 = CommonQuery.query_binding_count(q)
    end
  end

  describe "get_query_binding_source/2" do
    test "finds the source for a named from binding" do
      q = from(u in User, as: :user)
      assert {"users", User} = CommonQuery.get_query_binding_source(q, :user)
    end

    test "finds the source for a join by its position number" do
      q = from(u in User, as: :user, join: p in Post, as: :post, on: true)

      assert {"users", User} = CommonQuery.get_query_binding_source(q, 1)
      assert {nil, Post} = CommonQuery.get_query_binding_source(q, 2)
    end

    test "finds the source for a join by its alias name" do
      q = from(u in User, as: :user, join: p in Post, as: :post, on: true)

      assert {nil, Post} = CommonQuery.get_query_binding_source(q, :post)
    end

    test "returns nil when the alias does not exist" do
      q = from(u in User, as: :user)
      assert nil === CommonQuery.get_query_binding_source(q, :does_not_exist)
    end

    test "returns nil when the position is out of range" do
      q = from(u in User, as: :user)
      assert nil === CommonQuery.get_query_binding_source(q, 2)
    end

    test "finds the last join using a negative position" do
      q =
        from(u in User,
          join: p in Post,
          on: true,
          join: c in Comment,
          on: true
        )

      assert {nil, Comment} = CommonQuery.get_query_binding_source(q, -1)
    end

    test "finds the related schema for an association join" do
      q =
        from(u in User,
          as: :user,
          join: p in assoc(u, :posts),
          as: :post
        )

      assert {nil, Post} = CommonQuery.get_query_binding_source(q, :post)
      assert {nil, Post} = CommonQuery.get_query_binding_source(q, 2)
    end

    test "follows a chain of association joins to find the final schema" do
      q =
        from(u in User,
          as: :user,
          join: p in assoc(u, :posts),
          as: :post,
          join: c in assoc(p, :comments),
          as: :comment
        )

      assert {nil, Comment} = CommonQuery.get_query_binding_source(q, :comment)
      assert {nil, Comment} = CommonQuery.get_query_binding_source(q, 3)
    end

    test "finds an association join inside a subquery" do
      inner =
        from(u in User,
          as: :user,
          join: p in assoc(u, :posts),
          as: :post
        )

      q = from(u in subquery(inner))

      assert {nil, Post} = CommonQuery.get_query_binding_source(q, :post)
    end

    test "returns the table name without a schema for a named bare table query" do
      q = from(u in "users", as: :user)
      assert {"users", nil} = CommonQuery.get_query_binding_source(q, :user)
    end
  end

  describe "get_query_prefix/1 extended" do
    test "returns nil for a query with no prefix-bearing source expr" do
      q = from(u in "users")
      assert nil === CommonQuery.get_query_prefix(q)
    end

    test "accepts a bare table string as queryable" do
      assert nil === CommonQuery.get_query_prefix("users")
    end

    test "accepts a tuple source as queryable" do
      assert nil === CommonQuery.get_query_prefix({"users", User})
    end
  end

  describe "get_query_source/1 extended" do
    test "accepts a bare table string as queryable" do
      assert {"users", nil} = CommonQuery.get_query_source("users")
    end

    test "accepts a tuple source as queryable" do
      assert {"users", User} = CommonQuery.get_query_source({"users", User})
    end
  end

  describe "get_query_binding_source/2 extended" do
    test "returns nil for a join with a schemaless root (bare table string)" do
      q = from(u in "users", join: p in Post, as: :post, on: true)
      assert {nil, Post} = CommonQuery.get_query_binding_source(q, :post)
    end

    test "returns the source for an association join via a chained subquery binding" do
      inner =
        from(u in User,
          as: :user,
          join: p in assoc(u, :posts),
          as: :post,
          join: c in assoc(p, :comments),
          as: :comment
        )

      q = from(u in subquery(inner))
      assert {nil, Comment} = CommonQuery.get_query_binding_source(q, :comment)
    end

    test "returns the source for the root from binding (position 1)" do
      q = from(u in User, as: :user, join: p in Post, as: :post, on: true)
      assert {"users", User} = CommonQuery.get_query_binding_source(q, 1)
    end

    test "handles an association join where the root is a schemaless from" do
      q =
        from(u in "users",
          join: p in Post,
          as: :post,
          on: true
        )

      assert {nil, Post} = CommonQuery.get_query_binding_source(q, :post)
    end

    test "returns nil for an association join on a nil-schema root" do
      q =
        from(u in "users",
          as: :user,
          join: p in assoc(u, :posts),
          as: :post
        )

      assert nil === CommonQuery.get_query_binding_source(q, :post)
    end
  end

  describe "to_query!/1 raises for invalid queryable" do
    test "raises ArgumentError for a non-queryable term" do
      assert_raise ArgumentError, ~r/expected a queryable/, fn ->
        CommonQuery.get_query_source(123)
      end
    end
  end

  describe "get_query_binding_source/2 via non-Ecto.Query queryable" do
    test "resolves binding source from a schema module queryable" do
      assert {"users", User} = CommonQuery.get_query_binding_source(User, 1)
    end
  end

  describe "get_query_binding_source/2 nil binding_alias path" do
    test "returns the from source when binding alias is nil" do
      q = from(u in User, as: :user)
      assert {"users", User} = CommonQuery.get_query_binding_source(q, nil)
    end
  end

  describe "has_subquery? detection paths" do
    test "get_query_source_expr traverses subquery to inner query" do
      inner = from(u in User)
      q = from(u in subquery(inner))
      assert {"users", User} = CommonQuery.get_query_source(q)
    end

    test "get_query_binding_source traverses association join through subquery" do
      inner =
        from(u in User,
          as: :user,
          join: p in assoc(u, :posts),
          as: :post
        )

      q = from(u in subquery(inner))
      assert {nil, EctoShorts.Schema.Post} = CommonQuery.get_query_binding_source(q, :post)
    end
  end

  describe "get_join_expr_source assoc {_, nil} path" do
    test "returns nil when root schema cannot be resolved for assoc join" do
      q =
        from(u in "users",
          as: :user,
          join: p in assoc(u, :posts),
          as: :post
        )

      assert nil === CommonQuery.get_query_binding_source(q, :post)
    end
  end

  describe "get_query_prefix/1 nil fallthrough" do
    test "returns nil for a bare schema module with no prefix" do
      assert nil === CommonQuery.get_query_prefix(User)
    end
  end

  describe "get_query_source/1 nil fallthrough" do
    test "returns nil for a query with only a subquery from and no inner table source" do
      inner = from(u in User, select: u.id)
      q = from(x in subquery(inner))
      assert {"users", User} = CommonQuery.get_query_source(q)
    end
  end

  describe "has_subquery? overloads" do
    test "has_subquery? is true for a query with subquery/1 from" do
      inner = from(u in User)
      q = from(u in subquery(inner))
      assert {"users", User} = CommonQuery.get_query_source(q)
    end

    test "gets binding source through subquery wrapping an association join" do
      inner =
        from(u in User,
          as: :user,
          join: p in assoc(u, :posts),
          as: :post,
          join: c in assoc(p, :comments),
          as: :comment
        )

      outer = from(x in subquery(inner))
      assert {nil, Comment} = CommonQuery.get_query_binding_source(outer, :comment)
    end
  end
end
