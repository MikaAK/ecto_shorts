defmodule EctoShorts.SchemaHelpers do
  @moduledoc """
  Module that has helpers that are globably useful on ecto schemas
  """

  @doc """
  Returns a struct for the given ecto schema.

  ### Options

      See `Ecto.put_meta/2` for more information.

  ### Examples

      iex> EctoShorts.SchemaHelpers.build_struct(%EctoShorts.Support.Schemas.Comment{}, state: :loaded, source: "comment", prefix: "prefix")
      %EctoShorts.Support.Schemas.Comment{
        __meta__: %Ecto.Schema.Metadata{
          context: nil,
          prefix: "prefix",
          schema: EctoShorts.Support.Schemas.Comment,
          source: "comment",
          state: :loaded
        }
      }

      iex> EctoShorts.SchemaHelpers.build_struct(EctoShorts.Support.Schemas.Comment, state: :loaded, source: "comment", prefix: "prefix")
      %EctoShorts.Support.Schemas.Comment{
        __meta__: %Ecto.Schema.Metadata{
          context: nil,
          prefix: "prefix",
          schema: EctoShorts.Support.Schemas.Comment,
          source: "comment",
          state: :loaded
        }
      }
  """
  @doc since: "2.5.0"
  @spec build_struct(
    schema :: Ecto.Queryable.t() | Ecto.Schema.t(),
    meta :: keyword()
  ) :: Ecto.Schema.t()
  def build_struct(%_{} = schema_data, meta) do
    meta = Keyword.put_new(meta, :state, :loaded)

    Ecto.put_meta(schema_data, meta)
  end

  def build_struct(schema, meta) do
    schema
    |> struct()
    |> build_struct(meta)
  end

  @doc """
  Determine if item passed in is a Ecto Schema

  ## Example

    iex> EctoShorts.SchemaHelpers.schema?(%EctoShorts.Support.Schemas.Comment{})
    true

    iex> EctoShorts.SchemaHelpers.schema?(%{some_map: 1})
    false

    iex> EctoShorts.SchemaHelpers.schema?([%EctoShorts.Support.Schemas.Comment{}])
    false
  """
  @spec schema?(Ecto.Schema.t | any) :: boolean
  def schema?(%{__meta__: %{schema: _}}), do: true
  def schema?(_), do: false

  @doc """
  Determine if any items in list are a schema

  ## Example

    iex> EctoShorts.SchemaHelpers.has_schemas?([%{some_map: 1}, %EctoShorts.Support.Schemas.Comment{}])
    true

    iex> EctoShorts.SchemaHelpers.has_schemas?([%{some_map: 1}])
    false
  """
  @spec has_schemas?(list(Ecto.Schema.t | any)) :: boolean
  def has_schemas?(items), do: Enum.any?(items, &schema?/1)

  @doc """
  Determine if all items in list are a schema

  ## Example

    iex> EctoShorts.SchemaHelpers.all_schemas?([%{some_map: 1}, %EctoShorts.Support.Schemas.Comment{}])
    false

    iex> EctoShorts.SchemaHelpers.all_schemas?([%EctoShorts.Support.Schemas.Comment{}])
    true
  """
  @spec all_schemas?(list(Ecto.Schema.t | any)) :: boolean
  def all_schemas?(items), do: Enum.all?(items, &schema?/1)

  @doc """
  Returns `true` if the map has the atom key `:id` or
  the string key `"id"` and the value is not nil.

  ## Example

    iex> EctoShorts.SchemaHelpers.created?(%{id: 2})
    true

    iex> EctoShorts.SchemaHelpers.created?(%{"id" => 2})
    true

    iex> EctoShorts.SchemaHelpers.created?(%{item: 3})
    false
  """
  @spec created?(Ecto.Schema.t | any) :: boolean
  def created?(%{id: id}), do: !is_nil(id)
  def created?(%{"id" => id}), do: !is_nil(id)
  def created?(_), do: false

  @spec all_created?(list(Ecto.Schema.t | any)) :: boolean
  @doc """
  Determine if all items in list has been created or not

  ## Example

    iex> EctoShorts.SchemaHelpers.all_created?([%{id: 2}, %{"id" => 5}])
    true

    iex> EctoShorts.SchemaHelpers.all_created?([%{"id" => 2}, %{item: 3}])
    false
  """
  def all_created?(items), do: Enum.all?(items, &created?/1)

  @spec any_created?(list(Ecto.Schema.t | any)) :: boolean
  @doc """
  Returns `true` if any of the items passed as an argument to
  `EctoShorts.SchemaHelpers.created?/1` is `true`.

  ## Example

    iex> EctoShorts.SchemaHelpers.any_created?([%{id: 2}, %{"id" => 5}])
    true

    iex> EctoShorts.SchemaHelpers.any_created?([%{"id" => 2}, %{item: 3}])
    true

    iex> EctoShorts.SchemaHelpers.any_created?([%{test: 3}, %{item: 3}])
    false
  """
  def any_created?(items), do: Enum.any?(items, &created?/1)
end
