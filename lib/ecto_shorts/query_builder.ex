defmodule EctoShorts.QueryBuilder do
  @moduledoc since: "2.5.0"
  @moduledoc """
  `EctoShorts.QueryBuilder` defines the behavior for building custom
  filters into Ecto queries.

  A query builder is responsible for interpreting parameters like
  `%{id: 1}` or `%{limit: 5}` and implementing the filtering logic
  like `where` or `limit` clauses.

  This module lets you plug in your own adapter that knows how to
  turn those filter parameters into real Ecto queries giving you
  full control of how your queries are composed.

  This allows you to:

    - Build queries based on parameters you define which can be
      changed at any time.

    - Apply filters consistently across different parts of your app.

    - Extend Ecto's filtering capabilities using things such as
      fragments to access the underlying database functionality.

  ## Creating your own Adapter

  Suppose you want `limit` the amount of records returned in the result.

  You could implement your own adapter like this:

      defmodule MyApp.QueryBuilder do
        @behaviour EctoShorts.QueryBuilder

        alias Ecto.Query

        require Ecto.Query

        def filters, do: [:limit]

        def build_query(query, _binding_alias, _schema_module, :limit, value, _opts) do
          if binding_alias do
            Query.limit(query, [{^binding_alias, q}], ^value)
          else
            Query.limit(query, [q], ^value)
          end
        end
      end

  Then use it like this:

      EctoShorts.QueryBuilder.build_query(MyApp.QueryBuilder, Post, nil, Post, :limit, 5)

  which returns the new query with the filter applied:

      #Ecto.Query<from p0 in Post, limit: ^5>
  """

  @type query :: Ecto.Query.t()
  @type schema_module :: Ecto.Queryable.t()
  @type schema_source :: binary()
  @type source_and_schema :: {schema_source(), schema_module()}
  @type sourceable :: schema_module() | source_and_schema()
  @type queryable_source :: query() | schema_module()
  @type query_source :: query() | sourceable()
  @type binding_alias :: atom()

  @type adapter :: module()
  @type key :: atom()
  @type value :: any()
  @type params :: map() | keyword()
  @type filter :: atom()
  @type filters :: list(filter())
  @type opts :: keyword()

  @doc """
  Returns a list of supported filters for the adapter.
  """
  @callback filters :: filters()

  @doc """
  Defines the behavior for building a query from a single filter key and value.

  Adapters implementing this callback are responsible for translating the key and
  value into a query expression. This could be a `where`, `limit`, `order_by`,
  or even a join or subquery, depending on the key and how the adapter is designed.

  ## Parameters

    * `query` — An existing query, queryable, or `{schema_source, schema_module}` tuple.
    * `binding` — An optional alias used to refer to the query binding (e.g. `:post`).
    * `queryable` — The schema module or queryable the filters apply to.
    * `key` — A filter key, such as a field name (`:title`) or virtual key (`:limit`).
    * `value` — The value to filter by. This may be a scalar, list, or expression map
      like `%{ilike: "foo"}`.

  ## Return

  This function must return the given the new query with the filter applied,
  for example:

      defmodule MyApp.QueryBuilder do
        @behaviour EctoShorts.QueryBuilder

        alias Ecto.Query

        require Ecto.Query

        def filters, do: [:limit]

        def build_query(query, _binding_alias, _schema_module, :limit, value, _opts) do
          if binding_alias do
            Query.limit(query, [{^binding_alias, q}], ^value)
          else
            Query.limit(query, [q], ^value)
          end
        end
      end
  """
  @callback build_query(
              query_source(),
              binding_alias() | nil,
              schema_module(),
              key(),
              value(),
              opts()
            ) :: queryable_source()

  @doc """
  Returns a list of supported filters that can be used with the
  configured query builder.
  """
  @spec filters(adapter()) :: filters()
  def filters(adapter), do: adapter.filters()

  @doc """
  Dispatches to the configured query builder adapter to build a query
  based on a filter key and value.

  The adapter used to build the query is chosen in the following order:

    * If `:query_builder_adapter` is present in the options, it is used.

    * Otherwise, the `:query_builder_adapter` option configured in
      application environment is checked.

    * If neither is set, the default is `EctoShorts.QueryBuilders`.

  ## Examples

      iex> EctoShorts.QueryBuilder.build_query(Post, :post, Post, :limit, 10)
      #Ecto.Query<from p in Post, limit: 10>
  """
  @spec build_query(
          adapter(),
          query_source(),
          binding_alias() | nil,
          schema_module(),
          key(),
          value()
        ) :: queryable_source()
  @spec build_query(
          adapter(),
          query_source(),
          binding_alias() | nil,
          schema_module(),
          key(),
          value(),
          opts()
        ) :: queryable_source()
  def build_query(adapter, query, binding_alias, schema_module, key, value, opts \\ []) do
    adapter.build_query(
      query,
      binding_alias,
      schema_module,
      key,
      value,
      opts
    )
  end
end
