defmodule EctoShorts.TestingTest do
  use ExUnit.Case, async: true

  alias EctoShorts.Testing
  alias EctoShorts.Schema.Post

  import Ecto.Query

  describe "refute_dynamic/2" do
    test "returns :ok when dynamic expressions differ" do
      dyn_a = dynamic([p], p.id == 1)
      dyn_b = dynamic([p], p.id == 2)

      assert Testing.refute_dynamic(dyn_a, dyn_b) === :ok
    end
  end

  describe "refute_sql/4" do
    test "returns :ok when queries produce different SQL" do
      q1 = from(p in Post, where: p.id == ^1)
      q2 = from(p in Post, where: p.id == ^2)

      assert Testing.refute_sql(EctoShorts.Repo, q1, q2) === :ok
    end
  end

  describe "refute_query/2" do
    test "returns :ok when queries differ" do
      q1 = from(p in Post, where: p.id == ^1)
      q2 = from(p in Post, where: p.id == ^2)

      assert Testing.refute_query(q1, q2) === :ok
    end
  end
end
