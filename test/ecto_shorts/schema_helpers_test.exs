defmodule EctoShorts.SchemaHelpersTest do
  use ExUnit.Case, async: true

  alias EctoShorts.SchemaHelpers
  alias EctoShorts.Schema.Post
  alias EctoShorts.Schema.Comment
  alias EctoShorts.Schema.User

  describe "get_related_schema/2" do
    test "returns nil when the schema is nil" do
      assert nil === SchemaHelpers.get_related_schema(nil, :comments)
    end

    test "follows a through association to find the final schema" do
      assert User = SchemaHelpers.get_related_schema(Post, :comments_authors)
    end

    test "returns nil when the association does not exist" do
      assert nil === SchemaHelpers.get_related_schema(Post, :does_not_exist)
    end
  end

  describe "schema_field_type/2" do
    test "returns the type of a field" do
      assert :string = SchemaHelpers.schema_field_type(Post, :title)
    end

    test "returns the array type for an array field" do
      assert {:array, :string} = SchemaHelpers.schema_field_type(Post, :tags)
    end
  end

  describe "association_not_loaded?/2" do
    test "returns true when association is not loaded" do
      post = %Post{}

      assert true = SchemaHelpers.association_not_loaded?(post, :comments)
    end

    test "returns false when association is loaded" do
      post = %Post{comments: []}

      assert false === SchemaHelpers.association_not_loaded?(post, :comments)
    end
  end

  describe "all_schema_struct?/1" do
    test "returns false for empty list" do
      assert false === SchemaHelpers.all_schema_struct?([])
    end

    test "returns false for empty map" do
      assert false === SchemaHelpers.all_schema_struct?(%{})
    end

    test "returns true when all items are schema structs" do
      assert true = SchemaHelpers.all_schema_struct?([%Post{}, %Comment{}])
    end

    test "returns false when mixed with plain maps" do
      assert false === SchemaHelpers.all_schema_struct?([%Post{}, %{id: 1}])
    end
  end

  describe "any_schema_struct?/1" do
    test "returns true when any item is a schema struct" do
      assert true = SchemaHelpers.any_schema_struct?([%Post{}, %{id: 1}])
    end

    test "returns false when no items are schema structs" do
      assert false === SchemaHelpers.any_schema_struct?([%{id: 1}])
    end
  end

  describe "schema_module?/1" do
    test "returns false when the value is not an atom" do
      assert false === SchemaHelpers.schema_module?("not_a_module")
      assert false === SchemaHelpers.schema_module?(123)
    end
  end

  describe "any_persisted?/1" do
    test "returns true when the map has a non-nil :id" do
      assert true = SchemaHelpers.any_persisted?(%{id: 42})
    end

    test "returns false when the map has a nil :id" do
      assert false === SchemaHelpers.any_persisted?(%{id: nil})
    end

    test "returns true when the map has a non-nil string id" do
      assert true = SchemaHelpers.any_persisted?(%{"id" => 99})
    end

    test "returns false when the map has a nil string id" do
      assert false === SchemaHelpers.any_persisted?(%{"id" => nil})
    end
  end
end
