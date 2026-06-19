defmodule EctoShorts.DynamicBuildersTest do
  use ExUnit.Case, async: true

  import Ecto.Query

  alias EctoShorts.DynamicBuilders
  alias EctoShorts.Schema.Post
  alias EctoShorts.Testing

  # Fake repo modules that report specific adapter names without any real DB connection.
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

  describe "build_dynamic/4 unsupported adapter raises" do
    test "raises for Ecto.Adapters.MyXQL" do
      assert_raise RuntimeError, ~r/Adapter not yet implemented: Ecto.Adapters.MyXQL/, fn ->
        DynamicBuilders.build_dynamic(Post, {:as, nil}, {:id, 1}, repo: FakeMyXQLRepo)
      end
    end

    test "raises for Ecto.Adapters.SQL" do
      assert_raise RuntimeError, ~r/Adapter not yet implemented: Ecto.Adapters.SQL/, fn ->
        DynamicBuilders.build_dynamic(Post, {:as, nil}, {:id, 1}, repo: FakeSQLRepo)
      end
    end

    test "raises for Ecto.Adapters.Tds" do
      assert_raise RuntimeError, ~r/Adapter not yet implemented/, fn ->
        DynamicBuilders.build_dynamic(Post, {:as, nil}, {:id, 1}, repo: FakeTdsRepo)
      end
    end

    test "raises for an unknown/unsupported adapter" do
      assert_raise RuntimeError, ~r/is not supported/, fn ->
        DynamicBuilders.build_dynamic(Post, {:as, nil}, {:id, 1}, repo: FakeUnknownRepo)
      end
    end
  end
end
