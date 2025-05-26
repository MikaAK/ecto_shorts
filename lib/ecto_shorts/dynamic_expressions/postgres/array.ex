defmodule EctoShorts.DynamicExpressions.Postgres.Array do
  @moduledoc since: "2.5.0"
  @moduledoc """
  Builds dynamic filter expressions for Postgres array fields.

  This module is designed to handle conditions where the target
  schema field is an array, and the value being matched is either
  a scalar, a list, or wrapped in case transformation.

  It supports a wide variety of operators like equality (`:==`),
  inequality (`:!=`), pattern matching (`:like`, `:ilike`, `:=~`),
  and comparison operators (`:<`, `:<=`, `:>`, `:>=`).

  These expressions are designed to be composed into `Ecto.Query.dynamic/2`
  calls and are safe to use with or without binding aliases.

  ## Supported operations

    * Scalar in array: `value in array_field`
    * Array matches literal: `array_field == value`
    * ANY comparisons: `value < ANY(array_field)`, etc.
    * Pattern match against ANY: `"pattern" ILIKE ANY(array_field)`
    * Case-based match: `LOWER(value) == LOWER(any in array_field)`
    * Handling `nil` and list values for robust runtime filters

  This module complements `EctoShorts.DynamicExpressions.Postgres.Field`
  and is typically used internally by dynamic query builders.

  ## Examples

      # value in array field
      iex> EctoShorts.DynamicExpressions.Postgres.Array.build_dynamic(:binding_name, "elixir", :==, :tags)

      # case-insensitive regex match
      iex> EctoShorts.DynamicExpressions.Postgres.Array.build_dynamic(:binding_name, "elixir", :=~, :tags)

      # lower-case match against array values
      iex> EctoShorts.DynamicExpressions.Postgres.Array.build_dynamic(:binding_name, :tags, :==, {:lower, "elixir"})

  """

  alias Ecto.Query

  require Ecto.Query

  @type dynamic_expr :: Ecto.Query.dynamic_expr()
  @type binding_alias :: atom() | nil

  @type operator :: atom()

  @doc """
  ...
  """
  @spec build_dynamic(binding_alias() | nil, any(), operator(), any()) :: dynamic_expr()
  def build_dynamic(binding_alias, key, :eq, value) do
    build_dynamic(binding_alias, key, :==, value)
  end

  def build_dynamic(binding_alias, key, :not, value) do
    build_dynamic(binding_alias, key, :!=, value)
  end

  def build_dynamic(binding_alias, key, :lt, value) do
    build_dynamic(binding_alias, key, :<, value)
  end

  def build_dynamic(binding_alias, key, :gt, value) do
    build_dynamic(binding_alias, key, :>, value)
  end

  def build_dynamic(binding_alias, key, :lte, value) do
    build_dynamic(binding_alias, key, :<=, value)
  end

  def build_dynamic(binding_alias, key, :gte, value) do
    build_dynamic(binding_alias, key, :>=, value)
  end

  def build_dynamic(binding_alias, value, :=~, key) do
    if binding_alias do
      Query.dynamic(
        [{^binding_alias, d}],
        fragment("? ~* ANY(?)", ^value, field(d, ^key))
      )
    else
      Query.dynamic([d], fragment("? ~* ANY(?)", ^value, field(d, ^key)))
    end
  end

  def build_dynamic(binding_alias, value, :ilike, key) do
    pattern = "%#{value}%"

    if binding_alias do
      Query.dynamic(
        [{^binding_alias, d}],
        fragment("? ILIKE ANY(?)", ^pattern, field(d, ^key))
      )
    else
      Query.dynamic([d], fragment("? ILIKE ANY(?)", ^pattern, field(d, ^key)))
    end
  end

  def build_dynamic(binding_alias, value, :like, key) do
    pattern = "%#{value}%"

    if binding_alias do
      Query.dynamic(
        [{^binding_alias, d}],
        fragment("? LIKE ANY(?)", ^pattern, field(d, ^key))
      )
    else
      Query.dynamic([d], fragment("? LIKE ANY(?)", ^pattern, field(d, ^key)))
    end
  end

  def build_dynamic(binding_alias, key, :<, values) when is_list(values) do
    if binding_alias do
      Query.dynamic([{^binding_alias, d}], field(d, ^key) < ^values)
    else
      Query.dynamic([d], field(d, ^key) < ^values)
    end
  end

  def build_dynamic(binding_alias, value, :<, key) when is_atom(key) do
    if binding_alias do
      Query.dynamic(
        [{^binding_alias, d}],
        fragment("? < ANY(?)", ^value, field(d, ^key))
      )
    else
      Query.dynamic([d], fragment("? < ANY(?)", ^value, field(d, ^key)))
    end
  end

  def build_dynamic(binding_alias, key, :>, values) when is_list(values) do
    if binding_alias do
      Query.dynamic([{^binding_alias, d}], field(d, ^key) > ^values)
    else
      Query.dynamic([d], field(d, ^key) > ^values)
    end
  end

  def build_dynamic(binding_alias, value, :>, key) when is_atom(key) do
    if binding_alias do
      Query.dynamic(
        [{^binding_alias, d}],
        fragment("? > ANY(?)", ^value, field(d, ^key))
      )
    else
      Query.dynamic([d], fragment("? > ANY(?)", ^value, field(d, ^key)))
    end
  end

  def build_dynamic(binding_alias, key, :<=, values) when is_list(values) do
    if binding_alias do
      Query.dynamic([{^binding_alias, d}], field(d, ^key) <= ^values)
    else
      Query.dynamic([d], field(d, ^key) <= ^values)
    end
  end

  def build_dynamic(binding_alias, value, :<=, key) when is_atom(key) do
    if binding_alias do
      Query.dynamic(
        [{^binding_alias, d}],
        fragment("? <= ANY(?)", ^value, field(d, ^key))
      )
    else
      Query.dynamic([d], fragment("? <= ANY(?)", ^value, field(d, ^key)))
    end
  end

  def build_dynamic(binding_alias, key, :>=, values) when is_list(values) do
    if binding_alias do
      Query.dynamic([{^binding_alias, d}], field(d, ^key) >= ^values)
    else
      Query.dynamic([d], field(d, ^key) >= ^values)
    end
  end

  def build_dynamic(binding_alias, value, :>=, key) when is_atom(key) do
    if binding_alias do
      Query.dynamic(
        [{^binding_alias, d}],
        fragment("? >= ANY(?)", ^value, field(d, ^key))
      )
    else
      Query.dynamic([d], fragment("? >= ANY(?)", ^value, field(d, ^key)))
    end
  end

  def build_dynamic(binding_alias, key, :!=, {:lower, value}) do
    if binding_alias do
      Query.dynamic(
        [{^binding_alias, d}],
        fragment(
          "EXISTS (SELECT 1 FROM unnest(?) AS value WHERE LOWER(value) != LOWER(?))",
          field(d, ^key),
          ^value
        )
      )
    else
      Query.dynamic(
        [d],
        fragment(
          "EXISTS (SELECT 1 FROM unnest(?) AS value WHERE LOWER(value) != LOWER(?))",
          field(d, ^key),
          ^value
        )
      )
    end
  end

  def build_dynamic(binding_alias, key, :!=, {:upper, value}) do
    if binding_alias do
      Query.dynamic(
        [{^binding_alias, d}],
        fragment(
          "EXISTS (SELECT 1 FROM unnest(?) AS value WHERE UPPER(value) != UPPER(?))",
          field(d, ^key),
          ^value
        )
      )
    else
      Query.dynamic(
        [d],
        fragment(
          "EXISTS (SELECT 1 FROM unnest(?) AS value WHERE UPPER(value) != UPPER(?))",
          field(d, ^key),
          ^value
        )
      )
    end
  end

  def build_dynamic(binding_alias, key, :!=, nil) do
    if binding_alias do
      Query.dynamic([{^binding_alias, d}], not is_nil(field(d, ^key)))
    else
      Query.dynamic([d], not is_nil(field(d, ^key)))
    end
  end

  def build_dynamic(binding_alias, key, :!=, values) when is_list(values) do
    if binding_alias do
      Query.dynamic([{^binding_alias, d}], field(d, ^key) != ^values)
    else
      Query.dynamic([d], field(d, ^key) != ^values)
    end
  end

  def build_dynamic(binding_alias, value, :!=, key) do
    if binding_alias do
      Query.dynamic([{^binding_alias, d}], ^value not in field(d, ^key))
    else
      Query.dynamic([d], ^value not in field(d, ^key))
    end
  end

  def build_dynamic(binding_alias, key, :==, {:lower, value}) do
    if binding_alias do
      Query.dynamic(
        [{^binding_alias, d}],
        fragment(
          "EXISTS (SELECT 1 FROM unnest(?) AS value WHERE LOWER(value) = LOWER(?))",
          field(d, ^key),
          ^value
        )
      )
    else
      Query.dynamic(
        [d],
        fragment(
          "EXISTS (SELECT 1 FROM unnest(?) AS value WHERE LOWER(value) = LOWER(?))",
          field(d, ^key),
          ^value
        )
      )
    end
  end

  def build_dynamic(binding_alias, key, :==, {:upper, value}) do
    if binding_alias do
      Query.dynamic(
        [{^binding_alias, d}],
        fragment(
          "EXISTS (SELECT 1 FROM unnest(?) AS value WHERE UPPER(value) = UPPER(?))",
          field(d, ^key),
          ^value
        )
      )
    else
      Query.dynamic(
        [d],
        fragment(
          "EXISTS (SELECT 1 FROM unnest(?) AS value WHERE UPPER(value) = UPPER(?))",
          field(d, ^key),
          ^value
        )
      )
    end
  end

  def build_dynamic(binding_alias, key, :==, nil) do
    if binding_alias do
      Query.dynamic([{^binding_alias, d}], is_nil(field(d, ^key)))
    else
      Query.dynamic([d], is_nil(field(d, ^key)))
    end
  end

  def build_dynamic(binding_alias, key, :==, values) when is_list(values) do
    if binding_alias do
      Query.dynamic([{^binding_alias, d}], field(d, ^key) == ^values)
    else
      Query.dynamic([d], field(d, ^key) == ^values)
    end
  end

  def build_dynamic(binding_alias, value, :==, key) do
    if binding_alias do
      Query.dynamic([{^binding_alias, d}], ^value in field(d, ^key))
    else
      Query.dynamic([d], ^value in field(d, ^key))
    end
  end
end
