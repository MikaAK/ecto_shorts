defmodule EctoShorts.CommonFilters.SetComparison do
  @moduledoc false

  alias EctoShorts.CommonFilters
  alias EctoShorts.CommonFilters.Select
  alias EctoShorts.CommonSchema
  alias EctoShorts.Logger

  @logger_prefix "EctoShorts.CommonFilters.SetComparison"

  def build_quantified_query(outer_key, params, opts)
      when is_map(params) and not is_struct(params) do
    build_quantified_query(outer_key, Map.to_list(params), opts)
  end

  def build_quantified_query(outer_key, params, opts) do
    if Keyword.keyword?(params) do
      source = Keyword.fetch!(params, :from)
      where_params = Keyword.get(params, :where, [])

      select_term =
        quantified_select_field(source, Keyword.get(params, :select, outer_key), outer_key, opts)

      inner_query = CommonFilters.convert_params_to_filter(source, where_params, opts)

      Select.build_query(:select, source, inner_query, {:as, nil}, select_term, opts)
    else
      Logger.warning(
        @logger_prefix,
        "Expected a map or keyword list, got: #{inspect(params)}"
      )

      params
    end
  end

  defp quantified_select_field(_source, field_name, _outer_key, _opts) when is_atom(field_name),
    do: field_name

  defp quantified_select_field(source, field_name, outer_key, opts) when is_binary(field_name) do
    normalize_field_name(source, field_name, opts) || outer_key
  end

  defp quantified_select_field(source, field_name, outer_key, opts)
       when is_map(field_name) and not is_struct(field_name) do
    quantified_select_field(source, Map.to_list(field_name), outer_key, opts)
  end

  defp quantified_select_field(source, field_name, outer_key, opts) when is_list(field_name) do
    if Keyword.keyword?(field_name) do
      quantified_select_field(source, Keyword.fetch!(field_name, :field), outer_key, opts)
    else
      field_name
    end
  end

  defp normalize_field_name(_source, field_name, _opts) when is_atom(field_name), do: field_name

  defp normalize_field_name(source, field_name, opts) when is_binary(field_name) do
    case (source !== nil && CommonSchema.get_schema(source) !== nil &&
            CommonSchema.get_schema_reflection(source, :fields)) || nil do
      fields when is_list(fields) ->
        string_fields = MapSet.new(fields, &Atom.to_string/1)

        if MapSet.member?(string_fields, field_name) do
          String.to_existing_atom(field_name)
        else
          Logger.warning(
            @logger_prefix,
            "Field \"#{field_name}\" does not exist on schema #{inspect(CommonSchema.get_schema(source))}, skipping field reference"
          )

          nil
        end

      _ ->
        allowed_keys = opts[:allowed_keys]

        if allowed_keys do
          allowed_set = MapSet.new(allowed_keys)

          if MapSet.member?(allowed_set, field_name) do
            String.to_atom(field_name)
          else
            Logger.warning(
              @logger_prefix,
              "Field \"#{field_name}\" is not in the :allowed_keys list, skipping field reference"
            )

            nil
          end
        else
          try do
            String.to_existing_atom(field_name)
          rescue
            ArgumentError ->
              Logger.warning(
                @logger_prefix,
                "Field \"#{field_name}\" could not be resolved to an existing atom, skipping field reference"
              )

              nil
          end
        end
    end
  end
end
