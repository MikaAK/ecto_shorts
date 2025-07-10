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
    Book,
    PostHasTupleFieldSource,
    Post,
    User,
    UserData
  }

  describe "put_new_change: " do
    test "adds change if it does not exist" do
      assert %Changeset{changes: %{title: "should_see_this"}}

      %Post{}
      |> Post.changeset(%{})
      |> CommonChanges.put_new_change(:title, fn -> "should_see_this" end)
    end

    test "does not replace existing change" do
      changeset = Post.changeset(%Post{}, %{title: "post_title"})
      assert %Changeset{changes: %{title: "post_title"}} = changeset
      assert changeset === CommonChanges.put_new_change(changeset, :title, "should_not_see_this")
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
    test "can preload and put assocs if change exists" do
      post = Testing.insert!(Repo, Post, %{title: "title"})
      comment = Testing.insert!(Repo, Comment, %{post_id: post.id})

      new_comment = Testing.insert!(Repo, Comment)

      changeset = Post.changeset(post, %{comments: [%{id: new_comment.id}]})

      assert %Ecto.Changeset{data: changeset_post, valid?: true} =
               CommonChanges.preload_change_assoc(changeset, :comments)

      assert %Post{comments: [^comment]} = changeset_post
    end

    test "can preload and cast assocs if change exists" do
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

  describe "preload_changeset: " do
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

    test "can put assocs" do
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
  end

  describe "put_or_cast_assoc: " do
    test "cast assoc when assoc params is an empty map" do
      assert %Ecto.Changeset{
               action: nil,
               data: %Post{},
               changes: %{
                 author: %Ecto.Changeset{
                   action: :insert,
                   data: %User{},
                   changes: %{},
                   params: %{},
                   valid?: true
                 }
               },
               params: %{"author" => %{}},
               valid?: true
             } =
               %Post{}
               |> Post.changeset(%{author: %{}})
               |> CommonChanges.put_or_cast_assoc(:author)
    end

    test "cast assoc when assoc params is an empty list" do
      assert %Ecto.Changeset{
               action: nil,
               data: %Post{},
               changes: %{comments: []},
               params: %{"comments" => []},
               valid?: true
             } =
               %Post{}
               |> Post.changeset(%{comments: []})
               |> CommonChanges.put_or_cast_assoc(:comments)
    end

    test "cast assoc from map params" do
      assert %Ecto.Changeset{
               action: nil,
               data: %Post{},
               changes: %{
                 author: %Ecto.Changeset{
                   action: :insert,
                   data: %User{},
                   changes: %{first_name: "author_first_name"},
                   params: %{"first_name" => "author_first_name"},
                   valid?: true
                 }
               },
               params: %{"author" => %{first_name: "author_first_name"}},
               valid?: true
             } =
               %Post{}
               |> Post.changeset(%{author: %{first_name: "author_first_name"}})
               |> CommonChanges.put_or_cast_assoc(:author)
    end

    test "cast assoc from list of map params" do
      assert %Ecto.Changeset{
               action: nil,
               data: %Post{},
               changes: %{
                 comments: [
                   %Ecto.Changeset{
                     action: :insert,
                     data: %Comment{},
                     changes: %{body: "comment_body"},
                     params: %{"body" => "comment_body"},
                     valid?: true
                   }
                 ]
               },
               params: %{"comments" => [%{body: "comment_body"}]},
               valid?: true
             } =
               %Post{}
               |> Post.changeset(%{comments: [%{body: "comment_body"}]})
               |> CommonChanges.put_or_cast_assoc(:comments)
    end

    test "when parent data not yet persisted: put assoc from existing structs" do
      comment = Testing.insert!(Repo, Comment)

      changeset =
        %Post{}
        |> Post.changeset(%{comments: [comment]})
        |> CommonChanges.put_or_cast_assoc(:comments)

      assert %Ecto.Changeset{
               action: nil,
               changes: %{
                 comments: [
                   %Ecto.Changeset{
                     action: :update,
                     data: ^comment,
                     params: nil,
                     valid?: true
                   }
                 ]
               },
               data: %Post{},
               errors: [],
               params: %{"comments" => [^comment]},
               valid?: true
             } = changeset
    end

    test "when parent data not yet persisted: put assoc given only a list of IDs for an association" do
      comment = Testing.insert!(Repo, Comment)

      comment_id = comment.id

      changeset =
        %Post{}
        |> Post.changeset(%{comments: [%{id: comment_id}]})
        |> CommonChanges.put_or_cast_assoc(:comments)

      assert %Ecto.Changeset{
               action: nil,
               changes: %{
                 comments: [
                   %Ecto.Changeset{
                     action: :update,
                     data: ^comment,
                     params: nil,
                     valid?: true
                   }
                 ]
               },
               data: %Post{},
               errors: [],
               params: %{"comments" => [%{id: ^comment_id}]},
               valid?: true
             } = changeset
    end

    test "put assoc from structs without IDs" do
      book_1 = Testing.insert!(Repo, Book, %{title: "book_title_1"})
      book_2 = Testing.insert!(Repo, Book, %{title: "book_title_2"})

      changeset =
        %User{}
        |> User.changeset(%{books: [book_1, book_2]})
        |> CommonChanges.put_or_cast_assoc(:books)

      assert %Ecto.Changeset{
               action: nil,
               changes: %{
                 books: [
                   %Ecto.Changeset{
                     action: :update,
                     data: ^book_2,
                     params: nil,
                     valid?: true
                   },
                   %Ecto.Changeset{
                     action: :update,
                     data: ^book_1,
                     params: nil,
                     valid?: true
                   }
                 ]
               },
               data: %User{},
               errors: [],
               params: %{"books" => [^book_1, ^book_2]},
               valid?: true
             } = changeset
    end

    test "calls put assoc to remove an assoc when assoc param is nil" do
      user = Testing.insert!(Repo, User)

      book =
        Repo
        |> Testing.insert!(Book, %{author_id: user.id})
        |> Repo.preload(:author)

      changeset =
        book
        |> Book.changeset(%{author: nil})
        |> CommonChanges.put_or_cast_assoc(:author)

      assert %Ecto.Changeset{
               action: nil,
               changes: %{
                 author: nil
               },
               data: ^book,
               errors: [],
               params: %{"author" => nil},
               valid?: true
             } = changeset
    end

    test "calls put assoc to remove an assoc when assoc param is an empty list" do
      post = Testing.insert!(Repo, Post)
      comment = Testing.insert!(Repo, Comment, %{post_id: post.id})

      post = Repo.preload(post, :comments)

      changeset =
        post
        |> Post.changeset(%{comments: []})
        |> CommonChanges.put_or_cast_assoc(:comments)

      assert %Ecto.Changeset{
               action: nil,
               changes: %{
                 comments: [
                   %Changeset{
                     action: :replace,
                     data: ^comment,
                     valid?: true
                   }
                 ]
               },
               data: ^post,
               errors: [],
               params: %{"comments" => []},
               valid?: true
             } = changeset
    end
  end
end
