defmodule EctoShorts.QueryBuilders.Common do
  @moduledoc since: "2.5.0"
  @moduledoc """
  Provides common query-building functionality for `EctoShorts`.

  This module implements the `EctoShorts.QueryBuilder` behaviour for filters
  that are common across many schemas. These include pagination, ordering,
  ID filtering, and temporal filters.

  It is designed to be composable and reusable, working alongside
  schema-specific query builders such as `EctoShorts.QueryBuilders.Schema`.

  ## Examples

      iex> EctoShorts.QueryBuilders.Common.filters()
      [:after, :before, :end_date, :first, :ids, :last, :limit, :offset, :order_by, :preload, :search, :since, :start_date, :until]

      iex> EctoShorts.QueryBuilders.Common.build_query(EctoShorts.Schemas.Post, nil, EctoShorts.Schemas.Post, :limit, 10)
      #Ecto.Query<from p0 in EctoShorts.Schemas.Post, limit: ^10>
  """

  alias EctoShorts.CommonQueryAPI

  @filters ~w(
    after
    before
    end_date
    first
    ids
    last
    limit
    offset
    order_by
    preload
    search
    since
    start_date
    until
  )a

  @behaviour EctoShorts.QueryBuilder

  @type query :: Ecto.Query.t()
  @type schema :: Ecto.Queryable.t()
  @type source :: binary()
  @type schema_source :: {source(), schema()}
  @type queryable_input :: schema() | schema_source()
  @type query_source :: query() | queryable_input()
  @type binding_alias :: atom() | nil
  @type value :: any()
  @type opts :: keyword()
  @type filter ::
          :after
          | :before
          | :end_date
          | :first
          | :ids
          | :last
          | :limit
          | :offset
          | :order_by
          | :preload
          | :search
          | :since
          | :start_date
          | :until

  @impl EctoShorts.QueryBuilder
  @doc """
  Returns the list of supported filters for this query builder.

  These filters include pagination controls, ordering, ID matching,
  and timestamp-based range filters.

  ## Examples

      iex> EctoShorts.QueryBuilders.Common.filters()
      [:after, :before, :end_date, :first, :ids, :last, :limit, :offset, :order_by, :preload, :search, :since, :start_date, :until]
  """
  @spec filters() :: [filter()]
  def filters, do: @filters

  @impl EctoShorts.QueryBuilder
  @doc """
  Builds a query using the provided filter key and value.

  Each filter transforms the query according to a known expression:

    * `:ids` – Filters records where the primary key (`id`) matches any in the given list.
    * `:first` – Limits the number of results returned to the given value.
    * `:last` – Retrieves the last N records based on `inserted_at`, preserving original order.
    * `:limit` – Limits the number of results directly (same as `:first` but without side-effects).
    * `:offset` – Skips a number of results before returning the remainder.
    * `:order_by` – Sorts the results using the provided sort conditions.
    * `:preload` – Eager loads associations specified in the value.
    * `:after` – Filters records where the `id` is greater than the given value.
    * `:before` – Filters records where the `id` is less than the given value.
    * `:since` / `:start_date` – Filters records where `inserted_at` is greater than or equal to the value.
    * `:until` / `:end_date` – Filters records where `inserted_at` is less than or equal to the value.
    * `:search` – If the schema defines `by_search/2`, delegates to it. Otherwise, returns the original query.

  ## Examples

      iex> EctoShorts.QueryBuilders.Common.build_query(EctoShorts.Schemas.Post, nil, EctoShorts.Schemas.Post, :ids, [1, 2, 3])
      #Ecto.Query<from p0 in EctoShorts.Schemas.Post, where: p0.id in ^[1, 2, 3]>

      iex> EctoShorts.QueryBuilders.Common.build_query(EctoShorts.Schemas.Post, nil, EctoShorts.Schemas.Post, :limit, 5)
      #Ecto.Query<from p0 in EctoShorts.Schemas.Post, limit: ^5>
  """
  @spec build_query(
          query_source(),
          binding_alias() | nil,
          schema(),
          filter(),
          value()
        ) :: query() | schema()
  @spec build_query(
          query_source(),
          binding_alias() | nil,
          schema(),
          filter(),
          value(),
          opts()
        ) :: query() | schema()
  def build_query(query, binding_alias, schema, key, value, opts \\ [])

  def build_query(query, binding_alias, _schema, :ids, values, opts) do
    CommonQueryAPI.where(query, binding_alias, %{id: %{==: values}}, opts)
  end

  def build_query(query, binding_alias, _schema, :first, value, _opts) do
    CommonQueryAPI.limit(query, binding_alias, value)
  end

  def build_query(query, binding_alias, _schema, :last, value, opts) do
    query
    |> CommonQueryAPI.exclude(:order_by)
    |> CommonQueryAPI.order_by(binding_alias, order_by: [desc: :inserted_at])
    |> CommonQueryAPI.limit(binding_alias, value)
    |> CommonQueryAPI.subquery(opts[:subquery_options] || [])
    |> CommonQueryAPI.order_by(binding_alias, :id)
  end

  def build_query(query, binding_alias, _schema, :limit, value, _opts) do
    CommonQueryAPI.limit(query, binding_alias, value)
  end

  def build_query(query, binding_alias, _schema, :offset, value, _opts) do
    CommonQueryAPI.offset(query, binding_alias, value)
  end

  def build_query(query, binding_alias, _schema, :order_by, value, _opts) do
    CommonQueryAPI.order_by(query, binding_alias, value)
  end

  def build_query(query, binding_alias, _schema, :preload, value, _opts) do
    CommonQueryAPI.preload(query, binding_alias, value)
  end

  def build_query(query, binding_alias, _schema, :after, value, opts) do
    CommonQueryAPI.where(query, binding_alias, %{id: %{>: value}}, opts)
  end

  def build_query(query, binding_alias, _schema, :before, value, opts) do
    CommonQueryAPI.where(query, binding_alias, %{id: %{<: value}}, opts)
  end

  def build_query(query, binding_alias, _schema, :since, value, opts) do
    CommonQueryAPI.where(query, binding_alias, %{inserted_at: %{>=: value}}, opts)
  end

  def build_query(query, binding_alias, _schema, :until, value, opts) do
    CommonQueryAPI.where(query, binding_alias, %{inserted_at: %{<=: value}}, opts)
  end

  def build_query(query, binding_alias, _schema, :start_date, value, opts) do
    CommonQueryAPI.where(query, binding_alias, %{inserted_at: %{>=: value}}, opts)
  end

  def build_query(query, binding_alias, _schema, :end_date, value, opts) do
    CommonQueryAPI.where(query, binding_alias, %{inserted_at: %{<=: value}}, opts)
  end

  def build_query(query, binding_alias, schema, :search, value, _opts) do
    cond do
      function_exported?(schema, :by_search, 3) ->
        schema.by_search(query, binding_alias, value)

      function_exported?(schema, :by_search, 2) ->
        schema.by_search(query, value)

      true ->
        query
    end
  end
end
