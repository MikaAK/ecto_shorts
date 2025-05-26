defmodule EctoShorts.DynamicExpressions.PostgresTest do
  use ExUnit.Case, async: true
  doctest EctoShorts.DynamicExpressions.Postgres

  alias EctoShorts.DynamicExpressions.Postgres
  alias EctoShorts.Schemas.Post

  import Ecto.Query, only: [dynamic: 2]
  import EctoShorts.Testing, only: [assert_dynamic: 2]

  setup do
    %{base: dynamic([q], q.description == "example")}
  end

  describe "create_dynamic/6 basic condition combination" do
    test "adds a condition with :and and :or", %{base: dyn} do
      assert_dynamic dynamic([q], q.description == "example" and q.id == ^1),
                     Postgres.build_dynamic(dyn, nil, :and, Post, :id, 1)

      assert_dynamic dynamic([q], q.description == "example" or q.id == ^1),
                     Postgres.build_dynamic(dyn, nil, :or, Post, :id, 1)
    end
  end

  describe "create_dynamic/6 with operator :==" do
    test "with scalar", %{base: dyn} do
      assert_dynamic dynamic([q], q.description == "example" and q.id == ^1),
                     Postgres.build_dynamic(dyn, nil, :and, Post, :id, {:==, 1})

      assert_dynamic dynamic([q], q.description == "example" or q.id == ^1),
                     Postgres.build_dynamic(dyn, nil, :or, Post, :id, {:==, 1})
    end

    test "with list", %{base: dyn} do
      assert_dynamic dynamic([q], q.description == "example" and q.id in ^[1, 2, 3]),
                     Postgres.build_dynamic(dyn, nil, :and, Post, :id, {:==, [1, 2, 3]})

      assert_dynamic dynamic([q], q.description == "example" or q.id in ^[1, 2, 3]),
                     Postgres.build_dynamic(dyn, nil, :or, Post, :id, {:==, [1, 2, 3]})
    end

    test "with fragment(:lower) and fragment(:upper)", %{base: dyn} do
      assert_dynamic dynamic(
                       [q],
                       q.description == "example" and fragment("LOWER(?)", q.id) == ^"example"
                     ),
                     Postgres.build_dynamic(
                       dyn,
                       nil,
                       :and,
                       Post,
                       :id,
                       {:==, {:lower, "example"}}
                     )

      assert_dynamic dynamic(
                       [q],
                       q.description == "example" or fragment("LOWER(?)", q.id) == ^"example"
                     ),
                     Postgres.build_dynamic(dyn, nil, :or, Post, :id, {:==, {:lower, "example"}})

      assert_dynamic dynamic(
                       [q],
                       q.description == "example" and fragment("UPPER(?)", q.id) == ^"example"
                     ),
                     Postgres.build_dynamic(
                       dyn,
                       nil,
                       :and,
                       Post,
                       :id,
                       {:==, {:upper, "example"}}
                     )

      assert_dynamic dynamic(
                       [q],
                       q.description == "example" or fragment("UPPER(?)", q.id) == ^"example"
                     ),
                     Postgres.build_dynamic(dyn, nil, :or, Post, :id, {:==, {:upper, "example"}})
    end
  end

  describe "create_dynamic/6 with operator :!=" do
    test "with scalar", %{base: dyn} do
      assert_dynamic dynamic([q], q.description == "example" and q.id != ^1),
                     Postgres.build_dynamic(dyn, nil, :and, Post, :id, {:!=, 1})

      assert_dynamic dynamic([q], q.description == "example" or q.id != ^1),
                     Postgres.build_dynamic(dyn, nil, :or, Post, :id, {:!=, 1})
    end

    test "with list", %{base: dyn} do
      assert_dynamic dynamic([q], q.description == "example" and q.id not in ^[1, 2, 3]),
                     Postgres.build_dynamic(dyn, nil, :and, Post, :id, {:!=, [1, 2, 3]})

      assert_dynamic dynamic([q], q.description == "example" or q.id not in ^[1, 2, 3]),
                     Postgres.build_dynamic(dyn, nil, :or, Post, :id, {:!=, [1, 2, 3]})
    end
  end

  describe "create_dynamic/6 with operator :>" do
    test "with scalar", %{base: dyn} do
      assert_dynamic dynamic([q], q.description == "example" and q.id > ^1),
                     Postgres.build_dynamic(dyn, nil, :and, Post, :id, {:>, 1})

      assert_dynamic dynamic([q], q.description == "example" or q.id > ^1),
                     Postgres.build_dynamic(dyn, nil, :or, Post, :id, {:>, 1})
    end
  end

  describe "create_dynamic/6 with operator :<" do
    test "with scalar", %{base: dyn} do
      assert_dynamic dynamic([q], q.description == "example" and q.id < ^1),
                     Postgres.build_dynamic(dyn, nil, :and, Post, :id, {:<, 1})

      assert_dynamic dynamic([q], q.description == "example" or q.id < ^1),
                     Postgres.build_dynamic(dyn, nil, :or, Post, :id, {:<, 1})
    end
  end

  describe "create_dynamic/6 with operator :>=" do
    test "with scalar", %{base: dyn} do
      assert_dynamic dynamic([q], q.description == "example" and q.id >= ^1),
                     Postgres.build_dynamic(dyn, nil, :and, Post, :id, {:>=, 1})

      assert_dynamic dynamic([q], q.description == "example" or q.id >= ^1),
                     Postgres.build_dynamic(dyn, nil, :or, Post, :id, {:>=, 1})
    end
  end

  describe "create_dynamic/6 with operator :<=" do
    test "with scalar", %{base: dyn} do
      assert_dynamic dynamic([q], q.description == "example" and q.id <= ^1),
                     Postgres.build_dynamic(dyn, nil, :and, Post, :id, {:<=, 1})

      assert_dynamic dynamic([q], q.description == "example" or q.id <= ^1),
                     Postgres.build_dynamic(dyn, nil, :or, Post, :id, {:<=, 1})
    end
  end

  describe "create_dynamic/6 with operator :ilike" do
    test "with scalar", %{base: dyn} do
      assert_dynamic dynamic([q], q.description == "example" and ilike(q.title, ^"%example%")),
                     Postgres.build_dynamic(dyn, nil, :and, Post, :title, {:ilike, "example"})

      assert_dynamic dynamic([q], q.description == "example" or ilike(q.title, ^"%example%")),
                     Postgres.build_dynamic(dyn, nil, :or, Post, :title, {:ilike, "example"})
    end
  end

  describe "create_dynamic/6 with operator :like" do
    test "with scalar", %{base: dyn} do
      assert_dynamic dynamic([q], q.description == "example" and like(q.title, ^"%example%")),
                     Postgres.build_dynamic(dyn, nil, :and, Post, :title, {:like, "example"})

      assert_dynamic dynamic([q], q.description == "example" or like(q.title, ^"%example%")),
                     Postgres.build_dynamic(dyn, nil, :or, Post, :title, {:like, "example"})
    end
  end

  describe "create_dynamic/6 with operator :=~ (regex match)" do
    test "with scalar", %{base: dyn} do
      assert_dynamic dynamic(
                       [q],
                       q.description == "example" and fragment("? ~* ?", q.title, ^"example")
                     ),
                     Postgres.build_dynamic(dyn, nil, :and, Post, :title, {:=~, "example"})

      assert_dynamic dynamic(
                       [q],
                       q.description == "example" or fragment("? ~* ?", q.title, ^"example")
                     ),
                     Postgres.build_dynamic(dyn, nil, :or, Post, :title, {:=~, "example"})
    end
  end
end
