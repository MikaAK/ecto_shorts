defmodule EctoShorts.QueryBuilder.SchemaTest do
  use ExUnit.Case, async: true
  doctest EctoShorts.QueryBuilder.Schema

  alias EctoShorts.QueryBuilder.Schema
  alias EctoShorts.Support.Schemas.{Comment, Post}

  describe "create_schema_filter: " do
    test "returns a query where record matches query field value" do
      query = Schema.create_schema_filter({:id, 1}, Post)

      assert %Ecto.Query{
        aliases: %{},
        from: %Ecto.Query.FromExpr{
          params: [],
          prefix: nil,
          source: {"posts", EctoShorts.Support.Schemas.Post}
        },
        joins: [],
        wheres: [
          %Ecto.Query.BooleanExpr{
            expr: {:==, [], [{{:., [], [{:&, [], [0]}, :id]}, [], []}, {:^, [], [0]}]},
            op: :and,
            params: [{1, {0, :id}}],
            subqueries: []
          }
        ]
      } = query
    end

    test "returns a query where record matches association params" do
      query = Schema.create_schema_filter({:comments, %{id: 1}}, Post)

      assert %Ecto.Query{
        aliases: %{
          ecto_shorts_comments: 1
        },
        from: %Ecto.Query.FromExpr{
          params: [],
          prefix: nil,
          source: {"posts", EctoShorts.Support.Schemas.Post}
        },
        joins: [
          %Ecto.Query.JoinExpr{
            as: :ecto_shorts_comments,
            assoc: {0, :comments},
            hints: [],
            ix: nil,
            on: %Ecto.Query.QueryExpr{
              expr: true,
              params: []
            },
            params: [],
            prefix: nil,
            qual: :inner,
            source: nil
          }
        ],
        wheres: [
          %Ecto.Query.BooleanExpr{
            expr: {:==, [], [{{:., [], [{:&, [], [1]}, :id]}, [], []}, {:^, [], [0]}]},
            op: :and,
            params: [{1, {1, :id}}],
            subqueries: []
          }
        ]
      } = query
    end

    test "returns query without changes when key is not a valid field" do
      expected_query = Post

      assert ^expected_query = Schema.create_schema_filter({:invalid_association, 1}, expected_query)
    end

    test "returns query that joins on has_many through association" do
      query = Schema.create_schema_filter({:authors, %{id: 1}}, Post)

      assert %Ecto.Query{
        aliases: %{
          ecto_shorts_authors: 1
        },
        from: %Ecto.Query.FromExpr{
          params: [],
          prefix: nil,
          source: {"posts", EctoShorts.Support.Schemas.Post}
        },
        joins: [
          %Ecto.Query.JoinExpr{
            as: :ecto_shorts_authors,
            assoc: {0, :authors},
            hints: [],
            ix: nil,
            on: %Ecto.Query.QueryExpr{
              expr: true,
              params: []
            },
            params: [],
            prefix: nil,
            qual: :inner,
            source: nil
          }
        ],
        wheres: [
          %Ecto.Query.BooleanExpr{
            expr: {:==, [], [{{:., [], [{:&, [], [1]}, :id]}, [], []}, {:^, [], [0]}]},
            op: :and,
            params: [{1, {1, :id}}],
            subqueries: []
          }
        ]
      } = query
    end

    test "returns query that matches on record by an array query field" do
      query = Schema.create_schema_filter({:tags, ["tag"]}, Comment)

      assert %Ecto.Query{
        aliases: %{},
        from: %Ecto.Query.FromExpr{
          params: [],
          prefix: nil,
          source: {"comments", EctoShorts.Support.Schemas.Comment}
        },
        joins: [],
        wheres: [
          %Ecto.Query.BooleanExpr{
            expr: {:==, [], [{{:., [], [{:&, [], [0]}, :tags]}, [], []}, {:^, [], [0]}]},
            op: :and,
            params: [{["tag"], {0, :tags}}],
            subqueries: []
          }
        ]
      } = query
    end
  end
end
