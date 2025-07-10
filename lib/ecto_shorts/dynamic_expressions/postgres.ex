defmodule EctoShorts.DynamicExpressions.Postgres do
  @moduledoc since: "2.5.0"
  @moduledoc """
  Build dynamic `where` and `or_where` filters for Postgres without
  writing raw `Ecto.Query` expressions.

  This module makes it easier to add dynamic filters to your Ecto
  queries, especially when the filters come from user input or need
  to change at runtime.

  Instead of writing out each condition manually, you can pass in a
  map or keyword list of filters. It handles building the right
  expressions for each field based on its type—so you don’t need to
  worry about whether a field is a string, number, or array.
  """

  alias EctoShorts.{
    CommonQueryAPI,
    DynamicExpressions.Postgres.Array,
    DynamicExpressions.Postgres.Field,
    SchemaHelpers
  }

  @behaviour EctoShorts.DynamicExpression

  @type schema :: Ecto.Queryable.t()
  @type dynamic_expr :: %Ecto.Query.DynamicExpr{}
  @type maybe_dynamic_expr :: dynamic_expr() | nil
  @type binding_alias :: atom() | nil

  @type condition :: :and | :or

  @type key :: atom()
  @type value :: any()
  @type operator :: any()
  @type params :: map()

  @sql_string_match_operators ~w(like ilike)a
  @symbolic_comparison_operators ~w(=~ == != < > <= >=)a
  @named_comparison_operator_aliases ~w(re eq not lt gt lte gte)a

  @operators @sql_string_match_operators ++
               @symbolic_comparison_operators ++ @named_comparison_operator_aliases

  @doc false
  def operators, do: @operators

  @impl EctoShorts.DynamicExpression
  @doc """
  Builds a dynamic expression for a single filter condition
  using the given field, operator, and value.

  This function is the core of dynamic filter generation.
  It inspects the field type in the schema to determine
  whether to apply a standard field condition or handle it
  as an array-based condition.

  Depending on whether the field is a normal scalar or an
  array, it delegates to the appropriate module (`Field` or
  `Array`) and then merges the resulting expression into the
  provided dynamic expression.

  ## Parameters

    * `schema` – the Ecto schema module used for field introspection.
    * `dyn` – the existing dynamic expression (or `nil`) to be merged into.
    * `binding_alias` – an optional binding alias for use in the dynamic clause.
    * `condition` – the logical operator used to combine expressions (`:and` or `:or`).
    * `key` – the field name being filtered on.
    * `value` – The value used for the operation, typically a tuple of `{operator, value}`
      representing the operator (e.g. `:==`, `:ilike`, `:in`) and its value.

  ## Examples

      iex> EctoShorts.DynamicExpressions.Postgres.build_dynamic(nil, :binding_name, :and, EctoShorts.Schemas.Post, :title, {:==, "Hello"})

      iex> EctoShorts.DynamicExpressions.Postgres.build_dynamic(nil, :binding_name, :or, EctoShorts.Schemas.Post, :tags, {:==, ["elixir", "ecto"]})

  """
  def build_dynamic(
        dyn,
        binding_alias,
        condition,
        source,
        key,
        {operator, value}
      )
      when operator in @operators do
    if SchemaHelpers.source_has_schema?(source) and schema_field_type_array?(source, key) do
      if list?(value) do
        CommonQueryAPI.merge_dynamic(
          dyn,
          condition,
          Array.build_dynamic(binding_alias, key, operator, value)
        )
      else
        CommonQueryAPI.merge_dynamic(
          dyn,
          condition,
          Array.build_dynamic(binding_alias, value, operator, key)
        )
      end
    else
      CommonQueryAPI.merge_dynamic(
        dyn,
        condition,
        Field.build_dynamic(binding_alias, key, operator, value)
      )
    end
  end

  def build_dynamic(
        dyn,
        binding_alias,
        condition,
        source,
        key,
        value
      ) do
    build_dynamic(
      dyn,
      binding_alias,
      condition,
      source,
      key,
      {:==, value}
    )
  end

  defp list?({_, value}) when is_list(value), do: true
  defp list?(value) when is_list(value), do: true
  defp list?(_), do: false

  defp schema_field_type_array?({_source, schema}, key) do
    schema_field_type_array?(schema, key)
  end

  defp schema_field_type_array?(schema, key) do
    case schema.__schema__(:type, key) do
      {:array, _} -> true
      _ -> false
    end
  end
end
