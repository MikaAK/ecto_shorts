defmodule EctoShorts.QueryBuilder.Schema do
  @moduledoc """
  This module contains query building parts for schemas themselves,
  when passed a query it can pull the schema from it and attempt
  to filter on any natural field
  """


  import Logger, only: [debug: 1]

  import Ecto.Query, only: [where: 3]

  alias EctoShorts.QueryBuilder

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
    if filter_field in schema.__schema__(:fields) do
      create_schema_field_filter(query, filter_field, val)
    else
      debug "create_schema_filter: #{Atom.to_string(filter_field)} is not a field for #{schema.__schema__(:source)} where filter"

      query
    end
  end

  defp create_schema_field_filter(query, filter_field, val) when is_list(val) do
    where(query, [scm], field(scm, ^filter_field) in ^val)
  end

  defp create_schema_field_filter(query, filter_field, %NaiveDateTime{} = val) do
    where(query, [scm], field(scm, ^filter_field) == ^val)
  end

  defp create_schema_field_filter(query, filter_field, %DateTime{} = val) do
    where(query, [scm], field(scm, ^filter_field) == ^val)
  end

  defp create_schema_field_filter(query, filter_field, filters) when is_map(filters) do
    Enum.reduce(filters, query, fn ({filter_type, value}, query_acc) ->
      create_schema_field_comparison_filter(query_acc, filter_field, filter_type, value)
    end)
  end

  defp create_schema_field_filter(_query, _filter_field, nil) do
    raise ArgumentError, message: "comparison with nil is forbidden as it is unsafe. If you want to check if a value is nil, use %{==: nil} or %{!=: nil} instead"
  end

  defp create_schema_field_filter(query, filter_field, val) do
    where(query, [scm], field(scm, ^filter_field) == ^val)
  end

  defp create_schema_field_comparison_filter(query, filter_field, :==, nil) do
    where(query, [scm], is_nil(field(scm, ^filter_field)))
  end

  defp create_schema_field_comparison_filter(query, filter_field, :!=, nil) do
    where(query, [scm], not is_nil(field(scm, ^filter_field)))
  end

  defp create_schema_field_comparison_filter(query, filter_field, :gt, val) do
    where(query, [scm], field(scm, ^filter_field) > ^val)
  end

  defp create_schema_field_comparison_filter(query, filter_field, :lt, val) do
    where(query, [scm], field(scm, ^filter_field) < ^val)
  end

  defp create_schema_field_comparison_filter(query, filter_field, :gte, val) do
    where(query, [scm], field(scm, ^filter_field) >= ^val)
  end

  defp create_schema_field_comparison_filter(query, filter_field, :lte, val) do
    where(query, [scm], field(scm, ^filter_field) <= ^val)
  end

  defp create_schema_field_comparison_filter(query, filter_field, :like, val) do
    search_query = "%#{val}%"

    where(query, [scm], like(field(scm, ^filter_field), ^search_query))
  end

  defp create_schema_field_comparison_filter(query, filter_field, :ilike, val) do
    search_query = "%#{val}%"

    where(query, [scm], ilike(field(scm, ^filter_field), ^search_query))
  end
end
