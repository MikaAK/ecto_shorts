defmodule EctoShorts.QueryBuilder.Custom do
  @moduledoc """
  This module enables the addition of custom query filters
  to the query builder through a custom module defined
  in the configuration of the dependent application.
  """

  @type filter_tuple :: {filter_type :: atom, value :: any}
  @type accumulator_query :: Ecto.Query.t

  @behaviour EctoShorts.QueryBuilder

  @impl EctoShorts.QueryBuilder
  @spec create_schema_filter(filter_tuple(), accumulator_query()) :: accumulator_query()
  def create_schema_filter(filter_tuple, accumulator_query),
    do: apply(custom_module(), :create_custom_schema_filter, [filter_tuple, accumulator_query])

  @doc "Adds to the accumulator query with filter_type and value"
  @callback create_custom_schema_filter(filter_tuple, accumulator_query) :: accumulator_query

  @spec create_custom_schema_filter(filter_tuple, accumulator_query) :: accumulator_query
  def create_custom_schema_filter(_filter_tuple, accumulator_query),
    do: accumulator_query

  def filters, do: apply(custom_module(), :custom_filters, [])

  @doc "List of custom filters"
  @callback custom_filters() :: list(atom)

  @spec custom_filters() :: list(atom)
  def custom_filters, do: []

  @spec custom_module() :: module
  defp custom_module() do
    Application.get_env(:ecto_shorts, :custom_query_builder_module) || EctoShorts.QueryBuilder.Custom
  end
end
