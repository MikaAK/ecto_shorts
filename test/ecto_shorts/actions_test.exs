defmodule EctoShorts.ActionsTest do
  @moduledoc false
  use EctoShorts.DataCase, async: true
  doctest EctoShorts.Actions

  alias EctoShorts.{
    Actions,
    Repo,
    Schemas.PostAbstract,
    Schemas.Post,
    Schemas.PostNoPrimaryKey,
    Testing
  }

  describe "batch/3" do
    test "converts query results to a map with batch keys as map keys and records as values" do
      _post = Testing.insert!(Repo, Post, %{title: "post_title"})

      assert %{%{title: "post_title"} => %EctoShorts.Schemas.Post{title: "post_title"}} =
               Actions.batch(Post, [:title], [%{title: "post_title"}])
    end

    test "can call with abstract source tuple" do
      _post = Testing.insert!(Repo, {"posts", PostAbstract}, %{title: "post_title"})

      assert %{%{title: "post_title"} => %EctoShorts.Schemas.PostAbstract{title: "post_title"}} =
               Actions.batch({"posts", PostAbstract}, [:title], [%{title: "post_title"}])
    end

    test "raises if schema has no primary key and batch key not provided" do
      _post = Testing.insert!(Repo, Post, %{title: "post_title"})

      assert_raise ArgumentError, ~r|Match keys not found|, fn ->
        Actions.batch(PostNoPrimaryKey, [%{title: "post_title"}])
      end
    end
  end

  describe "batch_find/2" do
    test "retrieves records matching the given params including primary key" do
      post_1 = Testing.insert!(Repo, Post, %{title: "post_1_title"})

      _post_2 = Testing.insert!(Repo, Post, %{title: "post_2_title"})

      post_1_id = post_1.id

      assert {:ok, [%EctoShorts.Schemas.Post{id: ^post_1_id, title: "post_1_title"}]} =
               Actions.batch_find(Post, [%{id: post_1_id, title: "post_1_title"}])
    end

    test "can call with abstract source tuple" do
      post_1 = Testing.insert!(Repo, {"posts", PostAbstract}, %{title: "post_1_title"})

      _post_2 = Testing.insert!(Repo, {"posts", PostAbstract}, %{title: "post_2_title"})

      post_1_id = post_1.id

      assert {:ok, [%EctoShorts.Schemas.PostAbstract{id: ^post_1_id, title: "post_1_title"}]} =
               Actions.batch_find(
                 {"posts", PostAbstract},
                 [%{id: post_1_id, title: "post_1_title"}]
               )
    end
  end

  describe "batch_find/3" do
    test "retrieves records using specified batch keys" do
      _post_1 = Testing.insert!(Repo, Post, %{title: "post_1_title"})

      _post_2 = Testing.insert!(Repo, Post, %{title: "post_2_title"})

      assert {:ok, [%EctoShorts.Schemas.Post{title: "post_2_title"}]} =
               Actions.batch_find(Post, [:title], [%{title: "post_2_title"}])
    end

    test "can call with abstract source tuple" do
      _post_1 = Testing.insert!(Repo, {"posts", PostAbstract}, %{title: "post_1_title"})

      _post_2 = Testing.insert!(Repo, {"posts", PostAbstract}, %{title: "post_2_title"})

      assert {:ok, [%EctoShorts.Schemas.PostAbstract{title: "post_2_title"}]} =
               Actions.batch_find({"posts", PostAbstract}, [:title], [%{title: "post_2_title"}])
    end

    test "returns error when no matching records exist" do
      assert {:error,
              [
                %ErrorMessage{
                  code: :not_found,
                  message: "Record not found.",
                  details: %{
                    failed_value: %{title: "does_not_exist"},
                    match_keys: [:title],
                    params: [%{title: "does_not_exist"}],
                    position: 0,
                    query: EctoShorts.Schemas.Post
                  }
                }
              ]} = Actions.batch_find(Post, [:title], [%{title: "does_not_exist"}])
    end

    test "returns error message with abstract source tuple" do
      assert {:error,
              [
                %ErrorMessage{
                  code: :not_found,
                  message: "Record not found.",
                  details: %{
                    failed_value: %{title: "does_not_exist"},
                    match_keys: [:title],
                    params: [%{title: "does_not_exist"}],
                    position: 0,
                    query: {"posts", PostAbstract}
                  }
                }
              ]} =
               Actions.batch_find(
                 {"posts", PostAbstract},
                 [:title],
                 [%{title: "does_not_exist"}]
               )
    end
  end

  describe "batch_load/4" do
    test "returns each param alongside its matching record" do
      post_1 = Testing.insert!(Repo, Post, %{title: "post_1_title"})

      post_2 = Testing.insert!(Repo, Post, %{title: "post_2_title"})

      post_3 = Testing.insert!(Repo, Post, %{title: "post_3_title"})

      post_4 = Testing.insert!(Repo, Post, %{title: "post_4_title"})

      assert [
               {%EctoShorts.Schemas.Post{title: "post_1_title"}, %{}},
               {%EctoShorts.Schemas.Post{title: "post_2_title"}, %{}},
               {%EctoShorts.Schemas.Post{title: "post_3_title"}, %{}},
               {%EctoShorts.Schemas.Post{title: "post_4_title"}, %{}},
               %{title: "this_should_be_skipped"}
             ] =
               Actions.batch_load(
                 Post,
                 [
                   {post_1, %{}},
                   {%{id: post_2.id}, %{}},
                   %{id: post_3.id},
                   %{id: post_4.id},
                   %{title: "this_should_be_skipped"}
                 ]
               )
    end

    test "can call with abstract source tuple" do
      post_1 = Testing.insert!(Repo, {"posts", PostAbstract}, %{title: "post_1_title"})

      post_2 = Testing.insert!(Repo, {"posts", PostAbstract}, %{title: "post_2_title"})

      post_3 = Testing.insert!(Repo, {"posts", PostAbstract}, %{title: "post_3_title"})

      post_4 = Testing.insert!(Repo, {"posts", PostAbstract}, %{title: "post_4_title"})

      assert [
               {%EctoShorts.Schemas.PostAbstract{title: "post_1_title"}, %{}},
               {%EctoShorts.Schemas.PostAbstract{title: "post_2_title"}, %{}},
               {%EctoShorts.Schemas.PostAbstract{title: "post_3_title"}, %{}},
               {%EctoShorts.Schemas.PostAbstract{title: "post_4_title"}, %{}},
               %{title: "this_should_be_skipped"}
             ] =
               Actions.batch_load(
                 {"posts", PostAbstract},
                 [
                   {post_1, %{}},
                   {%{id: post_2.id}, %{}},
                   %{id: post_3.id},
                   %{id: post_4.id},
                   %{title: "this_should_be_skipped"}
                 ]
               )
    end
  end

  describe "insert_all/2" do
    test "creates new records and returns them with returning: true option" do
      assert {:ok, {1, [%EctoShorts.Schemas.Post{title: "post_title"}]}} =
               Actions.insert_all(Post, [%{title: "post_title"}], returning: true)
    end

    test "can call with abstract source tuple" do
      assert {:ok, {1, nil}} =
               Actions.insert_all({"posts", PostAbstract}, [%{title: "post_title"}])
    end

    test "updates existing record when primary key is provided" do
      post = Testing.insert!(Repo, Post, %{title: "post_title"})

      post_id = post.id

      assert {:ok, {1, [%EctoShorts.Schemas.Post{id: ^post_id, title: "post_title"}]}} =
               Actions.insert_all(
                 Post,
                 [%{id: post_id, title: "post_title"}],
                 returning: true
               )
    end

    test "updates existing record using struct and params tuple" do
      post = Testing.insert!(Repo, Post, %{title: "post_title"})

      post_id = post.id

      assert {:ok, {1, [%EctoShorts.Schemas.Post{id: ^post_id, title: "post_title"}]}} =
               Actions.insert_all(Post, [{post, %{title: "post_title"}}], returning: true)
    end

    test "updates existing record using changeset and params tuple" do
      post = Testing.insert!(Repo, Post, %{title: "post_title"})

      post_id = post.id

      post_changeset = Post.changeset(post)

      assert {:ok, {1, [%EctoShorts.Schemas.Post{id: ^post_id, title: "post_title"}]}} =
               Actions.insert_all(Post, [{post_changeset, %{title: "post_title"}}],
                 returning: true
               )
    end
  end

  describe "update_all/2" do
    test "updates records matching the filter params" do
      _post_1 = Testing.insert!(Repo, Post, %{title: "post_1_title"})

      _post_2 = Testing.insert!(Repo, Post, %{title: "post_2_title"})

      assert {1, nil} =
               Actions.update_all(
                 Post,
                 %{title: "post_1_title"},
                 %{title: "updated_post_1_title"}
               )
    end

    test "can call with abstract source tuple" do
      _post_1 = Testing.insert!(Repo, {"posts", PostAbstract}, %{title: "post_1_title"})

      _post_2 = Testing.insert!(Repo, {"posts", PostAbstract}, %{title: "post_2_title"})

      assert {1, nil} =
               Actions.update_all(
                 {"posts", PostAbstract},
                 %{title: "post_1_title"},
                 %{title: "updated_post_1_title"}
               )
    end

    test "updates and returns matching records when select: true is specified" do
      _post_1 = Testing.insert!(Repo, Post, %{title: "post_1_title"})

      _post_2 = Testing.insert!(Repo, Post, %{title: "post_2_title"})

      assert {1, [%EctoShorts.Schemas.Post{title: "updated_post_2_title"}]} =
               Actions.update_all(
                 Post,
                 %{title: "post_2_title", select: true},
                 %{title: "updated_post_2_title"}
               )
    end
  end

  describe "delete_all/2" do
    test "deletes records matching the filter params" do
      _post = Testing.insert!(Repo, Post, %{title: "post_title"})

      assert {1, nil} = Actions.delete_all(Post, %{})
    end

    test "can call with abstract source tuple" do
      _post = Testing.insert!(Repo, {"posts", PostAbstract}, %{title: "post_title"})

      assert {1, nil} = Actions.delete_all({"posts", PostAbstract}, %{})
    end

    test "deletes and returns matching records when select: true is specified" do
      _post = Testing.insert!(Repo, Post, %{title: "post_title"})

      assert {1, [%EctoShorts.Schemas.Post{title: "post_title"}]} =
               Actions.delete_all(Post, %{select: true})
    end
  end

  describe "find_or_create_many/3" do
    test "creates multiple records when none exist" do
      assert {:ok,
              [
                %EctoShorts.Schemas.Post{title: "post_2_title"},
                %EctoShorts.Schemas.Post{title: "post_2_title"}
              ]} =
               Actions.find_or_create_many(Post, [
                 %{title: "post_2_title"},
                 %{title: "post_2_title"}
               ])
    end

    test "can call with abstract source tuple" do
      assert {:ok,
              [
                %EctoShorts.Schemas.PostAbstract{title: "post_2_title"},
                %EctoShorts.Schemas.PostAbstract{title: "post_2_title"}
              ]} =
               Actions.find_or_create_many(
                 {"posts", PostAbstract},
                 [
                   %{title: "post_2_title"},
                   %{title: "post_2_title"}
                 ]
               )
    end

    test "returns existing records when matches are found" do
      _post_1 = Testing.insert!(Repo, Post, %{title: "post_1_title"})

      _post_2 = Testing.insert!(Repo, Post, %{title: "post_2_title"})

      assert {:ok,
              [
                %EctoShorts.Schemas.Post{title: "post_2_title"},
                %EctoShorts.Schemas.Post{title: "post_2_title"}
              ]} =
               Actions.find_or_create_many(Post, [
                 %{title: "post_2_title"},
                 %{title: "post_2_title"}
               ])
    end

    test "returns error on unique constraint violation" do
      assert {:error,
              %ErrorMessage{
                code: :conflict,
                message: "Failed to create record.",
                details: %{
                  query: EctoShorts.Schemas.Post,
                  changes_so_far: [
                    %EctoShorts.Schemas.Post{
                      title: "post_1_title",
                      permalink: "this_is_a_unique_field"
                    }
                  ],
                  changeset: changeset,
                  position: 1,
                  params: [
                    %{title: "post_1_title", permalink: "this_is_a_unique_field"},
                    %{title: "post_2_title", permalink: "this_is_a_unique_field"}
                  ]
                }
              }} =
               Actions.find_or_create_many(Post, [
                 %{title: "post_1_title", permalink: "this_is_a_unique_field"},
                 %{title: "post_2_title", permalink: "this_is_a_unique_field"}
               ])

      assert {:permalink, ["has already been taken"]} in errors_on(changeset)
    end

    test "returns error message with abstract source tuple" do
      assert {:error,
              %ErrorMessage{
                code: :conflict,
                message: "Failed to create record.",
                details: %{
                  query: {"posts", PostAbstract},
                  changes_so_far: [
                    %EctoShorts.Schemas.PostAbstract{
                      title: "post_1_title",
                      permalink: "this_is_a_unique_field"
                    }
                  ],
                  changeset: changeset,
                  position: 1,
                  params: [
                    %{title: "post_1_title", permalink: "this_is_a_unique_field"},
                    %{title: "post_2_title", permalink: "this_is_a_unique_field"}
                  ]
                }
              }} =
               Actions.find_or_create_many(
                 {"posts", PostAbstract},
                 [
                   %{title: "post_1_title", permalink: "this_is_a_unique_field"},
                   %{title: "post_2_title", permalink: "this_is_a_unique_field"}
                 ]
               )

      assert {:permalink, ["has already been taken"]} in errors_on(changeset)
    end
  end

  describe "find_and_update_many/3" do
    test "updates multiple records that match search criteria" do
      _post_1 = Testing.insert!(Repo, Post, %{title: "post_1_title"})

      _post_2 = Testing.insert!(Repo, Post, %{title: "post_2_title"})

      assert {:ok,
              [
                %EctoShorts.Schemas.Post{title: "updated_post_1_title"},
                %EctoShorts.Schemas.Post{title: "updated_post_2_title"}
              ]} =
               Actions.find_and_update_many(Post, [
                 {%{title: "post_1_title"}, %{title: "updated_post_1_title"}},
                 {%{title: "post_2_title"}, %{title: "updated_post_2_title"}}
               ])
    end

    test "can call with abstract source tuple" do
      _post_1 = Testing.insert!(Repo, {"posts", PostAbstract}, %{title: "post_1_title"})

      _post_2 = Testing.insert!(Repo, {"posts", PostAbstract}, %{title: "post_2_title"})

      assert {:ok,
              [
                %EctoShorts.Schemas.PostAbstract{title: "updated_post_1_title"},
                %EctoShorts.Schemas.PostAbstract{title: "updated_post_2_title"}
              ]} =
               Actions.find_and_update_many(
                 {"posts", PostAbstract},
                 [
                   {%{title: "post_1_title"}, %{title: "updated_post_1_title"}},
                   {%{title: "post_2_title"}, %{title: "updated_post_2_title"}}
                 ]
               )
    end
  end

  describe "find_and_upsert_many/3" do
    test "creates multiple records when no matches exist" do
      assert {:ok,
              [
                %EctoShorts.Schemas.Post{title: "created_post_2_title"},
                %EctoShorts.Schemas.Post{title: "created_post_2_title"}
              ]} =
               Actions.find_and_upsert_many(Post, [
                 {%{title: "post_1_does_not_exist"}, %{title: "created_post_2_title"}},
                 {%{title: "post_2_does_not_exist"}, %{title: "created_post_2_title"}}
               ])
    end

    test "updates multiple existing records when matches are found" do
      _post_1 = Testing.insert!(Repo, Post, %{title: "post_1_title"})

      _post_2 = Testing.insert!(Repo, Post, %{title: "post_2_title"})

      assert {:ok,
              [
                %EctoShorts.Schemas.Post{title: "updated_post_1_title"},
                %EctoShorts.Schemas.Post{title: "updated_post_2_title"}
              ]} =
               Actions.find_and_upsert_many(Post, [
                 {%{title: "post_1_title"}, %{title: "updated_post_1_title"}},
                 {%{title: "post_2_title"}, %{title: "updated_post_2_title"}}
               ])
    end

    test "can call with abstract source tuple" do
      assert {:ok,
              [
                %EctoShorts.Schemas.PostAbstract{title: "created_post_2_title"},
                %EctoShorts.Schemas.PostAbstract{title: "created_post_2_title"}
              ]} =
               Actions.find_and_upsert_many(
                 {"posts", PostAbstract},
                 [
                   {%{title: "post_1_does_not_exist"}, %{title: "created_post_2_title"}},
                   {%{title: "post_2_does_not_exist"}, %{title: "created_post_2_title"}}
                 ]
               )
    end
  end

  describe "create_many/3" do
    test "creates multiple records in a single operation" do
      assert {:ok,
              [
                %EctoShorts.Schemas.Post{title: "post_1_title"},
                %EctoShorts.Schemas.Post{title: "post_2_title"}
              ]} =
               Actions.create_many(Post, [
                 %{title: "post_1_title"},
                 %{title: "post_2_title"}
               ])
    end

    test "can call with abstract source tuple" do
      assert {:ok,
              [
                %EctoShorts.Schemas.PostAbstract{title: "post_1_title"},
                %EctoShorts.Schemas.PostAbstract{title: "post_2_title"}
              ]} =
               Actions.create_many(
                 {"posts", PostAbstract},
                 [
                   %{title: "post_1_title"},
                   %{title: "post_2_title"}
                 ]
               )
    end
  end

  describe "find_many/3" do
    test "retrieves all records matching params" do
      _post = Testing.insert!(Repo, Post, %{title: "post_title"})

      assert {:ok, [%EctoShorts.Schemas.Post{title: "post_title"}]} =
               Actions.find_many(Post, [%{title: "post_title"}])
    end

    test "can call with abstract source tuple" do
      _post = Testing.insert!(Repo, {"posts", PostAbstract}, %{title: "post_title"})

      assert {:ok, [%EctoShorts.Schemas.PostAbstract{title: "post_title"}]} =
               Actions.find_many(
                 {"posts", PostAbstract},
                 [%{title: "post_title"}]
               )
    end

    test "returns error when no matches exist" do
      assert {
               :error,
               %ErrorMessage{
                 code: :not_found,
                 message: "Record not found.",
                 details: %{
                   query: EctoShorts.Schemas.Post,
                   params: [%{title: "does_not_exist"}],
                   failed_value: %{title: "does_not_exist"},
                   position: 0,
                   changes_so_far: []
                 }
               }
             } = Actions.find_many(Post, [%{title: "does_not_exist"}])
    end

    test "returns error message with abstract source tuple" do
      assert {
               :error,
               %ErrorMessage{
                 code: :not_found,
                 message: "Record not found.",
                 details: %{
                   query: {"posts", PostAbstract},
                   params: [%{title: "does_not_exist"}],
                   failed_value: %{title: "does_not_exist"},
                   position: 0,
                   changes_so_far: []
                 }
               }
             } =
               Actions.find_many(
                 {"posts", PostAbstract},
                 [%{title: "does_not_exist"}]
               )
    end
  end

  describe "delete_many/3" do
    test "deletes multiple records using structs" do
      post_1 = Testing.insert!(Repo, Post, %{title: "post_1_title"})

      post_2 = Testing.insert!(Repo, Post, %{title: "post_2_title"})

      assert {:ok,
              [
                %EctoShorts.Schemas.Post{title: "post_1_title"},
                %EctoShorts.Schemas.Post{title: "post_2_title"}
              ]} =
               Actions.delete_many([post_1, post_2])
    end

    test "deletes multiple records using changesets" do
      post_1 = Testing.insert!(Repo, Post, %{title: "post_1_title"})

      post_1_changeset = Post.changeset(post_1)

      post_2 = Testing.insert!(Repo, Post, %{title: "post_2_title"})

      post_2_changeset = Post.changeset(post_2)

      assert {:ok,
              [
                %EctoShorts.Schemas.Post{title: "post_1_title"},
                %EctoShorts.Schemas.Post{title: "post_2_title"}
              ]} =
               Actions.delete_many([post_1_changeset, post_2_changeset])
    end
  end

  describe "find_and_create/3" do
    test "returns existing record when match is found" do
      _post = Testing.insert!(Repo, Post, %{title: "existing_post_title"})

      assert {:ok, %EctoShorts.Schemas.Post{title: "existing_post_title"}} =
               Actions.find_and_create(Post, %{title: "existing_post_title"}, %{
                 title: "created_post_title"
               })
    end

    test "can call with abstract source tuple" do
      _post = Testing.insert!(Repo, {"posts", PostAbstract}, %{title: "existing_post_title"})

      assert {:ok, %EctoShorts.Schemas.PostAbstract{title: "existing_post_title"}} =
               Actions.find_and_create(
                 {"posts", PostAbstract},
                 %{title: "existing_post_title"},
                 %{title: "created_post_title"}
               )
    end

    test "creates new record when no match exists" do
      assert {:ok, %EctoShorts.Schemas.Post{title: "created_post_title"}} =
               Actions.find_and_create(Post, %{title: "existing_post_title"}, %{
                 title: "created_post_title"
               })
    end
  end

  describe "find_and_update/2" do
    test "updates record when match is found" do
      _post = Testing.insert!(Repo, Post, %{title: "existing_post_title"})

      assert {:ok, %EctoShorts.Schemas.Post{title: "updated_post_title"}} =
               Actions.find_and_update(
                 Post,
                 %{title: "existing_post_title"},
                 %{title: "updated_post_title"}
               )
    end

    test "can call with abstract source tuple" do
      _post = Testing.insert!(Repo, {"posts", PostAbstract}, %{title: "existing_post_title"})

      assert {:ok, %EctoShorts.Schemas.PostAbstract{title: "updated_post_title"}} =
               Actions.find_and_update(
                 {"posts", PostAbstract},
                 %{title: "existing_post_title"},
                 %{title: "updated_post_title"}
               )
    end

    test "returns error when no match exists" do
      assert {:error, %{code: :not_found}} =
               Actions.find_and_update(Post, %{title: "does_not_exist"}, %{})
    end

    test "returns error message with abstract source tuple" do
      assert {:error, %{code: :not_found}} =
               Actions.find_and_update(
                 {"posts", PostAbstract},
                 %{title: "does_not_exist"},
                 %{}
               )
    end
  end

  describe "find_and_upsert/2" do
    test "creates new record when no match exists" do
      assert {:ok, %EctoShorts.Schemas.Post{title: "existing_post_title"}} =
               Actions.find_and_upsert(
                 Post,
                 %{title: "existing_post_title"},
                 %{title: "existing_post_title"}
               )
    end

    test "can call with abstract source tuple" do
      assert {:ok, %EctoShorts.Schemas.PostAbstract{title: "existing_post_title"}} =
               Actions.find_and_upsert(
                 {"posts", PostAbstract},
                 %{title: "existing_post_title"},
                 %{title: "existing_post_title"}
               )
    end

    test "updates existing record when match is found" do
      _post = Testing.insert!(Repo, Post, %{title: "existing_post_title"})

      assert {:ok, %EctoShorts.Schemas.Post{title: "updated_post_title"}} =
               Actions.find_and_upsert(
                 Post,
                 %{title: "existing_post_title"},
                 %{title: "updated_post_title"}
               )
    end
  end

  describe "find_and_delete/2" do
    test "deletes record matching params" do
      _post = Testing.insert!(Repo, Post, %{title: "post_title"})

      assert {:ok, %EctoShorts.Schemas.Post{title: "post_title"}} =
               Actions.find_and_delete(Post, %{title: "post_title"})
    end

    test "can call with abstract source tuple" do
      _post = Testing.insert!(Repo, {"posts", PostAbstract}, %{title: "post_title"})

      assert {:ok, %EctoShorts.Schemas.PostAbstract{title: "post_title"}} =
               Actions.find_and_delete({"posts", PostAbstract}, %{title: "post_title"})
    end

    test "returns error when no matching record exists" do
      assert {:error, %{code: :not_found}} =
               Actions.find_and_delete(Post, %{title: "does_not_exist"})
    end

    test "returns error message with abstract source tuple" do
      assert {:error, %{code: :not_found}} =
               Actions.find_and_delete({"posts", PostAbstract}, %{title: "does_not_exist"})
    end
  end

  describe "find_or_create/3" do
    test "returns existing record when match is found" do
      _post = Testing.insert!(Repo, Post, %{title: "existing_post_title"})

      assert {:ok, %EctoShorts.Schemas.Post{title: "post_title"}} =
               Actions.find_or_create(Post, %{title: "post_title"})
    end

    test "can call with abstract source tuple" do
      _post = Testing.insert!(Repo, {"posts", PostAbstract}, %{title: "existing_post_title"})

      assert {:ok, %EctoShorts.Schemas.PostAbstract{title: "post_title"}} =
               Actions.find_or_create({"posts", PostAbstract}, %{title: "post_title"})
    end

    test "creates a new record with given params when no match is found" do
      assert {:ok, %EctoShorts.Schemas.Post{title: "post_title"}} =
               Actions.find_or_create(Post, %{title: "post_title"})
    end
  end

  describe "get/2" do
    test "retrieves a record by its primary key (id)" do
      post = Testing.insert!(Repo, Post, %{title: "post_title"})

      assert %EctoShorts.Schemas.Post{title: "post_title"} = Actions.get(Post, post.id)
    end

    test "can call with abstract source tuple" do
      post = Testing.insert!(Repo, {"posts", PostAbstract}, %{title: "post_title"})

      assert %EctoShorts.Schemas.PostAbstract{title: "post_title"} =
               Actions.get({"posts", PostAbstract}, post.id)
    end
  end

  describe "all/1" do
    test "returns records matching params" do
      post =
        Testing.insert!(Repo, Post, %{
          title: "post_title",
          tags: ["post_tag"],
          views: 1
        })

      assert %EctoShorts.Schemas.Post{
               title: "post_title",
               tags: ["post_tag"],
               views: 1
             } = post

      assert [^post] = Actions.all(Post)
    end

    test "can call with abstract source tuple" do
      post =
        Testing.insert!(Repo, {"posts", PostAbstract}, %{
          title: "post_title",
          tags: ["post_tag"],
          views: 1
        })

      assert %PostAbstract{
               title: "post_title",
               tags: ["post_tag"],
               views: 1
             } = post

      assert [^post] = Actions.all({"posts", PostAbstract}, %{id: post.id})
    end
  end

  describe "all/2" do
    test "returns only records that match the given filter params" do
      _post_1 = Testing.insert!(Repo, Post, %{title: "post_1_title"})

      _post_2 = Testing.insert!(Repo, Post, %{title: "post_2_title"})

      assert [%EctoShorts.Schemas.Post{title: "post_2_title"}] =
               Actions.all(Post, %{title: "post_2_title"})
    end

    test "can call with abstract source tuple" do
      _post_1 = Testing.insert!(Repo, Post, %{title: "post_1_title"})

      _post_2 = Testing.insert!(Repo, Post, %{title: "post_2_title"})

      assert [%EctoShorts.Schemas.PostAbstract{title: "post_2_title"}] =
               Actions.all({"posts", PostAbstract}, %{title: "post_2_title"})
    end
  end

  describe "create/2" do
    test "creates a new record with the given params" do
      assert {:ok, %EctoShorts.Schemas.Post{title: "post_title"}} =
               Actions.create(Post, %{title: "post_title"})
    end

    test "can call with abstract source tuple" do
      assert {:ok, %EctoShorts.Schemas.PostAbstract{title: "post_title"}} =
               Actions.create({"posts", PostAbstract}, %{title: "post_title"})
    end

    test "returns changeset errors when unique constraint is violated" do
      assert {:ok, %EctoShorts.Schemas.Post{permalink: "this_is_a_unique_field"}} =
               Actions.create(Post, %{permalink: "this_is_a_unique_field"})

      assert {:error, changeset} =
               Actions.create(Post, %{permalink: "this_is_a_unique_field"})

      assert {:permalink, ["has already been taken"]} in errors_on(changeset)
    end

    test "returns error message with abstract source tuple" do
      assert {:ok, %EctoShorts.Schemas.PostAbstract{permalink: "this_is_a_unique_field"}} =
               Actions.create({"posts", PostAbstract}, %{permalink: "this_is_a_unique_field"})

      assert {:error, changeset} =
               Actions.create(
                 {"posts", PostAbstract},
                 %{permalink: "this_is_a_unique_field"}
               )

      assert {:permalink, ["has already been taken"]} in errors_on(changeset)
    end
  end

  describe "find/2" do
    test "retrieves a record matching the params" do
      _post = Testing.insert!(Repo, Post, %{title: "post_title"})

      assert {:ok, %EctoShorts.Schemas.Post{title: "post_title"}} =
               Actions.find(Post, %{title: "post_title"})
    end

    test "can call with abstract source tuple" do
      _post = Testing.insert!(Repo, {"posts", PostAbstract}, %{title: "post_title"})

      assert {:ok, %EctoShorts.Schemas.PostAbstract{title: "post_title"}} =
               Actions.find({"posts", PostAbstract}, %{title: "post_title"})
    end

    test "returns detailed not_found error when no record matches params" do
      assert {:error,
              %ErrorMessage{
                code: :not_found,
                message: "Record not found.",
                details: %{
                  query: EctoShorts.Schemas.Post,
                  params: %{title: "post_title"}
                }
              }} = Actions.find(Post, %{title: "post_title"})
    end

    test "returns error message with abstract source tuple" do
      assert {:error,
              %ErrorMessage{
                code: :not_found,
                message: "Record not found.",
                details: %{
                  query: {"posts", PostAbstract},
                  params: %{title: "post_title"}
                }
              }} = Actions.find({"posts", PostAbstract}, %{title: "post_title"})
    end
  end

  describe "update/3" do
    test "can update record by id" do
      post = Testing.insert!(Repo, Post, %{title: "created_title"})

      post_id = post.id

      assert {:ok, %EctoShorts.Schemas.Post{id: ^post_id, title: "updated_title"}} =
               Actions.update(Post, post_id, %{title: "updated_title"})
    end

    test "can call with abstract source tuple" do
      post = Testing.insert!(Repo, {"posts", PostAbstract}, %{title: "created_title"})

      post_id = post.id

      assert {:ok, %EctoShorts.Schemas.PostAbstract{id: ^post_id, title: "updated_title"}} =
               Actions.update({"posts", PostAbstract}, post_id, %{title: "updated_title"})
    end

    test "can update record by struct" do
      post = Testing.insert!(Repo, Post, %{title: "created_title"})

      assert {:ok, %EctoShorts.Schemas.Post{title: "updated_title"}} =
               Actions.update(Post, post, %{title: "updated_title"})
    end
  end

  describe "delete/1" do
    test "can delete record by struct" do
      post = Testing.insert!(Repo, Post, %{title: "post_title"})

      assert {:ok, %EctoShorts.Schemas.Post{title: "post_title"}} = Actions.delete(post)
    end

    test "can delete record by changeset" do
      post = Testing.insert!(Repo, Post, %{title: "post_title"})

      assert {:ok, %EctoShorts.Schemas.Post{title: "post_title"}} =
               post
               |> Post.changeset(%{})
               |> Actions.delete()
    end

    test "can delete many structs" do
      post_1 = Testing.insert!(Repo, Post, %{title: "post_1_title"})

      post_2 = Testing.insert!(Repo, Post, %{title: "post_2_title"})

      assert {:ok,
              [
                %EctoShorts.Schemas.Post{title: "post_1_title"},
                %EctoShorts.Schemas.Post{title: "post_2_title"}
              ]} = Actions.delete([post_1, post_2])
    end

    test "can delete many changesets" do
      post_1 = Testing.insert!(Repo, Post, %{title: "post_1_title"})
      post_1_changeset = Post.changeset(post_1, %{})

      post_2 = Testing.insert!(Repo, Post, %{title: "post_2_title"})
      post_2_changeset = Post.changeset(post_2, %{})

      assert {:ok,
              [
                %EctoShorts.Schemas.Post{title: "post_1_title"},
                %EctoShorts.Schemas.Post{title: "post_2_title"}
              ]} = Actions.delete([post_1_changeset, post_2_changeset])
    end
  end

  describe "delete/2" do
    test "can delete record by id" do
      post = Testing.insert!(Repo, Post, %{title: "post_title"})

      assert {:ok, %EctoShorts.Schemas.Post{title: "post_title"}} = Actions.delete(Post, post.id)
    end

    test "can call with abstract source tuple" do
      post = Testing.insert!(Repo, {"posts", PostAbstract}, %{title: "post_title"})

      assert {:ok, %EctoShorts.Schemas.PostAbstract{title: "post_title"}} =
               Actions.delete({"posts", PostAbstract}, post.id)
    end
  end

  describe "stream/2" do
    test "returns records matching params" do
      _post = Testing.insert!(Repo, Post, %{title: "post_title"})

      assert {:ok, [%EctoShorts.Schemas.Post{title: "post_title"}]} =
               Repo.transaction(fn ->
                 Post
                 |> Actions.stream(%{})
                 |> Enum.to_list()
               end)
    end

    test "can call with abstract source tuple" do
      _post = Testing.insert!(Repo, {"posts", PostAbstract}, %{title: "post_title"})

      assert {:ok, [%EctoShorts.Schemas.PostAbstract{title: "post_title"}]} =
               Repo.transaction(fn ->
                 {"posts", PostAbstract}
                 |> Actions.stream(%{})
                 |> Enum.to_list()
               end)
    end
  end

  describe "aggregate/4" do
    test "performs count aggregation on matching records" do
      _post = Testing.insert!(Repo, Post, %{title: "post_title"})

      assert 1 = Actions.aggregate(Post, %{}, :count, :id)
    end

    test "can call with abstract source tuple" do
      _post = Testing.insert!(Repo, {"posts", PostAbstract}, %{title: "post_title"})

      assert 1 = Actions.aggregate({"posts", PostAbstract}, %{}, :count, :id)
    end
  end

  describe "transaction/2" do
    test "executes operations within a transaction" do
      _post = Testing.insert!(Repo, Post, %{title: "post_title"})

      assert {:ok, [%EctoShorts.Schemas.Post{title: "post_title"}]} =
               Actions.transaction(fn ->
                 Actions.all(Post, %{})
               end)
    end

    test "handles successful operation responses" do
      assert {:ok, %EctoShorts.Schemas.Post{title: "post_title"}} =
               Actions.transaction(fn ->
                 Actions.create(Post, %{title: "post_title"})
               end)
    end

    test "rolls back on error atom response" do
      assert :error =
               Actions.transaction(fn ->
                 with {:ok, _} <- Actions.create(Post, %{title: "post_title"}) do
                   :error
                 end
               end)

      assert {:error, %{code: :not_found}} = Actions.find(Post, %{title: "post_title"})
    end

    test "rolls back on error tuple response" do
      assert {:error, "message"} =
               Actions.transaction(fn ->
                 with {:ok, _} <-
                        Actions.create(Post, %{body: "post_body"}) do
                   {:error, "message"}
                 end
               end)

      assert {:error, %{code: :not_found}} =
               Actions.find(Post, %{body: "post_body"})
    end

    test "rolls back on constraint violations" do
      assert {:error, %Ecto.Changeset{}} =
               Actions.transaction(fn ->
                 with {:ok, _} <-
                        Actions.create(Post, %{permalink: "this_is_a_unique_field"}) do
                   Actions.create(Post, %{permalink: "this_is_a_unique_field"})
                 end
               end)

      assert {:error, %{code: :not_found}} =
               Actions.find(Post, %{permalink: "this_is_a_unique_field"})
    end

    test "can call with abstract source tuple" do
      _post = Testing.insert!(Repo, {"posts", PostAbstract}, %{title: "post_title"})

      assert {:ok, [%EctoShorts.Schemas.PostAbstract{title: "post_title"}]} =
               Actions.transaction(fn ->
                 Actions.all({"posts", PostAbstract}, %{})
               end)
    end
  end
end
