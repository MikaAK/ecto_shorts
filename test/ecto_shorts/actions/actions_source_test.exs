defmodule EctoShorts.Actions.SourceDispatchTest do
  use EctoShorts.DataCase, async: true

  alias EctoShorts.Actions
  alias EctoShorts.Actions.Source
  alias EctoShorts.Schema.Post
  alias EctoShorts.Schema.User

  defp source do
    Source.new(store: [posts: Post, users: User])
  end

  describe "exists?/3 with Source" do
    test "returns true when a record matching the filter exists" do
      %Post{} |> Post.changeset(%{title: "Exists"}) |> Repo.insert!()
      assert true = Actions.exists?(source(), %{from: :posts, title: "Exists"})
    end

    test "returns a not_found error when :from does not match any store entry" do
      assert {:error, error} = Actions.exists?(source(), %{from: :missing})
      assert :not_found = error.code
      assert "source not found." = error.message
    end
  end

  describe "all/3 with Source" do
    test "returns records matching the filter after resolving the source" do
      %Post{} |> Post.changeset(%{title: "AllPost"}) |> Repo.insert!()
      assert [%Post{title: "AllPost"}] = Actions.all(source(), %{from: :posts, title: "AllPost"})
    end

    test "returns a not_found error when :from does not match any store entry" do
      assert {:error, error} = Actions.all(source(), %{from: :missing})
      assert :not_found = error.code
      assert "source not found." = error.message
    end

    test "returns records matching the filter when called with explicit opts" do
      %Post{} |> Post.changeset(%{title: "AllPostOpts"}) |> Repo.insert!()

      assert [%Post{title: "AllPostOpts"}] =
               Actions.all(source(), %{from: :posts, title: "AllPostOpts"}, repo: Repo)
    end
  end

  describe "find/3 with Source" do
    test "returns the matching record when found" do
      post = %Post{} |> Post.changeset(%{title: "FindMe"}) |> Repo.insert!()
      assert {:ok, %Post{id: id}} = Actions.find(source(), %{from: :posts, id: post.id})
      assert id === post.id
    end

    test "returns a not_found error when :from does not match any store entry" do
      assert {:error, error} = Actions.find(source(), %{from: :missing, id: 1})
      assert :not_found = error.code
      assert "source not found." = error.message
    end
  end

  describe "create/3 with Source" do
    test "inserts a record via the resolved schema" do
      assert {:ok, %Post{title: "Created"}} =
               Actions.create(source(), %{from: :posts, title: "Created"})
    end

    test "returns a not_found error when :from does not match any store entry" do
      assert {:error, error} = Actions.create(source(), %{from: :missing, title: "X"})
      assert :not_found = error.code
      assert "source not found." = error.message
    end
  end

  describe "find_and_create/4 with Source" do
    test "finds an existing record" do
      %Post{} |> Post.changeset(%{title: "FAC"}) |> Repo.insert!()

      assert {:ok, %Post{title: "FAC"}} =
               Actions.find_and_create(source(), %{from: :posts, title: "FAC"}, %{title: "FAC"})
    end

    test "returns a not_found error when :from does not match any store entry" do
      assert {:error, error} =
               Actions.find_and_create(source(), %{from: :missing, title: "X"}, %{title: "X"})

      assert :not_found = error.code
      assert "source not found." = error.message
    end
  end

  describe "find_and_update/4 with Source" do
    test "finds and updates the matching record" do
      post = %Post{} |> Post.changeset(%{title: "Before"}) |> Repo.insert!()

      assert {:ok, %Post{title: "After"}} =
               Actions.find_and_update(source(), %{from: :posts, id: post.id}, %{title: "After"})
    end

    test "returns a not_found error when :from does not match any store entry" do
      assert {:error, error} =
               Actions.find_and_update(source(), %{from: :missing, id: 1}, %{title: "X"})

      assert :not_found = error.code
      assert "source not found." = error.message
    end
  end

  describe "find_and_upsert/4 with Source" do
    test "updates the record when it exists" do
      post = %Post{} |> Post.changeset(%{title: "Upsert"}) |> Repo.insert!()

      assert {:ok, %Post{title: "Updated"}} =
               Actions.find_and_upsert(source(), %{from: :posts, id: post.id}, %{title: "Updated"})
    end

    test "returns a not_found error when :from does not match any store entry" do
      assert {:error, error} =
               Actions.find_and_upsert(source(), %{from: :missing, id: 1}, %{title: "X"})

      assert :not_found = error.code
      assert "source not found." = error.message
    end
  end

  describe "find_and_delete/3 with Source" do
    test "finds and deletes the matching record" do
      post = %Post{} |> Post.changeset(%{title: "ToDelete"}) |> Repo.insert!()
      assert {:ok, %Post{}} = Actions.find_and_delete(source(), %{from: :posts, id: post.id})
    end

    test "returns a not_found error when :from does not match any store entry" do
      assert {:error, error} = Actions.find_and_delete(source(), %{from: :missing, id: 1})
      assert :not_found = error.code
      assert "source not found." = error.message
    end
  end

  describe "find_or_create/3 with Source" do
    test "finds the record when it exists" do
      %Post{} |> Post.changeset(%{title: "FOC"}) |> Repo.insert!()

      assert {:ok, %Post{title: "FOC"}} =
               Actions.find_or_create(source(), %{from: :posts, title: "FOC"})
    end

    test "returns a not_found error when :from does not match any store entry" do
      assert {:error, error} = Actions.find_or_create(source(), %{from: :missing, title: "X"})
      assert :not_found = error.code
      assert "source not found." = error.message
    end
  end

  describe "aggregate/3 with Source" do
    test "counts records matching the filter" do
      %Post{} |> Post.changeset(%{title: "Agg"}) |> Repo.insert!()
      assert 1 = Actions.aggregate(source(), %{from: :posts, title: "Agg"}, aggregate: :count, key: :id)
    end

    test "returns a not_found error when :from does not match any store entry" do
      assert {:error, error} = Actions.aggregate(source(), %{from: :missing}, aggregate: :count, key: :id)
      assert :not_found = error.code
      assert "source not found." = error.message
    end
  end
end
