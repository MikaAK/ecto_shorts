defmodule EctoShorts.CommonFilters.WithNamedBindingTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing

  alias EctoShorts.CommonFilters
  alias EctoShorts.Schema.Post

  import Ecto.Query
  import ExUnit.CaptureLog

  describe "with_named_binding shapes" do
    test "matches Ecto.Query for the documented with_named_binding workflow" do
      expected =
        from(p in Post,
          join: a in assoc(p, :author),
          as: :author
        )

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{with_named_binding: [author: %{join: [association: [source: :author, as: :author]]}]},
          []
        )

      assert_query(expected, actual)
    end

    # `with_named_binding` is idempotent. If the named binding already exists on the
    # query, the join params are ignored and the query passes through unchanged.
    test "matches Ecto.Query when with_named_binding no-ops on an existing binding" do
      source =
        from(p in Post,
          join: a in assoc(p, :author),
          as: :author
        )

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{
            with_named_binding: %{author: %{join: [association: [source: :author, as: :author]]}}
          },
          []
        )

      assert_query(source, actual)
    end
  end

  describe "with_named_binding warning paths" do
    test "logs a warning and returns query unchanged when params is not a map or keyword list" do
      expected = from(p in Post)

      log =
        capture_log(fn ->
          actual =
            CommonFilters.convert_params_to_filter(
              Post,
              %{with_named_binding: "bad value"},
              []
            )

          assert_query(expected, actual)
        end)

      assert log =~ "Expected :with_named_binding params to be a map or keyword list"
    end

    test "logs a warning and returns query unchanged for a non-tuple element in the params list" do
      expected = from(p in Post)

      log =
        capture_log(fn ->
          actual =
            CommonFilters.convert_params_to_filter(
              Post,
              %{with_named_binding: [:not_a_pair]},
              []
            )

          assert_query(expected, actual)
        end)

      assert log =~ "Expected :with_named_binding params to be a map or keyword list"
    end

    test "logs a warning when the callback does not create the named binding" do
      expected = from(p in Post)

      log =
        capture_log(fn ->
          actual =
            CommonFilters.convert_params_to_filter(
              Post,
              %{with_named_binding: [author: %{limit: 1}]},
              []
            )

          assert_query(expected, actual)
        end)

      assert log =~
               "Filters provided for :with_named_binding key :author did not create a named binding"
    end
  end
end
