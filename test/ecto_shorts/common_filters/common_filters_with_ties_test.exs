defmodule EctoShorts.CommonFilters.WithTiesTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing

  alias EctoShorts.CommonFilters
  alias EctoShorts.Schema.Post

  import Ecto.Query
  import ExUnit.CaptureLog

  describe "convert_params_to_filter/3 with_ties shapes" do
    test "matches Ecto.Query for root with_ties true with existing limit and order_by" do
      expected =
        Post
        |> order_by([], desc: :inserted_at)
        |> limit(^1)
        |> with_ties(true)

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          [order_by: [desc: :inserted_at], limit: 1, with_ties: true],
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for root with_ties false with existing limit and order_by" do
      expected =
        Post
        |> order_by([], desc: :inserted_at)
        |> limit(^1)
        |> with_ties(false)

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          [order_by: [desc: :inserted_at], limit: 1, with_ties: false],
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query when with_ties true adds the default limit" do
      expected =
        Post
        |> order_by([], desc: :inserted_at)
        |> limit(^1000)
        |> with_ties(true)

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          [order_by: [desc: :inserted_at], with_ties: true],
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query when with_ties true adds default primary key ordering" do
      expected =
        Post
        |> limit(^1000)
        |> order_by([], asc: :id)
        |> with_ties(true)

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{with_ties: true},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for a keyword limit payload" do
      expected =
        Post
        |> limit(^10)
        |> order_by([], asc: :id)
        |> with_ties(true)

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{with_ties: [limit: 10]},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for a map limit payload" do
      expected =
        Post
        |> limit(^10)
        |> order_by([], asc: :id)
        |> with_ties(true)

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{with_ties: %{limit: 10}},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for named binding with_ties true" do
      source =
        from(p in Post,
          as: :post,
          order_by: [desc: p.inserted_at],
          limit: 1
        )

      expected = with_ties(source, [post: p], true)

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{
            as: %{
              post: %{
                with_ties: true
              }
            }
          },
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for positional binding with_ties true" do
      source =
        from(p in Post,
          join: a in assoc(p, :author),
          order_by: [desc: p.inserted_at],
          limit: 1
        )

      expected = with_ties(source, [p, a], true)

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{
            at: %{
              2 => %{
                with_ties: true
              }
            }
          },
          []
        )

      assert_query(expected, actual)
    end

    test "keeps the query unchanged when with_ties payload is invalid" do
      expected = from(p in Post)

      log =
        capture_log(fn ->
          actual =
            CommonFilters.convert_params_to_filter(
              Post,
              %{with_ties: "invalid"},
              []
            )

          assert_query(expected, actual)
        end)

      assert log =~ "Expected :with_ties value to be a boolean or keyword/map payload"
    end

    test "keeps the query unchanged when with_ties limit is invalid" do
      expected = from(p in Post)

      log =
        capture_log(fn ->
          actual =
            CommonFilters.convert_params_to_filter(
              Post,
              %{with_ties: %{limit: "ten"}},
              []
            )

          assert_query(expected, actual)
        end)

      assert log =~ "Expected :with_ties :limit to be an integer or nil"
    end

    test "keeps the query unchanged when with_ties payload has unsupported keys" do
      expected = from(p in Post)

      log =
        capture_log(fn ->
          actual =
            CommonFilters.convert_params_to_filter(
              Post,
              %{with_ties: %{foo: :bar}},
              []
            )

          assert_query(expected, actual)
        end)

      assert log =~ "Expected :with_ties params to only include :limit"
    end
  end
end
