defmodule EctoShorts.QueryBuilder.Schema do
  @moduledoc """
  This module contains query building parts for schemas themselves,
  when passed a query it can pull the schema from it and attempt
  to filter on any natural field
  """
  @moduledoc since: "2.5.0"

  alias EctoShorts.{
    QueryBuilder,
    QueryHelpers
  }

  alias EctoShorts.QueryBuilder.Schema.ComparisonFilter

  alias Ecto.Query
  require Ecto.Query

  require Logger

  @type filter_key :: atom()
  @type filter_value :: any()
  @type filters :: list(atom())
  @type source :: binary()
  @type query :: Ecto.Query.t()
  @type queryable :: Ecto.Queryable.t()
  @type source_queryable :: {source(), queryable()}

  @behaviour QueryBuilder

  @impl true
  @doc """
  Implementation for `c:EctoShorts.QueryBuilder.create_schema_filter/3`.

  ### Examples

      iex> EctoShorts.QueryBuilder.Schema.create_schema_filter(EctoShorts.Support.Schemas.Post, :comments, %{id: 1})
  """
  @spec create_schema_filter(
    query :: query(),
    filter_key :: filter_key(),
    filter_value :: filter_value()
  ) :: query()
  def create_schema_filter(query, filter_key, filter_value) do
    queryable = QueryHelpers.get_queryable(query)

    create_schema_filter(queryable, query, filter_key, filter_value)
  end

  @doc """
  Builds an ecto query for the given `Ecto.Schema`.

  ### Examples

      iex> EctoShorts.QueryBuilder.Schema.create_schema_filter(
      ...>   EctoShorts.Support.Schemas.Post,
      ...>   Ecto.Query.from(EctoShorts.Support.Schemas.Post),
      ...>   :comments,
      ...>   %{id: 1}
      ...> )
  """
  @spec create_schema_filter(
    queryable :: queryable(),
    query :: query(),
    filter_key :: filter_key(),
    filter_value :: filter_value()
  ) :: query()
  def create_schema_filter(queryable, query, filter_key, filter_value) do
    cond do
      filter_key in queryable.__schema__(:query_fields) ->
        create_schema_query_field_filter(queryable, query, filter_key, filter_value)

      filter_key in queryable.__schema__(:associations) ->
        assoc_schema = ecto_association_queryable!(queryable, filter_key)

        create_schema_assocation_filter(queryable, query, filter_key, filter_value, assoc_schema)

      true ->
        Logger.debug("[EctoShorts] #{Atom.to_string(filter_key)} is neither a field nor has a valid association for #{queryable.__schema__(:source)} where filter")

        query
    end
  end

  defp ecto_association_queryable!(schema, field_key) do
    case schema.__schema__(:association, field_key) do
      %Ecto.Association.HasThrough{through: [field1, field2]} ->
        schema
        |> ecto_association_queryable!(field1)
        |> ecto_association_queryable!(field2)

      %{related: related} ->
        related

    end
  end

  defp create_schema_query_field_filter(queryable, query, filter_key, filter_value) do
    case queryable.__schema__(:type, filter_key) do
      {:array, _} ->
        ComparisonFilter.build_array(query, queryable.__schema__(:field_source, filter_key), filter_value)

      _ ->
        ComparisonFilter.build(query, queryable.__schema__(:field_source, filter_key), filter_value)

    end
  end

  defp create_schema_assocation_filter(_queryable, query, filter_key, filter_value, assoc_schema) do
    binding_alias = :"ecto_shorts_#{filter_key}"

    query
    |> Query.with_named_binding(binding_alias, fn query, binding_alias ->
      Query.join(
        query,
        :inner,
        [scm],
        assoc in assoc(scm, ^filter_key), as: ^binding_alias
      )
    end)
    |> ComparisonFilter.build_relational(binding_alias, filter_value, assoc_schema)
  end
end
