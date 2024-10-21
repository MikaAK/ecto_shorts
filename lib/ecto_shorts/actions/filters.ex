defmodule EctoShorts.Actions.Filters do
  @moduledoc """
  Converts parameters into filters and applies them to the query using the query builder.
  """
  require Logger

  @type query :: Ecto.Query.t()
  @type params :: map() | keyword()
  @type query_builder :: module()

  @doc """
  Applies filters to the query based on the provided parameters.
  """
  @spec convert_params_to_filter(query, params, query_builder) :: query
  def convert_params_to_filter(query, _params, nil), do: query

  def convert_params_to_filter(query, params, _query_builder)
      when not (is_map(params) or is_list(params)),
      do: query

  def convert_params_to_filter(query, params, _query_builder)
      when params === %{} or params === [],
      do: query

  def convert_params_to_filter(query, params, query_builder) do
    if supports_query_building?(query_builder) do
      schema = EctoShorts.QueryHelpers.get_queryable(query)

      Enum.reduce(params, query, &reduce_filter(query_builder, schema, &1, &2))
    else
      query
    end
  end

  defp reduce_filter(query_builder, schema, {filter_key, filter_value}, current_query) do
    if filter_key in query_builder.filters() do
      query_builder.build_query(schema, %{filter_key => filter_value}, current_query)
    else
      Logger.debug(
        "[EctoShorts] #{inspect(filter_key)} is not defined among filters in the #{inspect(query_builder)} context module"
      )

      current_query
    end
  end

  defp supports_query_building?(query_builder) do
    Code.ensure_loaded?(query_builder) and
      function_exported?(query_builder, :build_query, 3) and
      function_exported?(query_builder, :filters, 0)
  end
end
