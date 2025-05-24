defmodule EctoShorts.DynamicExpression do
  @moduledoc since: "2.5.0"
  @moduledoc """
  Defines a behavior and interface for building dynamic Ecto query
  expressions based on the adapter in use (e.g., Postgres).

  In Ecto, the `dynamic/2` macro is used to build flexible queries where
  parts of the expression depend on input at runtime . This module provides
  an API for building these expressions for different database backends.

  You can implement the `EctoShorts.DynamicExpression` behavior in your own
  adapter module to customize how dynamic conditions are generated based
  on things like schema, field name, and value type.

  ## Example

  Suppose you want to filter a field using Postgres-specific operators
  like `ILIKE`. You could write a custom adapter like:

      defmodule MyApp.DynamicPostgresAdapter do
        @behaviour EctoShorts.DynamicExpression

        def create_dynamic(dyn, binding, condition, schema, key, {:ilike, val}) do
          case condition do
            :and -> dynamic([q], ^dyn and ilike(field(^binding, ^key), ^val))
            :or -> dynamic([q], ^dyn or ilike(field(^binding, ^key), ^val))
          end
        end

        def create_dynamic(dyn, binding, condition, schema, key, val) do
          case condition do
            :and -> dynamic([q], ^dyn and field(^binding, ^key) == ^val)
            :or -> dynamic([q], ^dyn or field(^binding, ^key) == ^val)
          end
        end
      end

  Then you can call:

      EctoShorts.DynamicExpression.create_dynamic(
        MyApp.DynamicPostgresAdapter,
        nil,
        nil,
        :and,
        :name,
        {:ilike, "john"}
      )

  This returns a dynamic expression like:

      dynamic([q], ilike(q.name, ^"john")
  """

  @type adapter :: module()
  @type schema :: Ecto.Queryable.t()
  @type dynamic_expr :: %Ecto.Query.DynamicExpr{}
  @type maybe_dynamic_expr :: dynamic_expr() | nil
  @type binding_alias :: atom() | nil
  @type condition :: :and | :or
  @type key :: atom()
  @type value :: any()

  @doc """
  Defines a callback to implement custom logic for building a dynamic query expression.

  It receives:
    - `dyn`: the current dynamic expression being built or `nil`.
    - `binding_alias`: the binding index (e.g. 0 for the main schema)
    - `schema`: the module for the schema being queried
    - `key`: the field name (e.g. `:name`)
    - `value`: the filter value (e.g. a string or a special operator like `%{ilike: "foo"}`)

  Returns an updated dynamic expression.
  """
  @callback create_dynamic(
              schema(),
              maybe_dynamic_expr(),
              binding_alias(),
              condition(),
              key(),
              value()
            ) :: dynamic_expr()

  @doc """
  Delegates to the given adapter module to build a dynamic query expression
  based on the provided schema, field, and value.

  This function acts as the main entry point for constructing `dynamic/2`
  expressions across different database backends. It relies on the adapter
  implementing the `EctoShorts.DynamicExpression` behaviour and calling
  `create_dynamic/6` internally.

  The returned expression can be used in Ecto queries with `where/3`,
  `or_where/3`, or similar macros.

  ## Parameters

    * `adapter` – A module that implements the `EctoShorts.DynamicExpression` behaviour.
    * `schema` – The Ecto schema module for the query.
    * `dyn` – The current dynamic expression (or `nil` if starting a new one).
    * `binding_alias` – The alias or index representing the query binding (e.g. `:post` or `nil`).
    * `condition` – Logical operator (`:and` or `:or`) to merge expressions.
    * `key` – The schema field to filter on.
    * `value` – The value or `{operator, value}` tuple to filter by.

  ## Examples

      iex> EctoShorts.DynamicExpression.create_dynamic(
      ...>   EctoShorts.DynamicExpressions.Postgres,
      ...>   EctoShorts.Schemas.Post,
      ...>   nil,
      ...>   :post,
      ...>   :and,
      ...>   :title,
      ...>   "example"
      ...> )

      iex> EctoShorts.DynamicExpression.create_dynamic(
      ...>   EctoShorts.DynamicExpressions.Postgres,
      ...>   EctoShorts.Schemas.Post,
      ...>   nil,
      ...>   :post,
      ...>   :and,
      ...>   :title,
      ...>   {:ilike, "example"}
      ...> )

  """
  @spec create_dynamic(
          adapter(),
          schema(),
          maybe_dynamic_expr(),
          binding_alias(),
          condition(),
          key(),
          value()
        ) :: dynamic_expr()
  def create_dynamic(
        adapter,
        schema,
        dyn,
        binding_alias,
        condition,
        key,
        value
      ) do
    adapter.create_dynamic(
      schema,
      dyn,
      binding_alias,
      condition,
      key,
      value
    )
  end
end
