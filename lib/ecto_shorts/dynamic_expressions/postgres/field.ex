defmodule EctoShorts.DynamicExpressions.Postgres.Field do
  @moduledoc since: "2.5.0"
  @moduledoc """
  Provides dynamic filter expressions for scalar fields in Postgres.

  This module builds `Ecto.Query.dynamic/2` expressions for a wide
  range of field-level operators, including equality, inequality,
  pattern matching, comparison, and case transformations.

  It's designed to be used internally by dynamic filtering modules
  to simplify runtime filter generation based on user-provided or
  derived parameters.

  All expressions are safe for composition in dynamic queries and
  handle optional query binding aliases.

  ## Supported operators

    * `:==`, `:!=` — for equality and inequality
    * `:<`, `:<=`, `:>`, `:>=` — for comparison
    * `:like`, `:ilike`, `:=~` — for pattern matching
    * Special support for case-based comparison: `{:lower, val}`, `{:upper, val}`
    * List values: translated to `IN (...)` or `NOT IN (...)`
    * `nil` values: translated to `IS NULL` or `IS NOT NULL`

  ## Example Usage

      # field == value
      iex> EctoShorts.DynamicExpressions.Postgres.Field.create_dynamic(:binding_name, :title, :==, "Hello")

      # field ILIKE '%value%'
      iex> EctoShorts.DynamicExpressions.Postgres.Field.create_dynamic(:binding_name, :title, :ilike, "hello")

      # field IN list
      iex> EctoShorts.DynamicExpressions.Postgres.Field.create_dynamic(:binding_name, :id, :==, [1, 2, 3])

      # field IS NOT NULL
      iex> EctoShorts.DynamicExpressions.Postgres.Field.create_dynamic(:binding_name, :deleted_at, :!=, nil)

  """

  alias Ecto.Query

  require Ecto.Query

  @type dynamic_expr :: Ecto.Query.dynamic_expr()
  @type binding_alias :: atom()

  @type operator :: atom()

  @doc """
  Builds a dynamic query expression for a single scalar
  field using a given operator and value.

  Supports conditional behavior depending on the value type
  (e.g., `nil`, list, case-modified), and gracefully handles
  both named bindings (`as: :alias`) and positional bindings.

  This function is typically used by higher-level dynamic
  filtering modules, like `EctoShorts.DynamicExpressions.Postgres`,
  to generate `where` and `or_where` clauses dynamically.

  ## Parameters

    * `binding_alias` — an optional atom representing the binding alias for the schema in the query (e.g., `:p`). If `nil`, uses positional binding.
    * `key` — the field name (atom) to build the expression for.
    * `operator` — the comparison operator (`:==`, `:!=`, `:<`, `:>`, `:<=`, `:>=`, `:like`, `:ilike`, `:=~`).
    * `value` — the value to compare the field against. Can be a literal, a list, `nil`, or a case-wrapped value like `{:lower, val}`.

  ## Examples

      iex> EctoShorts.DynamicExpressions.Postgres.Field.create_dynamic(:p, :title, :==, "hello")

      iex> EctoShorts.DynamicExpressions.Postgres.Field.create_dynamic(nil, :tags, :!=, nil)

      iex> EctoShorts.DynamicExpressions.Postgres.Field.create_dynamic(:post, :views, :>=, 100)

      iex> EctoShorts.DynamicExpressions.Postgres.Field.create_dynamic(:post, :title, :=~, "regex")

      iex> EctoShorts.DynamicExpressions.Postgres.Field.create_dynamic(:post, :title, :==, {:lower, "hello"})

  """
  @spec create_dynamic(binding_alias() | nil, any(), operator(), any()) :: dynamic_expr()
  def create_dynamic(binding_alias, key, :eq, value) do
    create_dynamic(binding_alias, key, :==, value)
  end

  def create_dynamic(binding_alias, key, :not, value) do
    create_dynamic(binding_alias, key, :!=, value)
  end

  def create_dynamic(binding_alias, key, :lt, value) do
    create_dynamic(binding_alias, key, :<, value)
  end

  def create_dynamic(binding_alias, key, :gt, value) do
    create_dynamic(binding_alias, key, :>, value)
  end

    def create_dynamic(binding_alias, key, :lte, value) do
    create_dynamic(binding_alias, key, :<=, value)
  end

  def create_dynamic(binding_alias, key, :gte, value) do
    create_dynamic(binding_alias, key, :>=, value)
  end

  def create_dynamic(binding_alias, key, :=~, value) do
    if binding_alias do
      Query.dynamic([{^binding_alias, q}], fragment("? ~* ?", field(q, ^key), ^value))
    else
      Query.dynamic([q], fragment("? ~* ?", field(q, ^key), ^value))
    end
  end

  def create_dynamic(binding_alias, key, :ilike, value) do
    pattern = "%#{value}%"

    if binding_alias do
      Query.dynamic([{^binding_alias, q}], ilike(field(q, ^key), ^pattern))
    else
      Query.dynamic([q], ilike(field(q, ^key), ^pattern))
    end
  end

  def create_dynamic(binding_alias, key, :like, value) do
    pattern = "%#{value}%"

    if binding_alias do
      Query.dynamic([{^binding_alias, q}], like(field(q, ^key), ^pattern))
    else
      Query.dynamic([q], like(field(q, ^key), ^pattern))
    end
  end

  def create_dynamic(binding_alias, key, :<, value) do
    if binding_alias do
      Query.dynamic([{^binding_alias, q}], field(q, ^key) < ^value)
    else
      Query.dynamic([q], field(q, ^key) < ^value)
    end
  end

  def create_dynamic(binding_alias, key, :>, value) do
    if binding_alias do
      Query.dynamic([{^binding_alias, q}], field(q, ^key) > ^value)
    else
      Query.dynamic([q], field(q, ^key) > ^value)
    end
  end

  def create_dynamic(binding_alias, key, :<=, value) do
    if binding_alias do
      Query.dynamic([{^binding_alias, q}], field(q, ^key) <= ^value)
    else
      Query.dynamic([q], field(q, ^key) <= ^value)
    end
  end

  def create_dynamic(binding_alias, key, :>=, value) do
    if binding_alias do
      Query.dynamic([{^binding_alias, q}], field(q, ^key) >= ^value)
    else
      Query.dynamic([q], field(q, ^key) >= ^value)
    end
  end

  def create_dynamic(binding_alias, key, :!=, {:lower, value}) do
    if binding_alias do
      Query.dynamic(
        [{^binding_alias, q}],
        fragment("LOWER(?)", field(q, ^key)) != ^value
      )
    else
      Query.dynamic([q], fragment("LOWER(?)", field(q, ^key)) != ^value)
    end
  end

  def create_dynamic(binding_alias, key, :!=, {:upper, value}) do
    if binding_alias do
      Query.dynamic(
        [{^binding_alias, q}],
        fragment("UPPER(?)", field(q, ^key)) != ^value
      )
    else
      Query.dynamic([q], fragment("UPPER(?)", field(q, ^key)) != ^value)
    end
  end

  def create_dynamic(binding_alias, key, :!=, nil) do
    if binding_alias do
      Query.dynamic([{^binding_alias, q}], not is_nil(field(q, ^key)))
    else
      Query.dynamic([q], not is_nil(field(q, ^key)))
    end
  end

  def create_dynamic(binding_alias, key, :!=, values) when is_list(values) do
    if binding_alias do
      Query.dynamic([{^binding_alias, q}], field(q, ^key) not in ^values)
    else
      Query.dynamic([q], field(q, ^key) not in ^values)
    end
  end

  def create_dynamic(binding_alias, key, :!=, value) do
    if binding_alias do
      Query.dynamic([{^binding_alias, q}], field(q, ^key) != ^value)
    else
      Query.dynamic([q], field(q, ^key) != ^value)
    end
  end

  def create_dynamic(binding_alias, key, :==, {:lower, value}) do
    if binding_alias do
      Query.dynamic(
        [{^binding_alias, q}],
        fragment("LOWER(?)", field(q, ^key)) == ^value
      )
    else
      Query.dynamic([q], fragment("LOWER(?)", field(q, ^key)) == ^value)
    end
  end

  def create_dynamic(binding_alias, key, :==, {:upper, value}) do
    if binding_alias do
      Query.dynamic(
        [{^binding_alias, q}],
        fragment("UPPER(?)", field(q, ^key)) == ^value
      )
    else
      Query.dynamic([q], fragment("UPPER(?)", field(q, ^key)) == ^value)
    end
  end

  def create_dynamic(binding_alias, key, :==, nil) do
    if binding_alias do
      Query.dynamic([{^binding_alias, q}], is_nil(field(q, ^key)))
    else
      Query.dynamic([q], is_nil(field(q, ^key)))
    end
  end

  def create_dynamic(binding_alias, key, :==, values) when is_list(values) do
    if binding_alias do
      Query.dynamic([{^binding_alias, q}], field(q, ^key) in ^values)
    else
      Query.dynamic([q], field(q, ^key) in ^values)
    end
  end

  def create_dynamic(binding_alias, key, :==, value) do
    if binding_alias do
      Query.dynamic([{^binding_alias, q}], field(q, ^key) == ^value)
    else
      Query.dynamic([q], field(q, ^key) == ^value)
    end
  end
end
