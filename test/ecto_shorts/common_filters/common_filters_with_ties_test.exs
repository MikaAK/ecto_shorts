defmodule EctoShorts.CommonFilters.WithTiesTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing

  alias EctoShorts.CommonFilters
  alias EctoShorts.Schema.Post

  import Ecto.Query
  import ExUnit.CaptureLog

  describe "with_ties shapes" do
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

    test "casts string payloads for with_ties and its limit" do
      expected =
        Post
        |> limit(^10)
        |> order_by([], asc: :id)
        |> with_ties(true)

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{with_ties: %{limit: "10"}},
          []
        )

      assert_query(expected, actual)

      expected_true =
        Post
        |> limit(^1000)
        |> order_by([], asc: :id)
        |> with_ties(true)

      actual_true =
        CommonFilters.convert_params_to_filter(
          Post,
          %{with_ties: "true"},
          []
        )

      assert_query(expected_true, actual_true)
    end
  end

  # Covers apply_limit_param/5 nil branch (line 66 in with_ties.ex):
  # when params map has no :limit key, apply_limit_param is called with nil,
  # which applies the default limit and with_ties true.
  describe "with_ties with no :limit in params" do
    test "uses default limit when :limit key is absent from params map" do
      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{with_ties: %{}},
          []
        )

      assert %Ecto.Query{} = actual
    end
  end
end
