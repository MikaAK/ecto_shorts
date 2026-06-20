defmodule EctoShorts.CommonFilters.UpdateTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing
  @moduletag adapter: :postgres
  @moduletag feature: :update

  alias EctoShorts.CommonFilters
  alias EctoShorts.Schema.Post

  import Ecto.Query


  describe "update nil" do
    test "keeps the query unchanged when update value is nil" do
      expected = from(p in Post)

      actual = CommonFilters.convert_params_to_filter(Post, %{update: nil}, [])

      assert_query(expected, actual)
    end
  end

  describe "subquery shapes" do
    test "wraps the filtered query in a subquery when given a map filter" do
      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{subquery: %{limit: 5}},
          []
        )

      assert %Ecto.SubQuery{} = actual
    end

    test "logs warning and returns query unchanged when subquery value is not a map or keyword list" do
      import ExUnit.CaptureLog

      log =
        capture_log(fn ->
          actual =
            CommonFilters.convert_params_to_filter(
              Post,
              %{subquery: :invalid},
              []
            )

          assert %Ecto.Query{} = actual
          refute is_nil(actual)
        end)

      assert log =~ "Expected :subquery value"
    end
  end

  describe "update shapes" do
    test "matches Ecto.Query for a named binding update payload" do
      source =
        from(p in Post,
          join: u in assoc(p, :author),
          as: :author
        )

      updates = [set: [title: dynamic([author: u], u.first_name)]]
      expected = update(source, [author: u], ^updates)

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{
            as: %{
              author: %{
                update: [set: [title: dynamic([author: u], u.first_name)]]
              }
            }
          },
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for a positional binding update payload" do
      source =
        from(p in Post,
          join: u in assoc(p, :author)
        )

      updates = [set: [title: dynamic([_, u], u.first_name)]]
      expected = update(source, [_, u], ^updates)

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{
            at: %{
              2 => %{
                update: [set: [title: dynamic([_, u], u.first_name)]]
              }
            }
          },
          []
        )

      assert_query(expected, actual)
    end

    test "casts string values in update payloads" do
      updates = [set: [views: 10], inc: [views: 1]]
      expected = update(Post, [], ^updates)

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{update: [set: [views: "10"], inc: [views: "1"]]},
          []
        )

      assert_query(expected, actual)
    end

    # Covers update.ex line 21: the `else` branch of the keyword?/term check, where
    # `term` is neither a keyword list nor a map, so it is passed as-is to update_expr.
    test "passes a non-keyword non-map term through unchanged" do
      assert_raise ArgumentError, fn ->
        CommonFilters.convert_params_to_filter(Post, %{update: :not_a_keyword_list}, [])
      end
    end

    # Covers update.ex lines 11-13: the map-to-list conversion branch, which
    # converts a plain map update term into a keyword list before building the query.
    test "matches Ecto.Query for a root binding update with a map term" do
      updates = [set: [views: 1]]
      expected = update(Post, [], ^updates)

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{update: %{set: [views: 1]}},
          []
        )

      assert_query(expected, actual)
    end
  end

  # ---- merged from update (schemaless) ----
  describe "update shapes (schemaless)" do
    @describetag feature: :update
    @describetag schema_mode: :schemaless
    test "matches Ecto.Query for a root update set payload" do
      updates = [set: [title: "After"]]
      expected = update("posts", [], ^updates)

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{update: [set: [title: "After"]]},
          []
        )

      assert_query(expected, actual)
    end
  end
end
