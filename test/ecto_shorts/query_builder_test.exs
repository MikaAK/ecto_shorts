defmodule EctoShorts.QueryBuilderTest do
  use EctoShorts.DataCase

  require Ecto.Query

  doctest EctoShorts.QueryBuilder

  alias Ecto.Query
  alias EctoShorts.QueryBuilder
  alias EctoShorts.Support.Schemas.Comment
  alias EctoShorts.Support.Repo

  describe "create_schema_filter: " do
    test "returns the result of the ecto query dsl" do
      comment =
        %Comment{}
        |> Comment.changeset()
        |> Repo.insert!()

      comment_id = comment.id

      ecto_query = Query.from(c in Comment, where: c.id == ^comment_id)

      builder_query =
        QueryBuilder.create_schema_filter(QueryBuilder.Schema, Comment, :id, comment_id)

      assert Repo.one(ecto_query) === Repo.one(builder_query)
    end
  end
end
