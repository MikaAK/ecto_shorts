defmodule EctoShorts.CommonChangesTest do
  use EctoShorts.DataCase
  doctest EctoShorts.CommonChanges

  alias Ecto.Changeset

  alias EctoShorts.{
    CommonChanges,
    Repo,
    Testing
  }

  alias EctoShorts.Schemas.{
    Comment,
    CommentAbstract,
    CompositePrimaryKey,
    PostHasTupleFieldSource,
    Post,
    User,
    UserData
  }

  describe "changes_has_key?: " do
    test "returns true when change exists" do
      assert %Post{}
             |> Post.changeset(%{title: "post_title"})
             |> CommonChanges.changes_has_key?(:title)
    end

    test "returns false when change does not exist" do
      refute %Post{}
             |> Post.changeset(%{title: "post_title"})
             |> CommonChanges.changes_has_key?(:does_not_exist)
    end
  end

  describe "put_new_change: " do
    test "adds change if it does not exist" do
      assert %Changeset{changes: %{title: "should_see_this"}}

      %Post{}
      |> Post.changeset(%{})
      |> CommonChanges.put_new_change(:title, fn -> "should_see_this" end)
    end

    test "does not replace existing change" do
      assert %Changeset{changes: %{title: "existing_title"}}

      %Post{}
      |> Post.changeset(%{title: "existing_title"})
      |> CommonChanges.put_new_change(:title, "should_not_see_this")
    end
  end

  describe "changeset_change_empty?: " do
    test "returns false if the change field is not a map or list " do
      refute %Post{}
             |> Post.changeset(%{title: "post_title"})
             |> CommonChanges.changeset_change_empty?(:title)
    end

    test "returns true if change is an empty list" do
      assert %Post{}
             |> Post.changeset(%{tags: []})
             |> CommonChanges.changeset_change_empty?(:tags)
    end

    test "returns true if change is an empty map" do
      assert %UserData{}
             |> UserData.changeset(%{data: %{}})
             |> CommonChanges.changeset_change_empty?(:data)
    end
  end

  describe "changeset_field_empty?: " do
    test "returns false if the change field is not a map or list " do
      refute %Post{title: "post_title"}
             |> Post.changeset(%{})
             |> CommonChanges.changeset_field_empty?(:title)
    end

    test "returns true if change is an empty list" do
      assert %Post{tags: []}
             |> Post.changeset(%{})
             |> CommonChanges.changeset_field_empty?(:tags)
    end

    test "returns true if change is an empty map" do
      assert %UserData{data: %{}}
             |> UserData.changeset(%{})
             |> CommonChanges.changeset_field_empty?(:data)
    end
  end

  describe "changeset_change_nil?: " do
    test "returns true if the change key exists and the value is nil" do
      assert %Post{}
             |> Post.changeset(%{title: nil})
             |> CommonChanges.changeset_change_nil?(:title)
    end

    test "returns false if the change key exists and the value is not nil" do
      refute %Post{}
             |> Post.changeset(%{title: "post_title"})
             |> CommonChanges.changeset_change_nil?(:title)
    end
  end

  describe "truncate_naive_datetime_change: " do
    test "truncates a datetime field change" do
      assert %Changeset{changes: %{published_at: ~U[2025-06-07 19:03:07Z]}} =
               %Post{}
               |> Post.changeset(%{published_at: ~U[2025-06-07 19:03:07.395700Z]})
               |> CommonChanges.truncate_datetime_change(:published_at)
    end

    test "truncates a naive datetime field change" do
      assert %Changeset{changes: %{published_at: ~N[2025-06-07 19:03:07]}} =
               %Comment{}
               |> Comment.changeset(%{published_at: ~N[2025-06-07 19:03:07.395700]})
               |> CommonChanges.truncate_datetime_change(:published_at)
    end

    test "does not truncate value if it's not a datetime or naive datetime" do
      assert %Changeset{changes: %{published_at: nil}} =
               %Comment{published_at: ~N[2025-06-07 19:03:07]}
               |> Comment.changeset(%{published_at: nil})
               |> CommonChanges.truncate_datetime_change(:published_at)
    end
  end

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
    test "can preload and put associations if change exists" do
      post = Testing.insert!(Repo, PostHasTupleFieldSource, %{title: "title"})

      comment = Testing.insert!(Repo, {"comments", CommentAbstract}, %{post_id: post.id})

      assert %PostHasTupleFieldSource{comments: %Ecto.Association.NotLoaded{}} = post

      changeset = PostHasTupleFieldSource.changeset(post, %{comments: [%{id: comment.id}]})

      assert %Ecto.Changeset{data: changeset_post, valid?: true} =
               CommonChanges.preload_change_assoc(changeset, :comments)

      assert %PostHasTupleFieldSource{comments: [^comment]} = changeset_post
    end

    test "can preload and cast associations if change exists" do
      changeset =
        Changeset.cast(
          %PostHasTupleFieldSource{},
          %{comments: [%{id: 123_456, body: "comment_body"}]},
          [:title]
        )

      assert %Ecto.Changeset{valid?: true} =
               CommonChanges.preload_change_assoc(changeset, :comments)
    end

    test "marks association as required when using required_when_missing and the key does not exist" do
      assert %Changeset{
               errors: [post: {"can't be blank", [validation: :required]}],
               valid?: false
             } =
               %Comment{}
               |> Changeset.cast(%{}, [])
               |> CommonChanges.preload_change_assoc(:post, required_when_missing: :post_id)
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

    test "can put associations" do
      post = Testing.insert!(Repo, PostHasTupleFieldSource, %{title: "title"})

      comment = Testing.insert!(Repo, {"comments", CommentAbstract}, %{post_id: post.id})

      assert %PostHasTupleFieldSource{comments: %Ecto.Association.NotLoaded{}} = post

      assert %Ecto.Changeset{data: changeset_post, valid?: true} =
               post
               |> PostHasTupleFieldSource.changeset(%{comments: [%{id: comment.id}]})
               |> CommonChanges.preload_changeset_assoc(:comments)

      assert %PostHasTupleFieldSource{comments: [^comment]} = changeset_post
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

  describe "cast_assoc/4" do
    test "can find one association and put association given map with id" do
      user = Testing.insert!(Repo, User, %{})

      assert %Changeset{
               data: %Post{author: ^user},
               changes: %{
                 author: %Changeset{
                   data: ^user,
                   changes: %{
                     first_name: "user_first_name"
                   }
                 }
               }
             } =
               %Post{}
               |> Post.changeset()
               |> CommonChanges.cast_assoc(
                 :author,
                 %{id: user.id, first_name: "user_first_name"},
                 []
               )
    end

    test "creates a changeset for new record if record matching id not found" do
      assert %Changeset{
               data: %Post{author: %Ecto.Association.NotLoaded{}},
               changes: %{
                 author: %Changeset{
                   data: %User{id: nil},
                   changes: %{
                     id: 123_456,
                     first_name: "user_first_name"
                   }
                 }
               }
             } =
               %Post{}
               |> Post.changeset()
               |> CommonChanges.cast_assoc(
                 :author,
                 %{
                   id: 123_456,
                   first_name: "user_first_name"
                 },
                 []
               )
    end
  end

  describe "put_assoc/4" do
    test "can put assoc for schema with composite keys" do
      post = Testing.insert!(Repo, Post, %{})
      comment = Testing.insert!(Repo, Comment, %{post_id: post.id})

      composite_primary_key =
        Testing.insert!(Repo, CompositePrimaryKey, %{post_id: post.id, comment_id: comment.id})
        |> IO.inspect()

      assert %Changeset{
               changes: %{composite_primary_keys: [%Changeset{data: ^composite_primary_key}]}
             } =
               %Post{}
               |> Post.changeset(%{})
               |> CommonChanges.put_assoc(:composite_primary_keys, [
                 %{
                   comment_id: composite_primary_key.comment_id,
                   post_id: composite_primary_key.post_id
                 }
               ])
    end

    test "can find one association and put association given map with id" do
      user = Testing.insert!(Repo, User, %{})

      assert %Changeset{changes: %{author: %Changeset{data: ^user}}} =
               %Post{}
               |> Post.changeset(%{})
               |> CommonChanges.put_assoc(:author, %{id: user.id})
    end

    test "returns changeset with nil association when given map with id that does not exist" do
      assert %Changeset{data: %Post{author: nil}} =
               %Post{}
               |> Post.changeset(%{})
               |> CommonChanges.put_assoc(:author, %{id: 123_456})
    end

    test "can find many associations and put association given maps with id" do
      user = Testing.insert!(Repo, User, %{})

      assert %Changeset{changes: %{authors: [%Changeset{data: ^user}]}} =
               %Post{}
               |> Post.changeset(%{})
               |> CommonChanges.put_assoc(:authors, [%{id: user.id}])
    end

    test "can put association given schema data" do
      user = Testing.insert!(Repo, User, %{})

      assert %Changeset{changes: %{author: %Changeset{data: ^user}}} =
               %Post{}
               |> Post.changeset(%{})
               |> CommonChanges.put_assoc(:author, user)
    end

    test "can put many associations given a list of schema data" do
      user = Testing.insert!(Repo, User, %{})

      assert %Changeset{changes: %{authors: [%Changeset{data: ^user}]}} =
               %Post{}
               |> Post.changeset(%{})
               |> CommonChanges.put_assoc(:authors, [user])
    end

    test "raises if not a direct schema association" do
      author = Testing.insert!(Repo, User, %{})

      message =
        "association :comments_authors not found in the changeset for schema EctoShorts.Schemas.Post"

      assert_raise ArgumentError, message, fn ->
        %Post{}
        |> Post.changeset(%{})
        |> CommonChanges.put_assoc(:comments_authors, [author])
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

    test "uses cast_assoc when data is not created data" do
      changeset =
        %Comment{}
        |> Comment.changeset(%{post: %{title: "post_title"}})
        |> CommonChanges.put_or_cast_assoc(:post)

      assert %Ecto.Changeset{
               action: nil,
               changes: changes,
               data: data,
               errors: [],
               params: params,
               valid?: true
             } = changeset

      assert %Comment{} === data

      assert %{
               post: %Ecto.Changeset{
                 action: :insert,
                 data: %Post{},
                 changes: %{title: "post_title"}
               }
             } = changes

      assert %{"post" => %{title: "post_title"}} === params
    end

    test "uses put_assoc when data is created data" do
      post = Testing.insert!(Repo, Post, %{title: "post_title"})

      changeset =
        %Comment{}
        |> Comment.changeset(%{post: post})
        |> CommonChanges.put_or_cast_assoc(:post)

      assert %Ecto.Changeset{
               action: nil,
               changes: changes,
               data: data,
               errors: [],
               valid?: true
             } = changeset

      assert %Comment{} === data

      assert %{
               post: %Ecto.Changeset{
                 action: :update,
                 data: ^post
               }
             } = changes
    end

    test "uses cast_assoc when given maps and data is a list" do
      changeset =
        %Post{}
        |> Post.changeset(%{comments: [%{body: "comment_body"}]})
        |> CommonChanges.put_or_cast_assoc(:comments)

      assert %Ecto.Changeset{
               action: nil,
               changes: changes,
               data: data,
               errors: [],
               params: params,
               valid?: true
             } = changeset

      assert %Post{} === data

      assert %{
               comments: [
                 %Ecto.Changeset{
                   action: :insert,
                   data: %Comment{},
                   changes: %{body: "comment_body"}
                 }
               ]
             } = changes

      assert %{"comments" => [%{body: "comment_body"}]} === params
    end

    test "uses cast_assoc when given maps with ids and data is a list" do
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

    test "uses cast_assoc when given a primary key and params with ids and data is a list" do
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

    test "uses put_assoc when given only structs and data is a list" do
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

    test "uses put_assoc when given only a primary key for an association and data is a list" do
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

    test "uses put_assoc to associate existing record when parent is persisted, association is not preloaded, and only primary keys are provided and data is a list" do
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

    test "before put_assoc, loads only the associated record belonging to the parent when not preloaded and only primary key is provided and data is a list" do
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

    test "before cast_assoc, loads only the associated record belonging to the parent when not preloaded and only primary key is provided and data is a list" do
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

  describe "change/2: " do
    test "returns changeset as-is when params is empty map" do
      changeset = Post.changeset(%Post{}, %{title: "post_title"})
      assert changeset === CommonChanges.change(changeset, %{})
    end

    test "returns changeset as-is when params is empty list" do
      changeset = Post.changeset(%Post{}, %{title: "post_title"})
      assert changeset === CommonChanges.change(changeset, [])
    end

    test "applies changes to changeset given changeset and params" do
      changeset = Post.changeset(%Post{}, %{title: "post_title"})

      assert %Changeset{changes: %{title: "new_title"}} =
               CommonChanges.change(changeset, %{title: "new_title"})
    end

    test "applies changes to changeset given struct and params" do
      assert %Changeset{changes: %{title: "post_title"}} =
               CommonChanges.change(%Post{}, %{title: "post_title"})
    end

    test "applies changes to changeset given schema and params" do
      assert %Changeset{changes: %{title: "post_title"}} =
               CommonChanges.change(Post, %{title: "post_title"})
    end
  end

  describe "change/3: " do
    test "creates changeset with changes given changeset" do
      changeset = Post.changeset(%Post{}, %{published: true})

      assert %Changeset{changes: %{published: true, title: "post_title"}} =
               CommonChanges.change(Post, changeset, %{title: "post_title"})
    end

    test "creates changeset with changes given struct" do
      assert %Changeset{changes: %{title: "post_title"}} =
               CommonChanges.change(Post, %Post{}, %{title: "post_title"})
    end

    test "builds changeset with changeset change function if module is not a schema module" do
      assert %Changeset{changes: %{title: "post_title"}} =
               CommonChanges.change(DoesNotExist, %Post{}, %{title: "post_title"})
    end
  end
end
