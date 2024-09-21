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

  ```elixir
  CommonFilters.convert_params_to_filter(User, %{first: 10})
  CommonFilters.convert_params_to_filter(User, %{ids: [1, 2, 3, 4]})
  CommonFilters.convert_params_to_filter(User, %{order_by: {:desc, :email_updated_at})
  ```

  You are also able to filter on any natural field of a model, as well as use

  - gte/gt
  - lte/lt
  - like/ilike
  - is_nil/not(is_nil)

  ```elixir
  CommonFilters.convert_params_to_filter(User, %{name: "Billy"})
  CommonFilters.convert_params_to_filter(User, %{name: %{ilike: "steve"}})
  CommonFilters.convert_params_to_filter(User, %{name: %{age: %{gte: 18, lte: 30}}})
  CommonFilters.convert_params_to_filter(User, %{name: %{is_banned: %{!=: nil}}})
  CommonFilters.convert_params_to_filter(User, %{name: %{is_banned: %{==: nil}}})
  CommonFilters.convert_params_to_filter(User, %{name: %{balance: %{!=: 0}}})
  ```

  CommonFilters also supports limited fragment modifiers of natural fields:

  - :lower for "lower(?)"
  - :upper for "lower(?)"

  ```elixir
  CommonFilters.convert_params_to_filter(User, %{name: {:lower, "billy"}})
  CommonFilters.convert_params_to_filter(User, %{name: {:upper, "BILLY"}})
  CommonFilters.convert_params_to_filter(User, %{name: %{!=: {:lower, "billy"}}})
  ```
  """
  alias EctoShorts.{
    CommonSchemas,
    QueryBuilder
  }

  @type params :: map() | keyword()
  @type adapter :: module()
  @type filter_key :: atom()
  @type filter_value :: any()
  @type source :: binary()
  @type query :: Ecto.Query.t()
  @type queryable :: Ecto.Queryable.t()
  @type source_queryable :: {source(), queryable()}

  @common_filters QueryBuilder.Common.filters()

  @behaviour EctoShorts.QueryBuilder

  @doc """
  Converts filter params into a query.

  ### Examples

      iex> EctoShorts.CommonFilters.convert_params_to_filter(EctoShorts.Support.Schemas.Comment, %{id: 1})
      #Ecto.Query<from c0 in EctoShorts.Support.Schemas.Comment, where: c0.id == ^1>
  """
  @spec convert_params_to_filter(
    query :: query() | queryable() | source_queryable(),
    params :: params()
  ) :: query()
  def convert_params_to_filter(queryable, params) when params === %{} do
    CommonSchemas.get_schema_query(queryable)
  end

  def convert_params_to_filter(queryable, params) when is_map(params) do
    params = Map.to_list(params)

    queryable
    |> CommonSchemas.get_schema_query()
    |> convert_params_to_filter(params)
  end

  def convert_params_to_filter(queryable, params) do
    query = CommonSchemas.get_schema_query(queryable)

    params
    |> ensure_last_is_final_filter
    |> Enum.reduce(query, &reduce_schema_filter/2)
  end

  defp reduce_schema_filter({filter_key, filter_value}, query) do
    create_schema_filter(query, filter_key, filter_value)
  end

  @impl true
  @doc """
  Implementation for `c:EctoShorts.QueryBuilder.create_schema_filter/3`.

  ### Examples

      iex> EctoShorts.CommonFilters.create_schema_filter(EctoShorts.Support.Schemas.Post, :first, 1_000)
      #Ecto.Query<from p0 in EctoShorts.Support.Schemas.Post, limit: ^1000>

      iex> EctoShorts.CommonFilters.create_schema_filter(EctoShorts.Support.Schemas.Post, :comments, %{id: 1})
      #Ecto.Query<from p0 in EctoShorts.Support.Schemas.Post, join: c1 in assoc(p0, :comments), as: :ecto_shorts_comments, where: c1.id == ^1>
  """
  @spec create_schema_filter(
    query :: query(),
    filter_key :: filter_key(),
    filter_value :: filter_value()
  ) :: query()
  def create_schema_filter(query, filter_key, filter_value) when filter_key in @common_filters do
    QueryBuilder.create_schema_filter(QueryBuilder.Common, query, filter_key, filter_value)
  end

  def create_schema_filter(query, filter_key, filter_value) do
    QueryBuilder.create_schema_filter(QueryBuilder.Schema, query, filter_key, filter_value)
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
