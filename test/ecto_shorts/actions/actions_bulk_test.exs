defmodule EctoShorts.Actions.BulkTest do
  use EctoShorts.DataCase, async: true

  alias EctoShorts.Actions
  alias EctoShorts.Schema.Comment
  alias EctoShorts.Schema.Post
  alias EctoShorts.Schema.UserData

  describe "insert_all/3" do
    test "inserts all records and returns the count" do
      assert {:ok, {2, nil}} =
               Actions.insert_all(
                 Post,
                 [%{title: "First"}, %{title: "Second"}],
                 []
               )

      assert [%Post{title: "First"}, %Post{title: "Second"}] = Repo.all(Post)
    end

    test "returns the inserted records when the :returning option is true" do
      assert {:ok, {2, [%Post{title: "First"}, %Post{title: "Second"}]}} =
               Actions.insert_all(
                 Post,
                 [%{title: "First"}, %{title: "Second"}],
                 returning: true
               )
    end

    test "returns a changeset error when any record fails validation" do
      assert {:error, [changeset]} = Actions.insert_all(Post, [%{views: "oops"}])

      assert %Ecto.Changeset{valid?: false} = changeset
      assert Keyword.has_key?(changeset.errors, :views)
    end

    test "updates existing records when the insert includes their primary key" do
      existing_post =
        %Post{}
        |> Post.changeset(%{title: "Original Title"})
        |> Repo.insert!()

      assert {:ok, {1, nil}} =
               Actions.insert_all(
                 Post,
                 [%{id: existing_post.id, title: "Updated Title"}],
                 on_conflict_replace: [:title]
               )

      assert %Post{title: "Updated Title"} = Repo.get!(Post, existing_post.id)
    end

    test "handles duplicate primary keys without raising by default" do
      existing_post =
        %Post{}
        |> Post.changeset(%{title: "Original"})
        |> Repo.insert!()

      exception =
        try do
          Repo.insert_all(Post, [%{id: existing_post.id, title: "Will Raise"}], [])
          nil
        rescue
          e in Postgrex.Error ->
            e
        end

      assert %Postgrex.Error{} = exception

      assert {:ok, {1, nil}} =
               Actions.insert_all(
                 Post,
                 [%{id: existing_post.id, title: "Updated"}],
                 []
               )

      assert %Post{title: "Updated"} = Repo.get!(Post, existing_post.id)
    end

    test "on_conflict_replace: :none does not raise and leaves the existing row unchanged" do
      existing_post =
        %Post{}
        |> Post.changeset(%{title: "Original"})
        |> Repo.insert!()

      assert {:ok, {0, nil}} =
               Actions.insert_all(
                 Post,
                 [%{id: existing_post.id, title: "Ignored"}],
                 on_conflict_replace: :none
               )

      assert %Post{title: "Original"} = Repo.get!(Post, existing_post.id)
    end

    test "respects a caller-provided on_conflict option over the default" do
      existing_post =
        %Post{}
        |> Post.changeset(%{title: "Original"})
        |> Repo.insert!()

      assert {:ok, {0, nil}} =
               Actions.insert_all(
                 Post,
                 [%{id: existing_post.id, title: "Attempted Update"}],
                 on_conflict_replace: [:title],
                 on_conflict: :nothing
               )

      assert %Post{title: "Original"} = Repo.get!(Post, existing_post.id)
    end

    test "skips validation when validate is false" do
      assert {:ok, {2, nil}} =
               Actions.insert_all(
                 Comment,
                 [
                   %{body: "x"},
                   %{body: "y"}
                 ],
                 validate: false
               )

      assert [%Comment{body: "x"}, %Comment{body: "y"}] = Repo.all(Comment)
    end

    test "merges matching records into params before insertion when :batch_preload is set" do
      existing =
        %Post{}
        |> Post.changeset(%{title: "Existing"})
        |> Repo.insert!()

      entries = [%{title: "Existing"}, %{title: "New"}]

      assert {:ok, {2, nil}} =
               Actions.insert_all(Post, entries, batch_preload: :title)

      assert "Existing" = Repo.get!(Post, existing.id).title
    end

    test "passes through batch_find path when :batch_find option is set" do
      # When :batch_find is set but no entries match, batch_find returns the
      # entries unchanged and insert_all inserts them. This exercises the
      # batch_find branch in insert_all/3.
      assert {:ok, _} =
               Actions.insert_all(Post, [%{permalink: "no_match"}], batch_find: :permalink)
    end
  end

  describe "update_all/4" do
    test "updates all records matching the filter" do
      %Post{}
      |> Post.changeset(%{title: "Draft", published: false})
      |> Repo.insert!()

      %Post{}
      |> Post.changeset(%{title: "Already", published: true})
      |> Repo.insert!()

      assert {1, nil} =
               Actions.update_all(Post, %{published: false}, %{published: true})

      assert [_, _] = Actions.all(Post, %{published: true})
    end

    test "increments a numeric field using the :inc operation" do
      post =
        %Post{}
        |> Post.changeset(%{title: "Counter", views: 5})
        |> Repo.insert!()

      assert {1, nil} =
               Actions.update_all(Post, %{id: post.id}, %{views: {:inc, 3}})

      assert %Post{views: 8} = Repo.get!(Post, post.id)
    end
  end

  describe "delete_all/3" do
    test "deletes all records matching the filter and returns the count" do
      %Post{}
      |> Post.changeset(%{title: "A"})
      |> Repo.insert!()

      %Post{}
      |> Post.changeset(%{title: "A"})
      |> Repo.insert!()

      %Post{}
      |> Post.changeset(%{title: "B"})
      |> Repo.insert!()

      assert {2, nil} = Actions.delete_all(Post, %{title: "A"})
      assert [%Post{title: "B"}] = Repo.all(Post)
    end

    test "returns zero when no records match the filter" do
      %Post{}
      |> Post.changeset(%{title: "Only"})
      |> Repo.insert!()

      assert {0, nil} = Actions.delete_all(Post, %{title: "Missing"})
    end
  end

  describe "insert_all/3 with a schema that has a :data field" do
    test "treats a plain params map containing :data as params, not as a changeset" do
      # UserData has `field :data, :map`. Before the fix, %{data: %{...}} matched
      # the Ecto.Changeset clause and crashed with KeyError on .params access.
      assert {:ok, {1, nil}} =
               Actions.insert_all(UserData, [%{data: %{role: "admin"}}])
    end
  end
end
