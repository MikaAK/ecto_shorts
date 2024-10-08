defmodule EctoShorts.QueryBuilder.Schema do
  @moduledoc """
  This module contains query building parts for schemas themselves,
  when passed a query it can pull the schema from it and attempt
  to filter on any natural field
  """
  alias EctoShorts.QueryBuilder
  alias EctoShorts.QueryBuilder.Schema.ComparisonFilter

  require Logger
  require Ecto.Query

  @behaviour QueryBuilder

  @impl QueryBuilder
  def create_schema_filter({filter_field, val}, query) do
    create_schema_filter(
      {filter_field, val},
      QueryBuilder.query_schema(query),
      query
    )
  end

  def create_schema_filter({filter_field, val}, schema, query) do
    cond do
      filter_field in schema.__schema__(:query_fields) ->
        create_schema_query_field_filter(query, schema, filter_field, val)

      filter_field in schema.__schema__(:associations) ->
        relational_schema = ecto_association_queryable!(schema, filter_field)

        create_schema_assocation_filter(query, filter_field, val, schema, relational_schema)

      true ->
        Logger.debug("[EctoShorts] #{Atom.to_string(filter_field)} is neither a field nor has a valid association for #{schema.__schema__(:source)} where filter")

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

  defp create_schema_query_field_filter(query, schema, filter_field, val) do
    case schema.__schema__(:type, filter_field) do
      {:array, _} ->
        ComparisonFilter.build_array(query, schema.__schema__(:field_source, filter_field), val)

      _ ->
        ComparisonFilter.build(query, schema.__schema__(:field_source, filter_field), val)

    end
  end

  defp create_schema_assocation_filter(query, filter_field, val, _schema, relational_schema) do
    binding_alias = :"ecto_shorts_#{filter_field}"

    query
    |> Ecto.Query.with_named_binding(binding_alias, fn query, binding_alias ->
      Ecto.Query.join(
        query,
        :inner,
        [scm],
        assoc in assoc(scm, ^filter_field), as: ^binding_alias)
    end)
    |> ComparisonFilter.build_relational(binding_alias, val, relational_schema)
  end
end
