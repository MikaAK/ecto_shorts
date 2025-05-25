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
  alias EctoShorts.{CommonChanges, CommonQuery}

  @type query :: Ecto.Query.t()
  @type schema :: Ecto.Queryable.t()
  @type source :: binary()
  @type schema_data :: Ecto.Schema.t()
  @type schema_metadata :: Ecto.Schema.Metadata.t()
  @type schema_source :: {source() | nil, schema()}
  @type schema_input :: schema() | schema_source()
  @type query_input :: query() | schema_input()
  @type changeset :: Ecto.Changeset.t()
  @type create_changeset_input :: schema_input() | schema_data() | changeset()
  @type prefix :: binary() | nil
  @type key :: atom()
  @type params :: map()
  @type opts :: keyword()

  @doc """
  Invokes the `__schema__/1` get_schema_reflection function.

  ### Examples

      iex> EctoShorts.CommonSchema.get_schema_reflection(EctoShorts.Schemas.Post, :primary_key)
      [:id]

      iex> EctoShorts.CommonSchema.get_schema_reflection({"posts", EctoShorts.Schemas.PostAbstract}, :primary_key)
      [:id]
  """
  @spec get_schema_reflection(schema_input(), any()) :: any()
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
  @spec get_schema_reflection(schema_input(), any(), any()) :: any()
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
  @spec get_schema_prefix(schema_input() | schema_data()) :: prefix()
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
  @spec get_schema_source(schema_data() | schema_input() | query_input()) :: schema_source()
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
    CommonQuery.validate_query_binding_schema_source!(query)
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
  @spec get_schema_metadata(schema_data() | changeset(), key()) :: schema()
  def get_schema_metadata(schema_data_or_changeset, key) do
    schema_data_or_changeset
    |> get_schema_metadata()
    |> Map.get(key)
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
  @spec get_schema_metadata(schema_data() | changeset() | schema_input()) :: schema_metadata()
  def get_schema_metadata(%{data: %{__meta__: meta}}), do: meta
  def get_schema_metadata(%{__meta__: meta}), do: meta

  def get_schema_metadata(schema_input),
    do: schema_input |> create_struct() |> get_schema_metadata()

  @doc """
  Updates the `__meta__` field on an Ecto schema struct.

  ### Options

    See `Ecto.put_meta/2` for more information.

  ### Examples

      iex> EctoShorts.CommonSchema.put_schema_metadata(%EctoShorts.Schemas.Post{}, state: :loaded, source: "custom_source", prefix: "custom_prefix")
      %EctoShorts.Schemas.Post{
        __meta__: %Ecto.Schema.Metadata{
          schema: EctoShorts.Schemas.Post,
          state: :loaded,
          source: "custom_source",
          prefix: "custom_prefix"
        }
      }

      iex> EctoShorts.CommonSchema.put_schema_metadata(EctoShorts.Schemas.Post, state: :loaded, source: "custom_source", prefix: "custom_prefix")
      %EctoShorts.Schemas.Post{
        __meta__: %Ecto.Schema.Metadata{
          schema: EctoShorts.Schemas.Post,
          state: :loaded,
          source: "custom_source",
          prefix: "custom_prefix"
        }
      }

      # the source given in the tuple takes precedence
      iex> EctoShorts.CommonSchema.put_schema_metadata({"posts", EctoShorts.Schemas.PostAbstract}, state: :loaded, source: "custom_source", prefix: "custom_prefix")
      %EctoShorts.Schemas.PostAbstract{
        __meta__: %Ecto.Schema.Metadata{
          schema: EctoShorts.Schemas.PostAbstract,
          state: :loaded,
          source: "custom_source",
          prefix: "custom_prefix"
        }
      }
  """
  @spec put_schema_metadata(schema_input() | schema_data()) :: schema_data()
  @spec put_schema_metadata(schema_input() | schema_data(), opts()) :: schema_data()
  def put_schema_metadata(schema_input_or_schema_data, opts \\ [])

  def put_schema_metadata(%_{__meta__: state} = schema_data, opts) do
    Ecto.put_meta(schema_data,
      context: opts[:context] || state.context,
      prefix: opts[:prefix] || state.prefix,
      source: opts[:source] || state.source,
      state: opts[:state] || state.state || :loaded
    )
  end

  def put_schema_metadata(schema_input, opts) do
    schema_input |> create_struct() |> put_schema_metadata(opts)
  end

  @doc """
  Builds a struct from a queryable, optionally overriding its source.

  ### Examples

      iex> EctoShorts.CommonSchema.create_struct(EctoShorts.Schemas.Post)
      %EctoShorts.Schemas.Post{__meta__: %Ecto.Schema.Metadata{state: :built, schema: EctoShorts.Schemas.Post, source: "posts"}}

      iex> EctoShorts.CommonSchema.create_struct({"custom_source", EctoShorts.Schemas.PostAbstract})
      %EctoShorts.Schemas.PostAbstract{__meta__: %Ecto.Schema.Metadata{state: :loaded, schema: EctoShorts.Schemas.PostAbstract,  source: "custom_source"}}
  """
  @spec create_struct(schema_input()) :: schema_data()
  def create_struct({source, schema}) do
    schema
    |> struct()
    |> put_schema_metadata(
      state: :loaded,
      source: source,
      prefix: get_schema_prefix(schema)
    )
  end

  def create_struct(schema) do
    struct(schema)
  end

  @doc """
  Builds an `Ecto.Changeset` given an Ecto queryable, Ecto schema, or
  Ecto changeset.

  This function resolves how to build the changeset based on the input
  type, and delegates to `create_changeset/4`.

  ## Examples

      iex> EctoShorts.CommonSchema.create_changeset(EctoShorts.Schemas.Post, %{body: "example"})

      iex> EctoShorts.CommonSchema.create_changeset({"custom_source", EctoShorts.Schemas.PostAbstract}, %{body: "example"})

      iex> EctoShorts.CommonSchema.create_changeset(%EctoShorts.Schemas.Post{}, %{body: "example"})

      iex> changeset = EctoShorts.Schemas.Post.changeset(%EctoShorts.Schemas.Post{}, %{})
      ...> EctoShorts.CommonSchema.create_changeset(changeset, %{body: "example"})
  """
  @spec create_changeset(create_changeset_input()) :: changeset()
  @spec create_changeset(create_changeset_input(), params()) :: changeset()
  @spec create_changeset(create_changeset_input(), params(), opts()) :: changeset()
  def create_changeset(create_changeset_input, params \\ %{}, opts \\ [])

  def create_changeset(
        %{data: %{__meta__: %{schema: schema}}} = changeset,
        params,
        opts
      ) do
    create_changeset(schema, changeset, params, opts)
  end

  def create_changeset(
        %{__meta__: %{schema: schema}} = struct,
        params,
        opts
      ) do
    create_changeset(schema, struct, params, opts)
  end

  def create_changeset(
        {source, schema},
        params,
        opts
      ) do
    create_changeset(
      schema,
      create_struct({source, schema}),
      params,
      opts
    )
  end

  def create_changeset(schema, params, opts) do
    create_changeset(
      schema,
      create_struct(schema),
      params,
      opts
    )
  end

  @doc """
  Builds an `Ecto.Changeset` using a variety of customization strategies.

  This function wraps the actual call to the `changeset/2` function defined
  on the schema module (or a custom function if specified in options). It
  provides flexibility for injecting custom behavior when generating a
  changeset.

  ## Options

    - `:create_changeset` - Customizes how the changeset is constructed. Accepted values:
      - `{mod, fun, args}` – Calls `apply(mod, fun, [struct_or_changeset, params] ++ args)`.
      - `{mod, fun}` – Equivalent to `{mod, fun, []}`.
      - `2-arity function` – A function that receives `struct_or_changeset` and `params`.
      - `1-arity function` – Receives the default changeset and returns a modified version.
      - `map` – A map of changes to merge into the params before building the changeset.

  Raises if the result is not an `Ecto.Changeset`.
  """
  @spec create_changeset(
          schema_input(),
          schema_data() | changeset(),
          params(),
          opts()
        ) :: changeset()
  def create_changeset(schema_input, struct_or_changeset, params, opts) do
    schema_input
    |> normalize_schema()
    |> to_changeset(
      prepare_changeset_data(struct_or_changeset, schema_input),
      params,
      opts[:create_changeset]
    )
  end

  defp prepare_changeset_data(
         %{data: %{__meta__: _} = schema_data} = changeset,
         {source, _schema}
       ) do
    %{changeset | data: put_schema_metadata(schema_data, source: source)}
  end

  defp prepare_changeset_data(
         %{__meta__: _} = schema_data,
         {source, _schema}
       ) do
    put_schema_metadata(schema_data, source: source)
  end

  defp prepare_changeset_data(struct_or_changeset, _schema) do
    struct_or_changeset
  end

  defp normalize_schema({_, schema}), do: schema
  defp normalize_schema(schema), do: schema

  defp to_changeset(schema, struct_or_changeset, params, nil) do
    CommonChanges.changeset(schema, struct_or_changeset, params)
  end

  defp to_changeset(_schema, struct_or_changeset, params, {module, fun, args}) do
    apply(module, fun, [struct_or_changeset, params] ++ args)
  end

  defp to_changeset(_schema, struct_or_changeset, params, {module, fun}) do
    apply(module, fun, [struct_or_changeset, params])
  end

  defp to_changeset(_schema, struct_or_changeset, params, module) when is_atom(module) do
    if function_exported?(module, :changeset, 2) do
      module.changeset(struct_or_changeset, params)
    else
      raise ArgumentError, "function changeset/2 not exported from module #{inspect(module)}"
    end
  end

  defp to_changeset(_schema, struct_or_changeset, params, fun) when is_function(fun, 2) do
    fun.(struct_or_changeset, params)
  end

  defp to_changeset(schema, struct_or_changeset, params, fun) when is_function(fun, 1) do
    schema
    |> CommonChanges.changeset(struct_or_changeset, params)
    |> fun.()
  end

  defp to_changeset(schema, struct_or_changeset, params, changes) when is_map(changes) do
    CommonChanges.changeset(schema, struct_or_changeset, Map.merge(params, changes))
  end
end
