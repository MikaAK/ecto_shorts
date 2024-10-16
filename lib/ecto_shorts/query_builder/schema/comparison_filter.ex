defmodule EctoShorts.QueryBuilder.Schema.ComparisonFilter do
  @moduledoc false

  # Unfortunately because of how the bindings work we can't pass in two separate
  # values which then forces us to define two separate versions

  require Logger

  alias Ecto.Query
  require Ecto.Query

  # Non relational fields
  def build(query, filter_key, filter_value) when is_list(filter_value) do
    Query.where(query, [scm], field(scm, ^filter_key) in ^filter_value)
  end

  def build(query, filter_key, %NaiveDateTime{} = filter_value) do
    Query.where(query, [scm], field(scm, ^filter_key) == ^filter_value)
  end

  def build(query, filter_key, %DateTime{} = filter_value) do
    Query.where(query, [scm], field(scm, ^filter_key) == ^filter_value)
  end

  def build(_query, _filter_key, nil) do
    raise ArgumentError, message: "comparison with nil is forbidden as it is unsafe. If you want to check if a value is nil, use %{==: nil} or %{!=: nil} instead"
  end

  def build(query, filter_key, filters) when is_map(filters) do
    Enum.reduce(filters, query, fn ({filter_type, value}, query) ->
      build_schema_field_filters(query, nil, filter_key, filter_type, value)
    end)
  end

  def build(query, filter_key, {:lower, filter_value}) do
    Query.where(query, [scm], fragment("lower(?)", field(scm, ^filter_key)) == ^filter_value)
  end

  def build(query, filter_key, {:upper, filter_value}) do
    Query.where(query, [scm], fragment("upper(?)", field(scm, ^filter_key)) == ^filter_value)
  end

  def build(query, filter_key, filter_value) do
    Query.where(query, [scm], field(scm, ^filter_key) == ^filter_value)
  end

  def build_array(query, filter_key, filter_value) when is_list(filter_value) do
    Query.where(query, [scm], field(scm, ^filter_key) == ^filter_value)
  end

  def build_array(query, filter_key, filters) when is_map(filters) do
    build(query, filter_key, filters)
  end

  def build_array(query, filter_key, filter_value) do
    Query.where(query, [scm], ^filter_value in field(scm, ^filter_key))
  end

  defp build_schema_field_filters(query, binding_alias, filter_key, :==, nil) do
    if binding_alias do
      Query.where(query, [{^binding_alias, scm}], is_nil(field(scm, ^filter_key)))
    else
      Query.where(query, [scm], is_nil(field(scm, ^filter_key)))
    end
  end

  defp build_schema_field_filters(query, binding_alias, filter_key, :!=, nil) do
    if binding_alias do
      Query.where(query, [{^binding_alias, scm}], not is_nil(field(scm, ^filter_key)))
    else
      Query.where(query, [scm], not is_nil(field(scm, ^filter_key)))
    end
  end

  defp build_schema_field_filters(query, binding_alias, filter_key, :!=, filter_value) when is_list(filter_value) do
    if binding_alias do
      Query.where(query, [{^binding_alias, scm}], field(scm, ^filter_key) not in ^filter_value)
    else
      Query.where(query, [scm], field(scm, ^filter_key) not in ^filter_value)
    end
  end

  defp build_schema_field_filters(query, binding_alias, filter_key, :!=, {:lower, filter_value}) do
    if binding_alias do
      Query.where(query, [{^binding_alias, scm}], fragment("lower(?)", field(scm, ^filter_key)) != ^filter_value)
    else
      Query.where(query, [scm], fragment("lower(?)", field(scm, ^filter_key)) != ^filter_value)
    end
  end

  defp build_schema_field_filters(query, binding_alias, filter_key, :!=, {:upper, filter_value}) do
    if binding_alias do
      Query.where(query, [{^binding_alias, scm}], fragment("upper(?)", field(scm, ^filter_key)) != ^filter_value)
    else
      Query.where(query, [scm], fragment("upper(?)", field(scm, ^filter_key)) != ^filter_value)
    end
  end

  defp build_schema_field_filters(query, binding_alias, filter_key, :!=, filter_value) do
    if binding_alias do
      Query.where(query, [{^binding_alias, scm}], field(scm, ^filter_key) != ^filter_value)
    else
      Query.where(query, [scm], field(scm, ^filter_key) != ^filter_value)
    end
  end

  defp build_schema_field_filters(query, binding_alias, filter_key, :gt, filter_value) do
    if binding_alias do
      Query.where(query, [{^binding_alias, scm}], field(scm, ^filter_key) > ^filter_value)
    else
      Query.where(query, [scm], field(scm, ^filter_key) > ^filter_value)
    end
  end

  defp build_schema_field_filters(query, binding_alias, filter_key, :lt, filter_value) do
    if binding_alias do
      Query.where(query, [{^binding_alias, scm}], field(scm, ^filter_key) < ^filter_value)
    else
      Query.where(query, [scm], field(scm, ^filter_key) < ^filter_value)
    end
  end

  defp build_schema_field_filters(query, binding_alias, filter_key, :gte, filter_value) do
    if binding_alias do
      Query.where(query, [{^binding_alias, scm}], field(scm, ^filter_key) >= ^filter_value)
    else
      Query.where(query, [scm], field(scm, ^filter_key) >= ^filter_value)
    end
  end

  defp build_schema_field_filters(query, binding_alias, filter_key, :lte, filter_value) do
    if binding_alias do
      Query.where(query, [{^binding_alias, scm}], field(scm, ^filter_key) <= ^filter_value)
    else
      Query.where(query, [scm], field(scm, ^filter_key) <= ^filter_value)
    end
  end

  defp build_schema_field_filters(query, binding_alias, filter_key, :like, filter_value) do
    search_query = "%#{filter_value}%"

    if binding_alias do
      Query.where(query, [{^binding_alias, scm}], like(field(scm, ^filter_key), ^search_query))
    else
      Query.where(query, [scm], like(field(scm, ^filter_key), ^search_query))
    end
  end

  defp build_schema_field_filters(query, binding_alias, filter_key, :ilike, filter_value) do
    search_query = "%#{filter_value}%"

    if binding_alias do
      Query.where(query, [{^binding_alias, scm}], ilike(field(scm, ^filter_key), ^search_query))
    else
      Query.where(query, [scm], ilike(field(scm, ^filter_key), ^search_query))
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

  defp build_relational_filter(query, binding_alias, filter_key, filter_value, _relational_schema) when is_list(filter_value) do
    Query.where(query, [{^binding_alias, scm}], field(scm, ^filter_key) in ^filter_value)
  end

  defp build_relational_filter(query, binding_alias, filter_key, %NaiveDateTime{} = filter_value, _relational_schema) do
    Query.where(query, [{^binding_alias, scm}], field(scm, ^filter_key) == ^filter_value)
  end

  defp build_relational_filter(query, binding_alias, filter_key, %DateTime{} = filter_value, _relational_schema) do
    Query.where(query, [{^binding_alias, scm}], field(scm, ^filter_key) == ^filter_value)
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

        build_relational_association_filter(
          query,
          binding_alias,
          field_key,
          filters,
          relational_schema,
          sub_relational_schema
        )

      true ->
        Logger.debug("[EctoShorts] #{Atom.to_string(field_key)} is neither a field nor has a valid association for #{relational_schema.__schema__(:source)} where filter")

        query
    end
  end

  defp build_relational_filter(query, binding_alias, filter_key, filter_value, _relational_schema) do
    Query.where(query, [{^binding_alias, scm}], field(scm, ^filter_key) == ^filter_value)
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
      build_schema_field_filters(query, binding_alias, field_key, filter_type, value)
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
