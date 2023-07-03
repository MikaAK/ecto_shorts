defmodule EctoShorts.QueryBuilder.Schema do
  @moduledoc """
  This module contains query building parts for schemas themselves,
  when passed a query it can pull the schema from it and attempt
  to filter on any natural field
  """

  require Logger
  require Ecto.Query

  alias EctoShorts.QueryBuilder
  alias EctoShorts.QueryBuilder.Schema.ComparisonFilter

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
        %{queryable: relational_schema} = schema.__schema__(:association, filter_field)
        create_schema_assocation_filter(query, filter_field, val, schema, relational_schema)
      true ->
        Logger.debug("[EctoShorts] #{Atom.to_string(filter_field)} is neither a field nor has a valid association for #{schema.__schema__(:source)} where filter")

        query
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

  defp create_schema_assocation_filter(_query, filter_field, _val, schema, nil) do
    raise ArgumentError, message: "#{Atom.to_string(filter_field)} does not have an associated schema for #{schema.__schema__(:source)}"
  end

  defp create_schema_assocation_filter(query, filter_field, val, _schema, relational_schema) do
    binding_alias = :"ecto_shorts_#{filter_field}"

    query = Ecto.Query.join(
      query,
      :inner,
      [scm],
      assoc in assoc(scm, ^filter_field)
    )

    query = %{query |
      aliases: add_relational_alias(query, binding_alias),
      joins: add_join_alias(query.joins, filter_field, binding_alias)
    }

    ComparisonFilter.build_relational(query, binding_alias, val, relational_schema)
  end

  defp add_relational_alias(query, new_alias) do
    if query.aliases[new_alias] do
      raise ArgumentError, message: "already defined #{new_alias} as an alias within query #{inspect query}"
    else
      # Here we need to put the size of current aliases plus one to indicate the next value
      Map.put(query.aliases, new_alias, map_size(query.aliases) + 1)
    end
  end

  defp add_join_alias(joins, filter_field, binding_alias) do
    Enum.map(joins, fn join ->
      if elem(join.assoc, 1) === filter_field do
        %{join | as: binding_alias}
      else
        join
      end
    end)
  end
end
