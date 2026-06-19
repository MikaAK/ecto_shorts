defmodule EctoShorts.DynamicBuilders.PostgresTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing

  alias EctoShorts.DynamicBuilders.Postgres
  alias EctoShorts.Schema.Post

  import Ecto.Query

  alias EctoShorts.CommonFilters.Predicate

  describe "build_dynamic/3 over a %Predicate{}" do
    test "the Postgres adapter turns a scalar Predicate into the right dynamic" do
      pred = %Predicate{field: :views, routing: :scalar, negated: false, expr: {:>, 10}}
      dyn = Postgres.build_dynamic(pred, {:as, nil}, [])

      q = from(p in Post, where: ^dyn)
      assert_sql(from(p in Post, where: p.views > ^10), q)
    end

    test "negation flips the scalar comparison" do
      pred = %Predicate{field: :views, routing: :scalar, negated: true, expr: {:==, 10}}
      dyn = Postgres.build_dynamic(pred, {:as, nil}, [])

      q = from(p in Post, where: ^dyn)
      assert_sql(from(p in Post, where: p.views != ^10), q)
    end

    test "an array-routed Predicate builds an array clause" do
      pred = %Predicate{field: :tags, routing: :array, negated: false, expr: {:overlaps, ["a", "b"]}}
      dyn = Postgres.build_dynamic(pred, {:as, nil}, [])

      q = from(p in Post, where: ^dyn)
      assert_sql(from(p in Post, where: fragment("? && ?", p.tags, ^["a", "b"])), q)
    end
  end
end
