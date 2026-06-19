defmodule EctoShorts.QueryBuildersTest do
  use ExUnit.Case, async: true
  import Ecto.Query
  alias EctoShorts.QueryBuilders

  defmodule PassthroughBuilder do
    @behaviour EctoShorts.QueryBuilder
    def build_query(_filter, _source, query, _binding, _term, _opts), do: query
  end

  test ":query_builder runtime opt selects the adapter" do
    q = from(p in "posts")
    # A module without build_query/6 would warn+passthrough; a valid one is invoked.
    assert %Ecto.Query{} =
             QueryBuilders.build_query(:where, "posts", q, {:as, nil}, {:x, 1},
               query_builder: PassthroughBuilder)
  end

  test "non-module :query_builder raises ArgumentError mentioning :query_builder" do
    q = from(p in "posts")
    assert_raise ArgumentError, ~r/:query_builder/, fn ->
      QueryBuilders.build_query(:where, "posts", q, {:as, nil}, {:x, 1}, query_builder: "nope")
    end
  end
end
