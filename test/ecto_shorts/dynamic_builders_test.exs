defmodule EctoShorts.DynamicBuildersTest do
  use ExUnit.Case, async: true

  import Ecto.Query
  import ExUnit.CaptureLog

  alias EctoShorts.DynamicBuilders
  alias EctoShorts.Testing

  # Fake repo modules that report specific adapter names without any real DB connection.
  defmodule FakePostgresRepo do
    def __adapter__, do: Ecto.Adapters.Postgres
  end

  defmodule FakeMyXQLRepo do
    def __adapter__, do: Ecto.Adapters.MyXQL
  end

  defmodule FakeSQLRepo do
    def __adapter__, do: Ecto.Adapters.SQL
  end

  defmodule FakeTdsRepo do
    def __adapter__, do: Ecto.Adapters.Tds
  end

  defmodule FakeUnknownRepo do
    def __adapter__, do: SomeOtherAdapter
  end

  # A minimal custom DynamicBuilder adapter for testing the override path. As of
  # v3.0.0 the callback consumes a resolved %Predicate{}.
  defmodule CustomDynamicBuilder do
    @behaviour EctoShorts.DynamicBuilder

    @impl true
    def build_dynamic(%EctoShorts.CommonFilters.Predicate{expr: {_op, value}}, _selected_binding, _opts) do
      dynamic([q], q.id == ^value)
    end
  end

  describe "build_dynamic/3 adapter override" do
    test "uses the :dynamic_builder opt at call time to bypass repo-based resolution" do
      expected = dynamic([q], q.id == ^42)

      predicate = %EctoShorts.CommonFilters.Predicate{
        field: :id,
        routing: :scalar,
        negated: false,
        expr: {:==, 42}
      }

      actual =
        DynamicBuilders.build_dynamic(
          predicate,
          {:as, nil},
          dynamic_builder: CustomDynamicBuilder
        )

      Testing.assert_dynamic(expected, actual)
    end
  end

  describe "unsupported adapter warns and defaults to Postgres" do
    @predicate %EctoShorts.CommonFilters.Predicate{
      field: :id,
      routing: :scalar,
      negated: false,
      expr: {:==, 1}
    }

    test "Postgres adapter resolves silently with no warning" do
      expected = dynamic([q], q.id == ^1)

      log =
        capture_log(fn ->
          actual = DynamicBuilders.build_dynamic(@predicate, {:as, nil}, repo: FakePostgresRepo)
          Testing.assert_dynamic(expected, actual)
        end)

      refute log =~ "no built-in dynamic builder"
    end

    for {adapter_name, repo} <- [
          {"Ecto.Adapters.MyXQL", FakeMyXQLRepo},
          {"Ecto.Adapters.SQL", FakeSQLRepo},
          {"Ecto.Adapters.Tds", FakeTdsRepo},
          {"an unknown adapter", FakeUnknownRepo}
        ] do
      test "warns and falls back to Postgres for #{adapter_name}" do
        expected = dynamic([q], q.id == ^1)

        log =
          capture_log(fn ->
            actual = DynamicBuilders.build_dynamic(@predicate, {:as, nil}, repo: unquote(repo))
            Testing.assert_dynamic(expected, actual)
          end)

        assert log =~ "no built-in dynamic builder"
        assert log =~ "defaulting to EctoShorts.DynamicBuilders.Postgres"
      end
    end
  end
end
