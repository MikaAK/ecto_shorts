defmodule EctoShorts.CommonFilters.SchemalessDatetimeWrappersTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing

  alias EctoShorts.CommonFilters

  import Ecto.Query

  describe "datetime wrappers (schemaless)" do
    test "matches records using datetime_add before comparison" do
      expected =
        from(p in "posts", where: p.inserted_at >= datetime_add(p.inserted_at, ^1, "day"))

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{
            inserted_at: %{
              >=: %{datetime: %{add: %{field: :inserted_at, count: 1, interval: "day"}}}
            }
          },
          []
        )

      assert_query(expected, actual)
    end

    test "matches records using ago before comparison" do
      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{inserted_at: %{>: %{datetime: %{ago: %{count: 1, interval: "day"}}}}},
          []
        )

      expected = from(p in "posts", where: p.inserted_at > ago(^1, "day"))

      assert [%{expr: {:>, _, [_, _]}}] = actual.wheres
      assert [%{expr: {:>, _, [_, _]}}] = expected.wheres
    end

    test "matches records using from_now before comparison" do
      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{inserted_at: %{>: %{datetime: %{from_now: %{count: 1, interval: "day"}}}}},
          []
        )

      expected = from(p in "posts", where: p.inserted_at > from_now(^1, "day"))

      assert [%{expr: {:>, _, [_, _]}}] = actual.wheres
      assert [%{expr: {:>, _, [_, _]}}] = expected.wheres
    end

    test "excludes records using negated datetime_add comparison" do
      expected =
        from(p in "posts", where: not (p.inserted_at >= datetime_add(p.inserted_at, ^1, "day")))

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{
            inserted_at: %{
              not: %{>=: %{datetime: %{add: %{field: :inserted_at, count: 1, interval: "day"}}}}
            }
          },
          []
        )

      assert_query(expected, actual)
    end
  end
end
