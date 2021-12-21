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
        ComparisonFilter.build(query, filter_field, val)

      filter_field in schema.__schema__(:associations) ->
        binding_alias = :"ecto_shorts_#{filter_field}"

        query = Ecto.Query.join(
          query,
          :inner,
          [scm],
          assoc in assoc(scm, ^filter_field)
        )

        query = %{query |
          aliases: add_relational_alias(query, binding_alias),
          joins: add_join_alias(query, filter_field, binding_alias)
        }

        ComparisonFilter.build_relational(query, binding_alias, val)

      true ->
        Logger.debug("[EctoShorts] #{Atom.to_string(filter_field)} is not a field for #{schema.__schema__(:source)} where filter")

        query
    end
  end

  defp add_relational_alias(query, new_alias) do
    if query.aliases[new_alias] do
      raise ArgumentError, message: "already defined #{new_alias} as an alias within query #{inspect query}"
    else
      # Here we need to put the size of current aliases plus one to indicate the next value
      Map.put(query.aliases, new_alias, map_size(query.aliases) + 1)
    end
  end

  defp add_join_alias(query, filter_field, binding_alias) do
    Enum.map(query.joins, fn join ->
      if elem(join.assoc, 1) === filter_field do
        %{join | as: binding_alias}
      else
        join
      end
    end)
  end
end
