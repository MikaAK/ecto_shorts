defmodule EctoShorts.CommonFilters.Schemaless.WithCteTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing
  @moduletag adapter: :postgres
  @moduletag schema_mode: :schemaless
  @moduletag feature: :with_cte

  alias EctoShorts.CommonFilters

  import Ecto.Query
  import ExUnit.CaptureLog

  describe "with_cte shapes (schemaless)" do
    test "matches Ecto.Query for with_cte with filter params using the default source" do
      cte_query = from(p in "posts", where: p.published == ^true)
      expected = with_cte("posts", "published_posts", as: ^cte_query)

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{with_cte: [published_posts: [as: [published: true]]]},
          []
        )

      assert_query(expected, actual)
    end

    test "keeps the query unchanged when with_cte params are invalid" do
      expected = from(p in "posts")

      log =
        capture_log(fn ->
          actual =
            CommonFilters.convert_params_to_filter(
              "posts",
              %{with_cte: "invalid"},
              []
            )

          assert_query(expected, actual)
        end)

      assert log =~ "Expected :with_cte params to be a map or keyword list"
    end
  end
end
