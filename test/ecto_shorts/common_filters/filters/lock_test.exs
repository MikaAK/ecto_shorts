defmodule EctoShorts.CommonFilters.LockTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing
  @moduletag adapter: :postgres
  @moduletag feature: :lock

  alias EctoShorts.CommonFilters
  alias EctoShorts.Schema.Post

  import Ecto.Query
  import ExUnit.CaptureLog


  describe "lock shapes" do
    # Built-in lock aliases (`:for_update`, `:for_share`) are resolved without a
    # provider. The `name:` key is checked against the built-in alias table first;
    # unrecognized names are forwarded to the query provider if one is configured.
    test "matches Ecto.Query for a root for_update alias lock" do
      expected = lock(Post, "FOR UPDATE")

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{lock: %{name: :for_update}},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for a root map alias lock" do
      expected = lock(Post, "FOR SHARE")

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{lock: %{name: :for_share}},
          []
        )

      assert_query(expected, actual)
    end

    # Provider-backed locks require the `query_provider:` opt. The provider callback
    # receives the lock name and values and must return `{:ok, fn query -> query end}`.
    test "matches Ecto.Query for a provider-backed lock" do
      expected = lock(Post, "FOR UPDATE")

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{lock: %{name: :provider_for_update}},
          query_provider: EctoShorts.TestQueryProvider
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for a provider-backed lock with values" do
      expected = from(p in Post, lock: fragment("FOR UPDATE SKIP LOCKED"))

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{lock: %{name: :for_update_with_clause, values: %{clause: "SKIP LOCKED"}}},
          query_provider: EctoShorts.TestQueryProvider
        )

      assert_query(expected, actual)
    end

    # This test explicitly verifies that the runtime `query_provider:` opt takes
    # priority over app config (which is nil in the test environment). Fix #1 in
    # the A2 review — the resolution order was previously inverted.
    test "runtime query_provider: opt is honored when Config.query_provider_module() is nil" do
      expected = lock(Post, "FOR UPDATE")

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{lock: %{name: :provider_for_update}},
          query_provider: EctoShorts.TestQueryProvider
        )

      assert_query(expected, actual)
    end

    test "legacy :query_provider_module runtime opt is NOT honored — falls through to no-provider path" do
      expected = from(p in Post)

      log =
        capture_log(fn ->
          actual =
            CommonFilters.convert_params_to_filter(
              Post,
              %{lock: %{name: :provider_for_update}},
              query_provider_module: EctoShorts.TestQueryProvider
            )

          assert_query(expected, actual)
        end)

      assert log =~ "No query provider module configured for lock filter"
    end

    test "logs warning and keeps query unchanged when no query provider module is configured" do
      expected = from(p in Post)

      log =
        capture_log(fn ->
          actual =
            CommonFilters.convert_params_to_filter(
              Post,
              %{lock: %{name: :custom_advisory_lock}},
              []
            )

          assert_query(expected, actual)
        end)

      assert log =~ "No query provider module configured for lock filter"
    end

    # The accepted lock shape is `%{name: atom}` or `[name: atom]`. Raw strings and
    # bare functions are malformed caller input; both raise (D-RAISE).
    test "raises for a direct raw string lock" do
      assert_raise EctoShorts.FilterError, ~r/:name key/, fn ->
        CommonFilters.convert_params_to_filter(Post, %{lock: "FOR SHARE NOWAIT"}, [])
      end
    end

    test "raises for a direct raw function lock" do
      lock_fun = fn query -> from(p in query, lock: "FOR UPDATE") end

      assert_raise EctoShorts.FilterError, ~r/:name key/, fn ->
        CommonFilters.convert_params_to_filter(Post, %{lock: lock_fun}, [])
      end
    end

    test "keeps the query unchanged when the lock provider returns nil" do
      expected = from(p in Post)

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{lock: %{name: :provider_for_update}},
          query_provider: EctoShorts.TestNoOpQueryProvider
        )

      assert_query(expected, actual)
    end

    test "keeps the query unchanged when the lock provider returns an error" do
      expected = from(p in Post)

      log =
        capture_log(fn ->
          actual =
            CommonFilters.convert_params_to_filter(
              Post,
              %{lock: %{name: :error_fragment}},
              query_provider: EctoShorts.TestQueryProvider
            )

          assert_query(expected, actual)
        end)

      assert log =~ "Lock expression callback returned error for :error_fragment: :forced_error"
    end

    # The provider return contract is `{:ok, fn}` | `{:error, reason}` | `nil`.
    # A return value that does not match one of these shapes is out of contract
    # and raises (D-PROVIDER).
    test "raises when the lock provider returns a raw expression (out of contract)" do
      assert_raise EctoShorts.FilterError, ~r/QueryProvider must return/, fn ->
        CommonFilters.convert_params_to_filter(
          Post,
          %{lock: %{name: :legacy_for_update}},
          query_provider: EctoShorts.TestQueryProvider
        )
      end
    end
  end

  describe "lock extended paths" do
    test "keeps the query unchanged when lock value is nil" do
      expected = from(p in Post)

      actual =
        CommonFilters.convert_params_to_filter(Post, %{lock: nil}, [])

      assert_query(expected, actual)
    end

    test "keeps the query unchanged when lock params map has no :name key" do
      expected = from(p in Post)

      actual =
        CommonFilters.convert_params_to_filter(
          Post,
          %{lock: %{values: %{clause: "SKIP LOCKED"}}},
          []
        )

      assert_query(expected, actual)
    end

    test "raises when provider callback returns a non-Ecto.Query (out of contract)" do
      assert_raise EctoShorts.FilterError, ~r/must return an Ecto.Query/, fn ->
        CommonFilters.convert_params_to_filter(
          Post,
          %{lock: %{name: :callback_bad_return}},
          query_provider: EctoShorts.TestQueryProvider
        )
      end
    end

    test "raises when provider returns a non-function ok tuple (out of contract)" do
      assert_raise EctoShorts.FilterError, ~r/must be a 1-arity function/, fn ->
        CommonFilters.convert_params_to_filter(
          Post,
          %{lock: %{name: :callback_not_function}},
          query_provider: EctoShorts.TestQueryProvider
        )
      end
    end
  end

  # ---- merged from lock (schemaless) ----
  describe "lock shapes (schemaless)" do
    @describetag feature: :lock
    @describetag schema_mode: :schemaless
    test "matches Ecto.Query for a root for_update alias lock" do
      expected = lock("posts", "FOR UPDATE")

      actual =
        CommonFilters.convert_params_to_filter(
          "posts",
          %{lock: %{name: :for_update}},
          []
        )

      assert_query(expected, actual)
    end

    test "raises for a direct raw string lock (D-RAISE)" do
      assert_raise EctoShorts.FilterError, ~r/:name key/, fn ->
        CommonFilters.convert_params_to_filter("posts", %{lock: "FOR SHARE NOWAIT"}, [])
      end
    end
  end
end
