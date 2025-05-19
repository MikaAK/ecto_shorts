defmodule EctoShorts.CommonChangesTest do
  use EctoShorts.DataCase, async: true
  doctest EctoShorts.CommonChanges

  alias Ecto.Changeset

  alias EctoShorts.{
    Actions,
    CommonChanges,
    Repo,
    Schema.Comment,
    Schema.Post,
    Schema.User
  }

  describe "put_when: " do
    test "returns changeset without changes if evaluator function returns false" do
      when_func =
        fn _changeset -> false end

      change_func =
        fn changeset ->
          Changeset.put_change(changeset, :title, "title")
        end

      changeset =
        %Post{}
        |> Post.changeset(%{})
        |> CommonChanges.put_when(when_func, change_func)

      assert %Changeset{changes: changes, params: params} = changeset

      assert %{} === changes

      assert %{} === params
    end

    test "returns changeset with changes if evaluator function returns true" do
      when_func =
        fn _changeset -> true end

      change_func =
        fn changeset ->
          Changeset.put_change(changeset, :title, "title")
        end

      changeset =
        %Post{}
        |> Post.changeset(%{})
        |> CommonChanges.put_when(when_func, change_func)

      assert %Changeset{changes: changes} = changeset

      assert %{title: "title"} === changes
    end
  end

  describe "changeset_field_empty?: " do
    test "returns false if changeset field is not an empty list" do
      params = %{}

      changeset =
        %Post{}
        |> Post.changeset(params)
        |> Changeset.put_assoc(:comments, [%{body: "body"}])

      refute CommonChanges.changeset_field_empty?(changeset, :comments)
    end

    test "returns true if changeset field is nil" do
      changeset = Post.changeset(%Post{}, %{})

      assert CommonChanges.changeset_field_empty?(changeset, :comments)
    end

    test "returns true if changeset field is an empty list" do
      changeset = Post.changeset(%Post{}, %{comments: []})

      assert CommonChanges.changeset_field_empty?(changeset, :comments)
    end
  end

  describe "changeset_field_nil?: " do
    test "returns false if changeset field is in data" do
      changeset = Post.changeset(%Post{title: "title"}, %{})

      refute CommonChanges.changeset_field_nil?(changeset, :title)
    end

    test "returns true if changeset field is not in changes" do
      changeset = Post.changeset(%Post{}, %{})

      assert CommonChanges.changeset_field_nil?(changeset, :title)
    end

    test "returns true if changeset field is in changes is nil" do
      changeset = Post.changeset(%Post{}, %{title: nil})

      assert CommonChanges.changeset_field_nil?(changeset, :title)
    end

    test "returns false if changeset field is in changes is nil and is a has_many association" do
      changeset = Post.changeset(%Post{}, %{comments: nil})

      refute CommonChanges.changeset_field_nil?(changeset, :comments)
    end
  end

  describe "preload_changeset_assoc: " do
    test "can preload belongs_to relationship" do
      assert {:ok, post} = Actions.create(Post, %{title: "created_title"})

      post_id = post.id

      assert {:ok, comment} =
               %Comment{}
               |> Comment.changeset(%{body: "created_body", post_id: post_id})
               |> Repo.insert()

      comment_id = comment.id

      changeset =
        comment
        |> Comment.changeset(%{
          post: %{
            id: post_id,
            title: "updated_title"
          }
        })
        |> CommonChanges.preload_changeset_assoc(:post)

      assert %Changeset{
               action: nil,
               changes: %{},
               data: %Comment{
                 id: ^comment_id,
                 body: "created_body",
                 post: %Post{
                   id: ^post_id
                 }
               },
               errors: [],
               valid?: true
             } = changeset
    end

    test "can preload has_many relationship" do
      assert {:ok, post} = Actions.create(Post, %{title: "created_title"})

      post_id = post.id

      assert {:ok, comment} =
               %Comment{}
               |> Comment.changeset(%{body: "created_body", post_id: post_id})
               |> Repo.insert()

      comment_id = comment.id

      changeset =
        post
        |> Post.changeset(%{
          comments: [
            %{
              id: comment_id,
              body: "updated_body"
            }
          ]
        })
        |> CommonChanges.preload_changeset_assoc(:comments)

      assert %Changeset{
               action: nil,
               changes: %{},
               data: %Post{
                 id: ^post_id,
                 comments: [
                   %Comment{
                     id: ^comment_id
                   }
                 ]
               },
               valid?: true
             } = changeset
    end

    test "can preload many_to_many relationship" do
      assert {:ok, post} = Actions.create(Post, %{title: "created_title"})

      post_id = post.id

      assert {:ok, user} =
               %User{}
               |> User.changeset(%{email: "created_email"})
               |> Changeset.put_assoc(:posts, [post])
               |> Repo.insert()

      user_id = user.id

      changeset =
        post
        |> Post.changeset(%{
          authors: [
            %{
              id: user_id,
              email: "updated_email"
            }
          ]
        })
        |> CommonChanges.preload_changeset_assoc(:authors)

      assert %Changeset{
               action: nil,
               changes: %{},
               data: %Post{
                 id: ^post_id,
                 authors: [
                   %User{id: ^user_id}
                 ]
               },
               valid?: true
             } = changeset
    end

    test "when option :ids set can preload has_many relationship" do
      assert {:ok, post} = Actions.create(Post, %{title: "created_title"})

      post_id = post.id

      assert {:ok, comment_1} =
               %Comment{}
               |> Comment.changeset(%{body: "comment_1_created_body", post_id: post_id})
               |> Repo.insert()

      assert {:ok, comment_2} =
               %Comment{}
               |> Comment.changeset(%{body: "comment_2_created_body", post_id: post_id})
               |> Repo.insert()

      comment_1_id = comment_1.id

      comment_2_id = comment_2.id

      changeset =
        post
        |> Post.changeset(%{
          comments: [
            %{
              id: comment_1_id,
              body: "comment_1_updated_body"
            }
          ]
        })
        |> CommonChanges.preload_changeset_assoc(:comments, ids: [comment_1_id, comment_2_id])

      assert %Changeset{
               action: nil,
               changes: %{},
               data: %Post{
                 id: ^post_id,
                 comments: [
                   %Comment{id: ^comment_1_id},
                   %Comment{id: ^comment_2_id}
                 ]
               },
               valid?: true
             } = changeset
    end

    test "when option :ids set can preload many_to_many relationship" do
      assert {:ok, post} = Actions.create(Post, %{title: "created_title"})

      post_id = post.id

      assert {:ok, user_1} =
               %User{}
               |> User.changeset(%{email: "user_1_created_email"})
               |> Changeset.put_assoc(:posts, [post])
               |> Repo.insert()

      user_1_id = user_1.id

      assert {:ok, user_2} =
               %User{}
               |> User.changeset(%{email: "user_2_created_email"})
               |> Changeset.put_assoc(:posts, [post])
               |> Repo.insert()

      user_2_id = user_2.id

      changeset =
        post
        |> Post.changeset(%{authors: [%{id: user_1_id, email: "user_1_updated_email"}]})
        |> CommonChanges.preload_changeset_assoc(:authors, ids: [user_1_id, user_2_id])

      assert %Changeset{
               action: nil,
               changes: %{},
               data: %Post{
                 id: ^post_id,
                 authors: authors
               },
               valid?: true
             } = changeset

      assert [
               %User{id: ^user_1_id},
               %User{id: ^user_2_id}
             ] = authors
    end

    test "when option :ids set raises if the association does not exist" do
      assert {:ok, post} = Actions.create(Post, %{title: "title"})

      assert_raise ArgumentError,
                   "schema EctoShorts.Schemas.Post does not have association or embed :non_existent_association",
                   fn ->
                     post
                     |> Post.changeset(%{})
                     |> CommonChanges.preload_changeset_assoc(:non_existent_association, ids: [1])
                   end
    end
  end

  describe "put_or_cast_assoc: " do
    test "returns changeset without changes when assoc is nil" do
      params = %{}

      changeset =
        %Comment{}
        |> Comment.changeset(params)
        |> CommonChanges.put_or_cast_assoc(:post)

      assert %Ecto.Changeset{
               action: nil,
               changes: changes,
               data: %Comment{},
               errors: [],
               valid?: true
             } = changeset

      assert %{} === changes
    end

    test "preloads and puts associations when changeset params has ids" do
      assert {:ok, existing_comment} = Actions.create(Comment, %{})

      params = %{comments: [%{id: existing_comment.id}]}

      changeset =
        %Post{}
        |> Post.changeset(params)
        |> CommonChanges.put_or_cast_assoc(:comments)

      assert %Ecto.Changeset{
               action: nil,
               changes: changes,
               data: %Post{},
               errors: [],
               params: params,
               valid?: true
             } = changeset

      assert %{
               comments: [
                 %Ecto.Changeset{
                   action: :update,
                   changes: %{},
                   data: ^existing_comment,
                   errors: [],
                   valid?: true
                 }
               ]
             } = changes

      assert %{"comments" => [%{id: existing_comment.id}]} === params
    end

    test "raises an error if the given key is not a valid association" do
      assert_raise ArgumentError,
                   "expected `tags` to be an assoc in `cast_assoc`, got: `{:array, :string}`",
                   fn ->
                     %Comment{}
                     |> Changeset.change(%{})
                     |> CommonChanges.put_or_cast_assoc(:tags)
                   end
    end

    test "raises an error if the key is not a type of ecto changeset queryable" do
      assert_raise ArgumentError,
                   "key not found in schema EctoShorts.Schemas.Comment associations, got: :invalid_association",
                   fn ->
                     %Comment{}
                     |> Comment.changeset(%{invalid_association: [%{id: 1}]})
                     |> CommonChanges.put_or_cast_assoc(:invalid_association)
                   end
    end
  end
end
