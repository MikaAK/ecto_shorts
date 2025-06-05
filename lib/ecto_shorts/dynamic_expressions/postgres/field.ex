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
  """

  alias Ecto.Query

  require Ecto.Query

  @type dynamic_expr :: Ecto.Query.dynamic_expr()
  @type binding_alias :: atom() | nil
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
  """
  @spec build_dynamic(binding_alias() | nil, any(), operator(), any()) :: dynamic_expr()
  def build_dynamic(binding_alias, key, :eq, value),
    do: build_dynamic(binding_alias, key, :==, value)

  def build_dynamic(binding_alias, key, :not, value),
    do: build_dynamic(binding_alias, key, :!=, value)

  def build_dynamic(binding_alias, key, :lt, value),
    do: build_dynamic(binding_alias, key, :<, value)

  def build_dynamic(binding_alias, key, :gt, value),
    do: build_dynamic(binding_alias, key, :>, value)

  def build_dynamic(binding_alias, key, :lte, value),
    do: build_dynamic(binding_alias, key, :<=, value)

  def build_dynamic(binding_alias, key, :gte, value),
    do: build_dynamic(binding_alias, key, :>=, value)

  # ---

  def build_dynamic(binding_alias, key, :ilike, values) when is_list(values) do
    patterns = Enum.map(values, &"%#{&1}%")

    if binding_alias do
      Query.dynamic(
        [{^binding_alias, d}],
        fragment("? ILIKE ANY(SELECT unnest(?))", field(d, ^key), ^patterns)
      )
    else
      Query.dynamic([d], fragment("? ILIKE ANY(SELECT unnest(?))", field(d, ^key), ^patterns))
    end
  end

  def build_dynamic(binding_alias, key, :ilike, value) do
    pattern = "%#{value}%"

    if binding_alias do
      Query.dynamic([{^binding_alias, d}], ilike(field(d, ^key), ^pattern))
    else
      Query.dynamic([d], ilike(field(d, ^key), ^pattern))
    end
  end

  # ---

  def build_dynamic(binding_alias, key, :like, values) when is_list(values) do
    patterns = Enum.map(values, &"%#{&1}%")

    if binding_alias do
      Query.dynamic(
        [{^binding_alias, d}],
        fragment("? LIKE ANY(SELECT unnest(?))", field(d, ^key), ^patterns)
      )
    else
      Query.dynamic([d], fragment("? LIKE ANY(SELECT unnest(?))", field(d, ^key), ^patterns))
    end
  end

  def build_dynamic(binding_alias, key, :like, value) do
    pattern = "%#{value}%"

    if binding_alias do
      Query.dynamic([{^binding_alias, d}], like(field(d, ^key), ^pattern))
    else
      Query.dynamic([d], like(field(d, ^key), ^pattern))
    end
  end

  # ---

  def build_dynamic(binding_alias, key, :=~, values) when is_list(values) do
    Enum.reduce(values, nil, fn value, dyn_a ->
      or_dynamic(dyn_a, build_dynamic(binding_alias, key, :=~, value))
    end)
  end

  def build_dynamic(binding_alias, key, :=~, value) do
    if binding_alias do
      Query.dynamic([{^binding_alias, d}], fragment("? ~* ?", field(d, ^key), ^value))
    else
      Query.dynamic([d], fragment("? ~* ?", field(d, ^key), ^value))
    end
  end

  # ---

  def build_dynamic(binding_alias, key, :<, values) when is_list(values) do
    if binding_alias do
      Query.dynamic([{^binding_alias, d}], fragment("? < ANY(?)", field(d, ^key), ^values))
    else
      Query.dynamic([d], fragment("? < ANY(?)", field(d, ^key), ^values))
    end
  end

  def build_dynamic(binding_alias, key, :<, value) do
    if binding_alias do
      Query.dynamic([{^binding_alias, d}], field(d, ^key) < ^value)
    else
      Query.dynamic([d], field(d, ^key) < ^value)
    end
  end

  # ---

  def build_dynamic(binding_alias, key, :>, values) when is_list(values) do
    if binding_alias do
      Query.dynamic([{^binding_alias, d}], fragment("? > ANY(?)", field(d, ^key), ^values))
    else
      Query.dynamic([d], fragment("? > ANY(?)", field(d, ^key), ^values))
    end
  end

  def build_dynamic(binding_alias, key, :>, value) do
    if binding_alias do
      Query.dynamic([{^binding_alias, d}], field(d, ^key) > ^value)
    else
      Query.dynamic([d], field(d, ^key) > ^value)
    end
  end

  # ---

  def build_dynamic(binding_alias, key, :<=, values) when is_list(values) do
    if binding_alias do
      Query.dynamic([{^binding_alias, d}], fragment("? <= ANY(?)", field(d, ^key), ^values))
    else
      Query.dynamic([d], fragment("? <= ANY(?)", field(d, ^key), ^values))
    end
  end

  def build_dynamic(binding_alias, key, :<=, value) do
    if binding_alias do
      Query.dynamic([{^binding_alias, d}], field(d, ^key) <= ^value)
    else
      Query.dynamic([d], field(d, ^key) <= ^value)
    end
  end

  # ---

  def build_dynamic(binding_alias, key, :>=, values) when is_list(values) do
    if binding_alias do
      Query.dynamic([{^binding_alias, d}], fragment("? >= ANY(?)", field(d, ^key), ^values))
    else
      Query.dynamic([d], fragment("? >= ANY(?)", field(d, ^key), ^values))
    end
  end

  def build_dynamic(binding_alias, key, :>=, value) do
    if binding_alias do
      Query.dynamic([{^binding_alias, d}], field(d, ^key) >= ^value)
    else
      Query.dynamic([d], field(d, ^key) >= ^value)
    end
  end

  # ---

  def build_dynamic(binding_alias, key, :!=, {:lower, values}) when is_list(values) do
    if binding_alias do
      Query.dynamic(
        [{^binding_alias, d}],
        fragment("LOWER(?)", field(d, ^key)) not in ^values
      )
    else
      Query.dynamic([d], fragment("LOWER(?)", field(d, ^key)) not in ^values)
    end
  end

  def build_dynamic(binding_alias, key, :!=, {:lower, value}) do
    if binding_alias do
      Query.dynamic(
        [{^binding_alias, d}],
        fragment("LOWER(?)", field(d, ^key)) != ^value
      )
    else
      Query.dynamic([d], fragment("LOWER(?)", field(d, ^key)) != ^value)
    end
  end

  # ---

  def build_dynamic(binding_alias, key, :!=, {:upper, values}) when is_list(values) do
    if binding_alias do
      Query.dynamic(
        [{^binding_alias, d}],
        fragment("UPPER(?)", field(d, ^key)) not in ^values
      )
    else
      Query.dynamic([d], fragment("UPPER(?)", field(d, ^key)) not in ^values)
    end
  end

  def build_dynamic(binding_alias, key, :!=, {:upper, value}) do
    if binding_alias do
      Query.dynamic(
        [{^binding_alias, d}],
        fragment("UPPER(?)", field(d, ^key)) != ^value
      )
    else
      Query.dynamic([d], fragment("UPPER(?)", field(d, ^key)) != ^value)
    end
  end

  # ---

  def build_dynamic(binding_alias, key, :!=, nil) do
    if binding_alias do
      Query.dynamic([{^binding_alias, d}], not is_nil(field(d, ^key)))
    else
      Query.dynamic([d], not is_nil(field(d, ^key)))
    end
  end

  def build_dynamic(binding_alias, key, :!=, values) when is_list(values) do
    if binding_alias do
      Query.dynamic([{^binding_alias, d}], field(d, ^key) not in ^values)
    else
      Query.dynamic([d], field(d, ^key) not in ^values)
    end
  end

  def build_dynamic(binding_alias, key, :!=, value) do
    if binding_alias do
      Query.dynamic([{^binding_alias, d}], field(d, ^key) != ^value)
    else
      Query.dynamic([d], field(d, ^key) != ^value)
    end
  end

  # ---

  def build_dynamic(binding_alias, key, :==, {:lower, values}) when is_list(values) do
    if binding_alias do
      Query.dynamic([{^binding_alias, d}], fragment("LOWER(?)", field(d, ^key)) in ^values)
    else
      Query.dynamic([d], fragment("LOWER(?)", field(d, ^key)) in ^values)
    end
  end

  def build_dynamic(binding_alias, key, :==, {:lower, value}) do
    if binding_alias do
      Query.dynamic(
        [{^binding_alias, d}],
        fragment("LOWER(?)", field(d, ^key)) == ^value
      )
    else
      Query.dynamic([d], fragment("LOWER(?)", field(d, ^key)) == ^value)
    end
  end

  # ---

  def build_dynamic(binding_alias, key, :==, {:upper, values}) when is_list(values) do
    if binding_alias do
      Query.dynamic([{^binding_alias, d}], fragment("UPPER(?)", field(d, ^key)) in ^values)
    else
      Query.dynamic([d], fragment("UPPER(?)", field(d, ^key)) in ^values)
    end
  end

  def build_dynamic(binding_alias, key, :==, {:upper, value}) do
    if binding_alias do
      Query.dynamic(
        [{^binding_alias, d}],
        fragment("UPPER(?)", field(d, ^key)) == ^value
      )
    else
      Query.dynamic([d], fragment("UPPER(?)", field(d, ^key)) == ^value)
    end
  end

  # ---

  def build_dynamic(binding_alias, key, :==, nil) do
    if binding_alias do
      Query.dynamic([{^binding_alias, d}], is_nil(field(d, ^key)))
    else
      Query.dynamic([d], is_nil(field(d, ^key)))
    end
  end

  def build_dynamic(binding_alias, key, :==, values) when is_list(values) do
    if binding_alias do
      Query.dynamic([{^binding_alias, d}], field(d, ^key) in ^values)
    else
      Query.dynamic([d], field(d, ^key) in ^values)
    end
  end

  def build_dynamic(binding_alias, key, :==, value) do
    if binding_alias do
      Query.dynamic([{^binding_alias, d}], field(d, ^key) == ^value)
    else
      Query.dynamic([d], field(d, ^key) == ^value)
    end
  end

  defp or_dynamic(nil, dyn_b), do: dyn_b
  defp or_dynamic(dyn_a, dyn_b), do: Query.dynamic(^dyn_a or ^dyn_b)
end
