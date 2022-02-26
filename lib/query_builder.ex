defmodule EctoShorts.QueryBuilder do
  @moduledoc "Behaviour for query building from filter tuples"

  @type filter_tuple :: {filter_type :: atom, value :: any}
  @type accumulator_query :: Ecto.Query.t

  @doc "Adds to accumulator query with filter_type and value"
  @callback create_schema_filter(filter_tuple, accumulator_query) :: Ecto.Query.t

  @spec create_schema_filter(module, filter_tuple, accumulator_query) :: Ecto.Query.t
  def create_schema_filter(builder_module, filter_tuple, query) when is_atom(builder_module) do
    builder_module.create_schema_filter(filter_tuple, query)
  end
  def create_schema_filter(filter_fn, filter_tuple, query) when is_function(filter_fn) do
    filter_fn.(filter_tuple, query)
  end
  def create_schema_filter(filter_fn, filter, val, query) when is_function(filter_fn) do
    filter_fn.(filter, val, query)
  end

  @spec query_schema(Ecto.Query.t) :: Ecto.Schema.t
  @doc "Pulls the schema from a query"
  def query_schema(%{from: %{source: {_, schema}}}), do: query_schema(schema)
  def query_schema(%{from: %{query: %{from: {_, schema}}}}), do: schema
  def query_schema(query), do: query
end
