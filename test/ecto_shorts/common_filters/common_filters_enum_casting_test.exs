defmodule EctoShorts.CommonFilters.EnumCastingTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing

  alias EctoShorts.CommonFilters
  alias EctoShorts.Schema.EnumSchema

  import Ecto.Query

  describe "convert_params_to_filter/3 Ecto.Enum casting" do
    test "casts a bare Ecto.Enum atom to its integer mapping" do
      expected = from(e in EnumSchema, where: e.status == ^1)
      actual = CommonFilters.convert_params_to_filter(EnumSchema, %{status: :published}, [])

      assert_sql(expected, actual)
    end

    test "casts an operator-wrapped Ecto.Enum atom" do
      expected = from(e in EnumSchema, where: e.status != ^2)
      actual = CommonFilters.convert_params_to_filter(EnumSchema, %{status: %{!=: :archived}}, [])

      assert_sql(expected, actual)
    end

    test "casts a list of Ecto.Enum atoms for membership" do
      expected = from(e in EnumSchema, where: e.status in ^[1, 2])
      actual = CommonFilters.convert_params_to_filter(EnumSchema, %{status: [:published, :archived]}, [])

      assert_sql(expected, actual)
    end

    test "passes through non-enum values unchanged" do
      expected = from(e in EnumSchema, where: e.views == ^42)
      actual = CommonFilters.convert_params_to_filter(EnumSchema, %{views: 42}, [])

      assert_sql(expected, actual)
    end

    test "passes through nil without casting" do
      expected = from(e in EnumSchema, where: is_nil(e.status))
      actual = CommonFilters.convert_params_to_filter(EnumSchema, %{status: nil}, [])

      assert_sql(expected, actual)
    end
  end
end
