defmodule EctoShorts.DynamicBuilders.PostgresTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing

  alias EctoShorts.CommonFilters
  alias EctoShorts.DynamicBuilders.Postgres
  alias EctoShorts.Schema.EnumSchema
  alias EctoShorts.Schema.Post

  import Ecto.Query

  describe "build_dynamic/4 quantifier operators" do
    test "builds :all quantifier expression for a single field" do
      actual = Postgres.build_dynamic(Post, {:as, nil}, {:all, [published: true]})

      assert %Ecto.Query.DynamicExpr{} = actual
    end

    test "builds :any quantifier expression for a single field" do
      actual = Postgres.build_dynamic(Post, {:as, nil}, {:any, [published: true]})

      assert %Ecto.Query.DynamicExpr{} = actual
    end

    test "returns nil when quantifier params normalize to empty" do
      result = Postgres.build_dynamic(Post, {:as, nil}, {:any, []})

      assert is_nil(result)
    end
  end

  describe "build_dynamic/4 merge ops (:and/:or entries)" do
    test "builds expression when entry has :or merge op from or-group" do
      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{or: [published: true, views: %{>: 0}]},
          []
        )

      assert %Ecto.Query{} = actual
    end
  end

  describe "build_dynamic/4 Ecto.Enum casting" do
    test "casts a bare Ecto.Enum atom to its integer mapping" do
      expected = dynamic([q], field(q, :status) == ^1)
      actual = Postgres.build_dynamic(EnumSchema, {:as, nil}, {:status, :published})

      assert_dynamic(expected, actual)
    end

    test "casts an operator-wrapped Ecto.Enum atom" do
      expected = dynamic([q], field(q, :status) != ^2)
      actual = Postgres.build_dynamic(EnumSchema, {:as, nil}, {:status, {:!=, :archived}})

      assert_dynamic(expected, actual)
    end

    test "casts a list of Ecto.Enum atoms for membership" do
      expected = dynamic([q], field(q, :status) in ^[1, 2])
      actual = Postgres.build_dynamic(EnumSchema, {:as, nil}, {:status, [:published, :archived]})

      assert_dynamic(expected, actual)
    end

    test "passes through values that do not need casting" do
      expected = dynamic([q], field(q, :views) == ^42)
      actual = Postgres.build_dynamic(EnumSchema, {:as, nil}, {:views, 42})

      assert_dynamic(expected, actual)
    end

    test "passes through nil without casting" do
      expected = dynamic([q], is_nil(field(q, :status)))
      actual = Postgres.build_dynamic(EnumSchema, {:as, nil}, {:status, nil})

      assert_dynamic(expected, actual)
    end

    test "casts a string integer for a scalar field" do
      expected = dynamic([q], field(q, :id) == ^1)
      actual = Postgres.build_dynamic(Post, {:as, nil}, {:id, "1"})

      assert_dynamic(expected, actual)
    end

    test "casts an operator-wrapped string integer" do
      expected = dynamic([q], field(q, :views) > ^10)
      actual = Postgres.build_dynamic(Post, {:as, nil}, {:views, {:>, "10"}})

      assert_dynamic(expected, actual)
    end

    test "casts a list of string integers for membership" do
      expected = dynamic([q], field(q, :id) in ^[1, 2, 3])
      actual = Postgres.build_dynamic(Post, {:as, nil}, {:id, ["1", "2", "3"]})

      assert_dynamic(expected, actual)
    end
  end
end
