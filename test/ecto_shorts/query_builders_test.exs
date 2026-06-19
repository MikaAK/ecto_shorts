defmodule EctoShorts.QueryBuildersTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog
  import Ecto.Query

  alias EctoShorts.QueryBuilders
  alias EctoShorts.Schema.Post
  alias EctoShorts.Testing

  # Ensure the default adapter module is loaded before tests run.
  # In isolated test contexts the BEAM may not have loaded it yet, causing
  # function_exported?/3 to return false even though the module exists.
  setup_all do
    Code.ensure_loaded!(EctoShorts.CommonFilters.Builder)
    :ok
  end

  # A minimal module that exports build_query/6 and applies a distinct limit.
  defmodule CustomBuilder do
    @behaviour EctoShorts.QueryBuilder
    def build_query(_filter, _source, query, _binding, _term, _opts) do
      from(p in query, limit: 99)
    end
  end

  # A module that does NOT export build_query/6.
  defmodule BuilderWithoutCallback do
    @behaviour EctoShorts.QueryBuilder
  end

  describe "build_query/6 adapter resolution" do
    test "uses the default adapter (CommonFilters.Builder) when no opts or config override is set" do
      expected = limit(Post, ^10)
      actual = QueryBuilders.build_query(:limit, Post, from(p in Post), {:as, nil}, 10, [])

      Testing.assert_query(expected, actual)
    end

    test "uses opts[:query_builder] override at runtime over the default adapter" do
      expected = from(p in Post, limit: 99)

      actual =
        QueryBuilders.build_query(
          :limit,
          Post,
          from(p in Post),
          {:as, nil},
          10,
          query_builder: CustomBuilder
        )

      Testing.assert_query(expected, actual)
    end

    test "opts[:query_builder_module] (old runtime key) is NOT honored — falls through to default adapter" do
      # After the :query_builder migration, passing the old key as a runtime opt
      # must not activate the custom builder; the default adapter is used instead.
      expected = limit(Post, ^10)

      actual =
        QueryBuilders.build_query(
          :limit,
          Post,
          from(p in Post),
          {:as, nil},
          10,
          query_builder_module: CustomBuilder
        )

      Testing.assert_query(expected, actual)
    end

    test "logs a warning and returns the query unchanged when the module does not export build_query/6" do
      q = from(p in Post)

      log =
        capture_log(fn ->
          result =
            QueryBuilders.build_query(
              :limit,
              Post,
              q,
              {:as, nil},
              10,
              query_builder: BuilderWithoutCallback
            )

          Testing.assert_query(q, result)
        end)

      assert log =~ "does not export the required function build_query/6"
      assert log =~ inspect(BuilderWithoutCallback)
    end

    test "raises ArgumentError when opts[:query_builder] is not a module atom" do
      assert_raise ArgumentError, ~r/Expected :query_builder option to be a module/, fn ->
        QueryBuilders.build_query(
          :limit,
          Post,
          from(p in Post),
          {:as, nil},
          10,
          query_builder: "not_a_module"
        )
      end
    end
  end
end
