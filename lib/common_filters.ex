defmodule EctoShorts.CommonFilters do
  @moduledoc """
  This modules main purpose is to house a collection of common schema filters
  and functionality to be included in params -> filters

  Common filters available include

  - `preload` - Preloads fields onto the query results
  - `start_date` - Query for items inserted after this date
  - `end_date` - Query for items inserted before this date
  - `before` - Get items with ID's before this value
  - `after` - Get items with ID's after this value
  - `ids` - Get items with a list of ids
  - `first` - Gets the first n items
  - `last` - Gets the last n items
  - `limit` - Gets the first n items
  - `offset` - Offsets limit by n items
  - `order_by` - orders the results in desc or asc order
  - `search` - ***Warning:*** This requires schemas using this to have a `&by_search(query, val)` function

  You are also able to filter on any natural field of a model, as well as use

  - gte/gt
  - lte/lt
  - like/ilike
  - is_nil/not(is_nil)

  ```elixir
  CommonFilters.convert_params_to_filter(User, %{name: %{ilike: "steve"}})
  CommonFilters.convert_params_to_filter(User, %{name: %{age: %{gte: 18, lte: 30}}})
  CommonFilters.convert_params_to_filter(User, %{name: %{is_banned: %{!=: nil}}})
  CommonFilters.convert_params_to_filter(User, %{name: %{is_banned: %{==: nil}}})
  CommonFilters.convert_params_to_filter(User, %{name: %{balance: %{!=: 0}}})
  CommonFilters.convert_params_to_filter(User, %{name: "Billy"})
  ```
  """

  import Ecto.Query, only: [where: 2, order_by: 2]
  require Logger

  alias EctoShorts.QueryBuilder

  @common_filters QueryBuilder.Common.filters()

  @doc "Converts filter params into a query"
  @spec convert_params_to_filter(
    queryable :: Ecto.Query.t(),
    params :: Keyword.t | map,
    order_by_prop :: atom,
    order_direction :: atom
  ) :: Ecto.Query.t
  def convert_params_to_filter(query, params, order_by_prop \\ :id, order_direction \\ :desc)

  def convert_params_to_filter(query, params, order_by_prop, order_direction) when is_map(params), do: convert_params_to_filter(query, Map.to_list(params), order_by_prop, order_direction)

  def convert_params_to_filter(query, params, order_by_prop, order_direction) when is_tuple(params), do: convert_params_to_filter(query, [params], order_by_prop, order_direction)

  def convert_params_to_filter(query, [], _, _), do: query

  def convert_params_to_filter(query, params, order_by_prop, :desc) when is_atom(order_by_prop) do
    params
      |> ensure_last_is_final_filter
      |> Enum.reduce(order_by(query, desc: ^order_by_prop), &create_schema_filter/2)
  end

  def convert_params_to_filter(query, params, order_by_prop, :asc) when is_atom(order_by_prop) do
    params
      |> ensure_last_is_final_filter
      |> Enum.reduce(order_by(query, asc: ^order_by_prop), &create_schema_filter/2)
  end

  def convert_params_to_filter(query, params, _, _) do
    params
      |> ensure_last_is_final_filter
      |> Enum.reduce(query, &create_schema_filter/2)
  end

  def create_schema_filter({filter, _} = filter_tuple, query) when filter in @common_filters do
    QueryBuilder.create_schema_filter(QueryBuilder.Common, filter_tuple, query)
  end

  def create_schema_filter({filter, {filter_fn, val}}, query) when is_function(filter_fn) do
    QueryBuilder.create_schema_filter(filter_fn, filter, val, query)
  end

  def create_schema_filter({filter, {val, filter_fn}}, query) when is_function(filter_fn) do
    QueryBuilder.create_schema_filter(filter_fn, filter, val, query)
  end

  def create_schema_filter({filter, filter_fn}, query) when is_function(filter_fn) do
    QueryBuilder.create_schema_filter(filter_fn, filter, query)
  end

  def create_schema_filter({_filter, %Ecto.Query.DynamicExpr{} = dynamic_filter}, query) do
    query
    |> where(^dynamic_filter)
  end

  def create_schema_filter(filter_tuple, query) do
    QueryBuilder.create_schema_filter(QueryBuilder.Schema, filter_tuple, query)
  end

  defp ensure_last_is_final_filter(params) when is_list(params) do
    if Keyword.has_key?(params, :last) do
      params
        |> Keyword.delete(:last)
        |> Kernel.++([last: params[:last]])
    else
      params
    end
  end

  defp ensure_last_is_final_filter(params), do: params

end
