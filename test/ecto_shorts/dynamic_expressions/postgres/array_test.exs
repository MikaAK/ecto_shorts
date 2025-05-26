defmodule EctoShorts.DynamicExpressions.Postgres.ArrayTest do
  use ExUnit.Case, async: true
  doctest EctoShorts.DynamicExpressions.Postgres.Array

  alias EctoShorts.DynamicExpressions.Postgres.Array

  import Ecto.Query, only: [dynamic: 2]
  import EctoShorts.Testing, only: [assert_dynamic: 2]

  describe "create_dynamic/4 with operator :==" do
    test "with scalar left side" do
      assert_dynamic dynamic([d], ^1 in d.tags),
                     Array.build_dynamic(nil, 1, :==, :tags)
    end

    test "with array on right side" do
      assert_dynamic dynamic([d], d.tags == ^["example"]),
                     Array.build_dynamic(nil, :tags, :==, ["example"])
    end

    test "with nil comparison" do
      assert_dynamic dynamic([d], is_nil(d.tags)),
                     Array.build_dynamic(nil, :tags, :==, nil)
    end

    test "with upper fragment" do
      assert_dynamic dynamic(
                       [d],
                       fragment(
                         "EXISTS (SELECT 1 FROM unnest(?) AS value WHERE UPPER(value) = UPPER(?))",
                         d.tags,
                         ^"example"
                       )
                     ),
                     Array.build_dynamic(nil, :tags, :==, {:upper, "example"})
    end
  end

  describe "create_dynamic/4 with operator :!=" do
    test "with scalar left side" do
      assert_dynamic dynamic([d], ^1 not in d.tags),
                     Array.build_dynamic(nil, 1, :!=, :tags)
    end

    test "with array on right side" do
      assert_dynamic dynamic([d], d.tags != ^["example"]),
                     Array.build_dynamic(nil, :tags, :!=, ["example"])
    end

    test "with nil comparison" do
      assert_dynamic dynamic([d], not is_nil(d.tags)),
                     Array.build_dynamic(nil, :tags, :!=, nil)
    end

    test "with upper fragment" do
      assert_dynamic dynamic(
                       [d],
                       fragment(
                         "EXISTS (SELECT 1 FROM unnest(?) AS value WHERE UPPER(value) != UPPER(?))",
                         d.tags,
                         ^"example"
                       )
                     ),
                     Array.build_dynamic(nil, :tags, :!=, {:upper, "example"})
    end
  end

  describe "create_dynamic/4 with operator :>" do
    test "field on left" do
      assert_dynamic dynamic([d], d.tags > ^["example"]),
                     Array.build_dynamic(nil, :tags, :>, ["example"])
    end

    test "value on left with ANY(fragment)" do
      assert_dynamic dynamic([d], fragment("? > ANY(?)", ^["example"], d.tags)),
                     Array.build_dynamic(nil, ["example"], :>, :tags)
    end
  end

  describe "create_dynamic/4 with operator :<" do
    test "field on left" do
      assert_dynamic dynamic([d], d.tags < ^["example"]),
                     Array.build_dynamic(nil, :tags, :<, ["example"])
    end

    test "value on left with ANY(fragment)" do
      assert_dynamic dynamic([d], fragment("? < ANY(?)", ^["example"], d.tags)),
                     Array.build_dynamic(nil, ["example"], :<, :tags)
    end
  end

  describe "create_dynamic/4 with operator :>=" do
    test "field on left" do
      assert_dynamic dynamic([d], d.tags >= ^["example"]),
                     Array.build_dynamic(nil, :tags, :>=, ["example"])
    end

    test "value on left with ANY(fragment)" do
      assert_dynamic dynamic([d], fragment("? >= ANY(?)", ^["example"], d.tags)),
                     Array.build_dynamic(nil, ["example"], :>=, :tags)
    end
  end

  describe "create_dynamic/4 with operator :<=" do
    test "field on left" do
      assert_dynamic dynamic([d], d.tags <= ^["example"]),
                     Array.build_dynamic(nil, :tags, :<=, ["example"])
    end

    test "value on left with ANY(fragment)" do
      assert_dynamic dynamic([d], fragment("? <= ANY(?)", ^["example"], d.tags)),
                     Array.build_dynamic(nil, ["example"], :<=, :tags)
    end
  end

  describe "create_dynamic/4 with operator :ilike" do
    test "with ILIKE ANY fragment" do
      assert_dynamic dynamic([d], fragment("? ILIKE ANY(?)", ^"%example%", d.tags)),
                     Array.build_dynamic(nil, "example", :ilike, :tags)
    end
  end

  describe "create_dynamic/4 with operator :like" do
    test "with LIKE ANY fragment" do
      assert_dynamic dynamic([d], fragment("? LIKE ANY(?)", ^"%example%", d.tags)),
                     Array.build_dynamic(nil, "example", :like, :tags)
    end
  end

  describe "create_dynamic/4 with operator :=~ (regex match)" do
    test "with ~* ANY fragment" do
      assert_dynamic dynamic([d], fragment("? ~* ANY(?)", ^"example", d.tags)),
                     Array.build_dynamic(nil, "example", :=~, :tags)
    end
  end
end
