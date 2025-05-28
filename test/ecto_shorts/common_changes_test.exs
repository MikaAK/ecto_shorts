defmodule EctoShorts.CommonChangesTest do
  alias EctoShorts.Schemas.CommentAbstract
  alias EctoShorts.Schemas.PostAbstract
  use EctoShorts.DataCase, async: true
  doctest EctoShorts.CommonChanges

  alias Ecto.Changeset

  alias EctoShorts.{
    CommonChanges,
    Repo,
    Schemas.Comment,
    Schemas.Post,
    Schemas.User,
    Testing
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

  describe "preload_change_assoc" do
    test "preloads a has_many association where the field on the schema is represented by a {source, schema} tuple" do
      post = Testing.insert!(Repo, {"posts", PostAbstract}, %{title: "title"})

      comment = Testing.insert!(Repo, {"comments", CommentAbstract}, %{post_id: post.id})

      assert %PostAbstract{comments: %Ecto.Association.NotLoaded{}} = post

      assert %Ecto.Changeset{data: changeset_post, valid?: true} =
               post
               |> PostAbstract.changeset(%{comments: [%{id: comment.id}]})
               |> CommonChanges.preload_change_assoc(:comments)

      assert %PostAbstract{comments: [^comment]} = changeset_post
    end
  end

  describe "preload_changeset_assoc: " do
    test "can preload belongs_to relationship" do
      post = Testing.insert!(Repo, Post, %{title: "title"})

      post_id = post.id

      assert {:ok, comment} =
               %Comment{}
               |> Comment.changeset(%{body: "body", post_id: post_id})
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
                 body: "body",
                 post: %Post{
                   id: ^post_id
                 }
               },
               errors: [],
               valid?: true
             } = changeset
    end

    test "can preload has_many relationship" do
      post = Testing.insert!(Repo, Post, %{title: "title"})

      post_id = post.id

      assert {:ok, comment} =
               %Comment{}
               |> Comment.changeset(%{body: "body", post_id: post_id})
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
      post = Testing.insert!(Repo, Post, %{title: "title"})

      post_id = post.id

      assert {:ok, user} =
               %User{}
               |> User.changeset(%{email: "email"})
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

    test "preloads a has_many association where the field on the schema is represented by a {source, schema} tuple" do
      post = Testing.insert!(Repo, {"posts", PostAbstract}, %{title: "title"})

      comment = Testing.insert!(Repo, {"comments", CommentAbstract}, %{post_id: post.id})

      assert %PostAbstract{comments: %Ecto.Association.NotLoaded{}} = post

      assert %Ecto.Changeset{data: changeset_post, valid?: true} =
               post
               |> PostAbstract.changeset(%{comments: [%{id: comment.id}]})
               |> CommonChanges.preload_changeset_assoc(:comments)

      assert %PostAbstract{comments: [^comment]} = changeset_post
    end

    test "when option :ids set can preload has_many relationship" do
      post = Testing.insert!(Repo, Post, %{title: "title"})

      post_id = post.id

      assert {:ok, comment_1} =
               %Comment{}
               |> Comment.changeset(%{body: "comment_body_1", post_id: post_id})
               |> Repo.insert()

      assert {:ok, comment_2} =
               %Comment{}
               |> Comment.changeset(%{body: "comment_body_2", post_id: post_id})
               |> Repo.insert()

      comment_1_id = comment_1.id

      comment_2_id = comment_2.id

      changeset =
        post
        |> Post.changeset(%{
          comments: [
            %{
              id: comment_1_id,
              body: "comment_body_1_updated"
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
      post = Testing.insert!(Repo, Post, %{title: "title"})

      post_id = post.id

      assert {:ok, user_1} =
               %User{}
               |> User.changeset(%{email: "user_1_email"})
               |> Changeset.put_assoc(:posts, [post])
               |> Repo.insert()

      user_1_id = user_1.id

      assert {:ok, user_2} =
               %User{}
               |> User.changeset(%{email: "user_2_email"})
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
      post = Testing.insert!(Repo, Post, %{title: "title"})

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

    test "uses cast_assoc when given maps for a new association in an unpersisted parent changeset" do
      post = Testing.insert!(Repo, Post, %{title: "post_title"})
      comment_a = Testing.insert!(Repo, Comment, %{post_id: post.id})
      comment_b = Testing.insert!(Repo, Comment, %{post_id: post.id})

      changeset =
        %Post{}
        |> Post.changeset(%{
          comments: [
            %{id: comment_a.id},
            %{id: comment_b.id, body: "updated_body"}
          ]
        })
        |> CommonChanges.put_or_cast_assoc(:comments)

      assert %Ecto.Changeset{
               action: nil,
               changes: changes,
               data: data,
               errors: [],
               params: params,
               valid?: true
             } = changeset

      assert %Post{id: nil, comments: [^comment_a, ^comment_b]} = data

      assert %{
               comments: [
                 %Ecto.Changeset{action: :update, data: ^comment_a, valid?: true},
                 %Ecto.Changeset{
                   action: :update,
                   data: ^comment_b,
                   changes: %{body: "updated_body"},
                   valid?: true
                 }
               ]
             } = changes

      assert %{"comments" => [%{id: comment_a.id}, %{id: comment_b.id, body: "updated_body"}]} ===
               params
    end

    test "uses cast_assoc when given a primary key and params for a new association in an unpersisted parent changeset" do
      post = Testing.insert!(Repo, Post, %{title: "post_title"})
      comment = Testing.insert!(Repo, Comment, %{post_id: post.id})

      changeset =
        %Post{}
        |> Post.changeset(%{comments: [%{id: comment.id, body: "updated_body"}]})
        |> CommonChanges.put_or_cast_assoc(:comments)

      assert %Ecto.Changeset{
               action: nil,
               changes: changes,
               data: data,
               errors: [],
               params: params,
               valid?: true
             } = changeset

      assert %Post{id: nil, comments: [^comment]} = data

      assert %{
               comments: [
                 %Ecto.Changeset{data: ^comment, changes: %{body: "updated_body"}, valid?: true}
               ]
             } = changes

      assert %{"comments" => [%{id: comment.id, body: "updated_body"}]} === params
    end

    test "uses put_assoc when given only structs" do
      post = Testing.insert!(Repo, Post, %{title: "post_title"})
      comment = Testing.insert!(Repo, Comment, %{post_id: post.id})

      changeset =
        %Post{}
        |> Post.changeset(%{comments: [comment]})
        |> CommonChanges.put_or_cast_assoc(:comments)

      assert %Ecto.Changeset{
               action: nil,
               changes: changes,
               data: data,
               errors: [],
               params: params,
               valid?: true
             } = changeset

      assert %Post{id: nil, comments: %Ecto.Association.NotLoaded{}} = data
      assert %{comments: [%Ecto.Changeset{data: ^comment, valid?: true}]} = changes
      assert %{"comments" => [comment]} === params
    end

    test "uses put_assoc when given only a primary key for an association in an unpersisted parent changeset" do
      post = Testing.insert!(Repo, Post, %{title: "post_title"})
      comment = Testing.insert!(Repo, Comment, %{post_id: post.id})

      changeset =
        %Post{}
        |> Post.changeset(%{comments: [%{id: comment.id}]})
        |> CommonChanges.put_or_cast_assoc(:comments)

      assert %Ecto.Changeset{
               action: nil,
               changes: changes,
               data: data,
               errors: [],
               params: params,
               valid?: true
             } = changeset

      assert %Post{id: nil, comments: []} = data
      assert %{comments: [%Ecto.Changeset{data: comment, valid?: true}]} = changes
      assert %{"comments" => [%{id: comment.id}]} === params
    end

    test "uses put_assoc to associate existing record when parent is persisted, association is not preloaded, and only primary keys are provided" do
      post = Testing.insert!(Repo, Post, %{title: "post_title"})
      comment = Testing.insert!(Repo, Comment, %{post_id: post.id})

      changeset =
        post
        |> Post.changeset(%{comments: [%{id: comment.id}]})
        |> CommonChanges.put_or_cast_assoc(:comments)

      assert %Ecto.Changeset{
               action: nil,
               changes: changes,
               data: data,
               errors: [],
               params: params,
               valid?: true
             } = changeset

      assert %Post{} = data
      assert post.id === data.id
      assert [comment] === data.comments

      assert %{} === changes
      assert %{"comments" => [%{id: comment.id}]} === params
    end

    test "before put_assoc, loads only the associated record belonging to the parent when not preloaded and only primary key is provided" do
      post = Testing.insert!(Repo, Post, %{title: "post_title"})
      comment = Testing.insert!(Repo, Comment, %{post_id: post.id})

      assert another_post = Testing.insert!(Repo, Post, %{title: "post_title"})
      assert _another_comment = Testing.insert!(Repo, Comment, %{post_id: another_post.id})

      changeset =
        post
        |> Post.changeset(%{comments: [%{id: comment.id}]})
        |> CommonChanges.put_or_cast_assoc(:comments)

      assert %Ecto.Changeset{data: %Post{comments: [^comment]}} = changeset
    end

    test "before cast_assoc, loads only the associated record belonging to the parent when not preloaded and only primary key is provided" do
      post = Testing.insert!(Repo, Post, %{title: "post_title"})
      comment = Testing.insert!(Repo, Comment, %{post_id: post.id})

      assert another_post = Testing.insert!(Repo, Post, %{title: "post_title"})
      assert _another_comment = Testing.insert!(Repo, Comment, %{post_id: another_post.id})

      changeset =
        post
        |> Post.changeset(%{comments: [%{id: comment.id, body: "updated_body"}]})
        |> CommonChanges.put_or_cast_assoc(:comments)

      assert %Ecto.Changeset{data: %Post{comments: [^comment]}} = changeset
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
                   "association :invalid_association not found in the changeset for schema EctoShorts.Schemas.Comment",
                   fn ->
                     %Comment{}
                     |> Comment.changeset(%{invalid_association: [%{id: 1}]})
                     |> CommonChanges.put_or_cast_assoc(:invalid_association)
                   end
    end
  end
end
