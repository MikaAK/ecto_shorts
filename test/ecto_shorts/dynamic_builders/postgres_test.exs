defmodule EctoShorts.DynamicBuilders.PostgresTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing

  alias EctoShorts.DynamicBuilders.Postgres
  alias EctoShorts.Schema.EnumSchema

  import Ecto.Query

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
  end
end
