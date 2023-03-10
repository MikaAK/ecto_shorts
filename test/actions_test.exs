defmodule EctoShorts.ActionsTest do
  use ExUnit.Case, async: true
  alias EctoShorts.Actions

  @dynamic_repo_name :echo_shorts_dynamic_repo

  describe "dynamic repo" do
    setup do
      {:ok, _pid} = EctoShorts.Repo.start_link(name: @dynamic_repo_name)

      EctoShorts.Repo.put_dynamic_repo(@dynamic_repo_name)

      :ok = Ecto.Adapters.SQL.Sandbox.checkout(EctoShorts.Repo)
    end

    test "returns expected result with dynamic repo name" do
      assert Actions.all(EctoShorts.Support.TestSchema, repo: {EctoShorts.Repo, @dynamic_repo_name})
    end

    test "raises when dynamic repo name is invalid" do
      assert_raise RuntimeError, ~r/could not lookup Ecto repo :bad_name/, fn ->
        Actions.all(EctoShorts.Support.TestSchema, repo: {EctoShorts.Repo, :bad_name})
      end
    end
  end
end
