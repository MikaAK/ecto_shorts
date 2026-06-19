defmodule EctoShorts.Actions.BatchTest do
  use EctoShorts.DataCase, async: true

  alias EctoShorts.Actions
  alias EctoShorts.Schema.Comment
  alias EctoShorts.Schema.Post
  alias EctoShorts.Schema.User

  describe "batch/3" do
    test "returns an empty map when no params are given" do
      assert %{} = Actions.batch(Post, [], batch_keys: [:title], cardinality: :many)
    end

    test "returns one record per key when cardinality is :one" do
      %Post{}
      |> Post.changeset(%{title: "A"})
      |> Repo.insert!()

      %Post{}
      |> Post.changeset(%{title: "B"})
      |> Repo.insert!()

      result = Actions.batch(Post, [%{title: "A"}, %{title: "B"}], batch_keys: :title, cardinality: :one)

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

      result = Actions.batch(Post, [%{title: "A"}, %{title: "B"}], batch_keys: :title, cardinality: :many)

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

      result = Actions.batch(Post, [%{title: "A"}, %{title: "B"}], batch_keys: [:title], cardinality: :many)

      assert %{
               %{title: "A"} => [%Post{title: "A"}],
               %{title: "B"} => [%Post{title: "B"}]
             } = result
    end

    test "returns an empty map when params are missing the batch key" do
      %Post{}
      |> Post.changeset(%{title: "A"})
      |> Repo.insert!()

      assert %{} = Actions.batch(Post, [%{permalink: "missing-title"}], batch_keys: [:title], cardinality: :many)
    end

    test "uses :id as default batch_keys and :many as default cardinality" do
      post =
        %Post{}
        |> Post.changeset(%{title: "Default"})
        |> Repo.insert!()

      post_id = post.id
      result = Actions.batch(Post, [%{id: post_id}])

      assert %{^post_id => [%Post{title: "Default"}]} = result
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

  describe "batch/3 edge cases" do
    test "returns an empty map when batch_keys is an empty list" do
      %Post{}
      |> Post.changeset(%{title: "A"})
      |> Repo.insert!()

      # build_batch_params/4 with empty batch_keys returns [] which causes batch to return %{}
      result = Actions.batch(Post, [%{title: "A"}], batch_keys: [], cardinality: :many)
      assert result === %{}
    end

    test "raises ArgumentError when batch_keys contains a key not in the schema's query fields" do
      assert_raise ArgumentError, fn ->
        Actions.batch(Post, [%{title: "A"}], batch_keys: [:nonexistent_field_xyz], cardinality: :many)
      end
    end
  end

  describe "Batch.normalize_batch_key/2" do
    alias EctoShorts.Actions.Batch

    test "converts a keyword list params to a map and extracts the given keys" do
      result = Batch.normalize_batch_key([title: "Hello", views: 5], [:title])
      assert result === %{title: "Hello"}
    end

    test "wraps a scalar value as a map keyed by the given atom" do
      result = Batch.normalize_batch_key("my_permalink", :permalink)
      assert result === %{permalink: "my_permalink"}
    end

    test "takes the given keys from a map when params is a map and keys is a list" do
      result = Batch.normalize_batch_key(%{title: "Hello", views: 5}, [:title])
      assert result === %{title: "Hello"}
    end
  end

  describe "Batch.handle_batch_response/4 without preload" do
    alias EctoShorts.Actions.Batch

    test "returns the grouped results map unchanged when no :preload option is given" do
      input = [{"key_a", [%Post{title: "A"}]}]

      result = Batch.handle_batch_response(input, :many, :title, [])

      assert %{"key_a" => [%Post{title: "A"}]} = result
    end

    test "returns the grouped results map unchanged when :preload is an empty list" do
      input = [{"key_b", [%Post{title: "B"}]}]

      result = Batch.handle_batch_response(input, :many, :title, preload: [])

      assert %{"key_b" => [%Post{title: "B"}]} = result
    end

    test "returns an empty map unchanged when records are empty and :preload is set" do
      result = Batch.handle_batch_response([], :many, :title, preload: [:comments])
      assert result === %{}
    end
  end

  describe "Batch.extract_lookup_params/2 with true key" do
    alias EctoShorts.Actions.Batch

    test "uses the whole params map as the batch key when keys is true" do
      input = %{id: 1, title: "Hello"}

      {params_list, index_map} = Batch.extract_lookup_params([input], true)

      assert params_list === [input]
      assert index_map === %{0 => input}
    end
  end

  describe "Batch.extract_lookup_params/2 with list keys" do
    alias EctoShorts.Actions.Batch

    test "extracts the given fields as the batch key when keys is a list" do
      input = %{id: 1, title: "Hello", views: 5}

      {params_list, index_map} = Batch.extract_lookup_params([input], [:id, :title])

      assert params_list === [%{id: 1, title: "Hello"}]
      assert index_map === %{0 => %{id: 1, title: "Hello"}}
    end
  end

  describe "Batch.handle_batch_response/4 :one cardinality" do
    alias EctoShorts.Actions.Batch

    test "raises ArgumentError when a single batch key resolves to multiple values" do
      assert_raise ArgumentError, fn ->
        Batch.handle_batch_response(
          [{"key", [%Post{title: "A"}, %Post{title: "B"}]}],
          :one,
          :title,
          []
        )
      end
    end
  end

  describe "Batch.normalize_key_fields/1" do
    alias EctoShorts.Actions.Batch

    test "returns a list unchanged when given a list" do
      assert Batch.normalize_key_fields([:id, :title]) === [:id, :title]
    end

    test "returns a non-atom non-list value unchanged" do
      key_fn = fn params -> params end
      assert Batch.normalize_key_fields(key_fn) === key_fn
    end
  end

  describe "Batch.extract_lookup_params/2 with a function key" do
    alias EctoShorts.Actions.Batch

    test "extracts the batch key using the function when the function returns a map" do
      key_fn = fn params -> Map.take(params, [:permalink]) end
      input = %{permalink: "my-slug", title: "Anything"}

      {params_list, index_map} = Batch.extract_lookup_params([input], key_fn)

      assert params_list === [%{permalink: "my-slug"}]
      assert index_map === %{0 => %{permalink: "my-slug"}}
    end

    test "raises RuntimeError when the function key returns a non-map value" do
      key_fn = fn _params -> :not_a_map end
      input = %{title: "Bad"}

      assert_raise RuntimeError, fn ->
        Batch.extract_lookup_params([input], key_fn)
      end
    end
  end

  describe "batch/3 with :preload" do
    test "preloads associations on batched structs with :one cardinality" do
      %Post{}
      |> Post.changeset(%{title: "Alpha"})
      |> Repo.insert!()

      result = Actions.batch(Post, [%{title: "Alpha"}], batch_keys: :title, cardinality: :one, preload: [:comments])

      assert %Post{comments: []} = result["Alpha"]
    end

    test "preloads associations on batched lists with :many cardinality" do
      %Post{}
      |> Post.changeset(%{title: "Beta"})
      |> Repo.insert!()

      result = Actions.batch(Post, [%{title: "Beta"}], batch_keys: :title, cardinality: :many, preload: [:comments])

      assert [%Post{comments: []}] = result["Beta"]
    end

    test "preloads associations on multi-key batched structs with :one cardinality" do
      post =
        %Post{}
        |> Post.changeset(%{title: "Gamma", permalink: "gamma"})
        |> Repo.insert!()

      comment =
        %Comment{}
        |> Comment.changeset(%{body: "hello", post_id: post.id})
        |> Repo.insert!()

      key = %{title: "Gamma", permalink: "gamma"}

      result = Actions.batch(Post, [key], batch_keys: [:title, :permalink], cardinality: :one, preload: [:comments])

      assert %Post{id: post_id, comments: [%Comment{id: comment_id, body: "hello"}]} = result[key]
      assert post_id === post.id
      assert comment_id === comment.id
    end

    test "pairs each multi-key result back with the correct preloaded struct when multiple results are returned" do
      post_a =
        %Post{}
        |> Post.changeset(%{title: "Gamma", permalink: "gamma"})
        |> Repo.insert!()

      post_b =
        %Post{}
        |> Post.changeset(%{title: "Delta", permalink: "delta"})
        |> Repo.insert!()

      comment_a =
        %Comment{}
        |> Comment.changeset(%{body: "hello gamma", post_id: post_a.id})
        |> Repo.insert!()

      comment_b =
        %Comment{}
        |> Comment.changeset(%{body: "hello delta", post_id: post_b.id})
        |> Repo.insert!()

      key_a = %{title: "Gamma", permalink: "gamma"}
      key_b = %{title: "Delta", permalink: "delta"}

      result =
        Actions.batch(Post, [key_b, key_a], batch_keys: [:title, :permalink], cardinality: :one, preload: [:comments])

      assert %Post{id: post_a_id, comments: [%Comment{id: comment_a_id, body: "hello gamma"}]} =
               result[key_a]

      assert %Post{id: post_b_id, comments: [%Comment{id: comment_b_id, body: "hello delta"}]} =
               result[key_b]

      assert post_a_id === post_a.id
      assert post_b_id === post_b.id
      assert comment_a_id === comment_a.id
      assert comment_b_id === comment_b.id
    end
  end
end
