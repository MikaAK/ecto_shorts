defmodule EctoShorts.QueryHelpers do
  @moduledoc """
  Helper functions for ecto queries.
  """
  @moduledoc since: "2.5.0"
  alias Ecto.Query

  require Ecto.Query

  @type source :: binary()
  @type params :: map()
  @type query :: Ecto.Query.t()
  @type queryable :: Ecto.Queryable.t()
  @type source_queryable :: {source(), queryable()}
  @type filter_key :: atom()
  @type filter_value :: any()

  @doc """
  Returns a `{source, Ecto.Queryable}` tuple given an `Ecto.Query` or `Ecto.Queryable`.

  ### Examples

      iex> require Ecto.Query
      ...> EctoShorts.Support.Schemas.Comment |> Ecto.Query.from() |> EctoShorts.QueryHelpers.get_source_queryable()
      {"comments", EctoShorts.Support.Schemas.Comment}
  """
  @spec get_source_queryable(query :: Ecto.Query.t()) :: {binary(), Ecto.Queryable.t()}
  def get_source_queryable(%{from: %{source: {source, queryable}}}), do: {source, queryable}
  def get_source_queryable(%{from: %{query: %{from: {source, queryable}}}}), do: {source, queryable}

  @doc """
  Returns a `Ecto.Queryable` given an `Ecto.Query` or `Ecto.Queryable`.

  ### Examples

      iex> require Ecto.Query
      ...> EctoShorts.Support.Schemas.Comment |> Ecto.Query.from() |> EctoShorts.QueryHelpers.get_queryable()
      EctoShorts.Support.Schemas.Comment
  """
  @spec get_queryable(
    query_or_queryable :: Ecto.Query.t() | Ecto.Queryable.t()
  ) :: Ecto.Queryable.t()
  def get_queryable(%{from: %{source: {_, schema}}}), do: get_queryable(schema)
  def get_queryable(%{from: %{query: %{from: {_, schema}}}}), do: schema
  def get_queryable(queryable), do: queryable

  @doc """
  Returns an Ecto.Query for the given schema.

  ### Options

    * `schema_prefix` - Sets the prefix on the `from` expression.
      See the [ecto documentation](https://hexdocs.pm/ecto/multi-tenancy-with-query-prefixes.html#per-from-join-prefixes) for more information.

  ### Examples

      iex> EctoShorts.QueryHelpers.build_query_from(EctoShorts.Support.Schemas.Comment)
      iex> EctoShorts.QueryHelpers.build_query_from(EctoShorts.Support.Schemas.Comment, schema_prefix: "schema_prefix")

      iex> EctoShorts.QueryHelpers.build_query_from({"comments", EctoShorts.Support.Schemas.Comment})
      iex> EctoShorts.QueryHelpers.build_query_from({"comments", EctoShorts.Support.Schemas.Comment}, schema_prefix: "schema_prefix")

      iex> require Ecto.Query
      ...> EctoShorts.Support.Schemas.Comment |> Ecto.Query.from() |> EctoShorts.QueryHelpers.build_query_from()

      iex> require Ecto.Query
      ...> EctoShorts.Support.Schemas.Comment |> Ecto.Query.from() |> EctoShorts.QueryHelpers.build_query_from(schema_prefix: "schema_prefix")
  """
  @spec build_query_from(
    queryable :: queryable() | source_queryable(),
    opts :: keyword()
  ) :: Ecto.Query.t()
  def build_query_from(queryable, opts \\ []) do
    case opts[:schema_prefix] do
      nil -> Query.from(queryable)
      schema_prefix -> Query.from(queryable, prefix: ^schema_prefix)
    end
  end

  @doc """
  Returns an Ecto.Query for the given schema.

  ### Options

    * `query_prefix` - Sets the prefix on the `query`.
      See the [ecto documentation](https://hexdocs.pm/ecto/multi-tenancy-with-query-prefixes.html#per-query-and-per-struct-prefixes) for more information.

  See `&build_query_from/2` for more options.

  ### Examples

      iex> EctoShorts.QueryHelpers.build_schema_query(EctoShorts.Support.Schemas.Comment)
      iex> EctoShorts.QueryHelpers.build_schema_query(EctoShorts.Support.Schemas.Comment, query_prefix: "query_prefix")

      iex> EctoShorts.QueryHelpers.build_schema_query({"comments", EctoShorts.Support.Schemas.Comment})
      iex> EctoShorts.QueryHelpers.build_schema_query({"comments", EctoShorts.Support.Schemas.Comment}, query_prefix: "query_prefix")

      iex> require Ecto.Query
      ...> EctoShorts.Support.Schemas.Comment |> Ecto.Query.from() |> EctoShorts.QueryHelpers.build_schema_query()

      iex> require Ecto.Query
      ...> EctoShorts.Support.Schemas.Comment |> Ecto.Query.from() |> EctoShorts.QueryHelpers.build_schema_query(query_prefix: "query_prefix")
  """
  @spec build_schema_query(
    query :: query() | queryable() | source_queryable(),
    opts :: keyword()
  ) :: Ecto.Query.t()
  def build_schema_query(query, opts \\ [])

  def build_schema_query({source, queryable}, opts) do
    {source, queryable}
    |> build_query_from(schema_prefix: opts[:schema_prefix])
    |> build_schema_query(query_prefix: opts[:query_prefix])
  end

  def build_schema_query(queryable, opts) when is_atom(queryable) do
    queryable
    |> build_query_from(schema_prefix: opts[:schema_prefix])
    |> build_schema_query(query_prefix: opts[:query_prefix])
  end

  def build_schema_query(query, opts) do
    case opts[:query_prefix] do
      nil -> query
      query_prefix -> Query.put_query_prefix(query, query_prefix)
    end
  end
end
