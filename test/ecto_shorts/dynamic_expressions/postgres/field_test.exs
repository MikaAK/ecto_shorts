defmodule EctoShorts.DynamicExpressions.Postgres.FieldTest do
  use ExUnit.Case, async: true
  doctest EctoShorts.DynamicExpressions.Postgres.Field

  alias EctoShorts.DynamicExpressions.Postgres.Field

  import Ecto.Query, only: [dynamic: 2]
  import EctoShorts.Testing, only: [assert_dynamic: 2]

  describe "create_dynamic/4 with operator :==" do
    test "with nil" do
      assert_dynamic dynamic([q], is_nil(q.id)),
                     Field.build_dynamic(nil, :id, :==, nil)
    end

    test "with scalar" do
      assert_dynamic dynamic([q], q.id == ^1),
                     Field.build_dynamic(nil, :id, :==, 1)
    end

    test "with list" do
      assert_dynamic dynamic([q], q.id in ^[1, 2, 3]),
                     Field.build_dynamic(nil, :id, :==, [1, 2, 3])
    end

    test "with LOWER/UPPER fragments" do
      assert_dynamic dynamic([q], fragment("LOWER(?)", q.title) == ^"example"),
                     Field.build_dynamic(nil, :title, :==, {:lower, "example"})

      assert_dynamic dynamic([q], fragment("UPPER(?)", q.title) == ^"example"),
                     Field.build_dynamic(nil, :title, :==, {:upper, "example"})
    end
  end

  describe "create_dynamic/4 with operator :!=" do
    test "with nil" do
      assert_dynamic dynamic([q], not is_nil(q.id)),
                     Field.build_dynamic(nil, :id, :!=, nil)
    end

    test "with scalar" do
      assert_dynamic dynamic([q], q.id != ^1),
                     Field.build_dynamic(nil, :id, :!=, 1)
    end

    test "with list" do
      assert_dynamic dynamic([q], q.id not in ^[1, 2, 3]),
                     Field.build_dynamic(nil, :id, :!=, [1, 2, 3])
    end

    test "with LOWER/UPPER fragments" do
      assert_dynamic dynamic([q], fragment("LOWER(?)", q.title) != ^"example"),
                     Field.build_dynamic(nil, :title, :!=, {:lower, "example"})

      assert_dynamic dynamic([q], fragment("UPPER(?)", q.title) != ^"example"),
                     Field.build_dynamic(nil, :title, :!=, {:upper, "example"})
    end
  end

  describe "create_dynamic/4 with operator :>" do
    test "with scalar" do
      assert_dynamic dynamic([q], q.id > ^1),
                     Field.build_dynamic(nil, :id, :>, 1)
    end
  end

  describe "create_dynamic/4 with operator :<" do
    test "with scalar" do
      assert_dynamic dynamic([q], q.id < ^1),
                     Field.build_dynamic(nil, :id, :<, 1)
    end
  end

  describe "create_dynamic/4 with operator :>=" do
    test "with scalar" do
      assert_dynamic dynamic([q], q.id >= ^1),
                     Field.build_dynamic(nil, :id, :>=, 1)
    end
  end

  describe "create_dynamic/4 with operator :<=" do
    test "with scalar" do
      assert_dynamic dynamic([q], q.id <= ^1),
                     Field.build_dynamic(nil, :id, :<=, 1)
    end
  end

  describe "create_dynamic/4 with operator :ilike" do
    test "with scalar" do
      assert_dynamic dynamic([q], ilike(q.title, ^"%example%")),
                     Field.build_dynamic(nil, :title, :ilike, "example")
    end
  end

  describe "create_dynamic/4 with operator :like" do
    test "with scalar" do
      assert_dynamic dynamic([q], like(q.title, ^"%example%")),
                     Field.build_dynamic(nil, :title, :like, "example")
    end
  end

  describe "create_dynamic/4 with operator :=~ (regex match)" do
    test "with scalar" do
      assert_dynamic dynamic([q], fragment("? ~* ?", q.title, ^"example")),
                     Field.build_dynamic(nil, :title, :=~, "example")
    end
  end
end
