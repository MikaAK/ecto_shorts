defmodule EctoShorts.CommonSchemas do
  @moduledoc """
  An interface for the `Ecto.Schema` abstract table syntax
  `{source :: binary(), queryable :: Ecto.Queryable.t()}`.
  This allows you to use the abstract table syntax
  interchangeably where a `queryable` is accepted as an
  argument.

  For example:

  ```elixir
  EctoSchemas.Actions.all(YourSchema, %{id: 1})
  ```

  This can be written as:

  ```elixir
  EctoSchemas.Actions.all({"source", YourSchema}, %{id: 1})
  ```

  When the `source` and `queryable` is specified in this way
  the `source` in the tuple will take precedence over the
  `source` defined in the schema. This means you can use an
  ecto schema on any database table that has a matching schema.
  """
  alias EctoShorts.{QueryHelpers, SchemaHelpers}

  @doc """
  This function invokes the `&__schema__/1` callback function.

  ### Examples

      iex> EctoShorts.CommonSchemas.get_schema_reflection(EctoShorts.Support.Schemas.Comment, :fields)
      iex> EctoShorts.CommonSchemas.get_schema_reflection({"comments", EctoShorts.Support.Schemas.Comment}, :fields)
  """
  @spec get_schema_reflection(
    queryable :: Ecto.Queryable.t() | {binary(), Ecto.Queryable.t()},
    arg :: atom()
  ) :: any()
  def get_schema_reflection({_source, queryable}, arg) do
    queryable.__schema__(arg)
  end

  def get_schema_reflection(queryable, arg) do
    queryable.__schema__(arg)
  end

  @doc """
  This function invokes the `&__schema__/2` callback function.

  ### Examples

      iex> EctoShorts.CommonSchemas.get_schema_reflection(EctoShorts.Support.Schemas.Comment, :type, :body)
      iex> EctoShorts.CommonSchemas.get_schema_reflection({"comments", EctoShorts.Support.Schemas.Comment}, :type, :body)
  """
  @spec get_schema_reflection(
    queryable :: Ecto.Queryable.t() | {binary(), Ecto.Queryable.t()},
    arg1 :: atom(),
    arg2 :: atom()
  ) :: any()
  def get_schema_reflection({_source, queryable}, arg1, arg2) do
    queryable.__schema__(arg1, arg2)
  end

  def get_schema_reflection(queryable, arg1, arg2) do
    queryable.__schema__(arg1, arg2)
  end

  @doc """
  Returns a struct for the given schema.

  ### Examples

      iex> EctoShorts.CommonSchemas.get_loaded_struct(EctoShorts.Support.Schemas.Comment)
      iex> EctoShorts.CommonSchemas.get_loaded_struct({"comments", EctoShorts.Support.Schemas.Comment})
  """
  @spec get_loaded_struct(
    queryable :: Ecto.Queryable.t() | {binary(), Ecto.Queryable.t()}
  ) :: Ecto.Schema.t()
  def get_loaded_struct({source, queryable}) do
    prefix = get_schema_prefix(queryable)

    SchemaHelpers.build_struct(queryable,
      state: :loaded,
      source: source,
      prefix: prefix
    )
  end

  def get_loaded_struct(queryable) do
    source = get_schema_source(queryable)
    prefix = get_schema_prefix(queryable)

    SchemaHelpers.build_struct(queryable,
      state: :loaded,
      source: source,
      prefix: prefix
    )
  end

  @doc """
  Returns the `prefix` specified in the schema.

  ### Examples

      iex> EctoShorts.CommonSchemas.get_schema_prefix(EctoShorts.Support.Schemas.Comment)
      iex> EctoShorts.CommonSchemas.get_schema_prefix({"comments", EctoShorts.Support.Schemas.Comment})
  """
  @spec get_schema_prefix(
    queryable :: Ecto.Queryable.t() | {binary(), Ecto.Queryable.t()}
  ) :: binary() | nil
  def get_schema_prefix({_source, queryable}) do
    queryable.__schema__(:prefix)
  end

  def get_schema_prefix(queryable) do
    queryable.__schema__(:prefix)
  end

  @doc """
  Returns the `source` string.

  ### Examples

      iex> EctoShorts.CommonSchemas.get_schema_source(EctoShorts.Support.Schemas.Comment)
      iex> EctoShorts.CommonSchemas.get_schema_source({"comments", EctoShorts.Support.Schemas.Comment})
  """
  @spec get_schema_source(
    queryable :: Ecto.Queryable.t() | {binary(), Ecto.Queryable.t()}
  ) :: binary()
  def get_schema_source({source, _queryable}) do
    source
  end

  def get_schema_source(queryable) do
    queryable.__schema__(:source)
  end

  @doc """
  Returns an `Ecto.Queryable`.

  ### Examples

      iex> EctoShorts.CommonSchemas.get_schema_queryable(EctoShorts.Support.Schemas.Comment)
      iex> EctoShorts.CommonSchemas.get_schema_queryable({"comments", EctoShorts.Support.Schemas.Comment})
  """
  @spec get_schema_queryable(
    queryable :: Ecto.Queryable.t() | {binary(), Ecto.Queryable.t()}
  ) :: Ecto.Queryable.t()
  def get_schema_queryable({_source, queryable}) do
    queryable
  end

  def get_schema_queryable(queryable) do
    queryable
  end

  @doc """
  Returns an `Ecto.Query`.

  ### Options

  Options do not apply when an `Ecto.Query` is given.

  See `EctoShorts.QueryHelpers.build_schema_query/2` for more information.

  ### Examples

      iex> EctoShorts.CommonSchemas.get_schema_query(%Ecto.Query{})
      iex> EctoShorts.CommonSchemas.get_schema_query(EctoShorts.Support.Schemas.Comment)
      iex> EctoShorts.CommonSchemas.get_schema_query({"comments", EctoShorts.Support.Schemas.Comment})
  """
  @spec get_schema_query(
    queryable :: Ecto.Query.t() | Ecto.Queryable.t() | {binary(), Ecto.Queryable.t()}
  ) :: Ecto.Query.t()
  def get_schema_query(queryable) do
    QueryHelpers.build_schema_query(queryable)
  end
end
