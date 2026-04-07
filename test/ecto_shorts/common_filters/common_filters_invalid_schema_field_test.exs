defmodule EctoShorts.CommonFilters.InvalidSchemaFieldTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing

  alias EctoShorts.CommonFilters
  alias EctoShorts.Schema.Post
  alias EctoShorts.Schema.User

  import Ecto.Query
  import ExUnit.CaptureLog

  describe "invalid schema field guards" do
    test "keeps the query unchanged when where targets an invalid field" do
      expected = from(p in Post)

      log =
        capture_log(fn ->
          actual = CommonFilters.convert_params_to_filter(Post, %{does_not_exist: 1}, [])
          assert_query(expected, actual)
        end)

      assert log =~ "Field \"does_not_exist\" does not exist on schema EctoShorts.Schema.Post"
    end

    test "keeps the query unchanged when having targets an invalid field" do
      expected = from(p in Post, group_by: p.id)

      log =
        capture_log(fn ->
          actual =
            CommonFilters.convert_params_to_filter(
              Post,
              %{group_by: :id, having: %{does_not_exist: %{avg: %{>: 1}}}},
              []
            )

          assert_query(expected, actual)
        end)

      assert log =~ "Field \"does_not_exist\" does not exist on schema EctoShorts.Schema.Post"
    end

    test "keeps the query unchanged when join on only contains invalid fields" do
      expected = from(p in Post)

      log =
        capture_log(fn ->
          actual =
            CommonFilters.convert_params_to_filter(
              Post,
              %{join: [schema: [source: User, as: :user, on: %{does_not_exist: 1}]]},
              []
            )

          assert_query(expected, actual)
        end)

      assert log =~ "Field \"does_not_exist\" does not exist on schema EctoShorts.Schema.Post"
    end

    test "keeps the query unchanged when order_by targets an invalid field" do
      expected = from(p in Post)

      log =
        capture_log(fn ->
          actual = CommonFilters.convert_params_to_filter(Post, %{order_by: :does_not_exist}, [])
          assert_query(expected, actual)
        end)

      assert log =~ "Field \"does_not_exist\" does not exist on schema EctoShorts.Schema.Post"
    end

    test "keeps the query unchanged when group_by targets an invalid field" do
      expected = from(p in Post)

      log =
        capture_log(fn ->
          actual = CommonFilters.convert_params_to_filter(Post, %{group_by: :does_not_exist}, [])
          assert_query(expected, actual)
        end)

      assert log =~ "Field \"does_not_exist\" does not exist on schema EctoShorts.Schema.Post"
    end

    test "keeps the query unchanged when distinct targets an invalid field" do
      expected = from(p in Post)

      log =
        capture_log(fn ->
          actual = CommonFilters.convert_params_to_filter(Post, %{distinct: :does_not_exist}, [])
          assert_query(expected, actual)
        end)

      assert log =~ "Field \"does_not_exist\" does not exist on schema EctoShorts.Schema.Post"
    end
  end
end
