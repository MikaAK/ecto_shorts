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
    Enum.reduce(filters, query, fn ({filter_type, value}, query) ->
      convert_to_field_comparison_filter(query, nil, filter_field, filter_type, value)
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

  defp convert_to_field_comparison_filter(query, binding_alias, filter_field, :==, nil) do
    if binding_alias do
      where(query, [{^binding_alias, scm}], is_nil(field(scm, ^filter_field)))
    else
      where(query, [scm], is_nil(field(scm, ^filter_field)))
    end
  end

  defp convert_to_field_comparison_filter(query, binding_alias, filter_field, :!=, nil) do
    if binding_alias do
      where(query, [{^binding_alias, scm}], not is_nil(field(scm, ^filter_field)))
    else
      where(query, [scm], not is_nil(field(scm, ^filter_field)))
    end
  end

  defp convert_to_field_comparison_filter(query, binding_alias, filter_field, :!=, val) when is_list(val) do
    if binding_alias do
      where(query, [{^binding_alias, scm}], field(scm, ^filter_field) not in ^val)
    else
      where(query, [scm], field(scm, ^filter_field) not in ^val)
    end
  end

  defp convert_to_field_comparison_filter(query, binding_alias, filter_field, :!=, {:lower, val}) do
    if binding_alias do
      where(query, [{^binding_alias, scm}], fragment("lower(?)", field(scm, ^filter_field)) != ^val)
    else
      where(query, [scm], fragment("lower(?)", field(scm, ^filter_field)) != ^val)
    end
  end

  defp convert_to_field_comparison_filter(query, binding_alias, filter_field, :!=, {:upper, val}) do
    if binding_alias do
      where(query, [{^binding_alias, scm}], fragment("upper(?)", field(scm, ^filter_field)) != ^val)
    else
      where(query, [scm], fragment("upper(?)", field(scm, ^filter_field)) != ^val)
    end
  end

  defp convert_to_field_comparison_filter(query, binding_alias, filter_field, :!=, val) do
    if binding_alias do
      where(query, [{^binding_alias, scm}], field(scm, ^filter_field) != ^val)
    else
      where(query, [scm], field(scm, ^filter_field) != ^val)
    end
  end

  defp convert_to_field_comparison_filter(query, binding_alias, filter_field, :gt, val) do
    if binding_alias do
      where(query, [{^binding_alias, scm}], field(scm, ^filter_field) > ^val)
    else
      where(query, [scm], field(scm, ^filter_field) > ^val)
    end
  end

  defp convert_to_field_comparison_filter(query, binding_alias, filter_field, :lt, val) do
    if binding_alias do
      where(query, [{^binding_alias, scm}], field(scm, ^filter_field) < ^val)
    else
      where(query, [scm], field(scm, ^filter_field) < ^val)
    end
  end

  defp convert_to_field_comparison_filter(query, binding_alias, filter_field, :gte, val) do
    if binding_alias do
      where(query, [{^binding_alias, scm}], field(scm, ^filter_field) >= ^val)
    else
      where(query, [scm], field(scm, ^filter_field) >= ^val)
    end
  end

  defp convert_to_field_comparison_filter(query, binding_alias, filter_field, :lte, val) do
    if binding_alias do
      where(query, [{^binding_alias, scm}], field(scm, ^filter_field) <= ^val)
    else
      where(query, [scm], field(scm, ^filter_field) <= ^val)
    end
  end

  defp convert_to_field_comparison_filter(query, binding_alias, filter_field, :like, val) do
    search_query = "%#{val}%"

    if binding_alias do
      where(query, [{^binding_alias, scm}], like(field(scm, ^filter_field), ^search_query))
    else
      where(query, [scm], like(field(scm, ^filter_field), ^search_query))
    end
  end

  defp convert_to_field_comparison_filter(query, binding_alias, filter_field, :ilike, val) do
    search_query = "%#{val}%"

    case binding_alias do
      nil -> where(query, [scm], ilike(field(scm, ^filter_field), ^search_query))
      binding_alias -> where(query, [{^binding_alias, scm}], ilike(field(scm, ^filter_field), ^search_query))
    end
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
        # if the field key is a query field the filters must be
        # a map of comparison filter parameters, for example:
        # %{id: %{!=: nil}}
        build_relational_query_fields_filter(query, binding_alias, field_key, filters)

      field_key in relational_schema.__schema__(:associations) ->
        sub_relational_schema = ecto_association_queryable!(relational_schema, field_key)

        build_relational_association_filter(query, binding_alias, field_key, filters, relational_schema, sub_relational_schema)

      true ->
        Logger.debug("[EctoShorts] #{Atom.to_string(field_key)} is neither a field nor has a valid association for #{relational_schema.__schema__(:source)} where filter")

        query
    end
  end

  defp build_relational_filter(query, binding_alias, filter_field, val, _relational_schema) do
    where(query, [{^binding_alias, scm}], field(scm, ^filter_field) == ^val)
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

  defp build_relational_query_fields_filter(query, binding_alias, field_key, filters) do
    Enum.reduce(filters, query, fn ({filter_type, value}, query) ->
      convert_to_field_comparison_filter(query, binding_alias, field_key, filter_type, value)
    end)
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
end
