defmodule EctoShorts.CommonParamsTest do
  use ExUnit.Case, async: true

  alias EctoShorts.CommonParams
  alias EctoShorts.Schema.Post

  describe "convert_to_update_params/3 with schema module source" do
    test "groups operations by type and adds an updated_at timestamp" do
      updates =
        CommonParams.convert_to_update_params(Post, %{
          title: "Hello",
          views: [inc: 1],
          tags: [push: "elixir"]
        })

      assert [inc: inc_ops, push: push_ops, set: set_ops] = updates

      assert inc_ops === [views: 1]
      assert push_ops === [tags: "elixir"]

      assert Keyword.fetch!(set_ops, :title) === "Hello"
      assert %NaiveDateTime{} = Keyword.fetch!(set_ops, :updated_at)
    end

    test "raises when using :push on a field that is not an array" do
      assert_raise ArgumentError, fn ->
        CommonParams.convert_to_update_params(Post, %{views: [push: "oops"]})
      end
    end

    test "skips the updated_at timestamp when the option is false" do
      updates =
        CommonParams.convert_to_update_params(
          Post,
          %{title: "Hello"},
          updated_at: false
        )

      assert [set: set_ops] = updates
      assert set_ops === [title: "Hello"]
    end

    test "skips the updated_at timestamp when the source option is false" do
      updates =
        CommonParams.convert_to_update_params(
          Post,
          %{title: "Hello"},
          updated_at_source: false
        )

      assert [set: set_ops] = updates
      assert set_ops === [title: "Hello"]
    end
  end

  describe "convert_to_update_params/3 update operation variants" do
    test "accepts an explicit set operation for a field value" do
      updates = CommonParams.convert_to_update_params(Post, %{title: [set: "Explicit"]})

      assert [set: set_ops] = updates
      assert Keyword.fetch!(set_ops, :title) === "Explicit"
    end

    test "accepts a list of operations on the same field" do
      updates =
        CommonParams.convert_to_update_params(Post, %{
          tags: [push: "new_tag", pull: "old_tag"]
        })

      assert Keyword.has_key?(updates, :pull)
      assert Keyword.has_key?(updates, :push)
    end

    test "raises when incrementing with a non-integer value" do
      assert_raise ArgumentError, ~r/Expected value for key .* to be an integer/, fn ->
        CommonParams.convert_to_update_params(Post, %{views: [inc: "bad"]})
      end
    end

    test "raises when incrementing a non-integer field" do
      assert_raise ArgumentError, ~r/is not a type of `:integer`/, fn ->
        CommonParams.convert_to_update_params(Post, %{title: [inc: 1]})
      end
    end

    test "casts string values for set and inc update operations" do
      updates =
        CommonParams.convert_to_update_params(Post, %{
          views: [inc: "2"],
          id: "1"
        })

      assert Keyword.fetch!(updates, :inc) === [views: 2]
      assert Keyword.fetch!(updates, :set)[:id] === 1
    end
  end

  describe "build_on_conflict_options/3" do
    test "returns only the conflict target when on_conflict_replace is :none" do
      inserts = [%{id: 1, title: "Hello"}]

      opts =
        CommonParams.build_on_conflict_options(Post, inserts, on_conflict_replace: :none)

      assert Keyword.fetch!(opts, :conflict_target) === [:id]
      refute Keyword.has_key?(opts, :on_conflict)
    end

    test "raises when on_conflict_replace has an invalid value" do
      inserts = [%{id: 1, title: "Hello"}]

      assert_raise ArgumentError, ~r/Expected :on_conflict_replace/, fn ->
        CommonParams.build_on_conflict_options(Post, inserts, on_conflict_replace: :bad)
      end
    end
  end

  describe "convert_to_update_params/3 with schemaless sources" do
    test "allows any key when the source is nil" do
      updates =
        CommonParams.convert_to_update_params(nil, %{
          made_up_field: "value",
          updated_at: ~U[2026-01-01 00:00:00Z]
        })

      assert [set: set_ops] = updates

      assert Keyword.fetch!(set_ops, :made_up_field) === "value"
      assert %DateTime{} = Keyword.fetch!(set_ops, :updated_at)
    end

    test "allows any key when the source is a table name string" do
      updates =
        CommonParams.convert_to_update_params("posts", %{
          made_up_field: "value",
          updated_at: ~U[2026-01-01 00:00:00Z]
        })

      assert [set: set_ops] = updates

      assert Keyword.fetch!(set_ops, :made_up_field) === "value"
      assert %DateTime{} = Keyword.fetch!(set_ops, :updated_at)
    end

    test "allows any key when the source is a table-nil tuple" do
      updates =
        CommonParams.convert_to_update_params({"posts", nil}, %{
          made_up_field: "value",
          updated_at: ~U[2026-01-01 00:00:00Z]
        })

      assert [set: set_ops] = updates

      assert Keyword.fetch!(set_ops, :made_up_field) === "value"
      assert %DateTime{} = Keyword.fetch!(set_ops, :updated_at)
    end

    test "filters out unknown keys when the source includes a schema module" do
      updates =
        CommonParams.convert_to_update_params({"posts", Post}, %{
          title: "Hello",
          made_up_field: "value"
        })

      assert [set: set_ops] = updates

      assert Keyword.fetch!(set_ops, :title) === "Hello"
      refute Keyword.has_key?(set_ops, :made_up_field)
    end
  end

  describe "convert_to_insert_params/3" do
    test "builds insert maps and adds timestamps by default" do
      assert {:ok, insert_maps} =
               CommonParams.convert_to_insert_params(Post, [%{title: "Hello"}], validate: false)

      assert [insert_map] = insert_maps

      assert insert_map.title === "Hello"
      assert %NaiveDateTime{} = insert_map.inserted_at
      assert %NaiveDateTime{} = insert_map.updated_at
    end

    test "replaces matching values with placeholder references" do
      placeholders = %{permalink: "__PLACEHOLDER__"}

      assert {:ok, insert_maps} =
               CommonParams.convert_to_insert_params(
                 Post,
                 [%{title: "Hello", permalink: "__PLACEHOLDER__"}],
                 validate: false,
                 placeholders: placeholders
               )

      assert [%{permalink: {:placeholder, :permalink}}] = insert_maps
    end

    test "returns a changeset error when validation fails" do
      assert {:error, [changeset]} =
               CommonParams.convert_to_insert_params(Post, [%{views: "oops"}])

      assert %Ecto.Changeset{valid?: false} = changeset
      assert Keyword.has_key?(changeset.errors, :views)
    end
  end

  describe "convert_to_insert_params/3 with struct entry" do
    test "accepts a schema struct as an insert entry" do
      struct = %Post{title: "From Struct", published: true}

      assert {:ok, [insert_map]} =
               CommonParams.convert_to_insert_params(Post, [struct], validate: false)

      assert insert_map.title === "From Struct"
      assert insert_map.published === true
    end

    test "accepts a struct-and-params tuple as an insert entry" do
      struct = %Post{title: "Original"}
      params = %{title: "Overridden"}

      assert {:ok, [insert_map]} =
               CommonParams.convert_to_insert_params(Post, [{struct, params}], validate: false)

      assert insert_map.title === "Overridden"
    end

    test "accepts an Ecto changeset as an insert entry" do
      changeset = Post.changeset(%Post{}, %{title: "From Changeset"})

      assert {:ok, [insert_map]} =
               CommonParams.convert_to_insert_params(Post, [changeset])

      assert insert_map.title === "From Changeset"
    end

    test "accepts a keyword list as an insert entry" do
      assert {:ok, [insert_map]} =
               CommonParams.convert_to_insert_params(Post, [[title: "KW"]], validate: false)

      assert insert_map.title === "KW"
    end
  end

  describe "convert_to_insert_params/3 with usec timestamp types" do
    test "produces DateTime with microsecond precision when type is :utc_datetime_usec" do
      assert {:ok, [insert_map]} =
               CommonParams.convert_to_insert_params(
                 Post,
                 [%{title: "Hello"}],
                 validate: false,
                 timestamp_type: :utc_datetime_usec
               )

      assert %DateTime{microsecond: {_, precision}} = insert_map.inserted_at
      assert precision === 6
    end

    test "produces NaiveDateTime with microsecond precision when type is :naive_datetime_usec" do
      assert {:ok, [insert_map]} =
               CommonParams.convert_to_insert_params(
                 Post,
                 [%{title: "Hello"}],
                 validate: false,
                 timestamp_type: :naive_datetime_usec
               )

      assert %NaiveDateTime{microsecond: {_, precision}} = insert_map.inserted_at
      assert precision === 6
    end
  end

  describe "convert_to_update_params/3 with usec timestamp types" do
    test "produces DateTime with microsecond precision when type is :utc_datetime_usec" do
      updates =
        CommonParams.convert_to_update_params(
          Post,
          %{title: "Hello"},
          timestamp_type: :utc_datetime_usec
        )

      assert [set: set_ops] = updates
      assert %DateTime{microsecond: {_, 6}} = Keyword.fetch!(set_ops, :updated_at)
    end

    test "produces NaiveDateTime with microsecond precision when type is :naive_datetime_usec" do
      updates =
        CommonParams.convert_to_update_params(
          Post,
          %{title: "Hello"},
          timestamp_type: :naive_datetime_usec
        )

      assert [set: set_ops] = updates
      assert %NaiveDateTime{microsecond: {_, 6}} = Keyword.fetch!(set_ops, :updated_at)
    end
  end

  describe "convert_to_insert_params/3 with schemaless sources" do
    test "allows any key including string keys when the source is nil" do
      assert {:ok, [insert_map]} =
               CommonParams.convert_to_insert_params(nil, [%{"made_up_field" => "value"}])

      assert insert_map["made_up_field"] === "value"
      assert %DateTime{} = insert_map.updated_at
    end

    test "allows any key when the source is a table name string" do
      assert {:ok, [insert_map]} =
               CommonParams.convert_to_insert_params("posts", [%{"made_up_field" => "value"}])

      assert insert_map["made_up_field"] === "value"
      assert %DateTime{} = insert_map.updated_at
    end

    test "allows any key when the source is a table-nil tuple" do
      assert {:ok, [insert_map]} =
               CommonParams.convert_to_insert_params({"posts", nil}, [
                 %{"made_up_field" => "value"}
               ])

      assert insert_map["made_up_field"] === "value"
      assert %DateTime{} = insert_map.updated_at
    end

    test "filters out unknown keys when the source includes a schema module" do
      assert {:ok, [insert_map]} =
               CommonParams.convert_to_insert_params(
                 {"posts", Post},
                 [%{title: "Hello", made_up_field: "value"}],
                 validate: false
               )

      assert insert_map.title === "Hello"
      refute Map.has_key?(insert_map, :made_up_field)
    end
  end

  describe "convert_to_insert_params/3 timestamp options" do
    test "skips the inserted_at timestamp when inserted_at_source is false" do
      assert {:ok, [insert_map]} =
               CommonParams.convert_to_insert_params(
                 Post,
                 [%{title: "No TS"}],
                 validate: false,
                 inserted_at_source: false
               )

      refute Map.has_key?(insert_map, :inserted_at)
    end

    test "uses a custom inserted_at field name when inserted_at_source is provided" do
      assert {:ok, [insert_map]} =
               CommonParams.convert_to_insert_params(
                 Post,
                 [%{title: "Custom TS"}],
                 validate: false,
                 inserted_at_source: :created_on
               )

      assert Map.has_key?(insert_map, :created_on)
      refute Map.has_key?(insert_map, :inserted_at)
    end

    test "preserves an existing non-nil inserted_at in params" do
      existing_ts = ~U[2024-01-01 00:00:00Z]

      assert {:ok, [insert_map]} =
               CommonParams.convert_to_insert_params(
                 Post,
                 [%{title: "Existing TS", inserted_at: existing_ts}],
                 validate: false
               )

      assert %NaiveDateTime{year: 2024} = insert_map.inserted_at
    end

    test "skips the updated_at timestamp when updated_at_source is false" do
      assert {:ok, [insert_map]} =
               CommonParams.convert_to_insert_params(
                 Post,
                 [%{title: "No Updated TS"}],
                 validate: false,
                 updated_at_source: false
               )

      refute Map.has_key?(insert_map, :updated_at)
    end

    test "skips the updated_at timestamp when updated_at value is false" do
      assert {:ok, [insert_map]} =
               CommonParams.convert_to_insert_params(
                 Post,
                 [%{title: "No Updated TS"}],
                 validate: false,
                 updated_at: false
               )

      refute Map.has_key?(insert_map, :updated_at)
    end
  end
end
