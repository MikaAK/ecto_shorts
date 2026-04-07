defmodule EctoShorts.CommonFilters.UpdateTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing

  alias EctoShorts.CommonFilters
  alias EctoShorts.Schema.Post

  import Ecto.Query

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
    test "matches Ecto.Query for a root update set payload" do
      updates = [set: [title: "After"]]
      expected = update(Post, [], ^updates)

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{update: [set: [title: "After"]]},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for a root update inc payload" do
      updates = [inc: [views: 1]]
      expected = update(Post, [], ^updates)

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{update: [inc: [views: 1]]},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for a root combined update payload" do
      updates = [set: [title: "After"], inc: [views: 1]]
      expected = update(Post, [], ^updates)

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{update: [set: [title: "After"], inc: [views: 1]]},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for a root update map payload" do
      updates = [set: [title: "After"]]
      expected = update(Post, [], ^updates)

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{update: %{set: %{title: "After"}}},
          []
        )

      assert_query(expected, actual)
    end

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
  end
end
