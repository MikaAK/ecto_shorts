defmodule EctoShorts.CommonParamsTest do
  use ExUnit.Case, async: true
  doctest EctoShorts.CommonParams

  alias EctoShorts.{
    CommonParams,
    Schemas.Post
  }

  describe "convert_to_insert_all_params" do
    test "does not include keys not in schema data" do
      assert {:ok, {[insert], _opts}} =
               CommonParams.convert_to_insert_all_params(Post, [%{unknown_key: "test"}],
                 validate: false
               )

      refute Map.has_key?(insert, :unknown_key)
    end

    test "does not include keys whose values match schema data" do
      assert {:ok, {[insert], []}} =
               CommonParams.convert_to_insert_all_params(
                 Post,
                 [{%Post{title: "Same Title"}, %{title: "Same Title"}}],
                 validate: false
               )

      assert %{title: "Same Title"} = insert
    end

    test "returns valid params for ecto repo insert_all" do
      assert {:ok, {inserts, insert_opts}} =
               CommonParams.convert_to_insert_all_params(Post, [
                 %{id: 1, title: "post_title_1"},
                 %{id: 2, title: "post_title_2"},
                 %{title: "post_title_3"}
               ])

      assert [
               %{
                 id: 1,
                 title: "post_title_1",
                 inserted_at: %NaiveDateTime{},
                 updated_at: %NaiveDateTime{}
               },
               %{
                 id: 2,
                 title: "post_title_2",
                 inserted_at: %NaiveDateTime{},
                 updated_at: %NaiveDateTime{}
               },
               %{
                 title: "post_title_3",
                 inserted_at: %NaiveDateTime{},
                 updated_at: %NaiveDateTime{}
               }
             ] = inserts

      assert [conflict_target: [:id], on_conflict: {:replace, [:id, :title]}] = insert_opts
    end

    test "returns valid params for ecto repo insert_all when :validate is false" do
      assert {:ok, {inserts, []}} =
               CommonParams.convert_to_insert_all_params(Post, [%{title: "post_title"}],
                 validate: false
               )

      assert [
               %{
                 title: "post_title",
                 inserted_at: %NaiveDateTime{},
                 updated_at: %NaiveDateTime{}
               }
             ] = inserts
    end

    test "returns options when primary key exists in data" do
      assert {:ok, {inserts, insert_options}} =
               CommonParams.convert_to_insert_all_params(Post, [
                 {%Post{id: 1}, %{title: "post_title"}}
               ])

      assert [
               %{
                 id: 1,
                 title: "post_title",
                 updated_at: %NaiveDateTime{}
               }
             ] = inserts

      assert [conflict_target: [:id], on_conflict: {:replace, [:title]}] = insert_options
    end

    test "returns an error changeset for invalid data" do
      assert {:error, [%Ecto.Changeset{valid?: false}]} =
               CommonParams.convert_to_insert_all_params(Post, [%{views: "invalid_type"}, %{}])
    end

    test "change timestamp types to datetime" do
      assert {:ok, {inserts, []}} =
               CommonParams.convert_to_insert_all_params(Post, [%{title: "post_title"}],
                 timestamps: [inserted_at: :utc_datetime, updated_at: :utc_datetime]
               )

      assert [
               %{
                 title: "post_title",
                 inserted_at: %DateTime{},
                 updated_at: %DateTime{}
               }
             ] = inserts
    end

    test "returns the existing naive datetime for :inserted_at if set and :validate is false" do
      assert {:ok, {inserts, []}} =
               CommonParams.convert_to_insert_all_params(
                 Post,
                 [%{title: "post_title", inserted_at: ~N[2025-06-07 08:38:33]}],
                 validate: false
               )

      assert [
               %{
                 title: "post_title",
                 inserted_at: ~N[2025-06-07 08:38:33],
                 updated_at: %NaiveDateTime{}
               }
             ] = inserts
    end

    test "returns truncated timestamp when the inserted_at timestamp exists and creating a record and validate is false" do
      assert {:ok, {inserts, []}} =
               CommonParams.convert_to_insert_all_params(
                 Post,
                 [%{title: "post_title", inserted_at: ~U[2025-06-07 08:30:00.000000Z]}],
                 validate: false
               )

      assert [
               %{
                 title: "post_title",
                 inserted_at: ~N[2025-06-07 08:30:00],
                 updated_at: %NaiveDateTime{}
               }
             ] = inserts
    end

    test "disable timestamps with option :inserted_at and :updated_at set to false" do
      assert {:ok, {inserts, []}} =
               CommonParams.convert_to_insert_all_params(Post, [%{title: "post_title"}],
                 inserted_at: false,
                 updated_at: false
               )

      assert [%{title: "post_title"}] === inserts
    end

    # ---

    test "returns params and no insert options when given {struct, map} and the struct is not created" do
      assert {:ok, {inserts, []}} =
               CommonParams.convert_to_insert_all_params(Post, [
                 {%Post{}, %{title: "updated_title"}}
               ])

      assert [
               %{
                 title: "updated_title",
                 inserted_at: %NaiveDateTime{},
                 updated_at: %NaiveDateTime{}
               }
             ] = inserts
    end

    test "returns params and no insert options when given {struct, map} and the struct is not created and :validate is false" do
      assert {:ok, {inserts, []}} =
               CommonParams.convert_to_insert_all_params(
                 Post,
                 [{%Post{}, %{title: "updated_title"}}],
                 validate: false
               )

      assert [
               %{
                 title: "updated_title",
                 inserted_at: %NaiveDateTime{},
                 updated_at: %NaiveDateTime{}
               }
             ] = inserts
    end

    test "returns params and options to allow upsert when given {struct, map} and the struct is created" do
      assert {:ok, {inserts, insert_options}} =
               CommonParams.convert_to_insert_all_params(Post, [
                 {%Post{id: 1, title: "post_title"}, %{title: "updated_title"}}
               ])

      assert [
               %{
                 title: "updated_title",
                 inserted_at: %NaiveDateTime{},
                 updated_at: %NaiveDateTime{}
               }
             ] = inserts

      assert [conflict_target: [:id], on_conflict: {:replace, [:title]}] = insert_options
    end

    test "returns params and options to allow upsert when given {struct, map} and the struct is created and :validate is false" do
      assert {:ok, {inserts, insert_options}} =
               CommonParams.convert_to_insert_all_params(
                 Post,
                 [{%Post{id: 1, title: "post_title"}, %{title: "updated_title"}}],
                 validate: false
               )

      assert [
               %{
                 title: "updated_title",
                 inserted_at: %NaiveDateTime{},
                 updated_at: %NaiveDateTime{}
               }
             ] = inserts

      assert [conflict_target: [:id], on_conflict: {:replace, [:title]}] = insert_options
    end

    # ---

    test "returns params and no insert options when given struct and the struct is not created" do
      assert {:ok, {inserts, []}} =
               CommonParams.convert_to_insert_all_params(Post, [%Post{title: "post_title"}])

      assert [
               %{
                 title: "post_title",
                 inserted_at: %NaiveDateTime{},
                 updated_at: %NaiveDateTime{}
               }
             ] = inserts
    end

    test "returns params and no insert options when given struct and the struct is not created and :validate is false" do
      assert {:ok, {inserts, []}} =
               CommonParams.convert_to_insert_all_params(
                 Post,
                 [%Post{title: "post_title"}],
                 validate: false
               )

      assert [
               %{
                 title: "post_title",
                 inserted_at: %NaiveDateTime{},
                 updated_at: %NaiveDateTime{}
               }
             ] = inserts
    end

    test "returns params and options to allow upsert when given struct and the struct is created" do
      assert {:ok, {inserts, insert_options}} =
               CommonParams.convert_to_insert_all_params(Post, [%Post{id: 1, title: "post_title"}])

      assert [
               %{
                 id: 1,
                 title: "post_title",
                 inserted_at: %NaiveDateTime{},
                 updated_at: %NaiveDateTime{}
               }
             ] = inserts

      assert [
               conflict_target: [:id],
               on_conflict:
                 {:replace,
                  [
                    :author_id,
                    :body,
                    :id,
                    :inserted_at,
                    :notes,
                    :permalink,
                    :published,
                    :published_at,
                    :tags,
                    :title,
                    :updated_at,
                    :views
                  ]}
             ] = insert_options
    end

    test "returns params and options to allow upsert when given struct and the struct is created and :validate is false" do
      assert {:ok, {inserts, insert_options}} =
               CommonParams.convert_to_insert_all_params(
                 Post,
                 [%Post{id: 1, title: "post_title"}],
                 validate: false
               )

      assert [
               %{
                 title: "post_title",
                 inserted_at: %NaiveDateTime{},
                 updated_at: %NaiveDateTime{}
               }
             ] = inserts

      assert [
               conflict_target: [:id],
               on_conflict:
                 {:replace,
                  [
                    :author_id,
                    :body,
                    :id,
                    :inserted_at,
                    :notes,
                    :permalink,
                    :published,
                    :published_at,
                    :tags,
                    :title,
                    :updated_at,
                    :views
                  ]}
             ] = insert_options
    end

    # ---

    test "returns params and no insert options when given {changeset, map} and the data struct is not created" do
      changeset = Post.changeset(%Post{})

      assert {:ok, {inserts, []}} =
               CommonParams.convert_to_insert_all_params(Post, [
                 {changeset, %{title: "updated_title"}}
               ])

      assert [
               %{
                 title: "updated_title",
                 inserted_at: %NaiveDateTime{},
                 updated_at: %NaiveDateTime{}
               }
             ] = inserts
    end

    test "returns params and options to allow upsert when given {changeset, map} and the struct is created" do
      changeset = Post.changeset(%Post{id: 1, title: "post_title"})

      assert {:ok, {inserts, insert_options}} =
               CommonParams.convert_to_insert_all_params(Post, [
                 {changeset, %{title: "updated_title"}}
               ])

      assert [
               %{
                 title: "updated_title",
                 inserted_at: %NaiveDateTime{},
                 updated_at: %NaiveDateTime{}
               }
             ] = inserts

      assert [conflict_target: [:id], on_conflict: {:replace, [:title]}] = insert_options
    end

    # ---

    test "returns params and no insert options when given {changeset, map} and the data struct is not created and :validate is false" do
      changeset = Post.changeset(%Post{})

      assert {:ok, {inserts, []}} =
               CommonParams.convert_to_insert_all_params(
                 Post,
                 [{changeset, %{title: "updated_title"}}],
                 validate: false
               )

      assert [
               %{
                 title: "updated_title",
                 inserted_at: %NaiveDateTime{},
                 updated_at: %NaiveDateTime{}
               }
             ] = inserts
    end

    test "returns params and options to allow upsert when given {changeset, map} and the data struct is created and :validate is false" do
      changeset = Post.changeset(%Post{id: 1, title: "post_title"})

      assert {:ok, {inserts, insert_options}} =
               CommonParams.convert_to_insert_all_params(
                 Post,
                 [{changeset, %{title: "updated_title"}}],
                 validate: false
               )

      assert [
               %{
                 title: "updated_title",
                 inserted_at: %NaiveDateTime{},
                 updated_at: %NaiveDateTime{}
               }
             ] = inserts

      assert [conflict_target: [:id], on_conflict: {:replace, [:title]}] = insert_options
    end

    # ---

    test "returns params and no insert options when given changeset and the struct is not created" do
      changeset = Post.changeset(%Post{title: "post_title"})

      assert {:ok, {inserts, []}} =
               CommonParams.convert_to_insert_all_params(Post, [changeset])

      assert [
               %{
                 title: "post_title",
                 inserted_at: %NaiveDateTime{},
                 updated_at: %NaiveDateTime{}
               }
             ] = inserts
    end

    test "returns params and no insert options when given changeset and the struct is not created and :validate is false" do
      changeset = Post.changeset(%Post{title: "post_title"})

      assert {:ok, {inserts, []}} =
               CommonParams.convert_to_insert_all_params(Post, [changeset], validate: false)

      assert [
               %{
                 title: "post_title",
                 inserted_at: %NaiveDateTime{},
                 updated_at: %NaiveDateTime{}
               }
             ] = inserts
    end

    test "returns params and options to allow upsert when given changeset and the struct is created" do
      changeset = Post.changeset(%Post{id: 1}, %{title: "updated_title"})

      assert {:ok, {inserts, insert_options}} =
               CommonParams.convert_to_insert_all_params(Post, [changeset])

      assert [
               %{
                 id: 1,
                 title: "updated_title",
                 inserted_at: %NaiveDateTime{},
                 updated_at: %NaiveDateTime{}
               }
             ] = inserts

      assert [conflict_target: [:id], on_conflict: {:replace, [:title]}] = insert_options
    end

    test "returns params and options to allow upsert when given changeset and the struct is created and :validate is false" do
      changeset = Post.changeset(%Post{id: 1}, %{title: "updated_title"})

      assert {:ok, {inserts, insert_options}} =
               CommonParams.convert_to_insert_all_params(Post, [changeset], validate: false)

      assert [
               %{
                 id: 1,
                 title: nil,
                 inserted_at: %NaiveDateTime{},
                 updated_at: %NaiveDateTime{}
               }
             ] = inserts

      assert [conflict_target: [:id], on_conflict: {:replace, [:title]}] = insert_options
    end

    # ---

    test "does not add placeholders for keys not present in params" do
      assert {:ok, {[entry], []}} =
               CommonParams.convert_to_insert_all_params(
                 Post,
                 [%{title: "post_title"}],
                 placeholders: %{permalink: "post_permalink"}
               )

      refute entry[:permalink]
    end

    test "does nothing to resolve a placeholder when :on_placeholder_conflict is :nothing" do
      assert {:ok, {inserts, []}} =
               CommonParams.convert_to_insert_all_params(
                 Post,
                 [%{permalink: "should_see_this"}],
                 placeholders: %{permalink: "should_not_see_this"},
                 on_placeholder_conflict: :nothing
               )

      assert [%{permalink: "should_see_this"}] = inserts
    end

    test "replaces a specific field with a placeholder when :on_placeholder_conflict is {:replace, keys}" do
      assert {:ok, {inserts, []}} =
               CommonParams.convert_to_insert_all_params(
                 Post,
                 [%{permalink: "should_not_see_this"}],
                 placeholders: %{permalink: "different_value"},
                 on_placeholder_conflict: {:replace, [:permalink]}
               )

      assert [%{permalink: {:placeholder, :permalink}}] = inserts
    end

    test "does not replace placeholder field on conflict if the key is not in the keys of the option {:replace, keys}" do
      assert {:ok, {inserts, []}} =
               CommonParams.convert_to_insert_all_params(
                 Post,
                 [%{permalink: "should_see_this"}],
                 placeholders: %{permalink: "different_value"},
                 on_placeholder_conflict: {:replace, [:does_not_exist]}
               )

      assert [%{permalink: "should_see_this"}] = inserts
    end

    test "replaces all fields with placeholders when :on_placeholder_conflict is :replace_all" do
      assert {:ok, {inserts, []}} =
               CommonParams.convert_to_insert_all_params(
                 Post,
                 [
                   %{
                     title: "post_title",
                     permalink: "post_permalink"
                   }
                 ],
                 placeholders: %{does_not_exist: "value", permalink: "placeholder_permalink"},
                 on_placeholder_conflict: :replace_all
               )

      assert [
               %{
                 title: "post_title",
                 permalink: {:placeholder, :permalink}
               }
             ] = inserts
    end

    test "replaces field with placeholder when value matches placeholder value" do
      assert {:ok, {inserts, []}} =
               CommonParams.convert_to_insert_all_params(
                 Post,
                 [
                   %{
                     title: "post_title",
                     permalink: "same_as_placeholder_value"
                   }
                 ],
                 placeholders: %{permalink: "same_as_placeholder_value"},
                 on_placeholder_conflict: {:replace, [:description]}
               )

      assert [
               %{
                 title: "post_title",
                 permalink: {:placeholder, :permalink}
               }
             ] = inserts
    end

    test "raises an error when :on_placeholder_conflict value is invalid" do
      message =
        "Expected the value for option :on_placeholder_conflict to be one of [:replace, :replace_all, :nothing], got: :this_will_error"

      assert_raise ArgumentError, message, fn ->
        CommonParams.convert_to_insert_all_params(
          Post,
          [%{permalink: "post_permalink"}],
          placeholders: %{permalink: "permalink_placebolder"},
          on_placeholder_conflict: :this_will_error
        )
      end
    end
  end

  describe "convert_to_update_all_params" do
    test "returns expected update_all params" do
      assert [
               inc: [views: 1],
               pull: [tags: "c", tags: "d"],
               push: [tags: "a", tags: "b"],
               set: [
                 notes: "post_notes",
                 title: "post_title",
                 updated_at: %NaiveDateTime{}
               ]
             ] =
               CommonParams.convert_to_update_all_params(Post, %{
                 title: "post_title",
                 views: %{inc: 1},
                 tags: %{push: ["a", "b"], pull: ["c", "d"]},
                 notes: {:set, "post_notes"}
               })
    end

    test "skips key if not a query field on schema" do
      assert [] =
               CommonParams.convert_to_update_all_params(Post, [
                 %{does_not_exist: "should_not_see_this"}
               ])
    end

    test "raises if operation is :pull and schema field is not an :array type" do
      message =
        """
        The field `:id` on schema `EctoShorts.Schemas.Post` is not a type of `:array`
        and cannot be used with the `Ecto.Query` update operator `:pull`.

        actual type:
        :id
        """

      assert_raise ArgumentError, message, fn ->
        CommonParams.convert_to_update_all_params(Post, [%{id: %{pull: ["this_will_error"]}}])
      end
    end

    test "raises if operation is :push and schema field is not an :array type" do
      message =
        """
        The field `:id` on schema `EctoShorts.Schemas.Post` is not a type of `:array`
        and cannot be used with the `Ecto.Query` update operator `:push`.

        actual type:
        :id
        """

      assert_raise ArgumentError, message, fn ->
        CommonParams.convert_to_update_all_params(Post, [%{id: %{push: ["this_will_error"]}}])
      end
    end

    test "raises if operation is :inc and schema field is not an :integer type" do
      message =
        """
        The field `:id` on schema `EctoShorts.Schemas.Post` is not a type of `:integer`
        and cannot be used with the `Ecto.Query` update operator `:inc`.

        actual type:
        :id
        """

      assert_raise ArgumentError, message, fn ->
        CommonParams.convert_to_update_all_params(Post, [%{id: %{inc: "this_will_error"}}])
      end
    end

    test "raises if operation is :inc and value is not an :integer type" do
      message = "Expected value for key `:views` to be an integer, got: \"this_will_error\""

      assert_raise ArgumentError, message, fn ->
        CommonParams.convert_to_update_all_params(Post, [%{views: %{inc: "this_will_error"}}])
      end
    end
  end
end
