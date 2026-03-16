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
      assert CommonQuery.get_query_source(q) === {"users", nil}
    end

    test "returns the table name and schema module for a schema query" do
      assert CommonQuery.get_query_source(User) === {"users", User}
    end

    test "returns the custom table name when the query uses a tuple source" do
      q = from(u in {"custom_users", User})
      assert CommonQuery.get_query_source(q) === {"custom_users", User}
    end

    test "returns the source even after adding where and select clauses" do
      q = User |> where([u], u.age > 0) |> select([u], u.id)
      assert CommonQuery.get_query_source(q) === {"users", User}
    end

    test "returns the inner source when the query wraps a subquery" do
      inner = from(u in User, where: u.age > 0)
      q = from(u in subquery(inner))

      assert CommonQuery.get_query_source(q) === {"users", User}
    end
  end

  describe "get_query_prefix/1" do
    test "returns nil when no prefix is set" do
      assert CommonQuery.get_query_prefix(User) === nil
    end

    test "returns the schema prefix when the schema defines one" do
      assert CommonQuery.get_query_prefix(PostHasSchemaPrefix) === "custom_schema_prefix"
    end

    test "returns the prefix set directly on the query" do
      q = from(p in Post, prefix: "explicit_prefix")
      assert CommonQuery.get_query_prefix(q) === "explicit_prefix"
    end

    test "returns the prefix from the inner subquery" do
      inner = from(p in Post, prefix: "inner_prefix")
      q = from(p in subquery(inner))

      assert CommonQuery.get_query_prefix(q) === "inner_prefix"
    end
  end

  describe "query_binding_count/1" do
    test "counts one binding for a plain schema query" do
      assert CommonQuery.query_binding_count(User) === 1
    end

    test "counts each join as an additional binding" do
      q =
        from(u in User,
          join: p in assoc(u, :posts),
          join: c in assoc(p, :comments)
        )

      assert CommonQuery.query_binding_count(q) === 3
    end
  end

  describe "get_query_binding_source/2" do
    test "finds the source for a named from binding" do
      q = from(u in User, as: :user)
      assert CommonQuery.get_query_binding_source(q, :user) === {"users", User}
    end

    test "finds the source for a join by its position number" do
      q = from(u in User, as: :user, join: p in Post, as: :post, on: true)

      assert CommonQuery.get_query_binding_source(q, 1) === {"users", User}
      assert CommonQuery.get_query_binding_source(q, 2) === {nil, Post}
    end

    test "finds the source for a join by its alias name" do
      q = from(u in User, as: :user, join: p in Post, as: :post, on: true)

      assert CommonQuery.get_query_binding_source(q, :post) === {nil, Post}
    end

    test "returns nil when the alias does not exist" do
      q = from(u in User, as: :user)
      assert CommonQuery.get_query_binding_source(q, :does_not_exist) === nil
    end

    test "returns nil when the position is out of range" do
      q = from(u in User, as: :user)
      assert CommonQuery.get_query_binding_source(q, 2) === nil
    end

    test "finds the last join using a negative position" do
      q =
        from(u in User,
          join: p in Post,
          on: true,
          join: c in Comment,
          on: true
        )

      assert CommonQuery.get_query_binding_source(q, -1) === {nil, Comment}
    end

    test "finds the related schema for an association join" do
      q =
        from(u in User,
          as: :user,
          join: p in assoc(u, :posts),
          as: :post
        )

      assert CommonQuery.get_query_binding_source(q, :post) === {nil, Post}
      assert CommonQuery.get_query_binding_source(q, 2) === {nil, Post}
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

      assert CommonQuery.get_query_binding_source(q, :comment) === {nil, Comment}
      assert CommonQuery.get_query_binding_source(q, 3) === {nil, Comment}
    end

    test "finds an association join inside a subquery" do
      inner =
        from(u in User,
          as: :user,
          join: p in assoc(u, :posts),
          as: :post
        )

      q = from(u in subquery(inner))

      assert CommonQuery.get_query_binding_source(q, :post) === {nil, Post}
    end

    test "returns the table name without a schema for a named bare table query" do
      q = from(u in "users", as: :user)
      assert CommonQuery.get_query_binding_source(q, :user) === {"users", nil}
    end
  end

  describe "get_query_prefix/1 extended" do
    test "returns nil for a query with no prefix-bearing source expr" do
      q = from(u in "users")
      assert CommonQuery.get_query_prefix(q) === nil
    end

    test "accepts a bare table string as queryable" do
      assert CommonQuery.get_query_prefix("users") === nil
    end

    test "accepts a tuple source as queryable" do
      assert CommonQuery.get_query_prefix({"users", User}) === nil
    end
  end

  describe "get_query_source/1 extended" do
    test "accepts a bare table string as queryable" do
      assert CommonQuery.get_query_source("users") === {"users", nil}
    end

    test "accepts a tuple source as queryable" do
      assert CommonQuery.get_query_source({"users", User}) === {"users", User}
    end
  end

  describe "get_query_binding_source/2 extended" do
    test "returns nil for a join with a schemaless root (bare table string)" do
      q = from(u in "users", join: p in Post, as: :post, on: true)
      assert CommonQuery.get_query_binding_source(q, :post) === {nil, Post}
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
      assert CommonQuery.get_query_binding_source(q, :comment) === {nil, Comment}
    end

    test "returns the source for the root from binding (position 1)" do
      q = from(u in User, as: :user, join: p in Post, as: :post, on: true)
      assert CommonQuery.get_query_binding_source(q, 1) === {"users", User}
    end

    test "handles an association join where the root is a schemaless from" do
      q =
        from(u in "users",
          join: p in Post,
          as: :post,
          on: true
        )

      assert CommonQuery.get_query_binding_source(q, :post) === {nil, Post}
    end

    test "returns nil for an association join on a nil-schema root" do
      q =
        from(u in "users",
          as: :user,
          join: p in assoc(u, :posts),
          as: :post
        )

      assert CommonQuery.get_query_binding_source(q, :post) === nil
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
      assert CommonQuery.get_query_binding_source(User, 1) === {"users", User}
    end
  end

  describe "get_query_binding_source/2 nil binding_alias path" do
    test "returns the from source when binding alias is nil" do
      q = from(u in User, as: :user)
      assert CommonQuery.get_query_binding_source(q, nil) === {"users", User}
    end
  end

  describe "has_subquery? detection paths" do
    test "get_query_source_expr traverses subquery to inner query" do
      inner = from(u in User)
      q = from(u in subquery(inner))
      assert CommonQuery.get_query_source(q) === {"users", User}
    end

    test "get_query_binding_source traverses association join through subquery" do
      inner =
        from(u in User,
          as: :user,
          join: p in assoc(u, :posts),
          as: :post
        )

      q = from(u in subquery(inner))
      assert CommonQuery.get_query_binding_source(q, :post) === {nil, EctoShorts.Schema.Post}
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

      assert CommonQuery.get_query_binding_source(q, :post) === nil
    end
  end

  describe "get_query_prefix/1 nil fallthrough" do
    test "returns nil for a bare schema module with no prefix" do
      assert CommonQuery.get_query_prefix(User) === nil
    end
  end

  describe "get_query_source/1 nil fallthrough" do
    test "returns nil for a query with only a subquery from and no inner table source" do
      inner = from(u in User, select: u.id)
      q = from(x in subquery(inner))
      assert CommonQuery.get_query_source(q) === {"users", User}
    end
  end

  describe "has_subquery? overloads" do
    test "has_subquery? is true for a query with subquery/1 from" do
      inner = from(u in User)
      q = from(u in subquery(inner))
      assert CommonQuery.get_query_source(q) === {"users", User}
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
      assert CommonQuery.get_query_binding_source(outer, :comment) === {nil, Comment}
    end
  end
end
