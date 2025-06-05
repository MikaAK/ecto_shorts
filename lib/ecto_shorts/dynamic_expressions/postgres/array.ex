defmodule EctoShorts.DynamicExpressions.Postgres.Array do
  @moduledoc since: "2.5.0"
  @moduledoc """
  Builds Ecto.Query dynamic expressions for Postgres array fields.

  This API is intended for fields where the underlying database column type
  is an array. It supports a wide variety of operators like equality (`:==`),
  inequality (`:!=`), pattern matching (`:like`, `:ilike`, `:=~`), and
  comparison operators (`:<`, `:<=`, `:>`, `:>=`).

  These expressions are designed to be composed into `Ecto.Query.dynamic/2`
  calls and are safe to use with or without binding aliases.

  See `EctoShorts.DynamicExpressions.Postgres.Field` for more information
  on filtering other field types.
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
        fragment(
          """
          NOT EXISTS (
            SELECT 1
            FROM unnest(?) AS input_tag
            WHERE NOT EXISTS (
              SELECT 1
              FROM unnest(?) AS db_tag
              WHERE input_tag ILIKE db_tag
            )
          )
          """,
          ^patterns,
          field(d, ^key)
        )
      )
    else
      Query.dynamic(
        [d],
        fragment(
          """
          NOT EXISTS (
            SELECT 1
            FROM unnest(?) AS input_tag
            WHERE NOT EXISTS (
              SELECT 1
              FROM unnest(?) AS db_tag
              WHERE input_tag ILIKE db_tag
            )
          )
          """,
          ^patterns,
          field(d, ^key)
        )
      )
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

  # ---

  def build_dynamic(binding_alias, key, :like, values) when is_list(values) do
    patterns = Enum.map(values, &"%#{&1}%")

    if binding_alias do
      Query.dynamic(
        [{^binding_alias, d}],
        fragment(
          """
          NOT EXISTS (
            SELECT 1
            FROM unnest(?) AS input_tag
            WHERE NOT EXISTS (
              SELECT 1
              FROM unnest(?) AS db_tag
              WHERE input_tag LIKE db_tag
            )
          )
          """,
          ^patterns,
          field(d, ^key)
        )
      )
    else
      Query.dynamic(
        [d],
        fragment(
          """
          NOT EXISTS (
            SELECT 1
            FROM unnest(?) AS input_tag
            WHERE NOT EXISTS (
              SELECT 1
              FROM unnest(?) AS db_tag
              WHERE input_tag LIKE db_tag
            )
          )
          """,
          ^patterns,
          field(d, ^key)
        )
      )
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

  # ---

  def build_dynamic(binding_alias, key, :==, {:lower, value}) do
    if binding_alias do
      Query.dynamic(
        [{^binding_alias, d}],
        fragment(
          """
          (
            SELECT array_agg(LOWER(db_tag))
            FROM unnest(?::text[]) AS db_tag
          )
          =
          (
            SELECT array_agg(LOWER(input_tag))
            FROM unnest(?::text[]) AS input_tag
          )
          """,
          field(d, ^key),
          ^value
        )
      )
    else
      Query.dynamic(
        [d],
        fragment(
          """
          (
            SELECT array_agg(LOWER(db_tag))
            FROM unnest(?::text[]) AS db_tag
          )
          =
          (
            SELECT array_agg(LOWER(input_tag))
            FROM unnest(?::text[]) AS input_tag
          )
          """,
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
          """
          (
            SELECT array_agg(UPPER(db_tag))
            FROM unnest(?::text[]) AS db_tag
          )
          =
          (
            SELECT array_agg(UPPER(input_tag))
            FROM unnest(?::text[]) AS input_tag
          )
          """,
          field(d, ^key),
          ^value
        )
      )
    else
      Query.dynamic(
        [d],
        fragment(
          """
          (
            SELECT array_agg(UPPER(db_tag))
            FROM unnest(?::text[]) AS db_tag
          )
          =
          (
            SELECT array_agg(UPPER(input_tag))
            FROM unnest(?::text[]) AS input_tag
          )
          """,
          field(d, ^key),
          ^value
        )
      )
    end
  end

  # ---

  def build_dynamic(binding_alias, {:lower, value}, :==, key) do
    if binding_alias do
      Query.dynamic(
        [{^binding_alias, d}],
        fragment(
          """
          ? = ANY (
              SELECT LOWER(element)
              FROM unnest(?::text[]) AS element
            )
          """,
          ^value,
          field(d, ^key)
        )
      )
    else
      Query.dynamic(
        [d],
        fragment(
          """
          ? = ANY (
              SELECT LOWER(element)
              FROM unnest(?::text[]) AS element
            )
          """,
          ^value,
          field(d, ^key)
        )
      )
    end
  end

  def build_dynamic(binding_alias, {:upper, value}, :==, key) do
    if binding_alias do
      Query.dynamic(
        [{^binding_alias, d}],
        fragment(
          """
          ? = ANY (
              SELECT UPPER(element)
              FROM unnest(?::text[]) AS element
            )
          """,
          ^value,
          field(d, ^key)
        )
      )
    else
      Query.dynamic(
        [d],
        fragment(
          """
          ? = ANY (
              SELECT UPPER(element)
              FROM unnest(?::text[]) AS element
            )
          """,
          ^value,
          field(d, ^key)
        )
      )
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

  # ---

  def build_dynamic(binding_alias, key, :!=, {:lower, value}) do
    if binding_alias do
      Query.dynamic(
        [{^binding_alias, d}],
        fragment(
          """
          (
            SELECT array_agg(LOWER(db_tag))
            FROM unnest(?::text[]) AS db_tag
          )
          <>
          (
            SELECT array_agg(LOWER(input_tag))
            FROM unnest(?::text[]) AS input_tag
          )
          """,
          field(d, ^key),
          ^value
        )
      )
    else
      Query.dynamic(
        [d],
        fragment(
          """
          (
            SELECT array_agg(LOWER(db_tag))
            FROM unnest(?::text[]) AS db_tag
          )
          <>
          (
            SELECT array_agg(LOWER(input_tag))
            FROM unnest(?::text[]) AS input_tag
          )
          """,
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
          """
          (
            SELECT array_agg(UPPER(db_tag))
            FROM unnest(?::text[]) AS db_tag
          )
          <>
          (
            SELECT array_agg(UPPER(input_tag))
            FROM unnest(?::text[]) AS input_tag
          )
          """,
          field(d, ^key),
          ^value
        )
      )
    else
      Query.dynamic(
        [d],
        fragment(
          """
          (
            SELECT array_agg(UPPER(db_tag))
            FROM unnest(?::text[]) AS db_tag
          )
          <>
          (
            SELECT array_agg(UPPER(input_tag))
            FROM unnest(?::text[]) AS input_tag
          )
          """,
          field(d, ^key),
          ^value
        )
      )
    end
  end

  # ---

  def build_dynamic(binding_alias, {:lower, value}, :!=, key) do
    if binding_alias do
      Query.dynamic(
        [{^binding_alias, d}],
        fragment(
          """
          NOT (
            ? = ANY (
              SELECT LOWER(element)
              FROM unnest(?::text[]) AS element
            )
          )
          """,
          ^value,
          field(d, ^key)
        )
      )
    else
      Query.dynamic(
        [d],
        fragment(
          """
          NOT (
            ? = ANY (
              SELECT LOWER(element)
              FROM unnest(?::text[]) AS element
            )
          )
          """,
          ^value,
          field(d, ^key)
        )
      )
    end
  end

  def build_dynamic(binding_alias, {:upper, value}, :!=, key) do
    if binding_alias do
      Query.dynamic(
        [{^binding_alias, d}],
        fragment(
          """
          NOT (
            ? = ANY (
              SELECT UPPER(element)
              FROM unnest(?::text[]) AS element
            )
          )
          """,
          ^value,
          field(d, ^key)
        )
      )
    else
      Query.dynamic(
        [d],
        fragment(
          """
          NOT (
            ? = ANY (
              SELECT UPPER(element)
              FROM unnest(?::text[]) AS element
            )
          )
          """,
          ^value,
          field(d, ^key)
        )
      )
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

  # ---

  def build_dynamic(binding_alias, key, :<, values) when is_list(values) do
    if binding_alias do
      Query.dynamic([{^binding_alias, d}], field(d, ^key) < ^values)
    else
      Query.dynamic([d], field(d, ^key) < ^values)
    end
  end

  def build_dynamic(binding_alias, value, :<, key) do
    if binding_alias do
      Query.dynamic(
        [{^binding_alias, d}],
        fragment("? < ANY(?)", ^value, field(d, ^key))
      )
    else
      Query.dynamic([d], fragment("? < ANY(?)", ^value, field(d, ^key)))
    end
  end

  # ---

  def build_dynamic(binding_alias, key, :>, values) when is_list(values) do
    if binding_alias do
      Query.dynamic([{^binding_alias, d}], field(d, ^key) > ^values)
    else
      Query.dynamic([d], field(d, ^key) > ^values)
    end
  end

  def build_dynamic(binding_alias, value, :>, key) do
    if binding_alias do
      Query.dynamic(
        [{^binding_alias, d}],
        fragment("? > ANY(?)", ^value, field(d, ^key))
      )
    else
      Query.dynamic([d], fragment("? > ANY(?)", ^value, field(d, ^key)))
    end
  end

  # ---

  def build_dynamic(binding_alias, key, :<=, values) when is_list(values) do
    if binding_alias do
      Query.dynamic([{^binding_alias, d}], field(d, ^key) <= ^values)
    else
      Query.dynamic([d], field(d, ^key) <= ^values)
    end
  end

  def build_dynamic(binding_alias, value, :<=, key) do
    if binding_alias do
      Query.dynamic(
        [{^binding_alias, d}],
        fragment("? <= ANY(?)", ^value, field(d, ^key))
      )
    else
      Query.dynamic([d], fragment("? <= ANY(?)", ^value, field(d, ^key)))
    end
  end

  # ---

  def build_dynamic(binding_alias, key, :>=, values) when is_list(values) do
    if binding_alias do
      Query.dynamic([{^binding_alias, d}], field(d, ^key) >= ^values)
    else
      Query.dynamic([d], field(d, ^key) >= ^values)
    end
  end

  def build_dynamic(binding_alias, value, :>=, key) do
    if binding_alias do
      Query.dynamic(
        [{^binding_alias, d}],
        fragment("? >= ANY(?)", ^value, field(d, ^key))
      )
    else
      Query.dynamic([d], fragment("? >= ANY(?)", ^value, field(d, ^key)))
    end
  end

  # ---

  def build_dynamic(binding_alias, key, :=~, values) when is_list(values) do
    if binding_alias do
      Query.dynamic(
        [{^binding_alias, d}],
        fragment(
          "EXISTS (SELECT 1 FROM unnest(?) AS tag WHERE tag ~* ?)",
          field(d, ^key),
          ^values
        )
      )
    else
      Query.dynamic(
        [d],
        fragment(
          "EXISTS (SELECT 1 FROM unnest(?) AS tag WHERE tag ~* ?)",
          field(d, ^key),
          ^values
        )
      )
    end
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
end
