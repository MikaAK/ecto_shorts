defmodule EctoShorts.QueryHelpersAbstractSchemaTest do
  use ExUnit.Case, async: true
  doctest EctoShorts.QueryHelpers

  alias EctoShorts.QueryHelpers
  alias EctoShorts.Support.MockSchemas.{
    AbstractSchema,
    PrefixSchema
  }

  describe "build_schema_query/2: " do
    test "can set source given" do
      query = QueryHelpers.build_schema_query({"concrete_table", AbstractSchema})

      assert %Ecto.Query{
        from: %Ecto.Query.FromExpr{
          prefix: nil,
          source: {"concrete_table", AbstractSchema}
        }
      } = query
    end

    test "can set query prefix" do
      query =
        QueryHelpers.build_schema_query(
          {"concrete_table", AbstractSchema},
          query_prefix: "query_prefix"
        )

      assert %Ecto.Query{
        from: %Ecto.Query.FromExpr{
          prefix: nil,
          source: {"concrete_table", AbstractSchema}
        },
        prefix: "query_prefix"
      } = query
    end

    test "can set from prefix if schema does not have @schema_prefix module attribute" do
      query =
        QueryHelpers.build_schema_query(
          {"concrete_table", AbstractSchema},
          schema_prefix: "schema_prefix"
        )

      assert %Ecto.Query{
        from: %Ecto.Query.FromExpr{
          prefix: "schema_prefix",
          source: {"concrete_table", AbstractSchema}
        }
      } = query
    end

    test "raises when setting the from prefix if schema has @schema_prefix module attribute" do
      expected_error_message = "can't apply prefix `\"new_prefix\"`, `from` is already prefixed to `\"mock_schema_prefix\"`"

      func =
        fn ->
          QueryHelpers.build_schema_query(
            {"concrete_table", PrefixSchema},
            schema_prefix: "new_prefix"
          )
        end

      assert_raise Ecto.Query.CompileError, expected_error_message, func
    end
  end
end
