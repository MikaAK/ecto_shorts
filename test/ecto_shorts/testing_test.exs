defmodule EctoShorts.TestingTest do
  use ExUnit.Case, async: true
  doctest EctoShorts.Testing

  alias EctoShorts.Testing
  alias EctoShorts.Schema.{Comment, Post}
  alias EctoShorts.Repo

  import Ecto.Query, only: [dynamic: 2, from: 1]

  describe "assert_dynamic/2" do
    test "assert_dynamic/2 expands to equality comparison of macro strings" do
      quoted =
        quote do
          EctoShorts.Testing.assert_dynamic(
            dynamic([q], q.id == 1),
            dynamic([q], q.id == 1)
          )
        end

      expanded = Macro.expand_once(quoted, __ENV__)

      expected_ast =
        quote do
          assert Macro.to_string(dynamic([q], q.id == 1)) ===
                   Macro.to_string(dynamic([q], q.id == 1))
        end

      assert Macro.to_string(expanded) === Macro.to_string(expected_ast)
    end

    test "returns true when dynamic expressions are structurally equal" do
      dyn_a = dynamic([q], q.id == 1)
      dyn_b = dynamic([q], q.id == 1)

      assert "true" ===
               dyn_a
               |> Testing.assert_dynamic(dyn_b)
               |> Macro.to_string()
    end
  end

  describe "refute_dynamic/2" do
    test "refute_dynamic/2 expands to inequality comparison of macro strings" do
      quoted =
        quote do
          EctoShorts.Testing.refute_dynamic(
            dynamic([q], q.id == 1),
            dynamic([q], q.id == 2)
          )
        end

      expanded = Macro.expand_once(quoted, __ENV__)

      expected_ast =
        quote do
          refute Macro.to_string(dynamic([q], q.id == 1)) ===
                   Macro.to_string(dynamic([q], q.id == 2))
        end

      assert Macro.to_string(expanded) === Macro.to_string(expected_ast)
    end

    test "returns false when dynamic expressions differ" do
      dyn_a = dynamic([q], q.id == 1)
      dyn_b = dynamic([q], q.id == 2)

      assert "false" ===
               dyn_a
               |> Testing.refute_dynamic(dyn_b)
               |> Macro.to_string()
    end
  end

  describe "assert_sql/2" do
    test "assert_sql/4 expands to equality comparison of SQL strings" do
      quoted =
        quote do
          EctoShorts.Testing.assert_sql(Repo, from(p in Post), from(p in Post))
        end

      expanded = Macro.expand_once(quoted, __ENV__)

      expected_ast =
        quote do
          assert Ecto.Adapters.SQL.to_sql(:all, Repo, from(p in Post)) ===
                   Ecto.Adapters.SQL.to_sql(:all, Repo, from(p in Post))
        end

      assert Macro.to_string(expanded) == Macro.to_string(expected_ast)
    end

    test "returns true when both queries produce identical SQL" do
      query_a = from(p in Post)
      query_b = from(p in Post)

      assert "true" ===
               Repo
               |> Testing.assert_sql(query_a, query_b)
               |> Macro.to_string()
    end
  end

  describe "refute_sql/2" do
    test "refute_sql/3 expands to inequality comparison of SQL strings" do
      quoted =
        quote do
          EctoShorts.Testing.refute_sql(
            Repo,
            from(p in Post),
            from(c in Comment)
          )
        end

      expanded = Macro.expand_once(quoted, __ENV__)

      expected_ast =
        quote do
          refute Ecto.Adapters.SQL.to_sql(:all, Repo, from(p in Post)) ===
                   Ecto.Adapters.SQL.to_sql(:all, Repo, from(c in Comment))
        end

      assert Macro.to_string(expanded) === Macro.to_string(expected_ast)
    end

    test "returns false when queries produce different SQL" do
      query_a = from(p in Post)
      query_b = from(c in Comment)

      assert "false" ===
               Repo
               |> Testing.refute_sql(query_a, query_b)
               |> Macro.to_string()
    end
  end

  describe "assert_query/2" do
    test "assert_query/2 expands to equality of pretty-printed query inspection" do
      quoted =
        quote do
          EctoShorts.Testing.assert_query(
            from(p in Post),
            from(p in Post)
          )
        end

      expanded = Macro.expand_once(quoted, __ENV__)

      expected_ast =
        quote do
          assert inspect(from(p in Post), pretty: true) ===
                   inspect(from(p in Post), pretty: true)
        end

      assert Macro.to_string(expanded) === Macro.to_string(expected_ast)
    end

    test "returns true when queries are structurally identical" do
      query_a = from(p in Post)
      query_b = from(p in Post)

      assert "true" ===
               query_a
               |> Testing.assert_query(query_b)
               |> Macro.to_string()
    end
  end

  describe "refute_query/2" do
    test "refute_query/2 expands to inequality of pretty-printed query inspection" do
      quoted =
        quote do
          EctoShorts.Testing.refute_query(
            from(p in Post),
            from(c in Comment)
          )
        end

      expanded = Macro.expand_once(quoted, __ENV__)

      expected_ast =
        quote do
          refute inspect(from(p in Post), pretty: true) ===
                   inspect(from(c in Comment), pretty: true)
        end

      assert Macro.to_string(expanded) === Macro.to_string(expected_ast)
    end

    test "returns false when queries are structurally different" do
      query_a = from(p in Post)
      query_b = from(c in Comment)

      assert "false" ===
               query_a
               |> Testing.refute_query(query_b)
               |> Macro.to_string()
    end
  end
end
