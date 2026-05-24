defmodule EctoShorts.Actions.CRUDTest do
  use EctoShorts.DataCase, async: true

  alias Ecto.Changeset
  alias EctoShorts.Actions
  alias EctoShorts.Schema.Comment
  alias EctoShorts.Schema.Post
  alias EctoShorts.Schema.PostAuthor
  alias EctoShorts.Schema.PostWithLock
  alias EctoShorts.Schema.User

  import Ecto.Query

  describe "exists?/3" do
    test "returns true when a record matches the filter" do
      %Post{}
      |> Post.changeset(%{title: "Existing"})
      |> Repo.insert!()

      assert Actions.exists?(Post, %{title: "Existing"}) === true
    end

    test "returns false when no record matches the filter" do
      assert Actions.exists?(Post, %{title: "NonExistent"}) === false
    end
  end

  describe "all/3" do
    test "returns only the post with the given id" do
      post_a =
        %Post{}
        |> Post.changeset(%{title: "A"})
        |> Repo.insert!()

      _post_b =
        %Post{}
        |> Post.changeset(%{title: "B"})
        |> Repo.insert!()

      assert [%Post{title: "A"}] = Actions.all(Post, %{id: post_a.id})
    end

    test "returns posts matching either the where condition or the or_where condition" do
      %Post{}
      |> Post.changeset(%{title: "WhereMatch", published: true})
      |> Repo.insert!()

      %Post{}
      |> Post.changeset(%{title: "OrWhereMatch", published: false})
      |> Repo.insert!()

      results =
        Actions.all(Post, %{
          where: %{published: true},
          or_where: %{title: "OrWhereMatch"},
          order_by: [asc: :title]
        })

      assert Enum.map(results, & &1.title) === ["OrWhereMatch", "WhereMatch"]
    end

    test "returns posts whose associated author matches the given name" do
      author =
        %User{}
        |> User.changeset(%{first_name: "John"})
        |> Repo.insert!()

      other_author =
        %User{}
        |> User.changeset(%{first_name: "Jane"})
        |> Repo.insert!()

      %Post{}
      |> Post.changeset(%{title: "Authored", permalink: "authored-actions", author_id: author.id})
      |> Repo.insert!()

      _other_post =
        %Post{}
        |> Post.changeset(%{
          title: "Other",
          permalink: "other-actions",
          author_id: other_author.id
        })
        |> Repo.insert!()

      assert [%Post{title: "Authored"}] = Actions.all(Post, %{author: %{first_name: "John"}})
    end

    test "sorts results by the order_by option" do
      %Post{}
      |> Post.changeset(%{title: "B"})
      |> Repo.insert!()

      %Post{}
      |> Post.changeset(%{title: "A"})
      |> Repo.insert!()

      results = Actions.all(Post, %{}, order_by: [asc: :title])

      assert [%Post{title: "A"}, %Post{title: "B"}] = results
    end

    test "the order_by option takes priority over order_by in the params" do
      %Post{}
      |> Post.changeset(%{title: "B"})
      |> Repo.insert!()

      %Post{}
      |> Post.changeset(%{title: "A"})
      |> Repo.insert!()

      results = Actions.all(Post, %{order_by: [desc: :title]}, order_by: [asc: :title])

      assert [%Post{title: "A"}, %Post{title: "B"}] = results
    end

    test "sorts results by a named binding when order_by uses the live :as shape" do
      author_zoe =
        %User{}
        |> User.changeset(%{first_name: "Zoe"})
        |> Repo.insert!()

      author_amy =
        %User{}
        |> User.changeset(%{first_name: "Amy"})
        |> Repo.insert!()

      %Post{}
      |> Post.changeset(%{title: "A Post", author_id: author_zoe.id})
      |> Repo.insert!()

      %Post{}
      |> Post.changeset(%{title: "Z Post", author_id: author_amy.id})
      |> Repo.insert!()

      q =
        from(p in Post,
          join: a in assoc(p, :author),
          as: :author
        )

      results =
        Actions.all(q, %{
          as: %{
            author: %{
              order_by: [asc: :first_name]
            }
          }
        })

      assert Enum.map(results, & &1.title) === ["Z Post", "A Post"]
    end

    test "sorts results by a positional binding when order_by uses the live :at shape" do
      author_zoe =
        %User{}
        |> User.changeset(%{first_name: "Zoe"})
        |> Repo.insert!()

      author_amy =
        %User{}
        |> User.changeset(%{first_name: "Amy"})
        |> Repo.insert!()

      %Post{}
      |> Post.changeset(%{title: "A Post", author_id: author_zoe.id})
      |> Repo.insert!()

      %Post{}
      |> Post.changeset(%{title: "Z Post", author_id: author_amy.id})
      |> Repo.insert!()

      q =
        from(p in Post,
          join: a in assoc(p, :author)
        )

      results =
        Actions.all(q, %{
          at: %{
            2 => %{
              order_by: [asc: :first_name]
            }
          }
        })

      assert Enum.map(results, & &1.title) === ["Z Post", "A Post"]
    end
  end

  describe "all/3 filters" do
    test "returns the full struct when select is true" do
      %Post{}
      |> Post.changeset(%{title: "Selected", published: true})
      |> Repo.insert!()

      assert [%Post{title: "Selected"}] = Actions.all(Post, %{select: true, title: "Selected"})
    end

    test "returns only the selected field value" do
      post =
        %Post{}
        |> Post.changeset(%{title: "SelectId", published: true})
        |> Repo.insert!()

      assert [id] = Actions.all(Post, %{select: :id, id: post.id})
      assert id === post.id
    end

    test "returns a map with renamed fields when select uses a map alias" do
      post =
        %Post{}
        |> Post.changeset(%{title: "SelectAlias", published: true})
        |> Repo.insert!()

      assert [%{custom_id: id}] =
               Actions.all(Post, %{
                 select: %{map: %{custom_id: :id}},
                 id: post.id
               })

      assert id === post.id
    end

    test "returns a map with the listed fields when select uses a field list" do
      post =
        %Post{}
        |> Post.changeset(%{title: "SelectMap", published: true})
        |> Repo.insert!()

      assert [%{id: id, title: title}] =
               Actions.all(Post, %{
                 select: %{map: [:id, :title]},
                 id: post.id
               })

      assert id === post.id
      assert title === "SelectMap"
    end

    test "returns a struct with only the listed fields when select uses struct" do
      post =
        %Post{}
        |> Post.changeset(%{title: "SelectStruct", published: true})
        |> Repo.insert!()

      assert [%Post{id: id}] =
               Actions.all(Post, %{
                 select: %{struct: [:id]},
                 id: post.id
               })

      assert id === post.id
    end

    test "includes records matching either the main filter or the or_where filter" do
      %Post{}
      |> Post.changeset(%{title: "Published", published: true})
      |> Repo.insert!()

      %Post{}
      |> Post.changeset(%{title: "Unpublished", published: false})
      |> Repo.insert!()

      assert [%Post{title: "Published"}, %Post{title: "Unpublished"}] =
               Actions.all(Post, %{
                 published: true,
                 or_where: %{published: false}
               })
    end

    test "returns at most the number of records specified by limit" do
      %Post{}
      |> Post.changeset(%{title: "One"})
      |> Repo.insert!()

      %Post{}
      |> Post.changeset(%{title: "Two"})
      |> Repo.insert!()

      assert [%Post{title: "One"}] =
               Actions.all(Post, %{
                 order_by: [asc: :id],
                 limit: 1
               })
    end

    test "returns at most the number of records specified by first" do
      %Post{}
      |> Post.changeset(%{title: "One"})
      |> Repo.insert!()

      %Post{}
      |> Post.changeset(%{title: "Two"})
      |> Repo.insert!()

      assert [%Post{title: "One"}] =
               Actions.all(Post, %{
                 order_by: [asc: :id],
                 first: 1
               })
    end

    test "skips the first N records when offset is set" do
      %Post{}
      |> Post.changeset(%{title: "One"})
      |> Repo.insert!()

      %Post{}
      |> Post.changeset(%{title: "Two"})
      |> Repo.insert!()

      assert [%Post{title: "Two"}] =
               Actions.all(Post, %{
                 order_by: [asc: :id],
                 offset: 1
               })
    end

    test "loads the specified association on each returned record" do
      author =
        %User{}
        |> User.changeset(%{first_name: "Preload"})
        |> Repo.insert!()

      post =
        %Post{}
        |> Post.changeset(%{title: "WithAuthor", author_id: author.id})
        |> Repo.insert!()

      assert [%Post{title: "WithAuthor"} = result] =
               Actions.all(Post, %{
                 id: post.id,
                 preload: [:author]
               })

      assert %User{first_name: "Preload"} = result.author
    end

    test "loads nested associations on each returned record" do
      author =
        %User{}
        |> User.changeset(%{first_name: "Nested"})
        |> Repo.insert!()

      post =
        %Post{}
        |> Post.changeset(%{title: "WithComments", author_id: author.id})
        |> Repo.insert!()

      %Comment{}
      |> Comment.changeset(%{body: "A comment", post_id: post.id, author_id: author.id})
      |> Repo.insert!()

      assert [%Post{title: "WithComments"} = result] =
               Actions.all(Post, %{
                 id: post.id,
                 preload: [comments: :author]
               })

      assert [%Comment{body: "A comment"} = comment] = result.comments
      assert %User{first_name: "Nested"} = comment.author
    end

    test "loads an association from a named binding when preload uses the live :as shape" do
      author =
        %User{}
        |> User.changeset(%{first_name: "NamedPreload"})
        |> Repo.insert!()

      post =
        %Post{}
        |> Post.changeset(%{title: "WithNamedAuthor", author_id: author.id})
        |> Repo.insert!()

      q =
        from(p in Post,
          join: a in assoc(p, :author),
          as: :author
        )

      assert [%Post{title: "WithNamedAuthor"} = result] =
               Actions.all(q, %{
                 id: post.id,
                 as: %{
                   author: %{
                     preload: :author
                   }
                 }
               })

      assert %User{first_name: "NamedPreload"} = result.author
    end

    test "loads an association from a positional binding when preload uses the live :at shape" do
      author =
        %User{}
        |> User.changeset(%{first_name: "PositionalPreload"})
        |> Repo.insert!()

      post =
        %Post{}
        |> Post.changeset(%{title: "WithPositionalAuthor", author_id: author.id})
        |> Repo.insert!()

      q =
        from(p in Post,
          join: a in assoc(p, :author)
        )

      assert [%Post{title: "WithPositionalAuthor"} = result] =
               Actions.all(q, %{
                 id: post.id,
                 at: %{
                   2 => %{
                     preload: :author
                   }
                 }
               })

      assert %User{first_name: "PositionalPreload"} = result.author
    end

    test "loads nested posts from a named binding when preload uses the live :as shape" do
      author =
        %User{}
        |> User.changeset(%{first_name: "NamedPostsPreload"})
        |> Repo.insert!()

      post =
        %Post{}
        |> Post.changeset(%{title: "ParentPost", author_id: author.id})
        |> Repo.insert!()

      authored_post =
        %Post{}
        |> Post.changeset(%{title: "NestedPost", author_id: author.id})
        |> Repo.insert!()

      %PostAuthor{}
      |> PostAuthor.changeset(%{author_id: author.id, post_id: post.id})
      |> Repo.insert!()

      %PostAuthor{}
      |> PostAuthor.changeset(%{author_id: author.id, post_id: authored_post.id})
      |> Repo.insert!()

      q =
        from(p in Post,
          join: a in assoc(p, :author),
          as: :author
        )

      assert [%Post{title: "ParentPost"} = result] =
               Actions.all(q, %{
                 id: post.id,
                 as: %{
                   author: %{
                     preload: [author: [posts: :comments]]
                   }
                 }
               })

      assert %User{first_name: "NamedPostsPreload"} = loaded_author = result.author

      assert loaded_author.posts |> Enum.map(& &1.title) |> Enum.sort() === [
               "NestedPost",
               "ParentPost"
             ]
    end

    test "loads nested associations from a named binding when preload uses the live :as shape" do
      author =
        %User{}
        |> User.changeset(%{first_name: "NamedNestedPreload"})
        |> Repo.insert!()

      post =
        %Post{}
        |> Post.changeset(%{title: "ParentPost", author_id: author.id})
        |> Repo.insert!()

      authored_post =
        %Post{}
        |> Post.changeset(%{title: "NestedPost", author_id: author.id})
        |> Repo.insert!()

      %PostAuthor{}
      |> PostAuthor.changeset(%{author_id: author.id, post_id: post.id})
      |> Repo.insert!()

      %PostAuthor{}
      |> PostAuthor.changeset(%{author_id: author.id, post_id: authored_post.id})
      |> Repo.insert!()

      %Comment{}
      |> Comment.changeset(%{
        body: "NestedComment",
        post_id: authored_post.id,
        author_id: author.id
      })
      |> Repo.insert!()

      q =
        from(p in Post,
          join: a in assoc(p, :author),
          as: :author
        )

      assert [%Post{title: "ParentPost"} = result] =
               Actions.all(q, %{
                 id: post.id,
                 as: %{
                   author: %{
                     preload: [author: [posts: :comments]]
                   }
                 }
               })

      assert %User{first_name: "NamedNestedPreload"} = loaded_author = result.author

      assert loaded_author.posts |> Enum.map(& &1.title) |> Enum.sort() === [
               "NestedPost",
               "ParentPost"
             ]

      assert Enum.any?(loaded_author.posts, fn loaded_post ->
               Ecto.assoc_loaded?(loaded_post.comments) and
                 Enum.any?(loaded_post.comments, &(&1.body === "NestedComment"))
             end)
    end

    test "loads nested posts from a positional binding when preload uses the live :at shape" do
      author =
        %User{}
        |> User.changeset(%{first_name: "PositionalPostsPreload"})
        |> Repo.insert!()

      post =
        %Post{}
        |> Post.changeset(%{title: "ParentPost", author_id: author.id})
        |> Repo.insert!()

      authored_post =
        %Post{}
        |> Post.changeset(%{title: "NestedPost", author_id: author.id})
        |> Repo.insert!()

      %PostAuthor{}
      |> PostAuthor.changeset(%{author_id: author.id, post_id: post.id})
      |> Repo.insert!()

      %PostAuthor{}
      |> PostAuthor.changeset(%{author_id: author.id, post_id: authored_post.id})
      |> Repo.insert!()

      q =
        from(p in Post,
          join: a in assoc(p, :author)
        )

      assert [%Post{title: "ParentPost"} = result] =
               Actions.all(q, %{
                 id: post.id,
                 at: %{
                   2 => %{
                     preload: [author: [posts: :comments]]
                   }
                 }
               })

      assert %User{first_name: "PositionalPostsPreload"} = loaded_author = result.author

      assert loaded_author.posts |> Enum.map(& &1.title) |> Enum.sort() === [
               "NestedPost",
               "ParentPost"
             ]
    end

    test "loads nested associations from a positional binding when preload uses the live :at shape" do
      author =
        %User{}
        |> User.changeset(%{first_name: "PositionalNestedPreload"})
        |> Repo.insert!()

      post =
        %Post{}
        |> Post.changeset(%{title: "ParentPost", author_id: author.id})
        |> Repo.insert!()

      authored_post =
        %Post{}
        |> Post.changeset(%{title: "NestedPost", author_id: author.id})
        |> Repo.insert!()

      %PostAuthor{}
      |> PostAuthor.changeset(%{author_id: author.id, post_id: post.id})
      |> Repo.insert!()

      %PostAuthor{}
      |> PostAuthor.changeset(%{author_id: author.id, post_id: authored_post.id})
      |> Repo.insert!()

      %Comment{}
      |> Comment.changeset(%{
        body: "NestedComment",
        post_id: authored_post.id,
        author_id: author.id
      })
      |> Repo.insert!()

      q =
        from(p in Post,
          join: a in assoc(p, :author)
        )

      assert [%Post{title: "ParentPost"} = result] =
               Actions.all(q, %{
                 id: post.id,
                 at: %{
                   2 => %{
                     preload: [author: [posts: :comments]]
                   }
                 }
               })

      assert %User{first_name: "PositionalNestedPreload"} = loaded_author = result.author

      assert loaded_author.posts |> Enum.map(& &1.title) |> Enum.sort() === [
               "NestedPost",
               "ParentPost"
             ]

      assert Enum.any?(loaded_author.posts, fn loaded_post ->
               Ecto.assoc_loaded?(loaded_post.comments) and
                 Enum.any?(loaded_post.comments, &(&1.body === "NestedComment"))
             end)
    end

    test "returns the last N records in ascending order" do
      %Post{}
      |> Post.changeset(%{title: "One"})
      |> Repo.insert!()

      %Post{}
      |> Post.changeset(%{title: "Two"})
      |> Repo.insert!()

      %Post{}
      |> Post.changeset(%{title: "Three"})
      |> Repo.insert!()

      results = Actions.all(Post, %{last: 2})

      assert Enum.count(results) === 2
      assert Enum.map(results, & &1.title) === ["Two", "Three"]
    end

    test "returns the last N records sorted by the given key" do
      %Post{}
      |> Post.changeset(%{title: "One"})
      |> Repo.insert!()

      %Post{}
      |> Post.changeset(%{title: "Two"})
      |> Repo.insert!()

      %Post{}
      |> Post.changeset(%{title: "Three"})
      |> Repo.insert!()

      results = Actions.all(Post, %{last: %{id: 2}})

      assert Enum.count(results) === 2
      assert Enum.map(results, & &1.title) === ["Two", "Three"]
    end

    test "filters on a specific join position when bind uses :at" do
      author =
        %User{}
        |> User.changeset(%{first_name: "author"})
        |> Repo.insert!()

      %Post{}
      |> Post.changeset(%{
        title: "Published",
        published: true,
        author_id: author.id
      })
      |> Repo.insert!()

      _unpublished_post =
        %Post{}
        |> Post.changeset(%{
          title: "Unpublished",
          published: false,
          author_id: author.id
        })
        |> Repo.insert!()

      q =
        from(p in Post,
          join: a in assoc(p, :author)
        )

      assert [result] = Actions.all(q, %{at: %{1 => %{published: true}}})
      assert %Post{title: "Published", published: true} = result
    end

    test "filters on a named binding when bind uses :as" do
      %Post{}
      |> Post.changeset(%{title: "Published", published: true})
      |> Repo.insert!()

      _unpublished_post =
        %Post{}
        |> Post.changeset(%{title: "Unpublished", published: false})
        |> Repo.insert!()

      q = from(p in Post, as: :post)

      assert [result] = Actions.all(q, %{as: %{post: %{published: true}}})
      assert %Post{title: "Published", published: true} = result
    end

    test "filters using the explicit != operator" do
      %Post{}
      |> Post.changeset(%{title: "True", published: true})
      |> Repo.insert!()

      %Post{}
      |> Post.changeset(%{title: "False", published: false})
      |> Repo.insert!()

      assert [result] = Actions.all(Post, %{published: %{!=: true}})
      assert %Post{title: "False", published: false} = result
    end

    test "excludes records when the == operator is wrapped in not" do
      %Post{}
      |> Post.changeset(%{title: "True", published: true})
      |> Repo.insert!()

      %Post{}
      |> Post.changeset(%{title: "False", published: false})
      |> Repo.insert!()

      assert [result] = Actions.all(Post, %{published: %{not: %{==: true}}})
      assert %Post{title: "False", published: false} = result
    end

    test "includes records when the != operator is wrapped in not" do
      %Post{}
      |> Post.changeset(%{title: "True", published: true})
      |> Repo.insert!()

      %Post{}
      |> Post.changeset(%{title: "False", published: false})
      |> Repo.insert!()

      assert [result] = Actions.all(Post, %{published: %{not: %{!=: true}}})
      assert %Post{title: "True", published: true} = result
    end

    test "returns records where the field value is in the given list" do
      %Post{}
      |> Post.changeset(%{title: "True", published: true})
      |> Repo.insert!()

      %Post{}
      |> Post.changeset(%{title: "False", published: false})
      |> Repo.insert!()

      assert [%Post{title: "True", published: true}] =
               Actions.all(Post, %{published: %{in: [true]}})
    end

    test "excludes records where the field value is in the given list" do
      %Post{}
      |> Post.changeset(%{title: "True", published: true})
      |> Repo.insert!()

      %Post{}
      |> Post.changeset(%{title: "False", published: false})
      |> Repo.insert!()

      assert [%Post{title: "False", published: false}] =
               Actions.all(Post, %{published: %{not: %{in: [true]}}})
    end

    test "excludes records when == with a list is wrapped in not" do
      %Post{}
      |> Post.changeset(%{title: "True", published: true})
      |> Repo.insert!()

      %Post{}
      |> Post.changeset(%{title: "False", published: false})
      |> Repo.insert!()

      assert [%Post{title: "False", published: false}] =
               Actions.all(Post, %{published: %{not: %{==: [true]}}})
    end

    test "includes records when != with a list is wrapped in not" do
      %Post{}
      |> Post.changeset(%{title: "True", published: true})
      |> Repo.insert!()

      %Post{}
      |> Post.changeset(%{title: "False", published: false})
      |> Repo.insert!()

      assert [result] = Actions.all(Post, %{published: %{not: %{!=: [true]}}})
      assert %Post{title: "True", published: true} = result
    end

    test "returns records where the field is greater than or equal to the value" do
      %Post{}
      |> Post.changeset(%{title: "Low", views: 9})
      |> Repo.insert!()

      %Post{}
      |> Post.changeset(%{title: "High", views: 10})
      |> Repo.insert!()

      assert [result] = Actions.all(Post, %{views: %{>=: 10}})
      assert %Post{title: "High", views: 10} = result
    end

    test "returns records where the field is less than the value" do
      %Post{}
      |> Post.changeset(%{title: "Low", views: 9})
      |> Repo.insert!()

      %Post{}
      |> Post.changeset(%{title: "High", views: 10})
      |> Repo.insert!()

      assert [result] = Actions.all(Post, %{views: %{<: 10}})
      assert %Post{title: "Low", views: 9} = result
    end

    test "returns records where the field is less than or equal to the value" do
      %Post{}
      |> Post.changeset(%{title: "Low", views: 10})
      |> Repo.insert!()

      %Post{}
      |> Post.changeset(%{title: "High", views: 11})
      |> Repo.insert!()

      assert [result] = Actions.all(Post, %{views: %{<=: 10}})
      assert %Post{title: "Low", views: 10} = result
    end

    test "excludes records where the field is greater than the value" do
      %Post{}
      |> Post.changeset(%{title: "Low", views: 5})
      |> Repo.insert!()

      %Post{}
      |> Post.changeset(%{title: "High", views: 15})
      |> Repo.insert!()

      assert [result] = Actions.all(Post, %{views: %{not: %{>: 10}}})
      assert %Post{title: "Low", views: 5} = result
    end

    test "matches records by comparing the lowercased field to the value" do
      %Post{}
      |> Post.changeset(%{title: "Hello"})
      |> Repo.insert!()

      _no_match =
        %Post{}
        |> Post.changeset(%{title: "Other"})
        |> Repo.insert!()

      assert [result] = Actions.all(Post, %{title: %{lower: "hello"}})
      assert %Post{title: "Hello"} = result
    end

    test "matches records by comparing the uppercased field to the value" do
      %Post{}
      |> Post.changeset(%{title: "Hello"})
      |> Repo.insert!()

      _no_match =
        %Post{}
        |> Post.changeset(%{title: "Other"})
        |> Repo.insert!()

      assert [result] = Actions.all(Post, %{title: %{upper: "HELLO"}})
      assert %Post{title: "Hello"} = result
    end

    test "excludes records where the lowercased field matches the value" do
      _excluded =
        %Post{}
        |> Post.changeset(%{title: "Hello"})
        |> Repo.insert!()

      %Post{}
      |> Post.changeset(%{title: "Other"})
      |> Repo.insert!()

      assert [result] = Actions.all(Post, %{title: %{not: %{lower: "hello"}}})
      assert %Post{title: "Other"} = result
    end

    test "excludes records where the uppercased field matches the value" do
      _excluded =
        %Post{}
        |> Post.changeset(%{title: "Hello"})
        |> Repo.insert!()

      %Post{}
      |> Post.changeset(%{title: "Other"})
      |> Repo.insert!()

      assert [result] = Actions.all(Post, %{title: %{not: %{upper: "HELLO"}}})
      assert %Post{title: "Other"} = result
    end

    test "returns records where the field contains the search text" do
      %Post{}
      |> Post.changeset(%{title: "Hello world"})
      |> Repo.insert!()

      _no_match =
        %Post{}
        |> Post.changeset(%{title: "Goodbye"})
        |> Repo.insert!()

      assert [result] = Actions.all(Post, %{title: %{like: "Hello"}})
      assert %Post{title: "Hello world"} = result
    end

    test "returns records where the field matches the caller-supplied wildcard pattern" do
      %Post{}
      |> Post.changeset(%{title: "Hello world"})
      |> Repo.insert!()

      _no_match =
        %Post{}
        |> Post.changeset(%{title: "Say Hello"})
        |> Repo.insert!()

      assert [result] = Actions.all(Post, %{title: %{like: "Hello%"}})
      assert %Post{title: "Hello world"} = result
    end

    test "returns records where the field matches any pattern in the list" do
      %Post{}
      |> Post.changeset(%{title: "Hello"})
      |> Repo.insert!()

      %Post{}
      |> Post.changeset(%{title: "World"})
      |> Repo.insert!()

      _no_match =
        %Post{}
        |> Post.changeset(%{title: "Other"})
        |> Repo.insert!()

      results = Actions.all(Post, %{title: %{like: ["Hello", "World"]}, order_by: [asc: :title]})

      assert Enum.count(results) === 2
      assert Enum.any?(results, &match?(%Post{title: "Hello"}, &1))
      assert Enum.any?(results, &match?(%Post{title: "World"}, &1))
    end

    test "excludes records where the field contains the search text" do
      _match =
        %Post{}
        |> Post.changeset(%{title: "Hello"})
        |> Repo.insert!()

      %Post{}
      |> Post.changeset(%{title: "Other"})
      |> Repo.insert!()

      assert [result] = Actions.all(Post, %{title: %{not: %{like: "Hello"}}})
      assert %Post{title: "Other"} = result
    end

    test "matches records where any array element lowercased equals the value" do
      %Post{}
      |> Post.changeset(%{title: "Match", tags: ["Elixir"]})
      |> Repo.insert!()

      _no_match =
        %Post{}
        |> Post.changeset(%{title: "NoMatch", tags: ["ruby"]})
        |> Repo.insert!()

      assert [result] = Actions.all(Post, %{tags: %{lower: "elixir"}})
      assert %Post{title: "Match"} = result
    end

    test "matches records where any array element uppercased equals the value" do
      %Post{}
      |> Post.changeset(%{title: "Match", tags: ["Elixir"]})
      |> Repo.insert!()

      _no_match =
        %Post{}
        |> Post.changeset(%{title: "NoMatch", tags: ["ruby"]})
        |> Repo.insert!()

      assert [result] = Actions.all(Post, %{tags: %{upper: "ELIXIR"}})
      assert %Post{title: "Match"} = result
    end

    test "excludes records where any array element lowercased equals the value" do
      _excluded =
        %Post{}
        |> Post.changeset(%{title: "Excluded", tags: ["Elixir"]})
        |> Repo.insert!()

      %Post{}
      |> Post.changeset(%{title: "Kept", tags: ["ruby"]})
      |> Repo.insert!()

      assert [result] = Actions.all(Post, %{tags: %{not: %{lower: "elixir"}}})
      assert %Post{title: "Kept"} = result
    end

    test "excludes records where any array element uppercased equals the value" do
      _excluded =
        %Post{}
        |> Post.changeset(%{title: "Excluded", tags: ["Elixir"]})
        |> Repo.insert!()

      %Post{}
      |> Post.changeset(%{title: "Kept", tags: ["ruby"]})
      |> Repo.insert!()

      assert [result] = Actions.all(Post, %{tags: %{not: %{upper: "ELIXIR"}}})
      assert %Post{title: "Kept"} = result
    end

    test "excludes records where the field case-insensitively matches any pattern in the list" do
      _excluded =
        %Post{}
        |> Post.changeset(%{title: "HELLO"})
        |> Repo.insert!()

      %Post{}
      |> Post.changeset(%{title: "Other"})
      |> Repo.insert!()

      assert [result] = Actions.all(Post, %{title: %{not: %{ilike: ["hello", "world"]}}})
      assert %Post{title: "Other"} = result
    end

    test "returns records where the array field contains the given value" do
      %Post{}
      |> Post.changeset(%{
        title: "Match",
        tags: ["elixir", "erlang"]
      })
      |> Repo.insert!()

      _no_match =
        %Post{}
        |> Post.changeset(%{
          title: "NoMatch",
          tags: ["ruby"]
        })
        |> Repo.insert!()

      assert [result] = Actions.all(Post, %{tags: %{in: "elixir"}})
      assert %Post{title: "Match"} = result
    end

    test "returns records where the array field is nil" do
      %Post{}
      |> Post.changeset(%{title: "NoTags", tags: nil})
      |> Repo.insert!()

      _no_match =
        %Post{}
        |> Post.changeset(%{title: "HasTags", tags: ["elixir"]})
        |> Repo.insert!()

      assert [result] = Actions.all(Post, %{tags: nil})
      assert %Post{title: "NoTags", tags: nil} = result
    end

    test "returns records where the array field count is greater than zero" do
      %Post{}
      |> Post.changeset(%{title: "HasTags", tags: ["elixir"]})
      |> Repo.insert!()

      _no_match =
        %Post{}
        |> Post.changeset(%{title: "EmptyTags", tags: []})
        |> Repo.insert!()

      assert [result] = Actions.all(Post, %{tags: %{count: %{>: 0}}})
      assert %Post{title: "HasTags"} = result
    end

    test "returns records where the array field count equals zero" do
      %Post{}
      |> Post.changeset(%{title: "EmptyTags", tags: []})
      |> Repo.insert!()

      _no_match =
        %Post{}
        |> Post.changeset(%{title: "HasTags", tags: ["elixir"]})
        |> Repo.insert!()

      assert [result] = Actions.all(Post, %{tags: %{count: %{==: 0}}})
      assert %Post{title: "EmptyTags"} = result
    end

    test "returns records where every array element is greater than the value" do
      %Post{}
      |> Post.changeset(%{title: "AllGreater", tags: ["b", "c"]})
      |> Repo.insert!()

      _no_match =
        %Post{}
        |> Post.changeset(%{title: "HasLower", tags: ["a", "c"]})
        |> Repo.insert!()

      assert [result] = Actions.all(Post, %{tags: %{all: %{>: "a"}}})
      assert %Post{title: "AllGreater"} = result
    end

    test "returns records where every array element is contained in the given list" do
      %Post{}
      |> Post.changeset(%{title: "AllContained", tags: ["elixir"]})
      |> Repo.insert!()

      _no_match =
        %Post{}
        |> Post.changeset(%{title: "NotContained", tags: ["elixir", "ruby"]})
        |> Repo.insert!()

      assert [result] = Actions.all(Post, %{tags: %{all: %{in: ["elixir", "erlang"]}}})
      assert %Post{title: "AllContained"} = result
    end

    test "returns records where any array element matches the pattern" do
      %Post{}
      |> Post.changeset(%{title: "Match", tags: ["elixir"]})
      |> Repo.insert!()

      _no_match =
        %Post{}
        |> Post.changeset(%{title: "NoMatch", tags: ["ruby"]})
        |> Repo.insert!()

      assert [result] = Actions.all(Post, %{tags: %{like: "elixir"}})
      assert %Post{title: "Match"} = result
    end

    test "returns records where an array element matches the caller-supplied wildcard pattern" do
      %Post{}
      |> Post.changeset(%{title: "Match", tags: ["elixir-lang"]})
      |> Repo.insert!()

      _no_match =
        %Post{}
        |> Post.changeset(%{title: "NoMatch", tags: ["my-elixir-lang"]})
        |> Repo.insert!()

      assert [result] = Actions.all(Post, %{tags: %{like: "elixir%"}})
      assert %Post{title: "Match"} = result
    end

    test "returns records where any array element case-insensitively matches the pattern" do
      %Post{}
      |> Post.changeset(%{title: "Match", tags: ["Elixir"]})
      |> Repo.insert!()

      _no_match =
        %Post{}
        |> Post.changeset(%{title: "NoMatch", tags: ["ruby"]})
        |> Repo.insert!()

      assert [result] = Actions.all(Post, %{tags: %{ilike: "elixir"}})
      assert %Post{title: "Match"} = result
    end

    test "returns records where any array element matches any of the patterns" do
      %Post{}
      |> Post.changeset(%{title: "Match", tags: ["erlang"]})
      |> Repo.insert!()

      _no_match =
        %Post{}
        |> Post.changeset(%{
          title: "NoMatch",
          tags: ["ruby"]
        })
        |> Repo.insert!()

      assert [result] = Actions.all(Post, %{tags: %{like: ["elixir", "erlang"]}})
      assert %Post{title: "Match"} = result
    end

    test "excludes records where any array element matches the pattern" do
      _excluded =
        %Post{}
        |> Post.changeset(%{
          title: "Excluded",
          tags: ["elixir"]
        })
        |> Repo.insert!()

      %Post{}
      |> Post.changeset(%{title: "Kept", tags: ["ruby"]})
      |> Repo.insert!()

      assert [result] = Actions.all(Post, %{tags: %{not: %{like: "elixir"}}})
      assert %Post{title: "Kept"} = result
    end

    test "excludes records where any array element case-insensitively matches the pattern" do
      _excluded =
        %Post{}
        |> Post.changeset(%{
          title: "Excluded",
          tags: ["Elixir"]
        })
        |> Repo.insert!()

      %Post{}
      |> Post.changeset(%{title: "Kept", tags: ["ruby"]})
      |> Repo.insert!()

      assert [result] = Actions.all(Post, %{tags: %{not: %{ilike: "elixir"}}})
      assert %Post{title: "Kept"} = result
    end

    test "returns records where the array field exactly equals the given list" do
      %Post{}
      |> Post.changeset(%{
        title: "Match",
        tags: ["elixir", "erlang"]
      })
      |> Repo.insert!()

      _no_match =
        %Post{}
        |> Post.changeset(%{
          title: "NoMatch",
          tags: ["elixir"]
        })
        |> Repo.insert!()

      assert [result] = Actions.all(Post, %{tags: ["elixir", "erlang"]})
      assert %Post{title: "Match", tags: ["elixir", "erlang"]} = result
    end

    test "excludes records where the array field exactly equals the given list" do
      %Post{}
      |> Post.changeset(%{
        title: "Match",
        tags: ["elixir", "erlang"]
      })
      |> Repo.insert!()

      %Post{}
      |> Post.changeset(%{
        title: "NoMatch",
        tags: ["elixir"]
      })
      |> Repo.insert!()

      results = Actions.all(Post, %{tags: %{not: %{==: ["elixir"]}}})
      assert Enum.count(results) === 1
      assert Enum.any?(results, &match?(%Post{title: "Match"}, &1))
    end

    test "returns records where any array element is greater than the value" do
      %Post{}
      |> Post.changeset(%{title: "Match", tags: ["b"]})
      |> Repo.insert!()

      _no_match =
        %Post{}
        |> Post.changeset(%{title: "NoMatch", tags: ["a"]})
        |> Repo.insert!()

      assert [result] = Actions.all(Post, %{tags: %{>: "a"}})
      assert %Post{title: "Match"} = result
    end

    test "returns records where any array element is greater than or equal to the value" do
      %Post{}
      |> Post.changeset(%{title: "Match", tags: ["b"]})
      |> Repo.insert!()

      _no_match =
        %Post{}
        |> Post.changeset(%{title: "NoMatch", tags: ["a"]})
        |> Repo.insert!()

      assert [result] = Actions.all(Post, %{tags: %{>=: "b"}})
      assert %Post{title: "Match"} = result
    end

    test "returns records where any array element is less than the value" do
      %Post{}
      |> Post.changeset(%{title: "Match", tags: ["a"]})
      |> Repo.insert!()

      _no_match =
        %Post{}
        |> Post.changeset(%{title: "NoMatch", tags: ["b"]})
        |> Repo.insert!()

      assert [result] = Actions.all(Post, %{tags: %{<: "b"}})
      assert %Post{title: "Match"} = result
    end

    test "returns records where any array element is less than or equal to the value" do
      %Post{}
      |> Post.changeset(%{title: "Match", tags: ["a"]})
      |> Repo.insert!()

      _no_match =
        %Post{}
        |> Post.changeset(%{title: "NoMatch", tags: ["b"]})
        |> Repo.insert!()

      assert [result] = Actions.all(Post, %{tags: %{<=: "a"}})
      assert %Post{title: "Match"} = result
    end

    test "excludes records where any array element is greater than the value" do
      %Post{}
      |> Post.changeset(%{title: "Match", tags: ["a"]})
      |> Repo.insert!()

      %Post{}
      |> Post.changeset(%{
        title: "NoMatch",
        tags: ["b"]
      })
      |> Repo.insert!()

      assert [result] = Actions.all(Post, %{tags: %{not: %{>: "a"}}})
      assert %Post{title: "Match"} = result
    end

    test "accepts a keyword list as filter params" do
      %Post{}
      |> Post.changeset(%{title: "Published", published: true})
      |> Repo.insert!()

      _unpublished_post =
        %Post{}
        |> Post.changeset(%{title: "Unpublished", published: false})
        |> Repo.insert!()

      assert [%Post{title: "Published", published: true}] = Actions.all(Post, published: true)
    end

    test "treats a plain list value as an IN membership check" do
      %Post{}
      |> Post.changeset(%{title: "True", published: true})
      |> Repo.insert!()

      %Post{}
      |> Post.changeset(%{title: "False", published: false})
      |> Repo.insert!()

      assert [result] = Actions.all(Post, %{published: [true]})
      assert %Post{title: "True", published: true} = result
    end

    test "applies multiple comparison operators to the same field" do
      %Post{}
      |> Post.changeset(%{title: "True", published: true})
      |> Repo.insert!()

      %Post{}
      |> Post.changeset(%{title: "False", published: false})
      |> Repo.insert!()

      assert [result] = Actions.all(Post, %{where: %{published: [==: true, !=: false]}})
      assert %Post{title: "True", published: true} = result
    end

    test "returns records matching all conditions joined by and" do
      %Post{}
      |> Post.changeset(%{title: "Match", views: 15})
      |> Repo.insert!()

      %Post{}
      |> Post.changeset(%{title: "NoMatch", views: 25})
      |> Repo.insert!()

      assert [result] = Actions.all(Post, %{and: %{views: [>: 10, <: 20]}})
      assert %Post{title: "Match", views: 15} = result
    end

    test "returns records matching any condition joined by or" do
      %Post{}
      |> Post.changeset(%{title: "Match", views: 3})
      |> Repo.insert!()

      %Post{}
      |> Post.changeset(%{title: "NoMatch", views: 7})
      |> Repo.insert!()

      assert [result] = Actions.all(Post, [or_where: %{views: 3}, or_where: %{views: 11}], [])
      assert %Post{title: "Match", views: 3} = result
    end

    test "combines a where filter with an or_where boolean group" do
      %Post{}
      |> Post.changeset(%{
        title: "Published",
        published: true,
        views: 0
      })
      |> Repo.insert!()

      %Post{}
      |> Post.changeset(%{
        title: "Unpublished",
        published: false,
        views: 3
      })
      |> Repo.insert!()

      results =
        Actions.all(
          Post,
          [where: %{published: true}, or_where: %{views: 3}],
          []
        )

      assert Enum.count(results) === 2
      assert Enum.any?(results, &match?(%Post{title: "Published"}, &1))
      assert Enum.any?(results, &match?(%Post{title: "Unpublished"}, &1))
    end

    test ":and with a single field is equivalent to a plain field filter" do
      %Post{}
      |> Post.changeset(%{title: "Match", views: 15})
      |> Repo.insert!()

      %Post{}
      |> Post.changeset(%{title: "NoMatch", views: 99})
      |> Repo.insert!()

      plain = Actions.all(Post, %{views: 15})
      via_and = Actions.all(Post, %{and: %{views: 15}})

      assert [%Post{title: "Match"}] = plain
      assert plain === via_and
    end

    test ":and with a single field is equivalent to :where" do
      %Post{}
      |> Post.changeset(%{title: "Match", views: 15})
      |> Repo.insert!()

      %Post{}
      |> Post.changeset(%{title: "NoMatch", views: 99})
      |> Repo.insert!()

      via_where = Actions.all(Post, %{where: %{views: 15}})
      via_and = Actions.all(Post, %{and: %{views: 15}})

      assert [%Post{title: "Match"}] = via_where
      assert via_where === via_and
    end

    test ":or with a single field is equivalent to :or_where" do
      %Post{}
      |> Post.changeset(%{title: "A", published: true})
      |> Repo.insert!()

      %Post{}
      |> Post.changeset(%{title: "B", published: false})
      |> Repo.insert!()

      via_or_where =
        Actions.all(Post, where: %{published: true}, or_where: %{published: false})

      via_or =
        Actions.all(Post, where: %{published: true}, or: %{published: false})

      assert Enum.count(via_or_where) === 2
      assert Enum.sort_by(via_or_where, & &1.title) === Enum.sort_by(via_or, & &1.title)
    end

    test "multiple where: entries in a keyword list AND together" do
      %Post{}
      |> Post.changeset(%{title: "BothMatch", published: true, views: 5})
      |> Repo.insert!()

      %Post{}
      |> Post.changeset(%{title: "OnlyPublished", published: true, views: 99})
      |> Repo.insert!()

      %Post{}
      |> Post.changeset(%{title: "OnlyViews", published: false, views: 5})
      |> Repo.insert!()

      assert [result] =
               Actions.all(Post, where: %{published: true}, where: %{views: 5})

      assert %Post{title: "BothMatch"} = result
    end

    test "multiple or_where: entries in a keyword list OR together" do
      %Post{}
      |> Post.changeset(%{title: "A", published: true})
      |> Repo.insert!()

      %Post{}
      |> Post.changeset(%{title: "B", published: true})
      |> Repo.insert!()

      %Post{}
      |> Post.changeset(%{title: "C", published: false})
      |> Repo.insert!()

      results =
        Actions.all(Post, or_where: %{title: "A"}, or_where: %{title: "B"})

      assert Enum.count(results) === 2
      assert Enum.any?(results, &match?(%Post{title: "A"}, &1))
      assert Enum.any?(results, &match?(%Post{title: "B"}, &1))
    end

    test "multiple where: and multiple or_where: entries compose correctly" do
      %Post{}
      |> Post.changeset(%{title: "BothWhere", published: true, views: 0})
      |> Repo.insert!()

      %Post{}
      |> Post.changeset(%{title: "Extra1", published: false, views: 99})
      |> Repo.insert!()

      %Post{}
      |> Post.changeset(%{title: "Extra2", published: false, views: 99})
      |> Repo.insert!()

      %Post{}
      |> Post.changeset(%{title: "NoMatch", published: false, views: 1})
      |> Repo.insert!()

      results =
        Actions.all(Post,
          where: %{published: true},
          where: %{views: 0},
          or_where: %{title: "Extra1"},
          or_where: %{title: "Extra2"}
        )

      assert Enum.count(results) === 3
      assert Enum.any?(results, &match?(%Post{title: "BothWhere"}, &1))
      assert Enum.any?(results, &match?(%Post{title: "Extra1"}, &1))
      assert Enum.any?(results, &match?(%Post{title: "Extra2"}, &1))
    end

    test "two :and groups in a keyword list compose as AND" do
      %Post{}
      |> Post.changeset(%{title: "BothMatch", published: true, views: 5})
      |> Repo.insert!()

      %Post{}
      |> Post.changeset(%{title: "OnlyPublished", published: true, views: 99})
      |> Repo.insert!()

      %Post{}
      |> Post.changeset(%{title: "OnlyViews", published: false, views: 5})
      |> Repo.insert!()

      assert [result] =
               Actions.all(Post, and: %{published: true}, and: %{views: 5})

      assert %Post{title: "BothMatch"} = result
    end

    # When using a keyword list, sort_filter_params ensures :where entries execute
    # before :or_where entries, producing: (where conditions) OR (or_where conditions).
    test "keyword list: where + multiple or_where compose as (W) OR (OW1) OR (OW2)" do
      %Post{}
      |> Post.changeset(%{title: "WherePost", published: true})
      |> Repo.insert!()

      %Post{}
      |> Post.changeset(%{title: "OrA", published: false})
      |> Repo.insert!()

      %Post{}
      |> Post.changeset(%{title: "OrB", published: false})
      |> Repo.insert!()

      %Post{}
      |> Post.changeset(%{title: "NoMatch", published: false})
      |> Repo.insert!()

      results =
        Actions.all(Post,
          where: %{published: true},
          or_where: %{title: "OrA"},
          or_where: %{title: "OrB"}
        )

      assert Enum.count(results) === 3
      assert Enum.any?(results, &match?(%Post{title: "WherePost"}, &1))
      assert Enum.any?(results, &match?(%Post{title: "OrA"}, &1))
      assert Enum.any?(results, &match?(%Post{title: "OrB"}, &1))
    end

    # When using a map, Elixir does not guarantee key iteration order.
    # For order-sensitive compositions (e.g. mixing where and or_where), use a
    # keyword list instead. Maps work correctly for single where + single or_where
    # combinations where order does not affect the result.
    test "map: single where + single or_where matches both conditions" do
      %Post{}
      |> Post.changeset(%{title: "WherePost", published: true})
      |> Repo.insert!()

      %Post{}
      |> Post.changeset(%{title: "OrPost", published: false})
      |> Repo.insert!()

      %Post{}
      |> Post.changeset(%{title: "NoMatch", published: false})
      |> Repo.insert!()

      results =
        Actions.all(Post, %{
          where: %{published: true},
          or_where: %{title: "OrPost"}
        })

      assert Enum.count(results) === 2
      assert Enum.any?(results, &match?(%Post{title: "WherePost"}, &1))
      assert Enum.any?(results, &match?(%Post{title: "OrPost"}, &1))
    end

    test "returns records where the field is nil" do
      %Post{}
      |> Post.changeset(%{title: "Nil", permalink: "scalar-nil", published_at: nil})
      |> Repo.insert!()

      _not_nil =
        %Post{}
        |> Post.changeset(%{
          title: "NotNil",
          permalink: "scalar-not-nil",
          published_at: DateTime.utc_now()
        })
        |> Repo.insert!()

      assert [%Post{title: "Nil", published_at: nil}] =
               Actions.all(Post, %{published_at: nil})
    end

    test "returns records where the field is not nil" do
      %Post{}
      |> Post.changeset(%{title: "Nil", permalink: "scalar-ne-nil", published_at: nil})
      |> Repo.insert!()

      %Post{}
      |> Post.changeset(%{
        title: "NotNil",
        permalink: "scalar-ne-not-nil",
        published_at: DateTime.utc_now()
      })
      |> Repo.insert!()

      assert [%Post{title: "NotNil"}] =
               Actions.all(Post, %{published_at: %{!=: nil}})
    end

    test "excludes records where the field matches any value in the list using !=" do
      %Post{}
      |> Post.changeset(%{title: "A", views: 10})
      |> Repo.insert!()

      %Post{}
      |> Post.changeset(%{title: "B", views: 20})
      |> Repo.insert!()

      %Post{}
      |> Post.changeset(%{title: "C", views: 30})
      |> Repo.insert!()

      assert [%Post{title: "C", views: 30}] =
               Actions.all(Post, %{views: %{!=: [10, 20]}})
    end

    test "returns records where the field matches any value in the list using ==" do
      %Post{}
      |> Post.changeset(%{title: "A", views: 10})
      |> Repo.insert!()

      _b =
        %Post{}
        |> Post.changeset(%{title: "B", views: 20})
        |> Repo.insert!()

      assert [%Post{title: "A", views: 10}] =
               Actions.all(Post, %{views: %{==: [10]}})
    end

    test "returns records where the field is greater than the value" do
      %Post{}
      |> Post.changeset(%{title: "Low", views: 5})
      |> Repo.insert!()

      %Post{}
      |> Post.changeset(%{title: "High", views: 15})
      |> Repo.insert!()

      assert [%Post{title: "High", views: 15}] =
               Actions.all(Post, %{views: %{>: 10}})
    end

    test "excludes records where the field is less than the value" do
      %Post{}
      |> Post.changeset(%{title: "Low", views: 5})
      |> Repo.insert!()

      %Post{}
      |> Post.changeset(%{title: "High", views: 15})
      |> Repo.insert!()

      assert [%Post{title: "High", views: 15}] =
               Actions.all(Post, %{views: %{not: %{<: 10}}})
    end

    test "returns records with an id before the given id" do
      post_a =
        %Post{}
        |> Post.changeset(%{title: "A"})
        |> Repo.insert!()

      post_b =
        %Post{}
        |> Post.changeset(%{title: "B"})
        |> Repo.insert!()

      assert [%Post{title: "A"}] = Actions.all(Post, %{before: post_b.id})
      assert post_a.id < post_b.id
    end

    test "returns records with an id after the given id" do
      post_a =
        %Post{}
        |> Post.changeset(%{title: "A"})
        |> Repo.insert!()

      post_b =
        %Post{}
        |> Post.changeset(%{title: "B"})
        |> Repo.insert!()

      assert [%Post{title: "B"}] = Actions.all(Post, %{after: post_a.id})
      assert post_b.id > post_a.id
    end

    test "returns records where the array field exactly equals the list when != is wrapped in not" do
      %Post{}
      |> Post.changeset(%{title: "Match", tags: ["elixir"]})
      |> Repo.insert!()

      _no_match =
        %Post{}
        |> Post.changeset(%{title: "NoMatch", tags: ["ruby"]})
        |> Repo.insert!()

      assert [%Post{title: "Match", tags: ["elixir"]}] =
               Actions.all(Post, %{tags: %{not: %{!=: ["elixir"]}}})
    end

    test "excludes records where any array element is greater than or equal to the value" do
      %Post{}
      |> Post.changeset(%{title: "Match", tags: ["a"]})
      |> Repo.insert!()

      _no_match =
        %Post{}
        |> Post.changeset(%{title: "NoMatch", tags: ["b"]})
        |> Repo.insert!()

      assert [%Post{title: "Match"}] =
               Actions.all(Post, %{tags: %{not: %{>=: "b"}}})
    end

    test "excludes records where any array element is less than the value" do
      %Post{}
      |> Post.changeset(%{title: "Match", tags: ["b"]})
      |> Repo.insert!()

      _no_match =
        %Post{}
        |> Post.changeset(%{title: "NoMatch", tags: ["a"]})
        |> Repo.insert!()

      assert [%Post{title: "Match"}] =
               Actions.all(Post, %{tags: %{not: %{<: "b"}}})
    end

    test "excludes records where any array element is less than or equal to the value" do
      %Post{}
      |> Post.changeset(%{title: "Match", tags: ["b"]})
      |> Repo.insert!()

      _no_match =
        %Post{}
        |> Post.changeset(%{title: "NoMatch", tags: ["a"]})
        |> Repo.insert!()

      assert [%Post{title: "Match"}] =
               Actions.all(Post, %{tags: %{not: %{<=: "a"}}})
    end
  end

  describe "create/3" do
    test "inserts the record and returns it" do
      assert {:ok, %Post{title: "A"} = post} = Actions.create(Post, %{title: "A"})
      assert %Post{title: "A"} = Repo.get!(Post, post.id)
    end

    test "returns a changeset error when a unique constraint is violated" do
      %Post{}
      |> Post.changeset(%{title: "A", permalink: "create-dup"})
      |> Repo.insert!()

      assert {:error, %Changeset{} = changeset} =
               Actions.create(Post, %{title: "B", permalink: "create-dup"})

      assert "has already been taken" in errors_on(changeset).permalink
    end

    test "uses the custom changeset function from the options" do
      assert {:ok, %Post{title: "Overridden"}} =
               Actions.create(
                 Post,
                 %{title: "Original"},
                 changeset: fn schema, schema_data_or_changeset, params ->
                   schema.changeset(
                     schema_data_or_changeset,
                     Map.put(params, :title, "Overridden")
                   )
                 end
               )
    end
  end

  describe "get/3" do
    test "returns the record matching the given id" do
      post =
        %Post{}
        |> Post.changeset(%{title: "A"})
        |> Repo.insert!()

      assert %Post{title: "A"} = Actions.get(Post, post.id, repo: Repo)
    end

    test "returns nil when no record has the given id" do
      assert nil === Actions.get(Post, -1, repo: Repo)
    end
  end

  describe "find/3" do
    test "returns the record wrapped in ok when a match exists" do
      post =
        %Post{}
        |> Post.changeset(%{title: "A"})
        |> Repo.insert!()

      assert {:ok, %Post{title: "A"}} = Actions.find(Post, %{id: post.id}, [])
    end

    test "returns a not_found error when no match exists" do
      assert {:error, %{code: :not_found, message: "record not found.", details: details}} =
               Actions.find(Post, %{id: -1}, [])

      assert details.params === %{id: -1}
    end

    test "returns a not_found error immediately when the params map is empty" do
      assert {:error, %{code: :not_found, message: "record not found."}} =
               Actions.find(Post, %{}, [])
    end

    test "queries the database when params is empty but the source is a query" do
      %Post{}
      |> Post.changeset(%{title: "Only"})
      |> Repo.insert!()

      query = from(p in Post)

      assert {:ok, %Post{title: "Only"}} = Actions.find(query, %{}, [])
    end

    test "loads nested associations on the returned record" do
      author =
        %User{}
        |> User.changeset(%{first_name: "Nested"})
        |> Repo.insert!()

      post =
        %Post{}
        |> Post.changeset(%{title: "WithComments", author_id: author.id})
        |> Repo.insert!()

      %Comment{}
      |> Comment.changeset(%{body: "A comment", post_id: post.id, author_id: author.id})
      |> Repo.insert!()

      assert {:ok, %Post{title: "WithComments"} = result} =
               Actions.find(Post, %{id: post.id, preload: [comments: :author]}, [])

      assert [%Comment{body: "A comment"} = comment] = result.comments
      assert %User{first_name: "Nested"} = comment.author
    end
  end

  describe "update/4" do
    test "updates the record matching the given id" do
      post =
        %Post{}
        |> Post.changeset(%{title: "Before"})
        |> Repo.insert!()

      assert {:ok, %Post{title: "After"}} = Actions.update(Post, post.id, %{title: "After"})
      assert %Post{title: "After"} = Repo.get!(Post, post.id)
    end

    test "updates the record when given the struct directly" do
      post =
        %Post{}
        |> Post.changeset(%{title: "Before"})
        |> Repo.insert!()

      assert {:ok, %Post{title: "After"}} = Actions.update(Post, post, %{title: "After"})
      assert %Post{title: "After"} = Repo.get!(Post, post.id)
    end

    test "returns a not_found error when the id does not exist" do
      assert {:error, %{code: :not_found, message: "record not found.", details: details}} =
               Actions.update(Post, -1, %{title: "Ignored"})

      assert details.params === %{id: -1}
    end

    test "uses the custom changeset function from the options" do
      post =
        %Post{}
        |> Post.changeset(%{title: "Before"})
        |> Repo.insert!()

      assert {:ok, %Post{title: "Overridden"}} =
               Actions.update(
                 Post,
                 post.id,
                 %{title: "After"},
                 changeset: fn schema, schema_data_or_changeset, params ->
                   schema.changeset(
                     schema_data_or_changeset,
                     Map.put(params, :title, "Overridden")
                   )
                 end
               )
    end
  end

  describe "delete" do
    test "removes the record matching the given id" do
      post =
        %Post{}
        |> Post.changeset(%{title: "ToDelete"})
        |> Repo.insert!()

      assert {:ok, %Post{}} = Actions.delete(Post, post.id)
      assert Repo.get(Post, post.id) === nil
    end

    test "returns a not_found error when the id does not exist for delete" do
      assert {:error, %{code: :not_found, message: "record not found.", details: details}} =
               Actions.delete(Post, -1)

      assert details.params === %{id: -1}
    end

    test "removes the record when given the struct directly" do
      post =
        %Post{}
        |> Post.changeset(%{title: "ToDelete"})
        |> Repo.insert!()

      assert {:ok, %Post{}} = Actions.delete(post, [])
      assert Repo.get(Post, post.id) === nil
    end

    test "removes all records in the given list" do
      post_a =
        %Post{}
        |> Post.changeset(%{title: "A"})
        |> Repo.insert!()

      post_b =
        %Post{}
        |> Post.changeset(%{title: "B"})
        |> Repo.insert!()

      assert {:ok, [%Post{title: "A"}, %Post{title: "B"}]} = Actions.delete([post_a, post_b], [])
      assert Repo.get(Post, post_a.id) === nil
      assert Repo.get(Post, post_b.id) === nil
    end
  end

  describe "stream/3" do
    test "returns only the records matching the filter" do
      post_a =
        %Post{}
        |> Post.changeset(%{title: "A"})
        |> Repo.insert!()

      _post_b =
        %Post{}
        |> Post.changeset(%{title: "B"})
        |> Repo.insert!()

      assert {:ok, [%Post{title: "A"}]} =
               Repo.transaction(fn ->
                 Post
                 |> Actions.stream(%{id: post_a.id})
                 |> Enum.to_list()
               end)
    end

    test "returns records in the order specified by order_by" do
      %Post{}
      |> Post.changeset(%{title: "B"})
      |> Repo.insert!()

      %Post{}
      |> Post.changeset(%{title: "A"})
      |> Repo.insert!()

      assert {:ok, [%Post{title: "A"}, %Post{title: "B"}]} =
               Repo.transaction(fn ->
                 Post
                 |> Actions.stream(%{order_by: [asc: :title]})
                 |> Enum.to_list()
               end)
    end

    test "fetches all records even when max_rows is smaller than the total" do
      for i <- 1..5 do
        %Post{}
        |> Post.changeset(%{title: "Post #{i}"})
        |> Repo.insert!()
      end

      assert {:ok, posts} =
               Repo.transaction(fn ->
                 Post
                 |> Actions.stream(%{order_by: [asc: :id]}, max_rows: 2)
                 |> Enum.to_list()
               end)

      assert length(posts) === 5
    end
  end

  describe "aggregate/5" do
    test "counts all records when no filter is given" do
      %Post{}
      |> Post.changeset(%{title: "A"})
      |> Repo.insert!()

      %Post{}
      |> Post.changeset(%{title: "B"})
      |> Repo.insert!()

      assert 2 === Actions.aggregate(Post)
      assert 1 === Actions.aggregate(Post, %{title: "A"})
    end

    test "computes the aggregate using the specified function and field" do
      %Post{}
      |> Post.changeset(%{title: "Low", views: 1})
      |> Repo.insert!()

      %Post{}
      |> Post.changeset(%{title: "High", views: 10})
      |> Repo.insert!()

      assert 10 === Actions.aggregate(Post, %{}, :max, :views)
      assert 1 === Actions.aggregate(Post, %{title: "Low"}, :max, :views)
    end
  end

  describe "preload/3" do
    test "loads the named association onto the struct" do
      author =
        %User{}
        |> User.changeset(%{first_name: "Preloader"})
        |> Repo.insert!()

      post =
        %Post{}
        |> Post.changeset(%{title: "WithAuthor", author_id: author.id})
        |> Repo.insert!()

      post = Repo.get!(Post, post.id)

      assert %Ecto.Association.NotLoaded{} = post.author

      result = Actions.preload(post, :author)

      assert %Post{title: "WithAuthor"} = result
      assert %User{first_name: "Preloader"} = result.author
    end
  end

  describe "all/1" do
    test "returns every record when no filter is given" do
      %Post{}
      |> Post.changeset(%{title: "A"})
      |> Repo.insert!()

      %Post{}
      |> Post.changeset(%{title: "B"})
      |> Repo.insert!()

      results = Actions.all(Post)

      assert length(results) === 2
    end
  end

  describe "all/2 with keyword opts" do
    test "filters records when params are given as a keyword list" do
      %Post{}
      |> Post.changeset(%{title: "Published", published: true})
      |> Repo.insert!()

      %Post{}
      |> Post.changeset(%{title: "Unpublished", published: false})
      |> Repo.insert!()

      assert [%Post{title: "Published", published: true}] =
               Actions.all(Post, published: true)
    end
  end

  describe "find_and_create/3" do
    test "creates the record when no match exists" do
      assert {:ok, %Post{title: "Created"}} =
               Actions.find_and_create(Post, %{title: "Missing"}, %{title: "Created"})
    end

    test "returns the existing record when a match exists" do
      %Post{}
      |> Post.changeset(%{title: "Existing"})
      |> Repo.insert!()

      assert {:ok, %Post{title: "Existing"}} =
               Actions.find_and_create(Post, %{title: "Existing"}, %{title: "Created"})
    end
  end

  describe "find_and_update/4" do
    test "updates the record when a match exists" do
      %Post{}
      |> Post.changeset(%{title: "Existing"})
      |> Repo.insert!()

      assert {:ok, %Post{title: "Updated"}} =
               Actions.find_and_update(Post, %{title: "Existing"}, %{title: "Updated"})
    end

    test "returns a not_found error when no match exists" do
      assert {:error, %{code: :not_found, message: "record not found."}} =
               Actions.find_and_update(Post, %{title: "Missing"}, %{title: "Updated"})
    end
  end

  describe "find_and_upsert/4" do
    test "updates the record when a match exists" do
      %Post{}
      |> Post.changeset(%{title: "Existing"})
      |> Repo.insert!()

      assert {:ok, %Post{title: "Updated"}} =
               Actions.find_and_upsert(Post, %{title: "Existing"}, %{title: "Updated"})
    end

    test "creates the record when no match exists" do
      assert {:ok, %Post{title: "Upserted"}} =
               Actions.find_and_upsert(Post, %{title: "Missing"}, %{title: "Upserted"})
    end
  end

  describe "find_and_delete/3" do
    test "removes the record when a match exists" do
      %Post{}
      |> Post.changeset(%{title: "ToDelete"})
      |> Repo.insert!()

      assert {:ok, %Post{title: "ToDelete"}} = Actions.find_and_delete(Post, %{title: "ToDelete"})
    end

    test "returns a not_found error when no match exists" do
      assert {:error, %{code: :not_found, message: "record not found."}} =
               Actions.find_and_delete(Post, %{title: "Missing"})
    end
  end

  describe "find_or_create/3" do
    test "returns the existing record when a match exists" do
      %Post{}
      |> Post.changeset(%{title: "Existing"})
      |> Repo.insert!()

      assert {:ok, %Post{title: "Existing"}} = Actions.find_or_create(Post, %{title: "Existing"})
    end

    test "uses the query_fields option to narrow the lookup" do
      %Post{}
      |> Post.changeset(%{title: "Existing"})
      |> Repo.insert!()

      assert {:ok, %Post{title: "Existing"}} =
               Actions.find_or_create(
                 Post,
                 %{title: "Existing"},
                 query_fields: [:title]
               )
    end

    test "creates the record when no match exists" do
      assert {:ok, %Post{title: "Created"}} =
               Actions.find_or_create(
                 Post,
                 %{title: "Created"}
               )
    end
  end

  describe "update/4 optimistic locking via schema callback" do
    test "increments the lock version when the schema defines a lock callback" do
      post =
        %PostWithLock{}
        |> PostWithLock.changeset(%{title: "Original"})
        |> Repo.insert!()

      assert post.lock_version === 1

      assert {:ok, %PostWithLock{title: "Updated", lock_version: 2}} =
               Actions.update(PostWithLock, post, %{title: "Updated"})
    end

    test "returns a stale error when another process changed the record" do
      post =
        %PostWithLock{}
        |> PostWithLock.changeset(%{title: "Original"})
        |> Repo.insert!()

      PostWithLock
      |> where([p], p.id == ^post.id)
      |> Repo.update_all(set: [lock_version: 99])

      assert {:error, %{code: :stale, message: "record has been modified by another process."}} =
               Actions.update(PostWithLock, post, %{title: "Too Late"})
    end

    test "increments the lock version on every successful update" do
      post =
        %PostWithLock{}
        |> PostWithLock.changeset(%{title: "V1"})
        |> Repo.insert!()

      assert {:ok, %PostWithLock{lock_version: 2} = post} =
               Actions.update(PostWithLock, post, %{title: "V2"})

      assert {:ok, %PostWithLock{lock_version: 3}} =
               Actions.update(PostWithLock, post, %{title: "V3"})
    end
  end

  describe "update/4 optimistic locking via option" do
    test "uses the lock field specified in the options" do
      post =
        %PostWithLock{}
        |> PostWithLock.changeset(%{title: "Original"})
        |> Repo.insert!()

      assert {:ok, %PostWithLock{title: "Updated", lock_version: 2}} =
               Actions.update(PostWithLock, post, %{title: "Updated"},
                 optimistic_lock: :lock_version
               )
    end

    test "returns a stale error when the lock field option detects a version mismatch" do
      post =
        %PostWithLock{}
        |> PostWithLock.changeset(%{title: "Original"})
        |> Repo.insert!()

      PostWithLock
      |> where([p], p.id == ^post.id)
      |> Repo.update_all(set: [lock_version: 99])

      assert {:error, %{code: :stale}} =
               Actions.update(PostWithLock, post, %{title: "Too Late"},
                 optimistic_lock: :lock_version
               )
    end

    test "skips locking when optimistic_lock is set to false" do
      post =
        %PostWithLock{}
        |> PostWithLock.changeset(%{title: "Original"})
        |> Repo.insert!()

      PostWithLock
      |> where([p], p.id == ^post.id)
      |> Repo.update_all(set: [lock_version: 99])

      assert {:ok, %PostWithLock{title: "Updated"}} =
               Actions.update(PostWithLock, post, %{title: "Updated"}, optimistic_lock: false)
    end

    test "uses the custom incrementer function for the lock field" do
      post =
        %PostWithLock{}
        |> PostWithLock.changeset(%{title: "Original"})
        |> Repo.insert!()

      assert {:ok, %PostWithLock{title: "Updated", lock_version: 11}} =
               Actions.update(PostWithLock, post, %{title: "Updated"},
                 optimistic_lock: {:lock_version, fn _ -> 11 end}
               )
    end
  end

  describe "update/4 optimistic locking on schema without callback" do
    test "does not lock when the schema has no lock callback and no option is set" do
      post =
        %Post{}
        |> Post.changeset(%{title: "Original"})
        |> Repo.insert!()

      assert {:ok, %Post{title: "Updated"}} =
               Actions.update(Post, post, %{title: "Updated"})
    end
  end

  describe "all/3 with :preload" do
    test "preloads associations on returned structs" do
      post =
        %Post{}
        |> Post.changeset(%{title: "A"})
        |> Repo.insert!()

      %Comment{}
      |> Comment.changeset(%{body: "first", post_id: post.id})
      |> Repo.insert!()

      [result] = Actions.all(Post, %{id: post.id}, preload: [:comments])

      assert [%Comment{}] = result.comments
    end

    test "returns structs without preloading when :preload is absent" do
      %Post{}
      |> Post.changeset(%{title: "B"})
      |> Repo.insert!()

      [result] = Actions.all(Post, %{title: "B"})

      assert %Ecto.Association.NotLoaded{} = result.comments
    end

    test "returns structs unchanged when :preload is an empty list" do
      %Post{}
      |> Post.changeset(%{title: "C"})
      |> Repo.insert!()

      [result] = Actions.all(Post, %{title: "C"}, preload: [])

      assert %Ecto.Association.NotLoaded{} = result.comments
    end
  end

  describe "get/3 with :preload" do
    test "preloads associations on the returned struct" do
      post =
        %Post{}
        |> Post.changeset(%{title: "D"})
        |> Repo.insert!()

      %Comment{}
      |> Comment.changeset(%{body: "first", post_id: post.id})
      |> Repo.insert!()

      result = Actions.get(Post, post.id, preload: [:comments])

      assert [%Comment{}] = result.comments
    end

    test "returns nil unchanged when record is not found" do
      assert nil === Actions.get(Post, -1, preload: [:comments])
    end

    test "returns the record unchanged when :preload is an empty list" do
      post =
        %Post{}
        |> Post.changeset(%{title: "EmptyPreloadGet"})
        |> Repo.insert!()

      result = Actions.get(Post, post.id, preload: [])

      assert %Post{title: "EmptyPreloadGet"} = result
      assert %Ecto.Association.NotLoaded{} = result.comments
    end
  end

  describe "find/3 with :preload" do
    test "preloads associations on the found struct" do
      post =
        %Post{}
        |> Post.changeset(%{title: "E"})
        |> Repo.insert!()

      %Comment{}
      |> Comment.changeset(%{body: "first", post_id: post.id})
      |> Repo.insert!()

      assert {:ok, %Post{comments: [%Comment{}]}} =
               Actions.find(Post, %{id: post.id}, preload: [:comments])
    end

    test "returns the record unchanged when :preload is an empty list" do
      post =
        %Post{}
        |> Post.changeset(%{title: "EmptyPreloadFind"})
        |> Repo.insert!()

      assert {:ok, result} = Actions.find(Post, %{id: post.id}, preload: [])

      assert %Post{title: "EmptyPreloadFind"} = result
      assert %Ecto.Association.NotLoaded{} = result.comments
    end
  end

  describe "create/3 with :preload" do
    test "preloads associations on the created struct" do
      assert {:ok, %Post{comments: []}} =
               Actions.create(Post, %{title: "F"}, preload: [:comments])
    end

    test "returns the created struct unchanged when :preload is an empty list" do
      assert {:ok, %Post{title: "EmptyPreloadCreate"} = result} =
               Actions.create(Post, %{title: "EmptyPreloadCreate"}, preload: [])

      assert %Ecto.Association.NotLoaded{} = result.comments
    end
  end

  describe "update/4 with :preload" do
    test "preloads associations on the updated struct" do
      post =
        %Post{}
        |> Post.changeset(%{title: "G"})
        |> Repo.insert!()

      assert {:ok, %Post{title: "G updated", comments: []}} =
               Actions.update(Post, post, %{title: "G updated"}, preload: [:comments])
    end
  end

  describe "find_or_create/3 with :preload" do
    test "preloads associations on the created struct" do
      assert {:ok, %Post{comments: []}} =
               Actions.find_or_create(Post, %{title: "H"}, preload: [:comments])
    end

    test "preloads associations on the found struct" do
      %Post{}
      |> Post.changeset(%{title: "I"})
      |> Repo.insert!()

      assert {:ok, %Post{title: "I", comments: []}} =
               Actions.find_or_create(Post, %{title: "I"}, preload: [:comments])
    end
  end

  describe "find_and_create/4 with :preload" do
    test "preloads associations on the created struct when record is not found" do
      assert {:ok, %Post{comments: []}} =
               Actions.find_and_create(
                 Post,
                 %{title: "J"},
                 %{title: "J"},
                 preload: [:comments]
               )
    end
  end

  describe "find_and_update/4 with :preload" do
    test "preloads associations on the updated struct" do
      post =
        %Post{}
        |> Post.changeset(%{title: "K"})
        |> Repo.insert!()

      assert {:ok, %Post{title: "K updated", comments: []}} =
               Actions.find_and_update(Post, %{id: post.id}, %{title: "K updated"},
                 preload: [:comments]
               )
    end
  end

  describe "find_and_upsert/4 with :preload" do
    test "preloads associations on the created struct when record is not found" do
      assert {:ok, %Post{comments: []}} =
               Actions.find_and_upsert(
                 Post,
                 %{title: "L"},
                 %{},
                 preload: [:comments]
               )
    end

    test "preloads associations on the updated struct when record is found" do
      post =
        %Post{}
        |> Post.changeset(%{title: "M"})
        |> Repo.insert!()

      assert {:ok, %Post{title: "M updated", comments: []}} =
               Actions.find_and_upsert(Post, %{id: post.id}, %{title: "M updated"},
                 preload: [:comments]
               )
    end
  end

  describe "find_and_update/4 optimistic locking" do
    test "applies locking when find_and_update uses a schema with a lock callback" do
      post =
        %PostWithLock{}
        |> PostWithLock.changeset(%{title: "Original"})
        |> Repo.insert!()

      PostWithLock
      |> where([p], p.id == ^post.id)
      |> Repo.update_all(set: [lock_version: 99])

      assert {:ok, %PostWithLock{title: "Updated", lock_version: 100}} =
               Actions.find_and_update(PostWithLock, %{id: post.id}, %{title: "Updated"})
    end

    test "returns a stale error when the record was updated after it was found" do
      post =
        %PostWithLock{}
        |> PostWithLock.changeset(%{title: "Original"})
        |> Repo.insert!()

      assert {:ok, %PostWithLock{title: "First Update", lock_version: 2}} =
               Actions.find_and_update(PostWithLock, %{id: post.id}, %{title: "First Update"})

      assert {:error, %{code: :stale}} =
               Actions.update(PostWithLock, post, %{title: "Stale Update"})
    end
  end

  describe "delete/1 no-opts shorthand" do
    test "deletes the struct when called with only the struct argument" do
      post =
        %Post{}
        |> Post.changeset(%{title: "NoOpts"})
        |> Repo.insert!()

      assert {:ok, %Post{}} = Actions.delete(post)
      assert Repo.get(Post, post.id) === nil
    end
  end

  describe "delete/2 with a changeset" do
    test "deletes the record when given an Ecto.Changeset" do
      post =
        %Post{}
        |> Post.changeset(%{title: "ChangesetDelete"})
        |> Repo.insert!()

      changeset = Post.changeset(post, %{})

      assert {:ok, %Post{title: "ChangesetDelete"}} = Actions.delete(changeset, [])
      assert Repo.get(Post, post.id) === nil
    end
  end

  describe "delete/3 proxy (queryable + struct)" do
    test "deletes the given struct when called with queryable, struct, and opts" do
      post =
        %Post{}
        |> Post.changeset(%{title: "ProxyDelete"})
        |> Repo.insert!()

      assert {:ok, %Post{}} = Actions.delete(Post, post, [])
      assert Repo.get(Post, post.id) === nil
    end

    test "deletes a record by id when called with queryable, integer id, and opts" do
      post =
        %Post{}
        |> Post.changeset(%{title: "DeleteById3"})
        |> Repo.insert!()

      assert {:ok, %Post{}} = Actions.delete(Post, post.id, [])
      assert Repo.get(Post, post.id) === nil
    end
  end

  describe "delete/2 list error branch" do
    test "halts and returns the error when one delete in the list fails" do
      blocked =
        %Post{}
        |> Post.changeset(%{title: "Blocked"})
        |> Repo.insert!()

      ok_post =
        %Post{}
        |> Post.changeset(%{title: "OK"})
        |> Repo.insert!()

      %Comment{}
      |> Comment.changeset(%{body: "blocking", post_id: blocked.id})
      |> Repo.insert!()

      # Pass blocked post second so the first delete succeeds and the second halts
      assert {:error, %{code: :conflict}} = Actions.delete([ok_post, blocked], [])
    end
  end

  describe "all/2 with Source and keyword opts" do
    test "resolves the source and returns matching records when opts is a keyword list" do
      alias EctoShorts.Actions.Source

      %Post{}
      |> Post.changeset(%{title: "SourceKeyword"})
      |> Repo.insert!()

      source = Source.new(store: [posts: Post])

      result = Actions.all(source, from: :posts, title: "SourceKeyword")
      assert [%Post{title: "SourceKeyword"}] = result
    end
  end

  describe "all/2 ArgumentError" do
    test "raises ArgumentError when the second argument is not a map or keyword list" do
      assert_raise ArgumentError, fn ->
        Actions.all(Post, :not_a_valid_arg)
      end
    end
  end

  describe "stream/3 with Source" do
    test "resolves the source and streams matching records" do
      alias EctoShorts.Actions.Source

      %Post{}
      |> Post.changeset(%{title: "StreamSource"})
      |> Repo.insert!()

      source = Source.new(store: [posts: Post])

      assert {:ok, [%Post{title: "StreamSource"}]} =
               Repo.transaction(fn ->
                 source
                 |> Actions.stream(%{from: :posts, title: "StreamSource"})
                 |> Enum.to_list()
               end)
    end
  end

  describe "all/3 keyword params with put_param" do
    test "appends order_by to keyword list params when passed via opts" do
      %Post{}
      |> Post.changeset(%{title: "B"})
      |> Repo.insert!()

      %Post{}
      |> Post.changeset(%{title: "A"})
      |> Repo.insert!()

      # When params is a keyword list (not a map), put_param appends {key, value}
      # to the keyword list rather than calling Map.put.
      results = Actions.all(Post, [title: "A"], order_by: [asc: :title])
      assert [%Post{title: "A"}] = results
    end
  end

  describe "find/3 keyword params with put_param" do
    test "appends order_by to keyword list params when passed via opts" do
      %Post{}
      |> Post.changeset(%{title: "PutParamFindB"})
      |> Repo.insert!()

      post_a =
        %Post{}
        |> Post.changeset(%{title: "PutParamFindA"})
        |> Repo.insert!()

      # find/3 also calls put_param; passing keyword list params exercises
      # the enum ++ [{key, value}] branch when enum is not a map.
      assert {:ok, %Post{title: "PutParamFindA"}} =
               Actions.find(Post, [id: post_a.id], order_by: [asc: :title])
    end
  end
end
