defmodule EctoShorts.QueryHelpersQueryTest do
  use ExUnit.Case, async: true
  doctest EctoShorts.QueryHelpers

  alias EctoShorts.QueryHelpers
  alias EctoShorts.Support.MockSchemas.BasicSchema

  require Ecto.Query

  describe "build_schema_query/2: " do
    test "can set source" do
      query =
        BasicSchema
        |> Ecto.Query.from()
        |> QueryHelpers.build_schema_query()

      assert %Ecto.Query{
        from: %Ecto.Query.FromExpr{
          prefix: nil,
          source: {"basic_schemas", BasicSchema}
        }
      } = query
    end

    test "can set query prefix" do
      query =
        BasicSchema
        |> Ecto.Query.from()
        |> QueryHelpers.build_schema_query(query_prefix: "query_prefix")

      assert %Ecto.Query{
        from: %Ecto.Query.FromExpr{
          prefix: nil,
          source: {"basic_schemas", BasicSchema}
        },
        prefix: "query_prefix"
      } = query
    end

    test "can set from prefix if schema does not have @schema_prefix module attribute" do
      # The option `:schema_prefix` does not apply when an `Ecto.Query`
      # is given because the prefix should be set beforehand.

      query =
        BasicSchema
        |> Ecto.Query.from(prefix: "schema_prefix")
        |> QueryHelpers.build_schema_query()

      assert %Ecto.Query{
        from: %Ecto.Query.FromExpr{
          prefix: "schema_prefix",
          source: {"basic_schemas", BasicSchema}
        }
      } = query
    end

    test "option :schema_prefix is not used on query" do
      query =
        BasicSchema
        |> Ecto.Query.from()
        |> QueryHelpers.build_schema_query(schema_prefix: "schema_prefix")

      assert %Ecto.Query{
        from: %Ecto.Query.FromExpr{
          prefix: nil,
          source: {"basic_schemas", BasicSchema}
        }
      } = query
    end
  end
end
