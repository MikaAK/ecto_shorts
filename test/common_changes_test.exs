defmodule EctoShorts.CommonChangesTest do
  use EctoShorts.DataCase

  alias EctoShorts.{Actions, CommonChanges}
  alias EctoShorts.Support.Schemas.{Comment, Post, User}

  describe "put_when: " do
    test "returns changeset without changes if evaluator function returns false" do
      when_func = fn _changeset -> false end

      change_func = fn changeset -> Ecto.Changeset.put_change(changeset, :title, "title") end

      changeset =
        %Post{}
        |> Post.changeset(%{})
        |> CommonChanges.put_when(when_func, change_func)

      assert %Ecto.Changeset{
        changes: changes,
        params: params
      } = changeset

      assert %{} === changes

      assert %{} === params
    end

    test "returns changeset with changes if evaluator function returns true" do
      when_func = fn _changeset -> true end

      change_func = fn changeset -> Ecto.Changeset.put_change(changeset, :title, "title") end

      changeset =
        %Post{}
        |> Post.changeset(%{})
        |> CommonChanges.put_when(when_func, change_func)

      assert %Ecto.Changeset{
        changes: changes
      } = changeset

      assert %{title: "title"} === changes
    end
  end

  describe "changeset_field_empty?: " do
    test "returns false if changeset field is not an empty list" do
      params = %{}

      changeset =
        %Post{}
        |> Post.changeset(params)
        |> Ecto.Changeset.put_assoc(:comments, [%{body: "body"}])

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

  describe "preload_change_assoc: " do
    test "returns given changeset if association does not exist" do
      assert {:ok, post} = Actions.create(Post, %{title: "title"})

      created_changeset = Post.changeset(post, %{})

      returned_changeset = CommonChanges.preload_change_assoc(created_changeset, :invalid_association)

      assert created_changeset === returned_changeset
    end

    test "can preload belongs_to relationship" do
      assert {:ok, post} = Actions.create(Post, %{title: "title"})

      post_id = post.id

      assert {:ok, comment} =
        %Comment{}
        |> Comment.changeset(%{body: "created_body", post_id: post_id})
        |> EctoShorts.Support.Repo.insert()

      comment_id = comment.id

      changeset =
        comment
        |> Comment.changeset(%{post: %{
          id: post_id,
          title: "updated_title"
        }})
        |> CommonChanges.preload_change_assoc(:post)

      assert %Ecto.Changeset{
        action: nil,
        changes: %{
          post: %Ecto.Changeset{
            action: :update,
            data: %Post{
              id: ^post_id
            },
            changes: %{title: "updated_title"},
            errors: [],
            params:  %{
              "id" => ^post_id,
              "title" => "updated_title"
            },
            valid?: true
          }
        },
        data: %Comment{
          id: ^comment_id,
          post: %Post{
            id: ^post_id
          }
        },
        valid?: true
      } = changeset
    end

    test "can preload has_many relationship" do
      assert {:ok, post} = Actions.create(Post, %{title: "title"})

      post_id = post.id

      assert {:ok, comment} =
        %Comment{}
        |> Comment.changeset(%{body: "created_body", post_id: post_id})
        |> EctoShorts.Support.Repo.insert()

      comment_id = comment.id

      changeset =
        post
        |> Post.changeset(%{comments: [
          %{
            id: comment_id,
            body: "updated_body"
          }
        ]})
        |> CommonChanges.preload_change_assoc(:comments)

      assert %Ecto.Changeset{
        action: nil,
        changes: %{
          comments: [
            %Ecto.Changeset{
              action: :update,
              data: %Comment{
                id: ^comment_id
              },
              changes: %{body: "updated_body"},
              errors: [],
              params:  %{
                "id" => ^comment_id,
                "body" => "updated_body"
              },
              valid?: true
            }
          ]
        },
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
      assert {:ok, post} = Actions.create(Post, %{title: "title"})

      post_id = post.id

      assert {:ok, user} =
        %User{}
        |> User.changeset(%{email: "email"})
        |> Ecto.Changeset.put_assoc(:posts, [post])
        |> EctoShorts.Support.Repo.insert()

      user_id = user.id

      changeset =
        post
        |> Post.changeset(%{users: [
          %{
            id: user_id,
            email: "updated_email"
          }
        ]})
        |> CommonChanges.preload_change_assoc(:users)

      assert %Ecto.Changeset{
        action: nil,
        changes: %{
          users: [
            %Ecto.Changeset{
              action: :update,
              data: %User{
                id: ^user_id
              },
              changes: %{email: "updated_email"},
              params: nil,
              valid?: true
            }
          ]
        },
        data: %Post{
          id: ^post_id,
          users: [
            %User{
              id: ^user_id
            }
          ]
        },
        params: %{
          "users" => [%{email: "updated_email", id: ^user_id}]
        },
        valid?: true
      } = changeset
    end

    test "preload many_to_many relationship does not load association if parameters not set" do
      assert {:ok, post} = Actions.create(Post, %{title: "title"})

      post_id = post.id

      changeset =
        post
        |> Post.changeset(%{})
        |> CommonChanges.preload_change_assoc(:users)

      assert %Ecto.Changeset{
        action: nil,
        changes: %{},
        data: %Post{
          id: ^post_id,
          users: %Ecto.Association.NotLoaded{}
        },
        params: %{},
        valid?: true
      } = changeset
    end

    test "creates association when no ID is provided" do
      assert {:ok, post} = Actions.create(Post, %{title: "created_post_title"})

      post_id = post.id

      changeset =
        post
        |> Post.changeset(%{comments: [%{body: "new_comment_body"}]})
        |> CommonChanges.preload_change_assoc(:comments)

      assert %Ecto.Changeset{
        action: nil,
        changes: %{
          comments: [
            %Ecto.Changeset{
              action: :insert,
              changes: %{body: "new_comment_body"},
              data: %Comment{},
              errors: [],
              valid?: true
            }
          ]
        },
        data: %Post{
          id: ^post_id,
          title: "created_post_title"
        },
        errors: [],
        valid?: true
      } = changeset
    end

    test "creates association when preload record not found by id " do
      assert {:ok, post} = Actions.create(Post, %{title: "created_post_title"})

      post_id = post.id

      assert {:ok, comment} =
        %Comment{}
        |> Comment.changeset(%{body: "created_body", post_id: post_id})
        |> EctoShorts.Support.Repo.insert()

      assert {:ok, deleted_comment} =
        comment
        |> Comment.changeset()
        |> EctoShorts.Support.Repo.delete()

      deleted_comment_id = deleted_comment.id

      changeset =
        post
        |> Post.changeset(%{
          comments: [
            %{
              id: deleted_comment_id,
              body: "new_comment_body"
            }
          ]
        })
        |> CommonChanges.preload_change_assoc(:comments)

      assert %Ecto.Changeset{
        action: nil,
        changes: %{
          comments: [
            %Ecto.Changeset{
              action: :insert,
              changes: %{body: "new_comment_body"},
              data: %Comment{},
              params: %{
                "body" => "new_comment_body",
                "id" => ^deleted_comment_id
              },
              errors: [],
              valid?: true
            }
          ]
        },
        data: %Post{
          id: ^post_id,
          title: "created_post_title"
        },
        params: %{
          "comments" => [
            %{body: "new_comment_body", id: ^deleted_comment_id}
          ]
        },
        errors: [],
        valid?: true
      } = changeset
    end

    test "changeset invalid when option :required is set and association does not exist in data or changes" do
      changeset =
        %Comment{}
        |> Comment.changeset(%{})
        |> CommonChanges.preload_change_assoc(:post, required: true)

      refute changeset.valid?

      assert {:post, ["can't be blank"]} in errors_on(changeset)
    end

    test "changeset valid when option :required is set and association exist in data" do
      changeset =
        %Comment{post: %Post{id: 1}}
        |> Comment.changeset(%{})
        |> CommonChanges.preload_change_assoc(:post, required: true)

      assert %Ecto.Changeset{
        data: %Comment{post: %Post{id: 1}},
        valid?: true
      } = changeset
    end

    test "changeset valid when :required is set and the association exists in params" do
      changeset =
        %Comment{}
        |> Comment.changeset(%{post: %{id: 1}})
        |> CommonChanges.preload_change_assoc(:post, required: true)

      assert %Ecto.Changeset{
        data: %Comment{post: nil},
        params: %{"post" => %{id: 1}},
        valid?: true
      } = changeset
    end

    test "changeset invalid when :required_when_missing set and the association does not exist in changeset data or changes" do
      changeset =
        %Comment{}
        |> Comment.changeset(%{})
        |> CommonChanges.preload_change_assoc(:post, required_when_missing: :post_id)

      refute changeset.valid?

      assert {:post, ["can't be blank"]} in errors_on(changeset)
    end

    test "changeset valid when :required_when_missing set, the required key is not given, and association exists in changeset data" do
      changeset =
        %Comment{post: %Post{id: 1}}
        |> Comment.changeset(%{})
        |> CommonChanges.preload_change_assoc(:post, required_when_missing: :post_id)

      assert %Ecto.Changeset{
        data: %Comment{post: %Post{id: 1}},
        valid?: true
      } = changeset
    end

    test "changeset valid when :required_when_missing set, the required key is given, and association does not exist in changeset data" do
      changeset =
        %Comment{}
        |> Comment.changeset(%{post_id: 1})
        |> CommonChanges.preload_change_assoc(:post, required_when_missing: :post_id)

      assert %Ecto.Changeset{
        data: %Comment{post: %Ecto.Association.NotLoaded{}},
        changes: %{post_id: 1},
        params: %{"post_id" => 1},
        valid?: true
      } = changeset
    end
  end

  describe "preload_changeset_assoc: " do
    test "puts an association when the parameter is a map with an ID key" do
      assert {:ok, post} = Actions.create(Post, %{title: "title"})

      params = %{}

      changeset =
        %Comment{}
        |> Comment.changeset(params)
        |> Ecto.Changeset.put_assoc(:post, post)
        |> CommonChanges.preload_changeset_assoc(:post)

      assert %Ecto.Changeset{
        action: nil,
        changes: %{
          post: %Ecto.Changeset{
            action: :update,
            data: ^post,
            changes: %{},
            errors: [],
            params: nil,
            valid?: true
          }
        },
        data: %Comment{},
        errors: [],
        valid?: true
      } = changeset
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

      params = %{
        comments: [%{id: existing_comment.id}]
      }

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

    test "raises an error if invalid parameters is passed as the value for an association" do
      expected_error_message =
        "The key :tags is not an association for the queryable EctoShorts.Support.Schemas.Comment."

      # This is expected to fail because tags expects a list
      # of strings however we are passing in a list of maps
      # with an id which is intended for schema data.
      func =
        fn ->
          %Comment{}
          |> Comment.changeset(%{tags: [%{id: 1}]})
          |> CommonChanges.put_or_cast_assoc(:tags)
        end

      assert_raise ArgumentError, expected_error_message, func
    end

    test "raises an error if the key is not a type of ecto changeset queryable" do
      expected_error_message =
        "The key :invalid_association is not an association for the queryable EctoShorts.Support.Schemas.Comment."

      func =
        fn ->
          %Comment{}
          |> Comment.changeset(%{invalid_association: [%{id: 1}]})
          |> CommonChanges.put_or_cast_assoc(:invalid_association)
        end

      assert_raise ArgumentError, expected_error_message, func
    end
  end
end
