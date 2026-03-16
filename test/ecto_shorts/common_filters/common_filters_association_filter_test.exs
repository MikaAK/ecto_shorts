defmodule EctoShorts.CommonFilters.AssociationFilterTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing

  alias EctoShorts.CommonFilters
  alias EctoShorts.Schema.Post

  import Ecto.Query
  import ExUnit.CaptureLog

  describe "convert_params_to_filter/3 association filter shorthand" do
    test "routes a map value for a known association key through the association handler" do
      expected =
        from(p in Post,
          join: a in assoc(p, :author),
          as: :author,
          where: a.age == ^25
        )

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{author: %{age: 25}},
          []
        )

      assert_query(expected, actual)
    end

    test "routes a keyword list value for a known association key through the association handler" do
      expected =
        from(p in Post,
          join: a in assoc(p, :author),
          as: :author,
          where: a.age == ^25
        )

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          [author: [age: 25]],
          []
        )

      assert_query(expected, actual)
    end

    test "returns query unchanged and logs a warning when a known association key receives a scalar value" do
      expected = from(p in Post)

      log =
        capture_log(fn ->
          actual =
            CommonFilters.convert_params_to_filter(
              Post,
              %{author: "bad value"},
              []
            )

          assert_query(expected, actual)
        end)

      assert log =~ "Expected association filter value to be a map or keyword list"
    end
  end
end
