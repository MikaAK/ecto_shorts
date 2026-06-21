defmodule EctoShorts.TestingTest do
  use ExUnit.Case, async: true

  alias EctoShorts.Testing
  alias EctoShorts.Schema.Post

  import Ecto.Query

  describe "assert_dynamic/2" do
    test "returns :ok when dynamic expressions are structurally identical" do
      dyn_a = dynamic([p], p.id == ^1)
      dyn_b = dynamic([p], p.id == ^1)

      assert :ok = Testing.assert_dynamic(dyn_a, dyn_b)
    end

    test "raises AssertionError when dynamic expressions differ" do
      dyn_a = dynamic([p], p.id == ^1)
      dyn_b = dynamic([p], p.id == ^2)

      assert_raise ExUnit.AssertionError, ~r/Expected dynamic expressions to be equal/, fn ->
        Testing.assert_dynamic(dyn_a, dyn_b)
      end
    end
  end

  describe "refute_dynamic/2" do
    test "returns :ok when dynamic expressions differ" do
      dyn_a = dynamic([p], p.id == ^1)
      dyn_b = dynamic([p], p.id == ^2)

      assert :ok = Testing.refute_dynamic(dyn_a, dyn_b)
    end

    test "raises AssertionError when dynamic expressions are identical" do
      dyn_a = dynamic([p], p.id == ^1)
      dyn_b = dynamic([p], p.id == ^1)

      assert_raise ExUnit.AssertionError,
                   ~r/Expected dynamic expressions to be different/,
                   fn ->
                     Testing.refute_dynamic(dyn_a, dyn_b)
                   end
    end
  end

  describe "assert_query/2" do
    test "returns :ok when queries have equal inspect output" do
      q1 = from(p in Post, where: p.id == ^1)
      q2 = from(p in Post, where: p.id == ^1)

      assert :ok = Testing.assert_query(q1, q2)
    end

    test "raises AssertionError when queries differ" do
      q1 = from(p in Post, where: p.id == ^1)
      q2 = from(p in Post, where: p.id == ^2)

      assert_raise ExUnit.AssertionError, ~r/Expected queries to be equal/, fn ->
        Testing.assert_query(q1, q2)
      end
    end
  end

  describe "refute_query/2" do
    test "returns :ok when queries differ" do
      q1 = from(p in Post, where: p.id == ^1)
      q2 = from(p in Post, where: p.id == ^2)

      assert :ok = Testing.refute_query(q1, q2)
    end

    test "raises AssertionError when queries are identical" do
      q1 = from(p in Post, where: p.id == ^1)
      q2 = from(p in Post, where: p.id == ^1)

      assert_raise ExUnit.AssertionError, ~r/Expected queries to be different/, fn ->
        Testing.refute_query(q1, q2)
      end
    end
  end

  describe "assert_sql/4" do
    test "returns :ok when queries produce the same SQL" do
      q1 = from(p in Post, where: p.id == ^1)
      q2 = from(p in Post, where: p.id == ^1)

      assert :ok = Testing.assert_sql(EctoShorts.Repo, q1, q2)
    end

    test "raises AssertionError when queries produce different SQL" do
      q1 = from(p in Post, where: p.id == ^1)
      q2 = from(p in Post, where: p.title == ^"hello")

      assert_raise ExUnit.AssertionError,
                   ~r/Expected queries to produce the same SQL/,
                   fn ->
                     Testing.assert_sql(EctoShorts.Repo, q1, q2)
                   end
    end
  end

  describe "refute_sql/4" do
    test "returns :ok when queries produce different SQL" do
      q1 = from(p in Post, where: p.id == ^1)
      q2 = from(p in Post, where: p.id == ^2)

      assert :ok = Testing.refute_sql(EctoShorts.Repo, q1, q2)
    end

    test "raises AssertionError when queries produce identical SQL and params" do
      q1 = from(p in Post, where: p.id == ^1)
      q2 = from(p in Post, where: p.id == ^1)

      assert_raise ExUnit.AssertionError,
                   ~r/Expected queries to produce different SQL/,
                   fn ->
                     Testing.refute_sql(EctoShorts.Repo, q1, q2)
                   end
    end
  end
end
