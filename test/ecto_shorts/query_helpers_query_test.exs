defmodule EctoShorts.QueryHelpersQueryTest do
  use ExUnit.Case, async: true
  doctest EctoShorts.QueryHelpers

  alias EctoShorts.QueryHelpers

  require Ecto.Query

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
      query =
        EctoShorts.QueryHelpersQueryTest.MockSchema
        |> Ecto.Query.from()
        |> QueryHelpers.build_schema_query()

      assert %Ecto.Query{
        from: %Ecto.Query.FromExpr{
          prefix: nil,
          source: {"mock_schemas", EctoShorts.QueryHelpersQueryTest.MockSchema}
        }
      } = query
    end

    test "can set query prefix" do
      query =
        EctoShorts.QueryHelpersQueryTest.MockSchema
        |> Ecto.Query.from()
        |> QueryHelpers.build_schema_query(query_prefix: "query_prefix")

      assert %Ecto.Query{
        from: %Ecto.Query.FromExpr{
          prefix: nil,
          source: {"mock_schemas", EctoShorts.QueryHelpersQueryTest.MockSchema}
        },
        prefix: "query_prefix"
      } = query
    end

    test "can set from prefix if schema does not have @schema_prefix module attribute" do
      # The option `:schema_prefix` does not apply when an `Ecto.Query`
      # is given because the prefix should be set beforehand.

      query =
        EctoShorts.QueryHelpersQueryTest.MockSchema
        |> Ecto.Query.from(prefix: "schema_prefix")
        |> QueryHelpers.build_schema_query()

      assert %Ecto.Query{
        from: %Ecto.Query.FromExpr{
          prefix: "schema_prefix",
          source: {"mock_schemas", EctoShorts.QueryHelpersQueryTest.MockSchema}
        }
      } = query
    end

    test "option :schema_prefix is not used on query" do
      query =
        EctoShorts.QueryHelpersQueryTest.MockSchema
        |> Ecto.Query.from()
        |> QueryHelpers.build_schema_query(schema_prefix: "schema_prefix")

      assert %Ecto.Query{
        from: %Ecto.Query.FromExpr{
          prefix: nil,
          source: {"mock_schemas", EctoShorts.QueryHelpersQueryTest.MockSchema}
        }
      } = query
    end
  end
end
