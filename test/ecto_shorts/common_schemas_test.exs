defmodule EctoShorts.CommonSchemasTest do
  use ExUnit.Case, async: true
  doctest EctoShorts.CommonSchemas

  alias EctoShorts.CommonSchemas
  alias EctoShorts.Support.MockSchemas.{
    BasicSchema,
    AbstractSchema,
    PrefixSchema
  }

  require Ecto.Query

  describe "get_schema_reflection/1: " do
    test "returns expected value given schema" do
      assert [:id, :body, :inserted_at, :updated_at] =
        EctoShorts.CommonSchemas.get_schema_reflection(BasicSchema, :fields)
    end

    test "returns expected value given {source, queryable}" do
      assert [:id, :body, :inserted_at, :updated_at] =
        EctoShorts.CommonSchemas.get_schema_reflection({"concrete_table", AbstractSchema}, :fields)
    end
  end

  describe "get_schema_reflection/2: " do
    test "returns expected value given schema" do
      assert :string =
        EctoShorts.CommonSchemas.get_schema_reflection(BasicSchema, :type, :body)
    end

    test "returns expected value given {source, queryable}" do
      assert :string =
        EctoShorts.CommonSchemas.get_schema_reflection(
          {"concrete_table", AbstractSchema},
          :type,
          :body
        )
    end
  end

  describe "get_loaded_struct/2: " do
    test "returns struct with loaded state and source when given a queryable" do
      assert %EctoShorts.Support.MockSchemas.BasicSchema{
        __meta__: %Ecto.Schema.Metadata{
          state: :loaded,
          source: "basic_schemas",
          prefix: nil,
          context: nil
        }
      } = EctoShorts.CommonSchemas.get_loaded_struct(BasicSchema)
    end

    test "returns struct with loaded state and source given {source, queryable}" do
      assert %EctoShorts.Support.MockSchemas.AbstractSchema{
        __meta__: %Ecto.Schema.Metadata{
          state: :loaded,
          source: "concrete_table",
          prefix: nil,
          context: nil
        }
      } = EctoShorts.CommonSchemas.get_loaded_struct({"concrete_table", AbstractSchema})
    end

    test "returns struct with loaded state, source, and prefix if @schema_prefix module attribute is set" do
      assert %EctoShorts.Support.MockSchemas.PrefixSchema{
        __meta__: %Ecto.Schema.Metadata{
          state: :loaded,
          source: "prefix_schemas",
          prefix: "mock_schema_prefix",
          context: nil
        }
      } = EctoShorts.CommonSchemas.get_loaded_struct(PrefixSchema)
    end

    test "returns struct with loaded state, source, and prefix given {source, queryable} if @schema_prefix module attribute is set" do
      assert %EctoShorts.Support.MockSchemas.PrefixSchema{
        __meta__: %Ecto.Schema.Metadata{
          state: :loaded,
          source: "concrete_table",
          prefix: "mock_schema_prefix",
          context: nil
        }
      } = EctoShorts.CommonSchemas.get_loaded_struct({"concrete_table", PrefixSchema})
    end
  end

  describe "get_schema_prefix/2: " do
    test "returns @schema_prefix module attribute value if set in schema" do
      assert "mock_schema_prefix" = CommonSchemas.get_schema_prefix(PrefixSchema)
    end

    test "returns nil if schema does not have @schema_prefix module attribute set" do
      assert nil === CommonSchemas.get_schema_prefix(AbstractSchema)
    end

    test "returns @schema_prefix module attribute value if set in schema and {source, queryable} tuple is given" do
      assert "mock_schema_prefix" = CommonSchemas.get_schema_prefix({"concrete_table", PrefixSchema})
    end

    test "returns nil if schema does not have @schema_prefix module attribute set and {source, queryable} tuple is given" do
      assert nil === CommonSchemas.get_schema_prefix({"concrete_table", AbstractSchema})
    end
  end

  describe "get_schema_source/2: " do
    test "returns source defined in schema" do
      assert "basic_schemas" = CommonSchemas.get_schema_source(BasicSchema)
    end

    test "returns source given {source, queryable}" do
      assert "concrete_table" = CommonSchemas.get_schema_source({"concrete_table", PrefixSchema})
    end
  end

  describe "get_schema_queryable/2: " do
    test "returns queryable module" do
      assert EctoShorts.Support.MockSchemas.BasicSchema =
        CommonSchemas.get_schema_queryable(BasicSchema)
    end

    test "returns queryable module given {source, queryable}" do
      assert EctoShorts.Support.MockSchemas.AbstractSchema =
        CommonSchemas.get_schema_queryable({"concrete_table", AbstractSchema})
    end
  end

  describe "get_schema_query/1: " do
    test "returns query struct" do
      query = Ecto.Query.from(AbstractSchema)

      assert ^query = CommonSchemas.get_schema_query(query)
    end

    test "returns queryable" do
      queryable = EctoShorts.CommonSchemasTest.MockSchema

      assert ^queryable = CommonSchemas.get_schema_query(queryable)
    end

    test "returns query where the from prefix is the value set by the @schema_prefix module attribute" do
      query = CommonSchemas.get_schema_query({"concrete_table", PrefixSchema})

      assert %Ecto.Query{
        from: %{
          prefix: "mock_schema_prefix",
          source: {"concrete_table", PrefixSchema}
        }
      } = query
    end
  end
end
