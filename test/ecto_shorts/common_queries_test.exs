defmodule EctoShorts.CommonQueriesTest do
  use ExUnit.Case, async: true
  doctest EctoShorts.CommonQueries

  # alias EctoShorts.CommonQueries
  # alias EctoShorts.Schemas.Comment
  # alias EctoShorts.Schemas.Post

  # import Ecto.Query, only: [from: 2, subquery: 1]

  # describe "&get_from_expr" do
  #   test "returns FromExpr for a simple schema module" do
  #     assert %Ecto.Query.FromExpr{source: {"posts", EctoShorts.Schemas.Post}} =
  #              CommonQueries.get_from_expr(Post)
  #   end

  #   test "returns FromExpr for a schema source and module tuple" do
  #     assert %Ecto.Query.FromExpr{source: {"posts", EctoShorts.Schemas.Post}} =
  #              CommonQueries.get_from_expr({"posts", Post})
  #   end

  #   test "returns FromExpr for a basic inline query" do
  #     inner_query = from p in Post, where: p.published == true
  #     outer_query = from p in inner_query, as: :post

  #     assert %Ecto.Query.FromExpr{source: {"posts", EctoShorts.Schemas.Post}} =
  #              CommonQueries.get_from_expr(outer_query)
  #   end

  #   test "returns FromExpr from a subquery wrapper" do
  #     inner_query = from p in Post, where: p.published == true
  #     outer_query = from p in subquery(inner_query), as: :post

  #     assert %Ecto.Query.FromExpr{source: {"posts", EctoShorts.Schemas.Post}} =
  #              CommonQueries.get_from_expr(outer_query)
  #   end

  #   test "returns FromExpr after multiple levels of nested query wrapping" do
  #     first_query = from p in Post, where: p.published == true
  #     second_query = from p in subquery(first_query), as: :post
  #     third_query = from p in second_query, where: p.id in [1, 2, 3]

  #     assert %Ecto.Query.FromExpr{source: {"posts", EctoShorts.Schemas.Post}} =
  #              CommonQueries.get_from_expr(third_query)
  #   end

  #   test "returns FromExpr after subquerying a subquery" do
  #     first_query = from p in Post, where: p.published == true
  #     second_query = from p in subquery(first_query), as: :post
  #     third_query = from p in subquery(second_query), where: p.id in [1, 2, 3]

  #     assert %Ecto.Query.FromExpr{source: {"posts", EctoShorts.Schemas.Post}} =
  #              CommonQueries.get_from_expr(third_query)
  #   end
  # end

  # describe "has_source_subquery?/1" do
  #   test "returns false for a schema module" do
  #     refute CommonQueries.has_source_subquery?(Post)
  #   end

  #   test "returns true for a query that wraps a subquery once" do
  #     inner_query = from p in Post, where: p.published == true
  #     outer_query = from p in subquery(inner_query), as: :post

  #     assert CommonQueries.has_source_subquery?(outer_query)
  #   end

  #   test "returns true for a query that wraps a subquery inside another query" do
  #     first_query = from p in Post, where: p.published == true
  #     second_query = from p in subquery(first_query), as: :post
  #     third_query = from p in second_query, where: p.id in [1, 2, 3]

  #     assert CommonQueries.has_source_subquery?(third_query)
  #   end

  #   test "returns true for a query with multiple nested subqueries" do
  #     first_query = from p in Post, where: p.published == true
  #     second_query = from p in subquery(first_query), as: :post
  #     third_query = from p in subquery(second_query), where: p.id in [1, 2, 3]

  #     assert CommonQueries.has_source_subquery?(third_query)
  #   end
  # end

  # describe "get_source_subquery/1" do
  #   test "returns nil when source is a schema (not a subquery)" do
  #     assert nil === CommonQueries.get_source_subquery(Post)
  #   end

  #   test "returns the subquery when given a query directly wrapping a subquery" do
  #     # source query is the value being wrapped by a query
  #     source_query = from p in Post, where: p.published == true
  #     outer_query = from p in subquery(source_query), as: :post

  #     assert subquery(source_query) === CommonQueries.get_source_subquery(outer_query)
  #   end

  #   test "returns the original subquery when nested one level deeper" do
  #     # source query is the value being wrapped by a query
  #     source_query = from p in Post, where: p.published == true
  #     outer_query = from p in subquery(source_query), as: :post
  #     final_query = from p in outer_query, where: p.id in [1, 2, 3]

  #     assert subquery(source_query) === CommonQueries.get_source_subquery(final_query)
  #   end

  #   test "returns the original subquery when nested multiple layers deep" do
  #     base_query = from p in Post, where: p.published == true
  #     # source query is the value being wrapped by a query
  #     source_query = from p in subquery(base_query), as: :post
  #     outer_query = from p in subquery(source_query), where: p.id in [1, 2, 3]
  #     final_query = from p in outer_query, where: p.id in [1, 2, 3]

  #     assert subquery(source_query) === CommonQueries.get_source_subquery(final_query)
  #   end
  # end

  # describe "&find_binding_expr/2" do
  #   test "returns from expression when binding is nil" do
  #     query = from p in Post, where: p.published == true

  #     assert %Ecto.Query.FromExpr{
  #              source: {"posts", EctoShorts.Schemas.Post}
  #            } = CommonQueries.find_binding_expr(query, nil)
  #   end

  #   test "returns from expression for named binding on a subquery (binding assigned in outer query)" do
  #     base_query = from p in Post, where: p.published == true
  #     final_query = from p in subquery(base_query), as: :post, where: p.id == 1

  #     assert %Ecto.Query.FromExpr{
  #              source: %Ecto.SubQuery{query: ^base_query}
  #            } = CommonQueries.find_binding_expr(final_query, :post)
  #   end

  #   test "returns from expression for named binding from inner query (binding assigned in subquery)" do
  #     base_query = from p in Post, as: :post, where: p.published == true
  #     final_query = from p in subquery(base_query), where: p.id == 1

  #     assert %Ecto.Query.FromExpr{
  #              source: {"posts", EctoShorts.Schemas.Post},
  #              as: :post
  #            } = CommonQueries.find_binding_expr(final_query, :post)
  #   end

  #   test "returns join and from expressions for named binding with subquery join" do
  #     posts_query = from p in Post, where: p.published == true

  #     comments_query =
  #       from c in Comment,
  #         join: p in subquery(posts_query),
  #         join: u in User, on: u.id == c.user_id,
  #         as: :comments,
  #         on: c.post_id == p.id

  #     assert {
  #              %Ecto.Query.JoinExpr{
  #                qual: :inner,
  #                source: %Ecto.SubQuery{query: ^posts_query},
  #                assoc: nil
  #              },
  #              %Ecto.Query.FromExpr{
  #                source: {"comments", EctoShorts.Schemas.Comment}
  #              }
  #            } = CommonQueries.find_binding_expr(comments_query, :comments)
  #   end

  #   test "returns join and from expressions for named binding using schema join" do
  #     query =
  #       from p in Post,
  #         as: :post,
  #         join: c in Comment,
  #         as: :comments,
  #         on: c.post_id == p.id

  #     assert {
  #              %Ecto.Query.JoinExpr{
  #                qual: :inner,
  #                as: :comments,
  #                source: {nil, EctoShorts.Schemas.Comment},
  #                assoc: nil
  #              },
  #              %Ecto.Query.FromExpr{
  #                source: {"posts", EctoShorts.Schemas.Post},
  #                as: :post
  #              }
  #            } = CommonQueries.find_binding_expr(query, :comments)
  #   end

  #   test "returns join and from expressions for named binding using assoc/2 join" do
  #     query =
  #       from p in Post,
  #         as: :post,
  #         join: assoc(p, :comments),
  #         as: :comments,
  #         on: true

  #     assert {
  #              %Ecto.Query.JoinExpr{
  #                qual: :inner,
  #                as: :comments,
  #                source: nil,
  #                assoc: {0, :comments}
  #              },
  #              %Ecto.Query.FromExpr{
  #                source: {"posts", EctoShorts.Schemas.Post},
  #                as: :post
  #              }
  #            } = CommonQueries.find_binding_expr(query, :comments)
  #   end

  #   test "returns from expression for inner subquery binding" do
  #     posts_query = from p in Post, as: :post, where: p.published == true, join: c in Comment, as: :foo, on: c.post_id == p.id

  #     comments_query =
  #       from c in Comment,
  #         join: p in subquery(posts_query),
  #         as: :comments,
  #         on: c.post_id in [1] and p.post_id in [1]

  #     assert %Ecto.Query.FromExpr{
  #              source: {"posts", EctoShorts.Schemas.Post},
  #              as: :post
  #            } = CommonQueries.find_binding_expr(comments_query, :post)
  #   end

  #   test "" do
  #     # #Ecto.Query<from c0 in SchemasPG.Directory.CompanyProfileReviewGroup,
  #     # join: p1 in assoc(c0, :project), as: :ecto_shorts_project,
  #     # join: p2 in assoc(p1, :project_members), as: :ecto_shorts_project_members,
  #     # where: c0.id == ^1>

  #     query =
  #       from p in Post,
  #         join: c in assoc(p, :comments), as: :comments, on: c.post_id == p.id,
  #         join: a in assoc(c, :author), as: :author, on: c.author_id == a.id,
  #         join: x in assoc(c, :author), as: :test, on: x.body == "foo",
  #         where: c.id == 1

  #     assert {join_expr, from_expr} = CommonQueries.find_binding_expr(query, :author)

  #     assert %Ecto.Query.JoinExpr{
  #       qual: :inner,
  #       as: :author,
  #       source: nil,
  #       assoc: {1, :author}
  #     } = join_expr

  #     assert %Ecto.Query.FromExpr{
  #       source: {"comments", Comment},
  #       as: :comments
  #     } = from_expr
  #   end
  # end

  # describe "&find_binding_expr_source_and_schema/2" do
  #   test "returns source for a direct schema module" do
  #     assert {"posts", EctoShorts.Schemas.Post} =
  #              CommonQueries.find_binding_expr_source_and_schema(Post, nil)
  #   end

  #   test "resolves source from a named binding inside a subquery" do
  #     base_query = from p in Post, as: :post, where: p.published == true
  #     final_query = from p in subquery(base_query), where: p.id == 1

  #     assert {"posts", EctoShorts.Schemas.Post} =
  #              CommonQueries.find_binding_expr_source_and_schema(final_query, :post)
  #   end

  #   test "resolves source for an assoc join with a named binding" do
  #     query =
  #       from p in Post,
  #         as: :post,
  #         join: assoc(p, :comments),
  #         as: :comments,
  #         on: true

  #     assert {"comments", EctoShorts.Schemas.Comment} =
  #              CommonQueries.find_binding_expr_source_and_schema(query, :comments)
  #   end

  #   test "resolves source from a join into a subquery with a named binding" do
  #     posts_query = from p in Post, where: p.published == true

  #     comments_query =
  #       from c in Comment,
  #         join: p in subquery(posts_query),
  #         as: :comments,
  #         on: c.post_id == p.id

  #     assert {"posts", EctoShorts.Schemas.Post} =
  #              CommonQueries.find_binding_expr_source_and_schema(comments_query, :comments)
  #   end

  #   test "resolves source from a direct named join without subqueries" do
  #     query =
  #       from p in Post,
  #         as: :post,
  #         join: c in Comment,
  #         as: :comments,
  #         on: c.post_id == p.id

  #     assert {"comments", EctoShorts.Schemas.Comment} =
  #              CommonQueries.find_binding_expr_source_and_schema(query, :comments)
  #   end
  # end
end
