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

  @type schema_module :: Ecto.Queryable.t()
  @type schema_source :: binary()
  @type dynamic_expr :: %Ecto.Query.DynamicExpr{}
  @type maybe_dynamic_expr :: dynamic_expr() | nil
  @type binding_alias :: atom()

  @type condition :: :and | :or

  @type key :: atom()
  @type value :: any()
  @type operator :: any()
  @type params :: map()

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

    * `schema_module` – the Ecto schema module used for field introspection.
    * `dyn` – the existing dynamic expression (or `nil`) to be merged into.
    * `binding_alias` – an optional binding alias for use in the dynamic clause.
    * `condition` – the logical operator used to combine expressions (`:and` or `:or`).
    * `key` – the field name being filtered on.
    * `value` – The value used for the operation, typically a tuple of `{operator, value}`
      representing the operator (e.g. `:==`, `:ilike`, `:in`) and its value.

  ## Examples

      iex> EctoShorts.DynamicExpressions.Postgres.create_dynamic(EctoShorts.Schema.Post, nil, :binding_name, :and, :title, {:==, "Hello"})

      iex> EctoShorts.DynamicExpressions.Postgres.create_dynamic(EctoShorts.Schema.Post, nil, :binding_name, :or, :tags, {:==, ["elixir", "ecto"]})

  """
  @spec create_dynamic(
          schema_module(),
          maybe_dynamic_expr(),
          binding_alias() | nil,
          condition(),
          key(),
          value()
        ) :: dynamic_expr()
  def create_dynamic(
        schema_module,
        dyn,
        binding_alias,
        condition,
        key,
        {operator, value}
      ) do
    cond do
      SchemaHelpers.field_type_of_array?(schema_module, key) and is_list(value) ->
        CommonQueryAPI.merge_dynamic(
          dyn,
          condition,
          Array.create_dynamic(binding_alias, key, operator, value)
        )

      SchemaHelpers.field_type_of_array?(schema_module, key) ->
        CommonQueryAPI.merge_dynamic(
          dyn,
          condition,
          Array.create_dynamic(binding_alias, value, operator, key)
        )

      true ->
        CommonQueryAPI.merge_dynamic(
          dyn,
          condition,
          Field.create_dynamic(binding_alias, key, operator, value)
        )
    end
  end

  def create_dynamic(
        dyn,
        binding_alias,
        condition,
        schema_module,
        key,
        value
      ) do
    create_dynamic(
      dyn,
      binding_alias,
      condition,
      schema_module,
      key,
      {:==, value}
    )
  end
end
