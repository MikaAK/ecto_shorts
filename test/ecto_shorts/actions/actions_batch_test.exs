defmodule EctoShorts.Actions.BatchTest do
  use EctoShorts.DataCase, async: true

  alias EctoShorts.Actions
  alias EctoShorts.Schema.Comment
  alias EctoShorts.Schema.Post
  alias EctoShorts.Schema.User

  describe "batch/4" do
    test "returns an empty map when no params are given" do
      assert %{} = Actions.batch(Post, [], [:title], :many, [])
    end

    test "returns one record per key when cardinality is :one" do
      %Post{}
      |> Post.changeset(%{title: "A"})
      |> Repo.insert!()

      %Post{}
      |> Post.changeset(%{title: "B"})
      |> Repo.insert!()

      result = Actions.batch(Post, [%{title: "A"}, %{title: "B"}], :title, :one, [])

      assert %{
               "A" => %Post{title: "A"},
               "B" => %Post{title: "B"}
             } = result
    end

    test "groups records by a single key when the key is an atom" do
      %Post{}
      |> Post.changeset(%{title: "A"})
      |> Repo.insert!()

      %Post{}
      |> Post.changeset(%{title: "B"})
      |> Repo.insert!()

      result = Actions.batch(Post, [%{title: "A"}, %{title: "B"}], :title, :many, [])

      assert %{
               "A" => [%Post{title: "A"}],
               "B" => [%Post{title: "B"}]
             } = result
    end

    test "groups records by a list of keys" do
      %Post{}
      |> Post.changeset(%{title: "A"})
      |> Repo.insert!()

      %Post{}
      |> Post.changeset(%{title: "B"})
      |> Repo.insert!()

      result = Actions.batch(Post, [%{title: "A"}, %{title: "B"}], [:title], :many, [])

      assert %{
               %{title: "A"} => [%Post{title: "A"}],
               %{title: "B"} => [%Post{title: "B"}]
             } = result
    end

    test "returns an empty map when params are missing the batch key" do
      %Post{}
      |> Post.changeset(%{title: "A"})
      |> Repo.insert!()

      assert %{} = Actions.batch(Post, [%{permalink: "missing-title"}], [:title], :many, [])
    end
  end

  describe "batch_find/4" do
    setup do
      post =
        %Post{}
        |> Post.changeset(%{title: "Existing", permalink: "existing"})
        |> Repo.insert!()

      %{post: post}
    end

    # Entries whose first element is already a struct are passed through unchanged
    # without a database query.
    test "keeps the entry unchanged when it is a struct-and-map tuple", %{post: post} do
      input = {post, %{title: "Ignored"}}

      assert [result] = Actions.batch_find(Post, [input], :permalink, [])
      assert result === input
    end

    test "keeps the entry unchanged when it is a struct-and-keyword tuple", %{post: post} do
      input = {post, [title: "Ignored"]}

      assert [result] = Actions.batch_find(Post, [input], :permalink, [])
      assert result === input
    end

    test "replaces the map with the matching record when the entry is a map-and-map tuple", %{
      post: post
    } do
      input = {%{permalink: "existing"}, %{title: "New"}}

      assert [{%Post{id: id}, %{title: "New"}}] =
               Actions.batch_find(Post, [input], :permalink, [])

      assert id === post.id
    end

    test "replaces the keyword list with the matching record when the entry is a keyword-and-keyword tuple",
         %{
           post: post
         } do
      input = {[permalink: "existing"], [title: "New"]}

      assert [{%Post{id: id}, [title: "New"]}] =
               Actions.batch_find(Post, [input], :permalink, [])

      assert id === post.id
    end

    test "replaces the keyword list with the matching record when the entry is a keyword-and-map tuple",
         %{
           post: post
         } do
      input = {[permalink: "existing"], %{title: "New"}}

      assert [{%Post{id: id}, %{title: "New"}}] =
               Actions.batch_find(Post, [input], :permalink, [])

      assert id === post.id
    end

    test "replaces the map with the matching record when the entry is a map-and-keyword tuple", %{
      post: post
    } do
      input = {%{permalink: "existing"}, [title: "New"]}

      assert [{%Post{id: id}, [title: "New"]}] =
               Actions.batch_find(Post, [input], :permalink, [])

      assert id === post.id
    end

    # A bare map or keyword list is looked up and converted to
    # `{resolved_struct, original_params}`, preserving the original params.
    test "wraps the map entry into a tuple with the matching record", %{post: post} do
      input = %{permalink: "existing", title: "New"}

      assert [{%Post{id: id}, params}] = Actions.batch_find(Post, [input], :permalink, [])
      assert id === post.id
      assert params === input
    end

    test "wraps the keyword entry into a tuple with the matching record", %{post: post} do
      input = [permalink: "existing", title: "New"]

      assert [{%Post{id: id}, params}] = Actions.batch_find(Post, [input], :permalink, [])
      assert id === post.id
      assert params === input
    end

    test "keeps a nil entry unchanged", %{post: _post} do
      assert [nil] = Actions.batch_find(Post, [nil], :permalink, [])
    end
  end

  describe "batch_find/4 with :preload" do
    test "preloads associations on the resolved struct" do
      post =
        %Post{}
        |> Post.changeset(%{title: "Findable", permalink: "findable"})
        |> Repo.insert!()

      input = %{permalink: "findable", title: "New"}

      assert [{resolved_post, ^input}] =
               Actions.batch_find(Post, [input], :permalink, preload: [:comments])

      assert resolved_post.id === post.id
      assert resolved_post.comments === []
    end

    test "preloads nested associations on the resolved struct" do
      user =
        %User{}
        |> User.changeset(%{first_name: "Ada"})
        |> Repo.insert!()

      post =
        %Post{}
        |> Post.changeset(%{title: "Nested", permalink: "nested"})
        |> Repo.insert!()

      %Comment{}
      |> Comment.changeset(%{body: "hi there", post_id: post.id, author_id: user.id})
      |> Repo.insert!()

      input = %{permalink: "nested", title: "New"}

      assert [{resolved_post, ^input}] =
               Actions.batch_find(Post, [input], :permalink, preload: [comments: :author])

      assert [%Comment{author: %User{id: author_id}}] = resolved_post.comments
      assert author_id === user.id
    end
  end

  describe "batch_find/4 with multiple entries" do
    test "resolves multiple entries in a single batched lookup" do
      post_a =
        %Post{}
        |> Post.changeset(%{title: "Alpha", permalink: "alpha"})
        |> Repo.insert!()

      post_b =
        %Post{}
        |> Post.changeset(%{title: "Beta", permalink: "beta"})
        |> Repo.insert!()

      input_a = %{permalink: "alpha", title: "New A"}
      input_b = %{permalink: "beta", title: "New B"}

      assert [{%Post{id: id_a}, ^input_a}, {%Post{id: id_b}, ^input_b}] =
               Actions.batch_find(Post, [input_a, input_b], :permalink, [])

      assert id_a === post_a.id
      assert id_b === post_b.id
    end
  end

  describe "batch/5 with :preload" do
    test "preloads associations on batched structs with :one cardinality" do
      %Post{}
      |> Post.changeset(%{title: "Alpha"})
      |> Repo.insert!()

      result = Actions.batch(Post, [%{title: "Alpha"}], :title, :one, preload: [:comments])

      assert %Post{comments: []} = result["Alpha"]
    end

    test "preloads associations on batched lists with :many cardinality" do
      %Post{}
      |> Post.changeset(%{title: "Beta"})
      |> Repo.insert!()

      result = Actions.batch(Post, [%{title: "Beta"}], :title, :many, preload: [:comments])

      assert [%Post{comments: []}] = result["Beta"]
    end
  end
end
