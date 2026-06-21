defmodule EctoShorts.Actions.TransactionTest do
  use EctoShorts.DataCase, async: true

  alias Ecto.Changeset
  alias Ecto.Multi
  alias EctoShorts.Actions
  alias EctoShorts.Schema.Post

  describe "transact/2" do
    test "returns :ok when the function returns :ok" do
      assert :ok = Actions.transact(fn -> :ok end, repo: Repo)
    end

    test "rolls back and returns :error when the function returns :error" do
      assert :error =
               Actions.transact(
                 fn repo ->
                   repo.insert!(%Post{title: "ShouldRollback"})
                   :error
                 end,
                 repo: Repo
               )
    end

    test "unwraps a nested ok tuple in strict mode" do
      assert {:ok, 1} = Actions.transact(fn -> {:ok, {:ok, 1}} end, repo: Repo)
    end

    test "unwraps a nested error tuple in strict mode" do
      assert {:error, :my_error} =
               Actions.transact(fn -> {:ok, {:error, :my_error}} end, repo: Repo)
    end

    test "keeps the error tuple as committed data when strict mode is off" do
      assert {:ok, {:error, :reason}} =
               Actions.transact(fn -> {:error, :reason} end, repo: Repo, strict: false)
    end

    test "runs an Ecto.Multi and returns the inserted records" do
      multi =
        Multi.new()
        |> Multi.insert(:post_a, Post.changeset(%Post{}, %{title: "A"}))
        |> Multi.insert(:post_b, Post.changeset(%Post{}, %{title: "B"}))

      assert {:ok, [%Post{title: "A"}, %Post{title: "B"}]} = Actions.transact(multi, repo: Repo)
    end

    test "rolls back and returns a changeset error when an Ecto.Multi operation fails" do
      multi =
        Multi.new()
        |> Multi.insert(:post_a, Post.changeset(%Post{}, %{title: "A", permalink: "dup"}))
        |> Multi.insert(:post_b, Post.changeset(%Post{}, %{title: "B", permalink: "dup"}))

      assert {:error, %Changeset{}} = Actions.transact(multi, repo: Repo)
    end
  end

  describe "transaction/2" do
    test "wraps the function in a transaction and returns the result" do
      assert {:ok, {:ok, %Post{title: "Transacted"}}} =
               Actions.transaction(fn ->
                 Actions.create(Post, %{title: "Transacted"})
               end)
    end
  end

  describe "transact/1 (default opts)" do
    # Covers the def transact(fun_or_multi, opts \\ []) default-args head,
    # which generates a 1-arity delegate that uses [] as opts.
    test "runs successfully when called with only a function and no opts" do
      assert {:ok, %Post{title: "DefaultOpts"}} =
               Actions.transact(fn ->
                 Actions.create(Post, %{title: "DefaultOpts"})
               end)
    end
  end

  describe "transact/2 error rollback" do
    # Covers Transaction.maybe_rollback/2 line 49: {:error, reason} → repo.rollback(reason).
    # The existing `:error` test covers line 48; this test covers the tuple form.
    test "rolls back and returns the reason when the function returns an error tuple" do
      assert {:error, :my_reason} =
               Actions.transact(fn -> {:error, :my_reason} end, repo: Repo)
    end
  end
end
