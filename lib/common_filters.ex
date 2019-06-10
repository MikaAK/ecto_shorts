defmodule EctoShorts.CommonFilters do
  @moduledoc """
  This modules main purpose is to house a collection of common schema filters
  and functionality to be included in params -> filters
  """

  import Ecto.Query, only: [order_by: 2]

  alias EctoShorts.QueryBuilder

  @common_filters QueryBuilder.Common.filters()

  @doc "Converts filter params into a query"
  @spec convert_params_to_filter(
    queryable :: Ecto.Query.t(),
    params :: Keyword.t | map
  ) :: Ecto.Query.t
  def convert_params_to_filter(query, params) when params === %{}, do: query
  def convert_params_to_filter(query, params) when is_map(params), do: convert_params_to_filter(query, Map.to_list(params))

  def convert_params_to_filter(query, params, order_by_prop \\ :id)

  def convert_params_to_filter(query, params, nil) do
    params
      |> ensure_last_is_final_filter
      |> Enum.reduce(query, &create_schema_filter/2)
  end

  def convert_params_to_filter(query, params, order_by_prop) do
    params
      |> ensure_last_is_final_filter
      |> Enum.reduce(order_by(query, ^order_by_prop), &create_schema_filter/2)
  end

  def create_schema_filter({filter, val}, query) when filter in @common_filters do
    QueryBuilder.create_schema_filter(QueryBuilder.Common, {filter, val}, query)
  end

  def create_schema_filter({filter, val}, query) do
    QueryBuilder.create_schema_filter(QueryBuilder.Schema, {filter, val}, query)
  end

  defp ensure_last_is_final_filter(params) do
    if Keyword.has_key?(params, :last) do
      params
        |> Keyword.delete(:last)
        |> Kernel.++([last: params[:last]])
    else
      params
    end
  end
end
