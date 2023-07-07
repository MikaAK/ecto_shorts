defmodule EctoShorts.QueryBuilder do
  @moduledoc "Behaviour for query building from filter tuples"

  @type filter_tuple :: {filter_type :: atom, value :: any}
  @type accumulator_query :: Ecto.Query.t()

  @doc "Adds to accumulator query with filter_type and value"
  @callback create_schema_filter(filter_tuple, accumulator_query) :: Ecto.Query.t()

  @spec create_schema_filter(module, filter_tuple, accumulator_query) :: Ecto.Query.t()
  def create_schema_filter(builder, filter_tuple, query) do
    builder.create_schema_filter(filter_tuple, query)
  end

  @spec query_schema(Ecto.Queryable.t()) :: Ecto.Queryable.t()
  @doc "Pulls the schema from a query"
  def query_schema(%{from: %{source: {_, schema}}}), do: query_schema(schema)
  def query_schema(%{from: %{query: %{from: {_, schema}}}}), do: schema
  def query_schema(query), do: query
end
