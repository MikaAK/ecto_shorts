defmodule EctoShorts.CommonFilters.UpdateExpr do
  @moduledoc since: "3.0.0"
  @moduledoc false

  alias EctoShorts.CommonSchema
  alias EctoShorts.LogUtils
  alias EctoShorts.Types

  @logger_prefix "EctoShorts.CommonFilters.UpdateExpr"

  @update_operators [:set, :inc, :push, :pull]

  @doc false
  def build_update_operations(source, params, opts \\ [])

  def build_update_operations(source, params, opts)
      when is_map(params) and not is_struct(params) do
    build_update_operations(source, Map.to_list(params), opts)
  end

  def build_update_operations(source, params, opts) when is_list(params) do
    params
    |> filter_update_fields(source, opts)
    |> Enum.reduce([], fn {key, value}, acc ->
      normalize_update_value(source, key, value, acc)
    end)
  end

  def build_update_operations(_source, params, _opts) do
    LogUtils.warning(
      @logger_prefix,
      "Expected params to be a map or list, got #{inspect(params)}"
    )

    []
  end

  @doc false
  def build_update_expr(_source, %Ecto.Query.DynamicExpr{} = expr), do: expr

  def build_update_expr(source, params) when is_map(params) and not is_struct(params) do
    build_update_expr(source, Map.to_list(params))
  end

  def build_update_expr(source, params) when is_list(params) do
    if Keyword.keyword?(params) and Enum.all?(params, &query_update_operator_entry?/1) do
      Enum.map(params, fn {op, values} ->
        {op, cast_query_update_values(source, op, values)}
      end)
    else
      params
    end
  end

  def build_update_expr(_source, params) do
    LogUtils.warning(
      @logger_prefix,
      "Expected params to be a map or list, got #{inspect(params)}"
    )

    params
  end

  defp filter_update_fields(params, nil, _opts), do: params

  defp filter_update_fields(params, schema, opts) do
    query_fields = CommonSchema.get_query_fields(opts, schema)
    Enum.filter(params, fn {key, _value} -> key in query_fields end)
  end

  defp normalize_update_value(source, key, value, acc) do
    if is_list(value) and Enum.all?(value, &match?({op, _val} when op in @update_operators, &1)) do
      Enum.reduce(value, acc, fn entry, inner_acc ->
        reduce_update(source, key, entry, inner_acc)
      end)
    else
      reduce_update(source, key, value, acc)
    end
  end

  defp reduce_update(source, key, {op, value}, acc) when op in [:pull, :push] do
    case validate_field_type_of_array(source, key) do
      :ok ->
        element_type = array_inner_type(source, key)

        value
        |> List.wrap()
        |> Enum.reduce(acc, fn item, inner_acc ->
          [{op, key, Types.cast(element_type, item)} | inner_acc]
        end)

      {:error, actual_type} ->
        raise ArgumentError,
              """
              The field `#{inspect(key)}` on schema `#{inspect(source)}` is not a type of `:array`
              and cannot be used with the `Ecto.Query` update operator `#{inspect(op)}`.

              actual type:
              #{inspect(actual_type)}
              """
    end
  end

  defp reduce_update(source, key, {:inc, value}, acc) do
    case validate_field_type_of_int(source, key) do
      :ok ->
        value = Types.cast(:integer, value)

        if is_integer(value) do
          [{:inc, key, value} | acc]
        else
          raise ArgumentError,
                "Expected value for key `#{inspect(key)}` to be an integer, got: #{inspect(value)}"
        end

      {:error, actual_type} ->
        raise ArgumentError,
              """
              The field `#{inspect(key)}` on schema `#{inspect(source)}` is not a type of `:integer`
              and cannot be used with the `Ecto.Query` update operator `:inc`.

              actual type:
              #{inspect(actual_type)}
              """
    end
  end

  defp reduce_update(source, key, {:set, value}, acc) do
    [{:set, key, cast_field_value(source, key, value)} | acc]
  end

  defp reduce_update(source, key, value, acc) do
    [{:set, key, cast_field_value(source, key, value)} | acc]
  end

  defp cast_query_update_values(source, op, values)
       when is_map(values) and not is_struct(values) do
    cast_query_update_values(source, op, Map.to_list(values))
  end

  defp cast_query_update_values(source, :set, values) when is_list(values) do
    if Keyword.keyword?(values) do
      Enum.map(values, fn {key, value} -> {key, cast_field_value(source, key, value)} end)
    else
      values
    end
  end

  defp cast_query_update_values(_source, :inc, values) when is_list(values) do
    if Keyword.keyword?(values) do
      Enum.map(values, fn {key, value} -> {key, Types.cast(:integer, value)} end)
    else
      values
    end
  end

  defp cast_query_update_values(source, op, values)
       when op in [:push, :pull] and is_list(values) do
    if Keyword.keyword?(values) do
      Enum.map(values, fn {key, value} ->
        case array_inner_type(source, key) do
          nil -> {key, value}
          inner_type -> {key, Types.cast(inner_type, value)}
        end
      end)
    else
      values
    end
  end

  defp cast_query_update_values(_source, _op, values), do: values

  defp cast_field_value(nil, _key, value), do: value

  defp cast_field_value(source, key, value) do
    source
    |> CommonSchema.get_schema_reflection(:type, key)
    |> Types.cast(value)
  end

  defp validate_field_type_of_int(nil, _key), do: :ok

  defp validate_field_type_of_int(schema, key) do
    case schema.__schema__(:type, key) do
      :integer -> :ok
      val -> {:error, val}
    end
  end

  defp validate_field_type_of_array(nil, _key), do: :ok

  defp validate_field_type_of_array(schema, key) do
    case schema.__schema__(:type, key) do
      {:array, _} -> :ok
      val -> {:error, val}
    end
  end

  defp array_inner_type(nil, _key), do: nil

  defp array_inner_type(source, key) do
    case CommonSchema.get_schema_reflection(source, :type, key) do
      {:array, inner_type} -> inner_type
      _ -> nil
    end
  end

  defp query_update_operator_entry?({op, _values}), do: op in @update_operators
end
