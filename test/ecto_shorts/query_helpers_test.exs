defmodule EctoShorts.QueryHelpersTest do
  use ExUnit.Case, async: true
  doctest EctoShorts.QueryHelpers

  alias EctoShorts.QueryHelpers
  alias EctoShorts.Support.MockSchemas.{
    BasicSchema,
    PrefixSchema
  }

  describe "build_schema_query/2: " do
    test "can set source" do
      query = QueryHelpers.build_schema_query(BasicSchema)

      assert %Ecto.Query{
        from: %Ecto.Query.FromExpr{
          prefix: nil,
          source: {"basic_schemas", BasicSchema}
        }
      } = query
    end

    test "can set query prefix" do
      query = QueryHelpers.build_schema_query(BasicSchema, query_prefix: "query_prefix")

      assert %Ecto.Query{
        from: %Ecto.Query.FromExpr{
          prefix: nil,
          source: {"basic_schemas", BasicSchema}
        },
        prefix: "query_prefix"
      } = query
    end

    test "can set from prefix if schema does not have @schema_prefix module attribute" do
      query = QueryHelpers.build_schema_query(BasicSchema, schema_prefix: "schema_prefix")

      assert %Ecto.Query{
        from: %Ecto.Query.FromExpr{
          prefix: "schema_prefix",
          source: {"basic_schemas", BasicSchema}
        }
      } = query
    end

    test "raises when setting the from prefix if schema has @schema_prefix module attribute" do
      expected_error_message = ~r|can't apply prefix (.*) `from` is already prefixed to .*|

      func =
        fn ->
          QueryHelpers.build_schema_query(PrefixSchema, schema_prefix: "schema_prefix")
        end

      assert_raise Ecto.Query.CompileError, expected_error_message, func
    end
  end
end
