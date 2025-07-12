defmodule EctoShorts.CommonSchema do
  @moduledoc since: "2.5.0"
  @moduledoc """
  Provides utility functions for working with Ecto schemas,
  particularly when dealing with polymorphic associations.

  ## Polymorphic Associations

  This module supports [polymorphic associations](https://hexdocs.pm/ecto/Ecto.Schema.html#belongs_to/3-polymorphic-associations)
  by allowing you to use a `{source :: binary(), queryable :: Ecto.Queryable.t()}` tuple
  in place of a traditional schema module. This is useful when you want to query
  different tables using a shared schema definition.

  For example:

      EctoSchemas.Actions.all({"posts", EctoShorts.Schemas.PostAbstract}, %{id: 1})

  In this example, the query runs against the "posts" table instead of the default
  source defined in the schema. When both a `source` and `queryable` are provided,
  the explicit `source` takes precedence.

  This approach allows reusing schema modules across different tables,
  as long as the table structure matches the schema definition.
  """
  alias EctoShorts.CommonQuery

  @type source_name :: String.t()
  @type schema_module :: module()
  @type source_tuple :: {source_name(), schema_module()}
  @type query_source :: source_name() | schema_module() | source_tuple()

  @doc """
  Invokes the `__schema__/1` get_schema_reflection function.

  ### Examples

      iex> EctoShorts.CommonSchema.get_schema_reflection(EctoShorts.Schemas.Post, :primary_key)
      [:id]

      iex> EctoShorts.CommonSchema.get_schema_reflection({"posts", EctoShorts.Schemas.PostAbstract}, :primary_key)
      [:id]
  """
  def get_schema_reflection({_, schema}, arg), do: schema.__schema__(arg)
  def get_schema_reflection(schema, arg), do: schema.__schema__(arg)

  @doc """
  Invokes the `__schema__/2` reflection function.

  ### Examples

      iex> EctoShorts.CommonSchema.get_schema_reflection(EctoShorts.Schemas.Post, :type, :id)
      :id

      iex> EctoShorts.CommonSchema.get_schema_reflection({"posts", EctoShorts.Schemas.PostAbstract}, :type, :id)
      :id
  """
  def get_schema_reflection({_, schema}, arg1, arg2) do
    schema.__schema__(arg1, arg2)
  end

  def get_schema_reflection(schema, arg1, arg2) do
    schema.__schema__(arg1, arg2)
  end

  @doc """
  Returns the `prefix` defined in the schema, if any.

  ## Examples

      iex> EctoShorts.CommonSchema.get_schema_prefix(EctoShorts.Schemas.PostHasSchemaPrefix)
      "custom_schema_prefix"

      iex> EctoShorts.CommonSchema.get_schema_prefix({"posts", EctoShorts.Schemas.PostAbstractHasSchemaPrefix})
      "custom_schema_prefix"

      iex> EctoShorts.CommonSchema.get_schema_prefix(%EctoShorts.Schemas.PostHasSchemaPrefix{})
      "custom_schema_prefix"
  """
  def get_schema_prefix(%{__meta__: %{prefix: schema_prefix}}), do: schema_prefix
  def get_schema_prefix({_, schema}), do: schema.__schema__(:prefix)
  def get_schema_prefix(schema), do: schema.__schema__(:prefix)

  @doc """
  Returns a `{source, schema}` tuple where `source`
  is the database table name string or `nil` and `schema` is an
  Ecto schema module.

  ## Examples

      iex> EctoShorts.CommonSchema.get_schema_source(%EctoShorts.Schemas.Post{})
      {"posts", EctoShorts.Schemas.Post}

      iex> EctoShorts.CommonSchema.get_schema_source({"posts", EctoShorts.Schemas.PostAbstract})
      {"posts", EctoShorts.Schemas.PostAbstract}

      iex> EctoShorts.CommonSchema.get_schema_source(EctoShorts.Schemas.Post)
      {"posts", EctoShorts.Schemas.Post}
  """
  def get_schema_source(%{__meta__: %{schema: schema, source: source}}) do
    {source, schema}
  end

  def get_schema_source({source, schema}) when is_atom(schema) do
    {source, schema}
  end

  def get_schema_source(schema) when is_atom(schema) do
    {schema.__schema__(:source), schema}
  end

  def get_schema_source(query) do
    CommonQuery.lookup_base_expr_source(query)
  end

  @doc """
  Returns the schema module (queryable) from the `Ecto.Schema.Metadata`
  struct of the given schema struct.

  ## Examples

      iex> EctoShorts.CommonSchema.get_schema_metadata(%EctoShorts.Schemas.Post{})
      %Ecto.Schema.Metadata{schema: EctoShorts.Schemas.Post, source: "posts", state: :built}

      iex> changeset = Ecto.Changeset.change(%EctoShorts.Schemas.Post{})
      ...> EctoShorts.CommonSchema.get_schema_metadata(changeset)
      %Ecto.Schema.Metadata{schema: EctoShorts.Schemas.Post, source: "posts", state: :built}
  """
  def get_schema_metadata(schema_data_or_changeset, key) do
    schema_data_or_changeset
    |> get_schema_metadata()
    |> Map.fetch!(key)
  end

  @doc """
  Returns the `Ecto.Schema.Metadata` struct from the given schema struct.

  ## Examples

      iex> EctoShorts.CommonSchema.get_schema_metadata(%EctoShorts.Schemas.Post{})
      %Ecto.Schema.Metadata{schema: EctoShorts.Schemas.Post, source: "posts", state: :built}

      iex> changeset = Ecto.Changeset.change(%EctoShorts.Schemas.Post{})
      ...> EctoShorts.CommonSchema.get_schema_metadata(changeset)
      %Ecto.Schema.Metadata{schema: EctoShorts.Schemas.Post, source: "posts", state: :built}
  """
  def get_schema_metadata(%{data: %{__meta__: meta}}), do: meta
  def get_schema_metadata(%{__meta__: meta}), do: meta
  def get_schema_metadata(source), do: source |> prepare_struct() |> get_schema_metadata()

  @doc """
  Updates the `__meta__` field on an Ecto schema struct.

  ### Options

    See `Ecto.put_meta/2` for more information.

  ### Examples

      iex> EctoShorts.CommonSchema.put_metadata(%EctoShorts.Schemas.Post{}, state: :loaded, source: "custom_source", prefix: "custom_prefix")
      %EctoShorts.Schemas.Post{
        __meta__: %Ecto.Schema.Metadata{
          schema: EctoShorts.Schemas.Post,
          state: :loaded,
          source: "custom_source",
          prefix: "custom_prefix"
        }
      }

      iex> EctoShorts.CommonSchema.put_metadata(EctoShorts.Schemas.Post, state: :loaded, source: "custom_source", prefix: "custom_prefix")
      %EctoShorts.Schemas.Post{
        __meta__: %Ecto.Schema.Metadata{
          schema: EctoShorts.Schemas.Post,
          state: :loaded,
          source: "custom_source",
          prefix: "custom_prefix"
        }
      }

      # the source given in the tuple takes precedence
      iex> EctoShorts.CommonSchema.put_metadata({"posts", EctoShorts.Schemas.PostAbstract}, state: :loaded, source: "custom_source", prefix: "custom_prefix")
      %EctoShorts.Schemas.PostAbstract{
        __meta__: %Ecto.Schema.Metadata{
          schema: EctoShorts.Schemas.PostAbstract,
          state: :loaded,
          source: "custom_source",
          prefix: "custom_prefix"
        }
      }
  """
  def put_metadata(source_or_schema_data, params \\ [])

  def put_metadata(%_{__meta__: state} = schema_data, params) do
    Ecto.put_meta(schema_data,
      context: params[:context] || state.context,
      prefix: params[:prefix] || state.prefix,
      source: params[:source] || state.source,
      state: params[:state] || state.state || :loaded
    )
  end

  def put_metadata(source, params) do
    source |> prepare_struct() |> put_metadata(params)
  end

  @doc """
  ...
  """
  def prepare_struct({source, schema}) do
    schema
    |> struct()
    |> put_metadata(state: :loaded, source: source, prefix: get_schema_prefix(schema))
  end

  def prepare_struct(schema) do
    struct(schema)
  end

  def create_changeset(source, params, opts \\ [])

  def create_changeset({source, schema}, params, opts) do
    if function_exported?(schema, :create_changeset, 1) do
      schema.create_changeset({source, params})
    else
      prepare_changeset(schema, prepare_struct({source, schema}), params, opts)
    end
  end

  def create_changeset(schema, params, opts) do
    if function_exported?(schema, :create_changeset, 1) do
      schema.create_changeset(params)
    else
      prepare_changeset(schema, prepare_struct(schema), params, opts)
    end
  end

  @doc """
  `(schema_data :: Ecto.Schema.t(), params :: map(), options :: keyword())`
  `(changeset :: Ecto.Changeset.t(), params :: map(), options :: keyword())`
  `(query_source :: {source_name :: binary(), schema_module :: module()}, schema_data :: Ecto.Schema.t(), options :: keyword())`
  `(query_source :: {source_name :: binary(), schema_module :: module()}, changeset :: Ecto.Changeset.t(), options :: keyword())`
  `(query_source :: {source_name :: binary(), schema_module :: module()}, params :: map(), options :: keyword())`
  `(schema_module :: module(), schema_data :: Ecto.Schema.t(), options :: keyword())`
  `(schema_module :: module(), changeset :: Ecto.Changeset.t(), options :: keyword())`
  `(schema_module :: module(), params :: map(), options :: keyword())`
  """
  def prepare_changeset(%{__meta__: %{schema: schema}} = schema_data, params, opts) do
    prepare_changeset(schema, schema_data, params, opts)
  end

  def prepare_changeset(%{data: %{__meta__: %{schema: schema}}} = changeset, params, opts) do
    prepare_changeset(schema, changeset, params, opts)
  end

  def prepare_changeset({source, schema}, %{__meta__: _} = schema_data, opts) do
    prepare_changeset(schema, put_source(schema_data, {source, schema}), %{}, opts)
  end

  def prepare_changeset({source, schema}, %{data: %{__meta__: _}} = changeset, opts) do
    prepare_changeset(schema, put_source(changeset, {source, schema}), %{}, opts)
  end

  def prepare_changeset({source, schema}, params, opts) do
    prepare_changeset(schema, prepare_struct({source, schema}), params, opts)
  end

  def prepare_changeset(schema, %{__meta__: _} = schema_data, opts) do
    prepare_changeset(schema, schema_data, %{}, opts)
  end

  def prepare_changeset(schema, %{data: %{__meta__: _}} = changeset, opts) do
    prepare_changeset(schema, changeset, %{}, opts)
  end

  def prepare_changeset(schema, params, opts) do
    prepare_changeset(schema, prepare_struct(schema), params, opts)
  end

  # ---

  def prepare_changeset({source, schema}, %{__meta__: _} = schema_data, params, opts) do
    prepare_changeset(schema, put_source(schema_data, {source, schema}), params, opts)
  end

  def prepare_changeset({source, schema}, %{data: _} = changeset, params, opts) do
    prepare_changeset(schema, put_source(changeset, {source, schema}), params, opts)
  end

  def prepare_changeset(schema, schema_data_or_changeset, params, opts) do
    if Keyword.has_key?(opts, :changeset) do
      apply_changeset!(schema, schema_data_or_changeset, params, opts[:changeset])
    else
      if function_exported?(schema, :changeset, 2) do
        schema.changeset(schema_data_or_changeset, params)
      else
        Ecto.Changeset.change(schema_data_or_changeset, params)
      end
    end
  end

  defp apply_changeset!(schema, schema_data_or_changeset, params, callback) do
    case callback do
      fun when is_function(fun, 3) ->
        schema
        |> fun.(schema_data_or_changeset, params)
        |> ensure_changeset!()

      fun when is_function(fun, 2) ->
        schema_data_or_changeset
        |> fun.(params)
        |> ensure_changeset!()

      term ->
        raise ArgumentError,
              "Expected the value for option :prepare_changeset to be a 2-arity or 3-arity function, got: #{inspect(term)}"
    end
  end

  defp ensure_changeset!(term) do
    if changeset?(term) do
      term
    else
      raise "Expected an Ecto.Changeset, got: #{inspect(term)}"
    end
  end

  defp changeset?(%Ecto.Changeset{}), do: true
  defp changeset?(_), do: false

  defp put_source(%{data: schema_data} = changeset, {source, schema}) do
    %{changeset | data: put_metadata(schema_data, source: source, schema: schema)}
  end

  defp put_source(%{__meta__: _} = schema_data, {source, schema}) do
    put_metadata(schema_data, source: source, schema: schema)
  end

  defp put_source(schema_data_or_changeset, _) do
    schema_data_or_changeset
  end
end
