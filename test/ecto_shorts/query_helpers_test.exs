defmodule EctoShorts.QueryHelpersTest do
  use ExUnit.Case, async: true
  doctest EctoShorts.QueryHelpers

  alias EctoShorts.QueryHelpers

  defmodule MockSchema do
    @moduledoc false
    use Ecto.Schema
    import Ecto.Changeset

    schema "mock_schemas" do
      field :body, :string

      timestamps()
    end

    @available_attributes [:body]

    def changeset(model_or_changeset, attrs \\ %{}) do
      cast(model_or_changeset, attrs, @available_attributes)
    end
  end

  defmodule MockSchemaWithPrefix do
    @moduledoc false
    use Ecto.Schema
    import Ecto.Changeset

    @schema_prefix "mock_schema_prefix"

    schema "mock_schemas" do
      field :body, :string

      timestamps()
    end

    @available_attributes [:body]

    def changeset(model_or_changeset, attrs \\ %{}) do
      cast(model_or_changeset, attrs, @available_attributes)
    end
  end

  describe "build_schema_query/2: " do
    test "can set source" do
      query = QueryHelpers.build_schema_query(EctoShorts.QueryHelpersTest.MockSchema)

      assert %Ecto.Query{
        from: %Ecto.Query.FromExpr{
          prefix: nil,
          source: {"mock_schemas", EctoShorts.QueryHelpersTest.MockSchema}
        }
      } = query
    end

    test "can set query prefix" do
      query = QueryHelpers.build_schema_query(EctoShorts.QueryHelpersTest.MockSchema, query_prefix: "query_prefix")

      assert %Ecto.Query{
        from: %Ecto.Query.FromExpr{
          prefix: nil,
          source: {"mock_schemas", EctoShorts.QueryHelpersTest.MockSchema}
        },
        prefix: "query_prefix"
      } = query
    end

    test "can set from prefix if schema does not have @schema_prefix module attribute" do
      query = QueryHelpers.build_schema_query(EctoShorts.QueryHelpersTest.MockSchema, schema_prefix: "schema_prefix")

      assert %Ecto.Query{
        from: %Ecto.Query.FromExpr{
          prefix: "schema_prefix",
          source: {"mock_schemas", EctoShorts.QueryHelpersTest.MockSchema}
        }
      } = query
    end

    test "raises when setting the from prefix if schema has @schema_prefix module attribute" do
      expected_error_message = ~r|can't apply prefix (.*) `from` is already prefixed to .*|

      func =
        fn ->
          QueryHelpers.build_schema_query(EctoShorts.QueryHelpersTest.MockSchemaWithPrefix, schema_prefix: "schema_prefix")
        end

      assert_raise Ecto.Query.CompileError, expected_error_message, func
    end
  end
end
