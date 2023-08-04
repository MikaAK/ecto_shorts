defmodule EctoShorts.QueryBuilder.Schema.ComparisonFilter do
  @moduledoc false

  # Unfortunately because of how the bindings work we can't pass in two separate
  # values which then forces us to define two separate versions

  require Logger
  import Ecto.Query, only: [where: 3]

  # Non relational fields
  def build(query, filter_field, val) when is_list(val) do
    where(query, [scm], field(scm, ^filter_field) in ^val)
  end

  def build(query, filter_field, %NaiveDateTime{} = val) do
    where(query, [scm], field(scm, ^filter_field) == ^val)
  end

  def build(query, filter_field, %DateTime{} = val) do
    where(query, [scm], field(scm, ^filter_field) == ^val)
  end

  def build(_query, _filter_field, nil) do
    raise ArgumentError, message: "comparison with nil is forbidden as it is unsafe. If you want to check if a value is nil, use %{==: nil} or %{!=: nil} instead"
  end

  def build(query, filter_field, filters) when is_map(filters) do
    Enum.reduce(filters, query, fn ({filter_type, value}, query_acc) ->
      build_subfield_filter(query_acc, filter_field, filter_type, value)
    end)
  end

  def build(query, filter_field, {:lower, val}) do
    where(query, [scm], fragment("lower(?)", field(scm, ^filter_field)) == ^val)
  end

  def build(query, filter_field, {:upper, val}) do
    where(query, [scm], fragment("upper(?)", field(scm, ^filter_field)) == ^val)
  end

  def build(query, filter_field, val) do
    where(query, [scm], field(scm, ^filter_field) == ^val)
  end

  def build_array(query, filter_field, val) when is_list(val) do
    where(query, [scm], field(scm, ^filter_field) == ^val)
  end

  def build_array(query, filter_field, filters) when is_map(filters) do
    build(query, filter_field, filters)
  end

  def build_array(query, filter_field, val) do
    where(query, [scm], ^val in field(scm, ^filter_field))
  end

  defp build_subfield_filter(query, filter_field, :==, nil) do
    where(query, [scm], is_nil(field(scm, ^filter_field)))
  end

  defp build_subfield_filter(query, filter_field, :!=, nil) do
    where(query, [scm], not is_nil(field(scm, ^filter_field)))
  end

  defp build_subfield_filter(query, filter_field, :!=, {:lower, val}) do
    where(query, [scm], fragment("lower(?)", field(scm, ^filter_field)) != ^val)
  end

  defp build_subfield_filter(query, filter_field, :!=, {:upper, val}) do
    where(query, [scm], fragment("upper(?)", field(scm, ^filter_field)) != ^val)
  end

  defp build_subfield_filter(query, filter_field, :!=, val) do
    where(query, [scm], field(scm, ^filter_field) != ^val)
  end

  defp build_subfield_filter(query, filter_field, :gt, val) do
    where(query, [scm], field(scm, ^filter_field) > ^val)
  end

  defp build_subfield_filter(query, filter_field, :lt, val) do
    where(query, [scm], field(scm, ^filter_field) < ^val)
  end

  defp build_subfield_filter(query, filter_field, :gte, val) do
    where(query, [scm], field(scm, ^filter_field) >= ^val)
  end

  defp build_subfield_filter(query, filter_field, :lte, val) do
    where(query, [scm], field(scm, ^filter_field) <= ^val)
  end

  defp build_subfield_filter(query, filter_field, :like, val) do
    search_query = "%#{val}%"

    where(query, [scm], like(field(scm, ^filter_field), ^search_query))
  end

  defp build_subfield_filter(query, filter_field, :ilike, val) do
    search_query = "%#{val}%"

    where(query, [scm], ilike(field(scm, ^filter_field), ^search_query))
  end

  # Relational Versions

  def build_relational(_query, _binding_alias, nil) do
    raise ArgumentError, message: "comparison with nil is forbidden as it is unsafe. If you want to check if a value is nil, use %{==: nil} or %{!=: nil} instead"
  end

  def build_relational(query, binding_alias, field_filters, relational_schema) when is_map(field_filters) do
    Enum.reduce(field_filters, query, fn ({field_key, field_value}, query_acc) ->
      build_relational_filter(query_acc, binding_alias, field_key, field_value, relational_schema)
    end)
  end

  def build_relational(_query, _binding_alias, value, _relational_schema) do
    raise ArgumentError, message: "must provide a map for associations to filter on\ngiven #{inspect value}"
  end

  defp build_relational_filter(query, binding_alias, filter_field, val, _relational_schema) when is_list(val) do
    where(query, [{^binding_alias, scm}], field(scm, ^filter_field) in ^val)
  end

  defp build_relational_filter(query, binding_alias, filter_field, %NaiveDateTime{} = val, _relational_schema) do
    where(query, [{^binding_alias, scm}], field(scm, ^filter_field) == ^val)
  end

  defp build_relational_filter(query, binding_alias, filter_field, %DateTime{} = val, _relational_schema) do
    where(query, [{^binding_alias, scm}], field(scm, ^filter_field) == ^val)
  end

  defp build_relational_filter(query, binding_alias, field_key, filters, relational_schema) when is_map(filters) do
    cond do
      field_key in relational_schema.__schema__(:query_fields) ->
        build_relational_query_fields_filter(query, binding_alias, field_key, filters)
      field_key in relational_schema.__schema__(:associations) ->
        sub_relational_schema = get_associated_schema_from_field(relational_schema, field_key)
        build_relational_association_filter(query, binding_alias, field_key, filters, relational_schema, sub_relational_schema)
      true ->
        Logger.debug("[EctoShorts] #{Atom.to_string(field_key)} is neither a field nor has a valid association for #{relational_schema.__schema__(:source)} where filter")

        query
    end
  end

  defp build_relational_filter(query, binding_alias, filter_field, val, _relational_schema) do
    where(query, [{^binding_alias, scm}], field(scm, ^filter_field) == ^val)
  end

  defp get_associated_schema_from_field(schema, field_key) do
    schema.__schema__(:association, field_key).queryable
  end

  defp build_relational_query_fields_filter(query, binding_alias, field_key, filters) do
    Enum.reduce(filters, query, fn ({filter_type, value}, query_acc) ->
      build_relational_subfield_filter(query_acc, binding_alias, field_key, filter_type, value)
    end)
  end

  defp build_relational_association_filter(_query, _binding_alias, field_key, _filters, relational_schema, nil) do
    raise ArgumentError, message: "#{Atom.to_string(field_key)} does not have an associated schema for #{relational_schema.__schema__(:source)}"
  end

  defp build_relational_association_filter(query, binding_alias, field_key, filters, _relational_schema, sub_relational_schema) do
    sub_binding_alias = :"#{binding_alias}_#{field_key}"

    query
    |> Ecto.Query.with_named_binding(sub_binding_alias, fn query, sub_binding_alias ->
      Ecto.Query.join(
        query,
        :inner,
        [{^binding_alias, scm}],
        assoc in assoc(scm, ^field_key), as: ^sub_binding_alias)
    end)
    |> build_relational(sub_binding_alias, filters, sub_relational_schema)
  end

  defp build_relational_subfield_filter(query, binding_alias, filter_field, :==, nil) do
    where(query, [{^binding_alias, scm}], is_nil(field(scm, ^filter_field)))
  end

  defp build_relational_subfield_filter(query, binding_alias, filter_field, :!=, nil) do
    where(query, [{^binding_alias, scm}], not is_nil(field(scm, ^filter_field)))
  end

  defp build_relational_subfield_filter(query, binding_alias, filter_field, :gt, val) do
    where(query, [{^binding_alias, scm}], field(scm, ^filter_field) > ^val)
  end

  defp build_relational_subfield_filter(query, binding_alias, filter_field, :lt, val) do
    where(query, [{^binding_alias, scm}], field(scm, ^filter_field) < ^val)
  end

  defp build_relational_subfield_filter(query, binding_alias, filter_field, :gte, val) do
    where(query, [{^binding_alias, scm}], field(scm, ^filter_field) >= ^val)
  end

  defp build_relational_subfield_filter(query, binding_alias, filter_field, :lte, val) do
    where(query, [{^binding_alias, scm}], field(scm, ^filter_field) <= ^val)
  end

  defp build_relational_subfield_filter(query, binding_alias, filter_field, :like, val) do
    search_query = "%#{val}%"

    where(query, [{^binding_alias, scm}], like(field(scm, ^filter_field), ^search_query))
  end

  defp build_relational_subfield_filter(query, binding_alias, filter_field, :ilike, val) do
    search_query = "%#{val}%"

    where(query, [{^binding_alias, scm}], ilike(field(scm, ^filter_field), ^search_query))
  end
end
