defmodule EctoShorts.CommonSchemaTest do
  use EctoShorts.DataCase, async: true

  alias Ecto.Changeset
  alias EctoShorts.CommonSchema
  alias EctoShorts.Schema.EnumSchema
  alias EctoShorts.Schema.Post
  alias EctoShorts.Schema.PostAbstract
  alias EctoShorts.Schema.PostAbstractHasSchemaPrefix
  alias EctoShorts.Schema.PostHasSchemaPrefix
  alias EctoShorts.Schema.User

  describe "get_schema_reflection/2" do
    test "returns schema information for a schema module" do
      assert CommonSchema.get_schema_reflection(Post, :primary_key) === [:id]
    end

    test "returns schema information for a source tuple" do
      assert CommonSchema.get_schema_reflection({"posts", PostAbstract}, :primary_key) === [
               :id
             ]
    end
  end

  describe "get_schema_reflection/3" do
    test "returns the field type for a schema module" do
      assert CommonSchema.get_schema_reflection(Post, :type, :id) === :id
    end

    test "returns the field type for a source tuple" do
      assert CommonSchema.get_schema_reflection({"posts", PostAbstract}, :type, :id) === :id
    end
  end

  describe "get_schema_prefix/1" do
    test "returns nil when the schema has no prefix" do
      assert CommonSchema.get_schema_prefix(Post) === nil
    end

    test "returns the prefix defined on the schema module" do
      assert CommonSchema.get_schema_prefix(PostHasSchemaPrefix) === "custom_schema_prefix"
    end

    test "returns the prefix from a source tuple" do
      assert CommonSchema.get_schema_prefix({"posts", PostAbstractHasSchemaPrefix}) ===
               "custom_schema_prefix"
    end

    test "returns the prefix from a schema struct" do
      assert CommonSchema.get_schema_prefix(%PostHasSchemaPrefix{}) === "custom_schema_prefix"
    end

    test "returns the prefix from an Ecto changeset" do
      # The changeset's data is a schema struct; its __meta__ holds the prefix
      changeset = PostHasSchemaPrefix.changeset(%PostHasSchemaPrefix{}, %{})
      assert CommonSchema.get_schema_prefix(changeset) === "custom_schema_prefix"
    end
  end

  describe "get_schema_source/1" do
    import Ecto.Query

    test "returns source tuple from schema struct" do
      assert CommonSchema.get_schema_source(%Post{}) === {"posts", Post}
    end

    test "returns source tuple from schema module" do
      assert CommonSchema.get_schema_source(Post) === {"posts", Post}
    end

    test "returns source tuple from explicit source tuple" do
      assert CommonSchema.get_schema_source({"custom_posts", PostAbstract}) ===
               {"custom_posts", PostAbstract}
    end

    test "returns source tuple from query" do
      q = from(u in "users")
      assert CommonSchema.get_schema_source(q) === {"users", nil}
    end

    test "returns source tuple from an Ecto changeset" do
      changeset = Post.changeset(%Post{}, %{})
      assert CommonSchema.get_schema_source(changeset) === {"posts", Post}
    end

    test "returns nil for an unrecognized value" do
      assert CommonSchema.get_schema_source("not_a_schema") === nil
      assert CommonSchema.get_schema_source(42) === nil
    end
  end

  describe "get_schema_metadata/1" do
    test "returns metadata from schema struct" do
      meta = CommonSchema.get_schema_metadata(%Post{})
      assert %Ecto.Schema.Metadata{} = meta
      assert meta.schema === Post
      assert meta.source === "posts"
    end

    test "returns metadata from changeset" do
      meta =
        %Post{}
        |> Post.changeset(%{title: "Hello"})
        |> CommonSchema.get_schema_metadata()

      assert %Ecto.Schema.Metadata{} = meta
      assert meta.schema === Post
      assert meta.source === "posts"
    end

    test "returns metadata for schema module" do
      meta = CommonSchema.get_schema_metadata(Post)
      assert %Ecto.Schema.Metadata{} = meta
      assert meta.schema === Post
      assert meta.source === "posts"
    end
  end

  describe "put_schema_metadata/1 (default attrs)" do
    test "returns schema struct unchanged when called with no attrs" do
      struct = CommonSchema.put_schema_metadata(%Post{})
      meta = CommonSchema.get_schema_metadata(struct)
      assert meta.schema === Post
    end
  end

  describe "put_schema_metadata/2" do
    test "updates metadata on schema struct" do
      struct =
        CommonSchema.put_schema_metadata(%Post{}, state: :loaded, source: "custom_posts")

      meta = CommonSchema.get_schema_metadata(struct)

      assert meta.state === :loaded
      assert meta.source === "custom_posts"
      assert meta.schema === Post
    end

    test "builds struct for schema module and updates metadata" do
      struct = CommonSchema.put_schema_metadata(Post, state: :loaded, source: "custom_posts")
      meta = CommonSchema.get_schema_metadata(struct)

      assert meta.state === :loaded
      assert meta.source === "custom_posts"
      assert meta.schema === Post
    end

    test "builds struct for source tuple and applies tuple source" do
      struct =
        CommonSchema.put_schema_metadata({"custom_posts", PostAbstract}, state: :loaded)

      meta = CommonSchema.get_schema_metadata(struct)

      assert meta.state === :loaded
      assert meta.source === "custom_posts"
      assert meta.schema === PostAbstract
    end
  end

  describe "build_struct/1" do
    test "builds a struct for a schema module" do
      assert %User{} = CommonSchema.build_struct(User)
    end

    test "builds a struct for a source tuple and sets metadata" do
      struct = CommonSchema.build_struct({"custom_posts", PostAbstract})
      meta = CommonSchema.get_schema_metadata(struct)

      assert meta.schema === PostAbstract
      assert meta.source === "custom_posts"
    end
  end

  describe "create_changeset/3" do
    test "builds a changeset from a schema module and params" do
      changeset = CommonSchema.create_changeset(Post, %{title: "Hello"}, [])

      assert %Changeset{} = changeset
      assert changeset.changes.title === "Hello"
    end

    test "builds a changeset from a schema struct and params" do
      changeset = CommonSchema.create_changeset(%Post{}, %{title: "Hello"}, [])

      assert %Changeset{} = changeset
      assert changeset.changes.title === "Hello"
    end

    test "builds a changeset from an existing changeset and new params" do
      base = Post.changeset(%Post{}, %{title: "Base"})

      changeset = CommonSchema.create_changeset(base, %{title: "Override"}, [])

      assert %Changeset{} = changeset
      assert changeset.changes.title === "Override"
    end

    test "builds a changeset from a source tuple and params" do
      assert %Changeset{data: %{__meta__: %{source: "custom_posts"}}} =
               CommonSchema.create_changeset(
                 {"custom_posts", PostAbstract},
                 %{title: "Hello"},
                 []
               )
    end

    test "builds a changeset from a source tuple and a schema struct" do
      assert %Changeset{data: %{__meta__: %{source: "custom_posts"}}} =
               CommonSchema.create_changeset(
                 {"custom_posts", PostAbstract},
                 %PostAbstract{},
                 []
               )
    end

    test "uses a 3-argument changeset callback from the options" do
      assert %Changeset{data: %Post{}, changes: %{title: "Custom"}} =
               CommonSchema.create_changeset(Post, %Post{}, %{title: "Hello"},
                 changeset: fn _schema, schema_data_or_changeset, params ->
                   schema_data_or_changeset
                   |> Changeset.change(params)
                   |> Changeset.put_change(:title, "Custom")
                 end
               )
    end

    test "uses a 2-argument changeset callback from the options" do
      assert %Changeset{data: %Post{}, changes: %{title: "Custom"}} =
               CommonSchema.create_changeset(Post, %Post{}, %{title: "Hello"},
                 changeset: fn schema_data_or_changeset, params ->
                   schema_data_or_changeset
                   |> Changeset.change(params)
                   |> Changeset.put_change(:title, "Custom")
                 end
               )
    end

    test "uses a 1-argument changeset callback from the options" do
      assert %Changeset{data: %Post{}, changes: %{title: "Custom"}} =
               CommonSchema.create_changeset(Post, %Post{}, %{title: "Hello"},
                 changeset: fn changeset ->
                   Changeset.put_change(changeset, :title, "Custom")
                 end
               )
    end

    test "raises when the changeset option is not a function" do
      assert_raise ArgumentError,
                   "Expected the value for option :changeset to be a 1-arity, 2-arity, or 3-arity function, got: :invalid",
                   fn ->
                     CommonSchema.create_changeset(Post, %{}, changeset: :invalid)
                   end
    end

    test "raises when the changeset callback does not return a changeset" do
      assert_raise RuntimeError,
                   "Expected an Ecto.Changeset, got: :not_a_changeset",
                   fn ->
                     CommonSchema.create_changeset(Post, %{},
                       changeset: fn _changeset -> :not_a_changeset end
                     )
                   end
    end
  end

  describe "to_query/1" do
    test "returns a query from a bare table name string" do
      q = CommonSchema.to_query("posts")
      assert %Ecto.Query{} = q
    end

    test "returns a query from a {table, nil} source tuple" do
      q = CommonSchema.to_query({"posts", nil})
      assert %Ecto.Query{} = q
    end

    test "returns a query from a {table, schema} source tuple" do
      q = CommonSchema.to_query({"custom_posts", Post})
      assert %Ecto.Query{} = q
    end

    test "returns the query unchanged when given an Ecto.Query" do
      q = from(p in Post)
      assert CommonSchema.to_query(q) === q
    end
  end

  describe "normalize_source/1" do
    test "normalizes a changeset to {source, schema}" do
      changeset = Post.changeset(%Post{}, %{})
      assert CommonSchema.normalize_source(changeset) === {"posts", Post}
    end

    test "normalizes a schema struct to {source, schema}" do
      assert CommonSchema.normalize_source(%Post{}) === {"posts", Post}
    end

    test "normalizes a {nil, schema} tuple" do
      assert CommonSchema.normalize_source({nil, Post}) === {nil, Post}
    end

    test "returns {nil, nil} for a fully-nil source tuple" do
      assert CommonSchema.normalize_source({nil, nil}) === {nil, nil}
    end

    test "get_schema returns nil for a {nil, nil} source" do
      assert CommonSchema.get_schema({nil, nil}) === nil
    end

    test "raises ArgumentError for an unrecognized source" do
      assert_raise ArgumentError, fn ->
        CommonSchema.normalize_source(123)
      end
    end
  end

  describe "put_schema_metadata/2 for non-struct source" do
    test "builds a struct and updates metadata when given a schema module" do
      struct = CommonSchema.put_schema_metadata(Post, source: "alt_posts")
      meta = CommonSchema.get_schema_metadata(struct)
      assert meta.source === "alt_posts"
      assert meta.schema === Post
    end

    test "builds a struct and updates metadata when given a source tuple" do
      struct = CommonSchema.put_schema_metadata({"alt_posts", PostAbstract}, state: :loaded)
      meta = CommonSchema.get_schema_metadata(struct)
      assert meta.source === "alt_posts"
      assert meta.state === :loaded
    end
  end

  describe "create_schema_struct/1" do
    test "builds a struct from a schema module (alias for build_struct/1)" do
      assert %Post{} = CommonSchema.create_schema_struct(Post)
    end
  end

  describe "create_changeset/4 extended paths (4-arg)" do
    test "applies {source, schema} tuple and struct directly in 4-arg form" do
      result =
        CommonSchema.create_changeset(
          {"custom_posts", PostAbstract},
          %PostAbstract{},
          %{title: "hello"},
          []
        )

      assert %Changeset{data: %{__meta__: %{source: "custom_posts"}}} = result
    end

    test "falls back to Changeset.change/2 when schema has no changeset/2 in 4-arg form" do
      result =
        CommonSchema.create_changeset(
          PostAbstract,
          %PostAbstract{},
          %{title: "fallback"},
          []
        )

      assert %Changeset{} = result
    end

    test "falls back to Changeset.change/2 in 1-arity callback when schema has no changeset/2" do
      result =
        CommonSchema.create_changeset(
          PostAbstract,
          %PostAbstract{},
          %{title: "via callback"},
          changeset: fn cs -> Changeset.put_change(cs, :title, "from callback") end
        )

      assert %Changeset{} = result
      assert result.changes.title === "from callback"
    end
  end

  describe "create_changeset/3 extended paths" do
    test "builds a changeset from a source tuple and an existing changeset" do
      base = Changeset.change(%PostAbstract{}, %{title: "Base"})

      result =
        CommonSchema.create_changeset(
          {"custom_posts", PostAbstract},
          base,
          []
        )

      assert %Changeset{data: %{__meta__: %{source: "custom_posts"}}} = result
    end

    test "builds a changeset from a schema module and an existing changeset" do
      base = Post.changeset(%Post{}, %{title: "Base"})

      result = CommonSchema.create_changeset(Post, base, [])

      assert %Changeset{} = result
    end

    test "builds a changeset from a schema module and a schema struct (3-arg form)" do
      result = CommonSchema.create_changeset(Post, %Post{}, [])
      assert %Changeset{} = result
    end

    test "builds a changeset from a source tuple and a changeset (4-arg form)" do
      base = Changeset.change(%PostAbstract{}, %{title: "hello"})

      result =
        CommonSchema.create_changeset(
          {"custom_posts", PostAbstract},
          base,
          %{title: "Override"},
          []
        )

      assert %Changeset{data: %{__meta__: %{source: "custom_posts"}}} = result
    end

    test "uses schema.changeset/2 when no :changeset opt and schema exports changeset/2" do
      result = CommonSchema.create_changeset(Post, %Post{}, %{title: "hello"}, [])
      assert result.changes.title === "hello"
    end

    test "falls back to Changeset.change/2 when schema has no changeset/2" do
      result = CommonSchema.create_changeset(PostAbstract, %PostAbstract{}, %{title: "hello"}, [])
      assert %Changeset{} = result
    end

    test "uses Changeset.change/2 in 4-arg form when schema truly has no changeset/2" do
      result = CommonSchema.create_changeset(EnumSchema, %EnumSchema{}, %{views: 1}, [])
      assert %Changeset{} = result
    end

    test "uses Changeset.change/2 in 1-arity callback when schema truly has no changeset/2" do
      result =
        CommonSchema.create_changeset(EnumSchema, %EnumSchema{}, %{views: 1},
          changeset: fn cs -> cs end
        )

      assert %Changeset{} = result
    end
  end
end
