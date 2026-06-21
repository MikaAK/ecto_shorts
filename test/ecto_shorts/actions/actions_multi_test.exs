defmodule EctoShorts.Actions.MultiTest do
  use EctoShorts.DataCase, async: true

  alias Ecto.Changeset
  alias EctoShorts.Actions
  alias EctoShorts.Schema.Comment
  alias EctoShorts.Schema.Post

  describe "create_many/3" do
    test "inserts all records in a single transaction" do
      params = [
        %{title: "A"},
        %{title: "B"}
      ]

      assert {:ok, [%Post{title: "A"} = post_a, %Post{title: "B"} = post_b]} =
               Actions.create_many(Post, params)

      assert %Post{title: "A"} = Repo.get!(Post, post_a.id)
      assert %Post{title: "B"} = Repo.get!(Post, post_b.id)
    end

    test "rolls back all inserts when one record fails validation" do
      params = [
        %{permalink: "exising"},
        %{permalink: "exising"}
      ]

      assert {:error,
              %{
                code: :conflict,
                message: "failed to create record.",
                details: %{
                  schema: Post,
                  action: :create,
                  index: 1,
                  changeset: %Changeset{},
                  params: %{permalink: "exising"}
                }
              }} = Actions.create_many(Post, params)
    end

    test "rolls back all inserts when a database constraint is violated" do
      params = [
        %{title: "A", permalink: "create-many-dup"},
        %{title: "B", permalink: "create-many-dup"}
      ]

      assert {:error,
              %{
                code: :conflict,
                message: "failed to create record.",
                details: %{
                  index: 1,
                  changeset: %Changeset{},
                  params: %{permalink: "create-many-dup"}
                }
              }} =
               Actions.create_many(Post, params)
    end
  end

  describe "find_many/3" do
    test "returns all records when every lookup succeeds" do
      %Post{}
      |> Post.changeset(%{title: "A"})
      |> Repo.insert!()

      %Post{}
      |> Post.changeset(%{title: "B"})
      |> Repo.insert!()

      params = [
        %{title: "A"},
        %{title: "B"}
      ]

      assert {:ok, [%Post{title: "A"}, %Post{title: "B"}]} =
               Actions.find_many(Post, params)
    end

    test "rolls back when any record is not found" do
      %Post{}
      |> Post.changeset(%{title: "A"})
      |> Repo.insert!()

      params = [
        %{title: "A"},
        %{title: "Missing"}
      ]

      assert {:error,
              %{
                code: :not_found,
                message: "no records found",
                details: %{
                  schema: Post,
                  action: :find,
                  index: 1,
                  params: %{title: "Missing"},
                  changes_so_far: [%Post{title: "A"}]
                }
              }} =
               Actions.find_many(Post, params)
    end
  end

  describe "update_many/3" do
    test "updates all records in a single transaction" do
      post_a =
        %Post{}
        |> Post.changeset(%{title: "Original A"})
        |> Repo.insert!()

      post_b =
        %Post{}
        |> Post.changeset(%{title: "Original B"})
        |> Repo.insert!()

      params = [
        %{id: post_a.id, title: "Updated A"},
        %{id: post_b.id, title: "Updated B"}
      ]

      assert {:ok, [%Post{title: "Updated A"}, %Post{title: "Updated B"}]} =
               Actions.update_many(Post, params)

      assert %Post{title: "Updated A"} = Repo.get!(Post, post_a.id)
      assert %Post{title: "Updated B"} = Repo.get!(Post, post_b.id)
    end

    test "rolls back all updates when one record fails validation" do
      post_a =
        %Post{}
        |> Post.changeset(%{title: "Valid"})
        |> Repo.insert!()

      post_b =
        %Post{}
        |> Post.changeset(%{title: "Also Valid"})
        |> Repo.insert!()

      params = [
        %{id: post_a.id, title: "Updated"},
        %{id: post_b.id, views: "not_an_integer"}
      ]

      assert {:error,
              %{
                code: :conflict,
                message: "failed to update record.",
                details: %{
                  schema: Post,
                  action: :update,
                  index: 1,
                  changeset: %Changeset{},
                  params: %{views: "not_an_integer"}
                }
              }} =
               Actions.update_many(Post, params)

      # transaction rollback: records should not be updated
      assert %Post{title: "Valid"} = Repo.get!(Post, post_a.id)
      assert %Post{title: "Also Valid"} = Repo.get!(Post, post_b.id)
    end

    test "rolls back all updates when a record is not found" do
      post =
        %Post{}
        |> Post.changeset(%{title: "Existing"})
        |> Repo.insert!()

      params = [
        %{id: post.id, title: "Updated"},
        %{id: 999_999, title: "Not Found"}
      ]

      assert {:error, %{code: :not_found, message: "no records found", details: details}} =
               Actions.update_many(Post, params)

      assert 1 = details.index

      # transaction rollback: first record should not be updated
      assert %Post{title: "Existing"} = Repo.get!(Post, post.id)
    end
  end

  describe "delete_many/2" do
    test "deletes all records in a single transaction" do
      post_a =
        %Post{}
        |> Post.changeset(%{title: "A"})
        |> Repo.insert!()

      post_b =
        %Post{}
        |> Post.changeset(%{title: "B"})
        |> Repo.insert!()

      assert {:ok, [%Post{title: "A"}, %Post{title: "B"}]} =
               Actions.delete_many(Post, [post_a, post_b])

      assert nil === Repo.get(Post, post_a.id)
      assert nil === Repo.get(Post, post_b.id)
    end

    test "rolls back when a delete fails due to a constraint" do
      blocked =
        %Post{}
        |> Post.changeset(%{title: "Blocked"})
        |> Repo.insert!()

      %Comment{}
      |> Comment.changeset(%{body: "hello", post_id: blocked.id})
      |> Repo.insert!()

      assert {:error, %{code: :conflict, message: "failed to delete record."}} =
               Actions.delete_many(Post, [blocked])
    end
  end

  describe "find_or_create_many/3" do
    test "finds existing records and creates missing ones in a single transaction" do
      %Post{}
      |> Post.changeset(%{title: "Existing"})
      |> Repo.insert!()

      params = [
        %{title: "Existing"},
        %{title: "Created"}
      ]

      assert {:ok, [%Post{title: "Existing"}, %Post{title: "Created"}]} =
               Actions.find_or_create_many(Post, params)
    end
  end

  describe "find_and_upsert_many/3" do
    test "creates all records when none are found" do
      params = [
        {%{title: "A"}, %{title: "A"}},
        {%{title: "B"}, %{title: "B"}}
      ]

      assert {:ok, [%Post{title: "A"}, %Post{title: "B"}]} =
               Actions.find_and_upsert_many(Post, params)
    end

    test "updates the record when a match is found" do
      %Post{}
      |> Post.changeset(%{title: "A"})
      |> Repo.insert!()

      params = [
        {%{title: "A"}, %{title: "Updated"}}
      ]

      assert {:ok, [%Post{title: "Updated"}]} = Actions.find_and_upsert_many(Post, params)
    end
  end

  describe "create_many/3 with :preload" do
    test "preloads associations on all created structs" do
      assert {:ok, posts} =
               Actions.create_many(Post, [%{title: "A"}, %{title: "B"}], preload: [:comments])

      assert Enum.all?(posts, fn p -> p.comments === [] end)
    end
  end

  describe "find_many/3 with :preload" do
    test "preloads associations on all found structs" do
      post_a =
        %Post{}
        |> Post.changeset(%{title: "FM-A"})
        |> Repo.insert!()

      post_b =
        %Post{}
        |> Post.changeset(%{title: "FM-B"})
        |> Repo.insert!()

      assert {:ok, posts} =
               Actions.find_many(Post, [%{id: post_a.id}, %{id: post_b.id}], preload: [:comments])

      assert Enum.all?(posts, fn p -> p.comments === [] end)
    end
  end

  describe "update_many/3 with :preload" do
    test "preloads associations on all updated structs" do
      post_a =
        %Post{}
        |> Post.changeset(%{title: "UM-A"})
        |> Repo.insert!()

      post_b =
        %Post{}
        |> Post.changeset(%{title: "UM-B"})
        |> Repo.insert!()

      assert {:ok, posts} =
               Actions.update_many(
                 Post,
                 [
                   %{id: post_a.id, title: "UM-A Updated"},
                   %{id: post_b.id, title: "UM-B Updated"}
                 ],
                 preload: [:comments]
               )

      assert ["UM-A Updated", "UM-B Updated"] = posts |> Enum.map(& &1.title) |> Enum.sort()
      assert Enum.all?(posts, fn post -> post.comments === [] end)
    end
  end

  describe "delete_many/3 with :preload" do
    test "preloads associations on all deleted structs" do
      post_a =
        %Post{}
        |> Post.changeset(%{title: "DM-A"})
        |> Repo.insert!()

      post_b =
        %Post{}
        |> Post.changeset(%{title: "DM-B"})
        |> Repo.insert!()

      assert {:ok, deleted_posts} =
               Actions.delete_many(Post, [post_a, post_b], preload: [:comments])

      assert ["DM-A", "DM-B"] = deleted_posts |> Enum.map(& &1.title) |> Enum.sort()
      assert Enum.all?(deleted_posts, fn post -> post.comments === [] end)
      assert nil === Repo.get(Post, post_a.id)
      assert nil === Repo.get(Post, post_b.id)
    end
  end

  describe "find_or_create_many/3 with :preload" do
    test "preloads associations on found and created structs" do
      existing =
        %Post{}
        |> Post.changeset(%{title: "FOCM-Existing"})
        |> Repo.insert!()

      assert {:ok, posts} =
               Actions.find_or_create_many(
                 Post,
                 [
                   %{title: "FOCM-Existing"},
                   %{title: "FOCM-Created"}
                 ],
                 preload: [:comments]
               )

      assert ["FOCM-Created", "FOCM-Existing"] = posts |> Enum.map(& &1.title) |> Enum.sort()
      assert Enum.all?(posts, fn post -> post.comments === [] end)
      assert Enum.any?(posts, fn post -> post.id === existing.id end)
    end
  end

  describe "find_and_upsert_many/3 with :preload" do
    test "preloads associations on updated and created structs" do
      existing =
        %Post{}
        |> Post.changeset(%{title: "FAUM-Existing"})
        |> Repo.insert!()

      assert {:ok, posts} =
               Actions.find_and_upsert_many(
                 Post,
                 [
                   {%{id: existing.id}, %{title: "FAUM-Updated"}},
                   {%{title: "FAUM-Created"}, %{}}
                 ],
                 preload: [:comments]
               )

      assert ["FAUM-Created", "FAUM-Updated"] = posts |> Enum.map(& &1.title) |> Enum.sort()
      assert Enum.all?(posts, fn post -> post.comments === [] end)
      assert Enum.any?(posts, fn post -> post.id === existing.id end)
    end
  end

  describe "find_and_upsert_many/3 with map entries" do
    test "upserts a record when the entry is a map with an :id key" do
      existing =
        %Post{}
        |> Post.changeset(%{title: "MapUpsert"})
        |> Repo.insert!()

      assert {:ok, [%Post{title: "MapUpsertUpdated"}]} =
               Actions.find_and_upsert_many(Post, [%{id: existing.id, title: "MapUpsertUpdated"}])
    end

    test "raises ArgumentError when an entry is not a tuple and has no :id key" do
      assert_raise ArgumentError, fn ->
        Actions.find_and_upsert_many(Post, [:not_a_valid_entry])
      end
    end
  end

  describe "update_many/3 with map entries" do
    test "updates a record when the entry is a map with an :id key" do
      post =
        %Post{}
        |> Post.changeset(%{title: "MapUpdate"})
        |> Repo.insert!()

      assert {:ok, [%Post{title: "MapUpdateDone"}]} =
               Actions.update_many(Post, [%{id: post.id, title: "MapUpdateDone"}])
    end

    test "raises ArgumentError when an entry is neither a tuple nor a map with :id" do
      assert_raise ArgumentError, fn ->
        Actions.update_many(Post, [:not_a_valid_entry])
      end
    end
  end

  describe "update_many/3 with tuple entries" do
    test "finds and updates the record when the entry is a {find_params, update_params} tuple" do
      post =
        %Post{}
        |> Post.changeset(%{title: "TupleUpdateOriginal"})
        |> Repo.insert!()

      assert {:ok, [%Post{title: "TupleUpdateDone"}]} =
               Actions.update_many(Post, [{%{id: post.id}, %{title: "TupleUpdateDone"}}])

      assert %Post{title: "TupleUpdateDone"} = Repo.get!(Post, post.id)
    end
  end

  describe "delete_many/2 with non-struct entries" do
    test "deletes a record when the entry is a plain map with an :id key" do
      post =
        %Post{}
        |> Post.changeset(%{title: "MapDelete"})
        |> Repo.insert!()

      assert {:ok, [%Post{}]} = Actions.delete_many(Post, [%{id: post.id}])
      assert nil === Repo.get(Post, post.id)
    end

    test "deletes a record when the entry is a scalar id" do
      post =
        %Post{}
        |> Post.changeset(%{title: "ScalarDelete"})
        |> Repo.insert!()

      assert {:ok, [%Post{}]} = Actions.delete_many(Post, [post.id])
      assert nil === Repo.get(Post, post.id)
    end
  end
end
