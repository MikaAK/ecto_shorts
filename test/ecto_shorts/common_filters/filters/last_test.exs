defmodule EctoShorts.CommonFilters.LastTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing
  @moduletag adapter: :postgres
  @moduletag feature: :last

  alias EctoShorts.CommonFilters
  alias EctoShorts.Schema.Post

  import Ecto.Query


  import ExUnit.CaptureLog

  describe "last shapes" do
    test "returns query unchanged when last is a non-keyword list" do
      expected = from(p in Post)

      log =
        capture_log(fn ->
          actual =
            CommonFilters.convert_params_to_filter(
              Post,
              %{last: [:not_a_keyword_list]},
              []
            )

          assert_query(expected, actual)
        end)

      assert log =~ "Expected :last value"
    end

    test "matches Ecto.Query for a root integer last payload" do
      expected =
        Post
        |> exclude(:order_by)
        |> order_by([], desc: :id)
        |> limit(^2)
        |> subquery()
        |> order_by([], asc: :id)

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{last: 2},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for a root keyword last payload" do
      expected =
        Post
        |> exclude(:order_by)
        |> order_by([], desc: :title)
        |> limit(^2)
        |> subquery()
        |> order_by([], asc: :title)

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{last: [title: 2]},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for an explicit id last payload" do
      expected =
        Post
        |> exclude(:order_by)
        |> order_by([], desc: :id)
        |> limit(^2)
        |> subquery()
        |> order_by([], asc: :id)

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{last: %{id: 2}},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for an explicit title last payload" do
      expected =
        Post
        |> exclude(:order_by)
        |> order_by([], desc: :title)
        |> limit(^2)
        |> subquery()
        |> order_by([], asc: :title)

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{last: %{title: 2}},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for terminal last wrapping after local filters" do
      expected =
        Post
        |> where([p], p.published == ^true)
        |> exclude(:order_by)
        |> order_by([], desc: :id)
        |> limit(^2)
        |> subquery()
        |> order_by([], asc: :id)

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          [last: 2, published: true],
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query when last replaces a previous order_by" do
      expected =
        Post
        |> order_by([], desc: :title)
        |> exclude(:order_by)
        |> order_by([], desc: :id)
        |> limit(^2)
        |> subquery()
        |> order_by([], asc: :id)

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          [last: 2, order_by: :title],
          []
        )

      assert_query(expected, actual)
    end

    test "casts a string integer last payload" do
      expected =
        Post
        |> exclude(:order_by)
        |> order_by([], desc: :id)
        |> limit(^2)
        |> subquery()
        |> order_by([], asc: :id)

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{last: "2"},
          []
        )

      assert_query(expected, actual)
    end
  end

  # ---- merged from last (schemaless) ----
  describe "last shapes (schemaless)" do
    @describetag feature: :last
    @describetag schema_mode: :schemaless
    test "matches Ecto.Query for a root integer last payload" do
      expected =
        "posts"
        |> exclude(:order_by)
        |> order_by([], desc: :id)
        |> limit(^2)
        |> subquery()
        |> order_by([], asc: :id)

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{last: 2},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for terminal last wrapping after local filters" do
      expected =
        "posts"
        |> where([p], p.published == ^true)
        |> exclude(:order_by)
        |> order_by([], desc: :id)
        |> limit(^2)
        |> subquery()
        |> order_by([], asc: :id)

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          [last: 2, published: true],
          []
        )

      assert_query(expected, actual)
    end
  end
end
