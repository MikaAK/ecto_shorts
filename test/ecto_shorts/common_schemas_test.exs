defmodule EctoShorts.CommonSchemasTest do
  use ExUnit.Case, async: true
  doctest EctoShorts.CommonSchemas

  alias Ecto.Schema.Metadata
  alias EctoShorts.CommonSchemas

  alias EctoShorts.Schemas.{
    Post,
    PostHasSchemaPrefix,
    PostAbstract,
    PostAbstractHasSchemaPrefix
  }

  import Ecto.Query, only: [from: 2]

  describe "get_schema_reflection/2" do
    test "when given a schema module, returns the expected value" do
      assert [:id] = CommonSchemas.get_schema_reflection(Post, :primary_key)
    end

    test "when given an {source, schema} tuple, returns the expected value" do
      assert [:id] = CommonSchemas.get_schema_reflection({"posts", PostAbstract}, :primary_key)
    end
  end

  describe "get_schema_reflection/3" do
    test "when given a schema module, returns the expected type" do
      assert :id = CommonSchemas.get_schema_reflection(Post, :type, :id)
    end

    test "when given an {source, schema} tuple, returns the expected type" do
      assert :id = CommonSchemas.get_schema_reflection({"posts", PostAbstract}, :type, :id)
    end
  end

  describe "get_schema_prefix/1" do
    test "when given a schema module, returns the @schema_prefix value" do
      assert "custom_schema_prefix" = CommonSchemas.get_schema_prefix(PostHasSchemaPrefix)
    end

    test "when given an {source, schema} tuple, returns the @schema_prefix value" do
      assert "custom_schema_prefix" =
               CommonSchemas.get_schema_prefix({"posts", PostAbstractHasSchemaPrefix})
    end
  end

  describe "get_schema_source/1" do
    test "when given a schema module, returns database table name" do
      assert {"posts", PostHasSchemaPrefix} =
               CommonSchemas.get_schema_source(PostHasSchemaPrefix)
    end

    test "when given an {source, schema} tuple, returns database table name" do
      assert {"posts", PostAbstractHasSchemaPrefix} =
               CommonSchemas.get_schema_source({"posts", PostAbstractHasSchemaPrefix})
    end

    test "when given an ecto query, returns {binary, queryable}" do
      query = from p in PostHasSchemaPrefix, as: :posts

      assert {"posts", PostHasSchemaPrefix} = CommonSchemas.get_schema_source(query)
    end
  end

  describe "get_schema_metadata/1" do
    test "returns the schema's full metadata struct" do
      assert %Metadata{prefix: "custom_schema_prefix"} =
               CommonSchemas.get_schema_metadata(%PostHasSchemaPrefix{})
    end
  end

  describe "get_schema_metadata/2" do
    test "returns the value for the specified metadata key" do
      assert "custom_schema_prefix" =
               CommonSchemas.get_schema_metadata(%PostHasSchemaPrefix{}, :prefix)
    end
  end

  describe "put_schema_metadata/2" do
    test "updates the schema's metadata" do
      assert %EctoShorts.Schemas.Post{
               __meta__: %Metadata{prefix: "test_prefix"}
             } = CommonSchemas.put_schema_metadata(%Post{}, prefix: "test_prefix")
    end
  end

  describe "create_struct/1" do
    test "when given a schema module, returns a struct" do
      assert %Post{__meta__: %Metadata{source: "posts"}} =
               CommonSchemas.create_struct(Post)
    end

    test "when given a {source, schema} tuple, returns a struct" do
      assert %PostAbstract{__meta__: %Metadata{source: "custom_source"}} =
               CommonSchemas.create_struct({"custom_source", PostAbstract})
    end
  end
end
