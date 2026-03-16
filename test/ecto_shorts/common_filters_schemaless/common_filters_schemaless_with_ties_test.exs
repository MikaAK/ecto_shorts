defmodule EctoShorts.CommonFilters.SchemalessWithTiesTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing

  alias EctoShorts.CommonFilters

  import Ecto.Query
  import ExUnit.CaptureLog

  describe "convert_params_to_filter/3 with_ties shapes (schemaless)" do
    test "matches Ecto.Query for root with_ties true with existing limit and order_by" do
      expected =
        "posts"
        |> order_by([], desc: :inserted_at)
        |> limit(^1)
        |> with_ties(true)

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          [order_by: [desc: :inserted_at], limit: 1, with_ties: true],
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for root with_ties false with existing limit and order_by" do
      expected =
        "posts"
        |> order_by([], desc: :inserted_at)
        |> limit(^1)
        |> with_ties(false)

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          [order_by: [desc: :inserted_at], limit: 1, with_ties: false],
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query when with_ties true adds the default limit" do
      expected =
        "posts"
        |> order_by([], desc: :inserted_at)
        |> limit(^1000)
        |> with_ties(true)

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          [order_by: [desc: :inserted_at], with_ties: true],
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for a keyword limit payload" do
      expected =
        "posts"
        |> limit(^10)
        |> order_by([], asc: :id)
        |> with_ties(true)

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{with_ties: [limit: 10]},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for a map limit payload" do
      expected =
        "posts"
        |> limit(^10)
        |> order_by([], asc: :id)
        |> with_ties(true)

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{with_ties: %{limit: 10}},
          []
        )

      assert_query(expected, actual)
    end

    test "keeps the query unchanged when with_ties payload is invalid" do
      expected = from(p in "posts")

      log =
        capture_log(fn ->
          actual =
            CommonFilters.convert_params_to_filter(
              "posts",
              %{with_ties: "invalid"},
              []
            )

          assert_query(expected, actual)
        end)

      assert log =~ "Expected :with_ties value to be a boolean or keyword/map payload"
    end
  end
end
