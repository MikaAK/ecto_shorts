defmodule EctoShorts.QueryBuilder.CommonTest do
  use ExUnit.Case, async: true
  doctest EctoShorts.QueryBuilder.Common

  alias EctoShorts.QueryBuilder.Common
  alias EctoShorts.Support.Schemas.Comment

  describe "filters: " do
    test "returns expected list" do
      assert [
        :preload,
        :start_date,
        :end_date,
        :before,
        :after,
        :ids,
        :first,
        :last,
        :limit,
        :offset,
        :search,
        :order_by
      ] = Common.filters()
    end
  end

  describe "create_schema_filters: " do
    test "returns query without changes when passed {:search, term()}" do
      expected_query = Comment

      assert ^expected_query = Common.create_schema_filter({:search, %{id: 1}}, expected_query)
    end
  end
end
