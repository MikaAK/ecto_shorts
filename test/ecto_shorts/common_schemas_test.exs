defmodule EctoShorts.CommonSchemasTest do
  use ExUnit.Case, async: true
  doctest EctoShorts.CommonSchemas

  alias EctoShorts.CommonSchemas

  require Ecto.Query

  defmodule MockSchema do
    @moduledoc false
    use Ecto.Schema
    import Ecto.Changeset

    schema "mock_schemas" do
      field :body, :string

      timestamps()
    end

    @available_fields [:body]

    def changeset(model_or_changeset, attrs \\ %{}) do
      cast(model_or_changeset, attrs, @available_fields)
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

    @available_fields [:body]

    def changeset(model_or_changeset, attrs \\ %{}) do
      cast(model_or_changeset, attrs, @available_fields)
    end
  end

  describe "get_schema_reflection/1: " do
    test "returns expected value given schema" do
      assert [:id, :body, :inserted_at, :updated_at] =
        EctoShorts.CommonSchemas.get_schema_reflection(EctoShorts.CommonSchemasTest.MockSchema, :fields)
    end

    test "returns expected value given {source, queryable}" do
      assert [:id, :body, :inserted_at, :updated_at] =
        EctoShorts.CommonSchemas.get_schema_reflection({"mock_schemas", EctoShorts.CommonSchemasTest.MockSchema}, :fields)
    end
  end

  describe "get_schema_reflection/2: " do
    test "returns expected value given schema" do
      assert :string =
        EctoShorts.CommonSchemas.get_schema_reflection(
          EctoShorts.CommonSchemasTest.MockSchema,
          :type,
          :body
        )
    end

    test "returns expected value given {source, queryable}" do
      assert :string =
        EctoShorts.CommonSchemas.get_schema_reflection(
          {"mock_schemas", EctoShorts.CommonSchemasTest.MockSchema},
          :type,
          :body
        )
    end
  end

  describe "get_loaded_struct/2: " do
    test "returns struct with loaded state and source" do
      assert %EctoShorts.CommonSchemasTest.MockSchema{
        __meta__: %Ecto.Schema.Metadata{
          state: :loaded,
          source: "mock_schemas",
          prefix: nil,
          context: nil
        }
      } = EctoShorts.CommonSchemas.get_loaded_struct(EctoShorts.CommonSchemasTest.MockSchema)
    end

    test "returns struct with loaded state, source, and prefix if @schema_prefix module attribute is set" do
      assert %EctoShorts.CommonSchemasTest.MockSchemaWithPrefix{
        __meta__: %Ecto.Schema.Metadata{
          state: :loaded,
          source: "mock_schemas",
          prefix: "mock_schema_prefix",
          context: nil
        }
      } = EctoShorts.CommonSchemas.get_loaded_struct(EctoShorts.CommonSchemasTest.MockSchemaWithPrefix)
    end

    test "returns struct with loaded state and source given {source, queryable}" do
      assert %EctoShorts.CommonSchemasTest.MockSchema{
        __meta__: %Ecto.Schema.Metadata{
          state: :loaded,
          source: "mock_schemas",
          prefix: nil,
          context: nil
        }
      } =
        EctoShorts.CommonSchemas.get_loaded_struct(
          {"mock_schemas", EctoShorts.CommonSchemasTest.MockSchema}
        )
    end

    test "returns struct with loaded state, source, and prefix given {source, queryable} if @schema_prefix module attribute is set" do
      assert %EctoShorts.CommonSchemasTest.MockSchemaWithPrefix{
        __meta__: %Ecto.Schema.Metadata{
          state: :loaded,
          source: "mock_schemas",
          prefix: "mock_schema_prefix",
          context: nil
        }
      } =
        EctoShorts.CommonSchemas.get_loaded_struct(
          {"mock_schemas", EctoShorts.CommonSchemasTest.MockSchemaWithPrefix}
        )
    end
  end

  describe "get_schema_prefix/2: " do
    test "returns @schema_prefix module attribute value if set in schema" do
      assert "mock_schema_prefix" =
        CommonSchemas.get_schema_prefix(EctoShorts.CommonSchemasTest.MockSchemaWithPrefix)
    end

    test "returns nil if schema does not have @schema_prefix module attribute set" do
      assert nil === CommonSchemas.get_schema_prefix(EctoShorts.CommonSchemasTest.MockSchema)
    end

    test "returns @schema_prefix module attribute value if set in schema and {source, queryable} tuple is given" do
      assert "mock_schema_prefix" =
        CommonSchemas.get_schema_prefix({"mock_schemas", EctoShorts.CommonSchemasTest.MockSchemaWithPrefix})
    end

    test "returns nil if schema does not have @schema_prefix module attribute set and {source, queryable} tuple is given" do
      assert nil === CommonSchemas.get_schema_prefix({"mock_schemas", EctoShorts.CommonSchemasTest.MockSchema})
    end
  end

  describe "get_schema_source/2: " do
    test "returns source defined in schema" do
      assert "mock_schemas" =
        CommonSchemas.get_schema_source(EctoShorts.CommonSchemasTest.MockSchema)
    end

    test "returns schema given {source, queryable} tuple" do
      assert "custom_source" =
        CommonSchemas.get_schema_source({"custom_source", EctoShorts.CommonSchemasTest.MockSchema})
    end
  end

  describe "get_schema_queryable/2: " do
    test "returns schema" do
      assert EctoShorts.CommonSchemasTest.MockSchema =
        CommonSchemas.get_schema_queryable(EctoShorts.CommonSchemasTest.MockSchema)
    end

    test "returns schema given {source, queryable} tuple" do
      assert EctoShorts.CommonSchemasTest.MockSchema =
        CommonSchemas.get_schema_queryable({"mock_schemas", EctoShorts.CommonSchemasTest.MockSchema})
    end
  end

  describe "get_schema_query/1: " do
    test "returns the given ecto query" do
      query = Ecto.Query.from(EctoShorts.CommonSchemasTest.MockSchema)

      assert ^query = CommonSchemas.get_schema_query(query)
    end

    test "returns query where the from prefix is the value set by the @schema_prefix module attribute" do
      query = CommonSchemas.get_schema_query(EctoShorts.CommonSchemasTest.MockSchemaWithPrefix)

      assert %Ecto.Query{
        from: %{
          prefix: "mock_schema_prefix",
          source: {"mock_schemas", EctoShorts.CommonSchemasTest.MockSchemaWithPrefix}
        }
      } = query
    end

    test "returns query given {source, queryable} where the from prefix is the value set by the @schema_prefix module attribute" do
      query = CommonSchemas.get_schema_query(EctoShorts.CommonSchemasTest.MockSchemaWithPrefix)

      assert %Ecto.Query{
        from: %{
          prefix: "mock_schema_prefix",
          source: {"mock_schemas", EctoShorts.CommonSchemasTest.MockSchemaWithPrefix}
        }
      } = query
    end
  end
end
