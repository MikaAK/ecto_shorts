defmodule EctoShorts.CommonChangesTest do
  use EctoShorts.DataCase, async: true

  alias Ecto.Changeset
  alias EctoShorts.{Actions, CommonChanges, Repo}

  alias EctoShorts.Schema.{
    Comment,
    Post,
    User
  }

  describe "apply_when: " do
    test "does not apply the change when the condition returns false" do
      when_func = fn _changeset -> false end

      change_func = fn changeset -> Changeset.put_change(changeset, :title, "title") end

      changeset =
        %Post{}
        |> Post.changeset(%{})
        |> CommonChanges.apply_when(when_func, change_func)

      assert %Changeset{
               changes: changes,
               params: params
             } = changeset

      assert %{} = changes

      assert %{} = params
    end

    test "applies the change when the condition returns true" do
      when_func = fn _changeset -> true end

      change_func = fn changeset -> Changeset.put_change(changeset, :title, "title") end

      changeset =
        %Post{}
        |> Post.changeset(%{})
        |> CommonChanges.apply_when(when_func, change_func)

      assert %Changeset{
               changes: changes
             } = changeset

      assert %{title: "title"} = changes
    end
  end

  describe "validate_not_unset: " do
    test "adds an error when clearing a field that already has a value" do
      changeset = Post.changeset(%Post{title: "title"}, %{title: nil})

      changeset = CommonChanges.validate_not_unset(changeset, :title)

      refute changeset.valid?
      assert {:title, ["can't be blank"]} in errors_on(changeset)
    end

    test "allows clearing a field that was already nil" do
      changeset = Post.changeset(%Post{title: nil}, %{title: nil})

      changeset = CommonChanges.validate_not_unset(changeset, :title)

      assert changeset.valid?
      refute Keyword.has_key?(changeset.errors, :title)
    end

    test "validates multiple fields at once when given a list" do
      changeset =
        Post.changeset(%Post{title: "title", permalink: "permalink"}, %{
          title: nil,
          permalink: nil
        })

      changeset = CommonChanges.validate_not_unset(changeset, [:title, :permalink])

      refute changeset.valid?
      assert {:title, ["can't be blank"]} in errors_on(changeset)
      assert {:permalink, ["can't be blank"]} in errors_on(changeset)
    end
  end

  describe "truncate_datetime_change: " do
    test "removes fractional seconds from a DateTime change" do
      datetime = ~U[2026-01-20 23:39:04.123456Z]

      changeset =
        %Post{}
        |> Changeset.change()
        |> Changeset.put_change(:published_at, datetime)

      changeset = CommonChanges.truncate_datetime_change(changeset, :published_at)

      assert ~U[2026-01-20 23:39:04Z] = Changeset.get_change(changeset, :published_at)
    end

    test "removes extra precision from a NaiveDateTime change" do
      naive = ~N[2026-01-20 23:39:04.123456]

      changeset =
        %Comment{}
        |> Changeset.change()
        |> Changeset.put_change(:published_at, naive)

      changeset = CommonChanges.truncate_datetime_change(changeset, :published_at, :millisecond)

      assert ~N[2026-01-20 23:39:04.123] = Changeset.get_change(changeset, :published_at)
    end

    test "truncates multiple fields at once when given a list" do
      datetime = ~U[2026-01-20 23:39:04.123456Z]

      changeset =
        %Post{}
        |> Changeset.change()
        |> Changeset.put_change(:published_at, datetime)

      changeset = CommonChanges.truncate_datetime_change(changeset, [:published_at])

      assert ~U[2026-01-20 23:39:04Z] = Changeset.get_change(changeset, :published_at)
    end
  end

  describe "trim_string_change: " do
    test "removes leading and trailing whitespace from the field" do
      changeset = Post.changeset(%Post{}, %{title: "  title  "})

      changeset = CommonChanges.trim_string_change(changeset, :title)

      assert "title" = Changeset.get_change(changeset, :title)
    end

    test "trims multiple fields at once when given a list" do
      changeset = Post.changeset(%Post{}, %{title: "  title  ", permalink: "  permalink  "})

      changeset = CommonChanges.trim_string_change(changeset, [:title, :permalink])

      assert "title" = Changeset.get_change(changeset, :title)
      assert "permalink" = Changeset.get_change(changeset, :permalink)
    end
  end

  describe "put_new_change: " do
    test "sets the field when no change is pending" do
      changeset = Post.changeset(%Post{}, %{})

      changeset = CommonChanges.put_new_change(changeset, :title, "title")

      assert "title" = Changeset.get_change(changeset, :title)
    end

    test "keeps the existing change when one is already pending" do
      changeset = Post.changeset(%Post{}, %{title: "existing"})

      changeset = CommonChanges.put_new_change(changeset, :title, "new")

      assert "existing" = Changeset.get_change(changeset, :title)
    end

    test "computes the value from a function when no change is pending" do
      changeset = Post.changeset(%Post{}, %{})

      changeset =
        CommonChanges.put_new_change(changeset, :title, fn field -> Atom.to_string(field) end)

      assert "title" = Changeset.get_change(changeset, :title)
    end
  end

  describe "put_new_value: " do
    test "sets the field when the persisted value is nil" do
      changeset = Post.changeset(%Post{title: nil}, %{})

      changeset = CommonChanges.put_new_value(changeset, :title, "title")

      assert "title" = Changeset.get_change(changeset, :title)
    end

    test "keeps the persisted value when it is not nil" do
      changeset = Post.changeset(%Post{title: "existing"}, %{})

      changeset = CommonChanges.put_new_value(changeset, :title, "new")

      refute Changeset.changed?(changeset, :title)
    end

    test "computes the value from a function when the persisted value is nil" do
      changeset = Post.changeset(%Post{title: nil}, %{})

      changeset = CommonChanges.put_new_value(changeset, :title, fn -> "title" end)

      assert "title" = Changeset.get_change(changeset, :title)
    end
  end

  describe "field_empty?: " do
    test "returns false when the field has items" do
      params = %{}

      changeset =
        %Post{}
        |> Post.changeset(params)
        |> Changeset.put_assoc(:comments, [%{body: "body"}])

      refute CommonChanges.field_empty?(changeset, :comments)
    end

    test "returns true when the field is nil" do
      changeset = Post.changeset(%Post{}, %{})

      assert CommonChanges.field_empty?(changeset, :comments)
    end

    test "returns true when the field is an empty list" do
      changeset = Post.changeset(%Post{}, %{comments: []})

      assert CommonChanges.field_empty?(changeset, :comments)
    end
  end

  describe "field_nil?: " do
    test "returns false when the field has a persisted value" do
      changeset = Post.changeset(%Post{title: "title"}, %{})

      refute CommonChanges.field_nil?(changeset, :title)
    end

    test "returns true when the field has no value" do
      changeset = Post.changeset(%Post{}, %{})

      assert CommonChanges.field_nil?(changeset, :title)
    end

    test "returns true when the field is changed to nil" do
      changeset = Post.changeset(%Post{}, %{title: nil})

      assert CommonChanges.field_nil?(changeset, :title)
    end

    test "returns false when a has_many association is set to nil in params" do
      changeset = Post.changeset(%Post{}, %{comments: nil})

      refute CommonChanges.field_nil?(changeset, :comments)
    end
  end

  describe "has_nil_change?: " do
    test "returns true when the field has no pending change" do
      changeset = Post.changeset(%Post{title: "title"}, %{})

      assert CommonChanges.has_nil_change?(changeset, :title)
    end

    test "returns false when the field has a pending change" do
      changeset = Post.changeset(%Post{}, %{title: "new"})

      refute CommonChanges.has_nil_change?(changeset, :title)
    end
  end

  describe "preload_change_assoc: " do
    test "raises when the association does not exist on the schema" do
      assert {:ok, post} = Actions.create(Post, %{title: "title"})

      expected_message =
        "cannot cast assoc `invalid_association`, assoc `invalid_association` not found. Make sure it is spelled correctly and that the association type is not read-only"

      func =
        fn ->
          post
          |> Post.changeset(%{})
          |> CommonChanges.preload_change_assoc(:invalid_association)
        end

      assert_raise ArgumentError, expected_message, func
    end

    test "casts changes for a belongs_to association" do
      assert {:ok, post} = Actions.create(Post, %{title: "title"})

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
        |> CommonChanges.preload_change_assoc(:post)

      assert %Changeset{
               action: nil,
               changes: %{
                 post: %Changeset{
                   action: :update,
                   data: %Post{
                     id: ^post_id
                   },
                   changes: %{title: "updated_title"},
                   errors: [],
                   params: %{
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

    test "casts changes for a has_many association" do
      assert {:ok, post} = Actions.create(Post, %{title: "title"})

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
        |> CommonChanges.preload_change_assoc(:comments)

      assert %Changeset{
               action: nil,
               changes: %{
                 comments: [
                   %Changeset{
                     action: :update,
                     data: %Comment{
                       id: ^comment_id
                     },
                     changes: %{body: "updated_body"},
                     errors: [],
                     params: %{
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

    test "casts changes for a many_to_many association" do
      assert {:ok, post} = Actions.create(Post, %{title: "title"})

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
        |> CommonChanges.preload_change_assoc(:authors)

      assert %Changeset{
               action: nil,
               changes: %{
                 authors: [
                   %Changeset{
                     action: :update,
                     data: %User{
                       id: ^user_id
                     },
                     changes: %{email: "updated_email"},
                     params: %{
                       "email" => "updated_email",
                       "id" => ^user_id
                     },
                     valid?: true
                   }
                 ]
               },
               data: %Post{
                 id: ^post_id,
                 authors: [
                   %User{
                     id: ^user_id
                   }
                 ]
               },
               params: %{
                 "authors" => [%{email: "updated_email", id: ^user_id}]
               },
               valid?: true
             } = changeset
    end

    test "skips loading the association when no params are provided" do
      assert {:ok, post} = Actions.create(Post, %{title: "title"})

      post_id = post.id

      changeset =
        post
        |> Post.changeset(%{})
        |> CommonChanges.preload_change_assoc(:authors)

      assert %Changeset{
               action: nil,
               changes: %{},
               data: %Post{
                 id: ^post_id,
                 authors: %Ecto.Association.NotLoaded{}
               },
               params: %{},
               valid?: true
             } = changeset
    end

    test "makes no changes when the struct is already the associated record" do
      assert {:ok, post} = Actions.create(Post, %{title: "title"})

      post_id = post.id

      assert {:ok, comment} =
               %Comment{}
               |> Comment.changeset(%{body: "created_body", post_id: post_id})
               |> Repo.insert()

      comment_id = comment.id

      changeset =
        comment
        |> Comment.changeset(%{post: post})
        |> CommonChanges.preload_change_assoc(:post)

      assert %Changeset{
               action: nil,
               changes: changes,
               data: %Comment{
                 id: ^comment_id,
                 post: %Post{
                   id: ^post_id
                 }
               },
               valid?: true
             } = changeset

      assert %{} = changes
    end

    test "associates the struct when it is not yet linked to the record" do
      assert {:ok, post} = Actions.create(Post, %{title: "title"})

      post_id = post.id

      assert {:ok, comment} =
               %Comment{}
               |> Comment.changeset(%{body: "created_body"})
               |> Repo.insert()

      comment_id = comment.id

      changeset =
        comment
        |> Comment.changeset(%{post: post})
        |> CommonChanges.preload_change_assoc(:post)

      assert %Changeset{
               action: nil,
               changes: %{
                 post: %Changeset{
                   action: :update,
                   data: %Post{
                     id: ^post_id
                   },
                   changes: changes,
                   params: nil,
                   valid?: true
                 }
               },
               data: %Comment{
                 id: ^comment_id,
                 post: nil
               },
               valid?: true
             } = changeset

      assert %{} = changes
    end

    test "inserts a new association when the params have no id" do
      assert {:ok, post} = Actions.create(Post, %{title: "created_post_title"})

      post_id = post.id

      changeset =
        post
        |> Post.changeset(%{comments: [%{body: "new_comment_body"}]})
        |> CommonChanges.preload_change_assoc(:comments)

      assert %Changeset{
               action: nil,
               changes: %{
                 comments: [
                   %Changeset{
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

    test "inserts a new association when the id does not match any existing record" do
      assert {:ok, post} = Actions.create(Post, %{title: "created_post_title"})

      post_id = post.id

      assert {:ok, comment} =
               %Comment{}
               |> Comment.changeset(%{body: "created_body", post_id: post_id})
               |> Repo.insert()

      assert {:ok, deleted_comment} =
               comment
               |> Comment.changeset()
               |> Repo.delete()

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

      assert %Changeset{
               action: nil,
               changes: %{
                 comments: [
                   %Changeset{
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

    test "marks the changeset invalid when the required association is missing" do
      changeset =
        %Comment{}
        |> Comment.changeset(%{})
        |> CommonChanges.preload_change_assoc(:post, required: true)

      refute changeset.valid?

      assert {:post, ["can't be blank"]} in errors_on(changeset)
    end

    test "keeps the changeset valid when the required association exists in data" do
      changeset =
        %Comment{post: %Post{id: 1}}
        |> Comment.changeset(%{})
        |> CommonChanges.preload_change_assoc(:post, required: true)

      assert %Changeset{
               data: %Comment{post: %Post{id: 1}},
               valid?: true
             } = changeset
    end

    test "keeps the changeset valid when the required association exists in params" do
      changeset =
        %Comment{}
        |> Comment.changeset(%{post: %{id: 1}})
        |> CommonChanges.preload_change_assoc(:post, required: true)

      assert %Changeset{
               data: %Comment{post: nil},
               params: %{"post" => %{id: 1}},
               valid?: true
             } = changeset
    end

    test "marks the changeset invalid when the foreign key and association are both missing" do
      changeset =
        %Comment{}
        |> Comment.changeset(%{})
        |> CommonChanges.preload_change_assoc(:post, required_when_missing: :post_id)

      refute changeset.valid?

      assert {:post, ["can't be blank"]} in errors_on(changeset)
    end

    test "keeps the changeset valid when the association exists even without the foreign key" do
      changeset =
        %Comment{post: %Post{id: 1}}
        |> Comment.changeset(%{})
        |> CommonChanges.preload_change_assoc(:post, required_when_missing: :post_id)

      assert %Changeset{
               data: %Comment{post: %Post{id: 1}},
               valid?: true
             } = changeset
    end

    test "keeps the changeset valid when the foreign key is provided even without the association" do
      changeset =
        %Comment{}
        |> Comment.changeset(%{post_id: 1})
        |> CommonChanges.preload_change_assoc(:post, required_when_missing: :post_id)

      assert %Changeset{
               data: %Comment{post: %Ecto.Association.NotLoaded{}},
               changes: %{post_id: 1},
               params: %{"post_id" => 1},
               valid?: true
             } = changeset
    end

    test "does not crash when changeset was built with Ecto.Changeset.change/2 (nil params)" do
      changeset =
        %Post{}
        |> Ecto.Changeset.change(%{})
        |> CommonChanges.preload_change_assoc(:comments)

      assert %Changeset{valid?: true} = changeset
    end
  end

  describe "preload_changeset_assoc: " do
    test "preloads a belongs_to association onto the changeset data" do
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

    test "preloads a has_many association onto the changeset data" do
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

    test "preloads a many_to_many association onto the changeset data" do
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
                   %User{
                     id: ^user_id
                   }
                 ]
               },
               valid?: true
             } = changeset
    end

    test "preloads specific has_many records when :ids is provided" do
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
                   %Comment{
                     id: ^comment_1_id
                   },
                   %Comment{
                     id: ^comment_2_id
                   }
                 ]
               },
               valid?: true
             } = changeset
    end

    test "preloads specific many_to_many records when :ids is provided" do
      assert {:ok, post} = Actions.create(Post, %{title: "created_title"})

      post_id = post.id

      assert {:ok, user_1} =
               %User{}
               |> User.changeset(%{email: "user_1_created_email"})
               |> Changeset.put_assoc(:posts, [post])
               |> Repo.insert()

      assert {:ok, user_2} =
               %User{}
               |> User.changeset(%{email: "user_2_created_email"})
               |> Changeset.put_assoc(:posts, [post])
               |> Repo.insert()

      user_1_id = user_1.id
      user_2_id = user_2.id

      changeset =
        post
        |> Post.changeset(%{
          authors: [
            %{
              id: user_1_id,
              email: "user_1_updated_email"
            }
          ]
        })
        |> CommonChanges.preload_changeset_assoc(:authors, ids: [user_1_id, user_2_id])

      assert %Changeset{
               action: nil,
               changes: %{},
               data: %Post{
                 id: ^post_id,
                 authors: [
                   %User{
                     id: ^user_1_id
                   },
                   %User{
                     id: ^user_2_id
                   }
                 ]
               },
               valid?: true
             } = changeset
    end

    test "raises when the association does not exist and :ids is provided" do
      assert {:ok, post} = Actions.create(Post, %{title: "title"})

      expected_message = ~r|The key (.*) is not an association for the queryable (.*)|

      func =
        fn ->
          post
          |> Post.changeset(%{})
          |> CommonChanges.preload_changeset_assoc(:non_existent_association, ids: [1])
        end

      assert_raise ArgumentError, expected_message, func
    end
  end

  describe "put_or_cast_assoc: " do
    test "makes no changes when the association is not in the params" do
      params = %{}

      changeset =
        %Comment{}
        |> Comment.changeset(params)
        |> CommonChanges.put_or_cast_assoc(:post)

      assert %Changeset{
               action: nil,
               changes: changes,
               data: %Comment{},
               errors: [],
               valid?: true
             } = changeset

      assert %{} = changes
    end

    test "preloads and associates existing records when params contain ids" do
      assert {:ok, existing_comment} = Actions.create(Comment, %{})

      params = %{
        comments: [%{id: existing_comment.id}]
      }

      changeset =
        %Post{}
        |> Post.changeset(params)
        |> CommonChanges.put_or_cast_assoc(:comments)

      assert %Changeset{
               action: nil,
               changes: changes,
               data: %Post{},
               errors: [],
               params: params,
               valid?: true
             } = changeset

      assert %{
               comments: [
                 %Changeset{
                   action: :update,
                   changes: %{},
                   data: ^existing_comment,
                   errors: [],
                   valid?: true
                 }
               ]
             } = changes

      assert params === %{"comments" => [%{id: existing_comment.id}]}
    end

    test "raises when the key is not an association on the schema" do
      expected_error_message =
        "The key :tags is not an association for the queryable EctoShorts.Schema.Comment."

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

    test "uses cast_assoc when params contain an empty list" do
      params = %{comments: []}

      changeset =
        %Post{}
        |> Post.changeset(params)
        |> CommonChanges.put_or_cast_assoc(:comments)

      assert %Changeset{valid?: true} = changeset
    end

    test "does not crash when changeset was built with Ecto.Changeset.change/2 (nil params)" do
      changeset =
        %Post{}
        |> Ecto.Changeset.change(%{})
        |> CommonChanges.put_or_cast_assoc(:comments)

      assert %Changeset{valid?: true} = changeset
    end

    test "raises when the key does not exist on the schema" do
      expected_error_message =
        "The key :invalid_association is not an association for the queryable EctoShorts.Schema.Comment."

      func =
        fn ->
          %Comment{}
          |> Comment.changeset(%{invalid_association: [%{id: 1}]})
          |> CommonChanges.put_or_cast_assoc(:invalid_association)
        end

      assert_raise ArgumentError, expected_error_message, func
    end
  end

  describe "change_nil?/2 with a list of fields" do
    test "returns true when all listed fields have nil changes" do
      changeset = Post.changeset(%Post{}, %{})
      assert CommonChanges.change_nil?(changeset, [:title, :permalink])
    end

    test "returns false when at least one listed field has a non-nil change" do
      changeset = Post.changeset(%Post{}, %{title: "hello"})
      refute CommonChanges.change_nil?(changeset, [:title, :permalink])
    end
  end

  describe "change_nil?/2 with a single field" do
    test "returns false when the field has a non-nil change" do
      changeset = Post.changeset(%Post{}, %{title: "hello"})
      refute CommonChanges.change_nil?(changeset, :title)
    end

    test "returns true when the field change is nil" do
      changeset = Post.changeset(%Post{}, %{})
      assert CommonChanges.change_nil?(changeset, :title)
    end
  end

  describe "change_empty?/2 with a list of fields" do
    test "returns true when all listed fields have empty changes" do
      changeset =
        %Post{}
        |> Post.changeset(%{})
        |> Changeset.put_change(:tags, [])
        |> Changeset.put_change(:permalink, nil)

      assert CommonChanges.change_empty?(changeset, [:tags])
    end

    test "returns false when at least one listed field has a non-empty change" do
      changeset = Post.changeset(%Post{}, %{title: "hello"})
      refute CommonChanges.change_empty?(changeset, [:title, :permalink])
    end
  end

  describe "change_empty?/2 with a single field" do
    test "returns true when the field change is an empty list" do
      changeset =
        %Post{}
        |> Post.changeset(%{})
        |> Changeset.put_change(:tags, [])

      assert CommonChanges.change_empty?(changeset, :tags)
    end

    test "returns true when the field change is an empty map" do
      changeset =
        %Post{}
        |> Post.changeset(%{})
        |> Changeset.put_change(:notes, %{})

      assert CommonChanges.change_empty?(changeset, :notes)
    end

    test "returns false when there is no change" do
      changeset = Post.changeset(%Post{}, %{})
      refute CommonChanges.change_empty?(changeset, :tags)
    end
  end

  describe "truncate_datetime_change/3 passthrough" do
    test "passes non-datetime values through unchanged" do
      changeset =
        %Post{}
        |> Post.changeset(%{})
        |> Changeset.put_change(:title, "keep me")

      result = CommonChanges.truncate_datetime_change(changeset, :title)
      assert "keep me" = Changeset.get_change(result, :title)
    end
  end

  describe "trim_string_change/2 passthrough" do
    test "passes non-string change values through unchanged" do
      changeset =
        %Post{}
        |> Post.changeset(%{})
        |> Changeset.put_change(:views, 42)

      result = CommonChanges.trim_string_change(changeset, :views)
      assert 42 = Changeset.get_change(result, :views)
    end
  end

  describe "apply_when/3 raises on bad change function return" do
    test "raises ArgumentError when the change function returns a non-changeset" do
      changeset = Post.changeset(%Post{}, %{})

      assert_raise ArgumentError, ~r/Expected function to return a changeset/, fn ->
        CommonChanges.apply_when(
          changeset,
          fn _cs -> true end,
          fn _cs -> :not_a_changeset end
        )
      end
    end
  end

  describe "preload_change_assoc/2 with schema structs (put_assoc path)" do
    test "puts schema structs directly via put_assoc when cast params contain schema structs" do
      {:ok, post} = Actions.create(Post, %{title: "post"})

      {:ok, comment} =
        %Comment{}
        |> Comment.changeset(%{body: "comment one", post_id: post.id})
        |> Repo.insert()

      post = Repo.preload(post, :comments)

      changeset =
        post
        |> Post.changeset(%{comments: [comment]})
        |> CommonChanges.preload_change_assoc(:comments)

      assert is_struct(changeset, Changeset)
    end
  end

  describe "preload_change_assoc/2 member update path" do
    test "fetches existing records when cast params are id-only maps" do
      {:ok, post} = Actions.create(Post, %{title: "post"})

      {:ok, comment} =
        %Comment{}
        |> Comment.changeset(%{body: "long enough body", post_id: post.id})
        |> Repo.insert()

      post = Repo.preload(post, :comments)
      comment_id = comment.id

      changeset =
        post
        |> Post.changeset(%{comments: [%{id: comment_id}]})
        |> CommonChanges.preload_change_assoc(:comments)

      assert is_struct(changeset, Changeset)
    end
  end
end
