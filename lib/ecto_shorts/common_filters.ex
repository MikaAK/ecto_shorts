defmodule EctoShorts.CommonFilters do
  @moduledoc """
  Provides a declarative way to build complex Ecto queries using parameter maps.

  The `EctoShorts.CommonFilters` module converts parameter maps into Ecto queries, allowing
  you to express complex query conditions in a simple, declarative way. This approach
  is more readable and maintainable than building queries manually.

  ## Common Filters

  The following common filters are available:

  | Filter | Description | Example |
  | ------ | ----------- | ------- |
  | `preload` | Preloads associations onto the query results | `%{preload: [:posts, :comments]}` |
  | `start_date` | Query for items inserted after this date | `%{start_date: ~D[2023-01-01]}` |
  | `end_date` | Query for items inserted before this date | `%{end_date: ~D[2023-12-31]}` |
  | `before` | Get items with IDs before this value | `%{before: 100}` |
  | `after` | Get items with IDs after this value | `%{after: 50}` |
  | `ids` | Get items with IDs in the specified list | `%{ids: [1, 2, 3, 4]}` |
  | `first` | Gets the first n items | `%{first: 10}` |
  | `last` | Gets the last n items | `%{last: 5}` |
  | `limit` | Gets the first n items (alias for `first`) | `%{limit: 20}` |
  | `offset` | Offsets limit by n items | `%{offset: 10, limit: 10}` |
  | `order_by` | Orders the results in desc or asc order | `%{order_by: {:desc, :inserted_at}}` |
  | `search` | Performs a custom search (requires schema to implement `by_search/2`) | `%{search: "query"}` |

  ### Examples

  ```elixir
  # Get the first 10 users
  EctoShorts.CommonFilters.convert_params_to_filter(User, %{first: 10})

  # Get users with specific IDs
  EctoShorts.CommonFilters.convert_params_to_filter(User, %{ids: [1, 2, 3, 4]})

  # Get users ordered by email_updated_at in descending order
  EctoShorts.CommonFilters.convert_params_to_filter(User, %{order_by: {:desc, :email_updated_at}})
  ```

  ## Field Filters

  You can filter on any field of a schema using the following operators:

  | Operator | Description | Example |
  | -------- | ----------- | ------- |
  | `gte` | Greater than or equal to | `%{age: %{gte: 18}}` |
  | `gt` | Greater than | `%{price: %{gt: 100}}` |
  | `lte` | Less than or equal to | `%{age: %{lte: 65}}` |
  | `lt` | Less than | `%{price: %{lt: 50}}` |
  | `like` | Case-sensitive pattern matching (use % as wildcard) | `%{name: %{like: "Jo%"}}` |
  | `ilike` | Case-insensitive pattern matching (use % as wildcard) | `%{name: %{ilike: "jo%"}}` |
  | `==` | Equal to (same as direct field match) | `%{status: %{==: "active"}}` |
  | `!=` | Not equal to | `%{status: %{!=: "deleted"}}` |

  ### Examples

  ```elixir
  # Exact match on name (shorthand for ==)
  EctoShorts.CommonFilters.convert_params_to_filter(User, %{name: "Billy"})

  # Case-insensitive pattern matching on name
  EctoShorts.CommonFilters.convert_params_to_filter(User, %{name: %{ilike: "steve%"}})

  # Range filter on age (between 18 and 30 inclusive)
  EctoShorts.CommonFilters.convert_params_to_filter(User, %{age: %{gte: 18, lte: 30}})
  
  # Find records where is_banned is not nil
  EctoShorts.CommonFilters.convert_params_to_filter(User, %{is_banned: %{!=: nil}})
  
  # Find records where is_banned is nil
  EctoShorts.CommonFilters.convert_params_to_filter(User, %{is_banned: %{==: nil}})
  
  # Find records where balance is not zero
  EctoShorts.CommonFilters.convert_params_to_filter(User, %{balance: %{!=: 0}})
  ```

  ### String Transformations
  
  EctoShorts.CommonFilters also supports fragment modifiers for string fields:

  | Modifier | Description | Example |
  | -------- | ----------- | ------- |
  | `:lower` | Convert field to lowercase before comparison | `%{name: {:lower, "billy"}}` |
  | `:upper` | Convert field to uppercase before comparison | `%{name: {:upper, "BILLY"}}` |

  ```elixir
  # Match name field converted to lowercase against "billy"
  EctoShorts.CommonFilters.convert_params_to_filter(User, %{name: {:lower, "billy"}})
  
  # Match name field converted to uppercase against "BILLY"
  EctoShorts.CommonFilters.convert_params_to_filter(User, %{name: {:upper, "BILLY"}})
  
  # Find records where name field in lowercase is not "billy"
  EctoShorts.CommonFilters.convert_params_to_filter(User, %{name: %{!=: {:lower, "billy"}}})
  ```
  
  ## Additional Options
  
  When using `convert_params_to_filter/3`, you can pass additional options:
  
  ### Filter Mode
  
  Determine how multiple filters are combined (AND or OR logic).
  
  ```elixir
  # Get users with name "John" AND age 30
  query = EctoShorts.CommonFilters.convert_params_to_filter(User, %{name: "John", age: 30}, filter_mode: :and)
  
  # Get users with name "John" OR age 30
  query = EctoShorts.CommonFilters.convert_params_to_filter(User, %{name: "John", age: 30}, filter_mode: :or)
  ```
  
  ### Query Mode
  
  Determine whether to return all records or just a count.
  
  ```elixir
  # Get all users matching the filters
  query = EctoShorts.CommonFilters.convert_params_to_filter(User, %{age: %{gte: 18}}, query_mode: :all)
  users = Repo.all(query)
  
  # Get the count of users matching the filters
  query = EctoShorts.CommonFilters.convert_params_to_filter(User, %{age: %{gte: 18}}, query_mode: :count)
  count = Repo.one(query)
  ```
  
  For more detailed information about all available filter options, see the [Filter Options Reference](/docs/reference/filter-options.md).
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
