defmodule EctoShorts.CommonSchemas do
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

      EctoSchema.Actions.all({"posts", EctoShorts.Schemas.PostAbstract}, %{id: 1})

  In this example, the query runs against the "posts" table instead of the default
  source defined in the schema. When both a `source` and `queryable` are provided,
  the explicit `source` takes precedence.

  This approach allows reusing schema modules across different tables,
  as long as the table structure matches the schema definition.
  """

  alias EctoShorts.CommonQueries

  @type query :: Ecto.Query.t()
  @type schema_module :: Ecto.Queryable.t()
  @type schema_source :: binary()
  @type schema_struct :: Ecto.Schema.t()
  @type schema_metadata :: Ecto.Schema.Metadata.t()
  @type source_and_schema :: {schema_source(), schema_module()}
  @type sourceable :: schema_module() | source_and_schema()
  @type schema_attribute :: :schema | :source
  @type query_source :: query() | sourceable()
  @type changeset :: Ecto.Changeset.t()
  @type changeset_input :: sourceable() | schema_struct() | changeset()
  @type prefix :: binary() | nil
  @type key :: atom()
  @type params :: map()
  @type opts :: keyword()

  @doc """
  Invokes the `__schema__/1` get_reflection function.

  ### Examples

      iex> EctoShorts.CommonSchemas.get_reflection(EctoShorts.Schemas.Post, :primary_key)
      [:id]

      iex> EctoShorts.CommonSchemas.get_reflection({"posts", EctoShorts.Schemas.PostAbstract}, :primary_key)
      [:id]
  """
  @spec get_reflection(sourceable(), any()) :: any()
  def get_reflection({_, schema_module}, arg), do: schema_module.__schema__(arg)
  def get_reflection(schema_module, arg), do: schema_module.__schema__(arg)

  @doc """
  Invokes the `__schema__/2` reflection function.

  ### Examples

      iex> EctoShorts.CommonSchemas.get_reflection(EctoShorts.Schemas.Post, :type, :id)
      :id

      iex> EctoShorts.CommonSchemas.get_reflection({"posts", EctoShorts.Schemas.PostAbstract}, :type, :id)
      :id
  """
  @spec get_reflection(sourceable(), any(), any()) :: any()
  def get_reflection({_, schema_module}, arg1, arg2) do
    schema_module.__schema__(arg1, arg2)
  end

  def get_reflection(schema_module, arg1, arg2) do
    schema_module.__schema__(arg1, arg2)
  end

  @doc """
  Returns the `prefix` defined in the schema, if any.

  ## Examples

      iex> EctoShorts.CommonSchemas.get_schema_prefix(EctoShorts.Schemas.PostHasSchemaPrefix)
      "custom_schema_prefix"

      iex> EctoShorts.CommonSchemas.get_schema_prefix({"posts", EctoShorts.Schemas.PostAbstractHasSchemaPrefix})
      "custom_schema_prefix"

      iex> EctoShorts.CommonSchemas.get_schema_prefix(%EctoShorts.Schemas.PostHasSchemaPrefix{})
      "custom_schema_prefix"
  """
  @spec get_schema_prefix(sourceable() | schema_struct()) :: prefix()
  def get_schema_prefix(%{__meta__: %{prefix: schema_prefix}}), do: schema_prefix
  def get_schema_prefix({_, schema_module}), do: schema_module.__schema__(:prefix)
  def get_schema_prefix(schema_module), do: schema_module.__schema__(:prefix)

  @doc """
  Returns a `{schema_source, schema_module}` tuple where `schema_source`
  is the database table name string or `nil` and `schema_module` is an
  Ecto schema module.

  ## Examples

      iex> EctoShorts.CommonSchemas.get_source_and_schema(%EctoShorts.Schemas.Post{})
      {"posts", EctoShorts.Schemas.Post}

      iex> EctoShorts.CommonSchemas.get_source_and_schema({"posts", EctoShorts.Schemas.PostAbstract})
      {"posts", EctoShorts.Schemas.PostAbstract}

      iex> EctoShorts.CommonSchemas.get_source_and_schema(EctoShorts.Schemas.Post)
      {"posts", EctoShorts.Schemas.Post}
  """
  @spec get_source_and_schema(schema_struct() | sourceable() | query_source()) ::
          source_and_schema()
  def get_source_and_schema(%{__meta__: %{schema: schema_module, source: schema_source}}) do
    {schema_source, schema_module}
  end

  def get_source_and_schema({schema_source, schema_module}) do
    {schema_source, schema_module}
  end

  def get_source_and_schema(schema_module) when is_atom(schema_module) do
    if function_exported?(schema_module, :__schema__, 1) do
      {schema_module.__schema__(:source), schema_module}
    else
      CommonQueries.get_from_expr(schema_module, :source)
    end
  end

  def get_source_and_schema(query) do
    CommonQueries.get_from_expr(query, :source)
  end

  @doc """
  Returns the database table name if they key is `:source` otherwise
  the schema module if the key is `:schema`.

  ## Examples

      iex> EctoShorts.CommonSchemas.get_source_and_schema({"posts", EctoShorts.Schemas.PostAbstract}, :schema)
      EctoShorts.Schemas.PostAbstract

      iex> EctoShorts.CommonSchemas.get_source_and_schema({"custom_table_name", EctoShorts.Schemas.PostAbstract}, :source)
      "custom_table_name"

      iex> EctoShorts.CommonSchemas.get_source_and_schema(EctoShorts.Schemas.Post, :schema)
      EctoShorts.Schemas.Post

      iex> EctoShorts.CommonSchemas.get_source_and_schema(EctoShorts.Schemas.Post, :source)
      "posts"

      iex> EctoShorts.CommonSchemas.get_source_and_schema(%EctoShorts.Schemas.Post{}, :schema)
      EctoShorts.Schemas.Post

      iex> EctoShorts.CommonSchemas.get_source_and_schema(%EctoShorts.Schemas.Post{}, :source)
      "posts"
  """
  @spec get_source_and_schema(
          schema_struct() | sourceable() | query_source(),
          schema_attribute()
        ) :: any()
  def get_source_and_schema(schema_input, :schema) do
    {_schema_source, schema_module} = get_source_and_schema(schema_input)

    schema_module
  end

  def get_source_and_schema(schema_input, :source) do
    {schema_source, _schema_module} = get_source_and_schema(schema_input)

    schema_source
  end

  @doc """
  Returns the schema module (queryable) from the `Ecto.Schema.Metadata`
  struct of the given schema struct.

  ## Examples

      iex> EctoShorts.CommonSchemas.get_metadata(%EctoShorts.Schemas.Post{})
      %Ecto.Schema.Metadata{schema: EctoShorts.Schemas.Post, source: "posts", state: :built}

      iex> changeset = Ecto.Changeset.change(%EctoShorts.Schemas.Post{})
      ...> EctoShorts.CommonSchemas.get_metadata(changeset)
      %Ecto.Schema.Metadata{schema: EctoShorts.Schemas.Post, source: "posts", state: :built}
  """
  @spec get_metadata(schema_struct() | changeset(), key()) :: schema_module()
  def get_metadata(schema_struct_or_changeset, key) do
    schema_struct_or_changeset
    |> get_metadata()
    |> Map.get(key)
  end

  @doc """
  Returns the `Ecto.Schema.Metadata` struct from the given schema struct.

  ## Examples

      iex> EctoShorts.CommonSchemas.get_metadata(%EctoShorts.Schemas.Post{})
      %Ecto.Schema.Metadata{schema: EctoShorts.Schemas.Post, source: "posts", state: :built}

      iex> changeset = Ecto.Changeset.change(%EctoShorts.Schemas.Post{})
      ...> EctoShorts.CommonSchemas.get_metadata(changeset)
      %Ecto.Schema.Metadata{schema: EctoShorts.Schemas.Post, source: "posts", state: :built}
  """
  @spec get_metadata(schema_struct() | changeset() | sourceable()) :: schema_metadata()
  def get_metadata(%{data: %{__meta__: meta}}), do: meta
  def get_metadata(%{__meta__: meta}), do: meta
  def get_metadata(sourceable), do: sourceable |> create_struct() |> get_metadata()

  @doc """
  Updates the `__meta__` field on an Ecto schema struct.

  ### Options

    See `Ecto.put_meta/2` for more information.

  ### Examples

      iex> EctoShorts.CommonSchemas.put_metadata(%EctoShorts.Schemas.Post{}, state: :loaded, source: "custom_source", prefix: "custom_prefix")
      %EctoShorts.Schemas.Post{
        __meta__: %Ecto.Schema.Metadata{
          schema: EctoShorts.Schemas.Post,
          state: :loaded,
          source: "custom_source",
          prefix: "custom_prefix"
        }
      }

      iex> EctoShorts.CommonSchemas.put_metadata(EctoShorts.Schemas.Post, state: :loaded, source: "custom_source", prefix: "custom_prefix")
      %EctoShorts.Schemas.Post{
        __meta__: %Ecto.Schema.Metadata{
          schema: EctoShorts.Schemas.Post,
          state: :loaded,
          source: "custom_source",
          prefix: "custom_prefix"
        }
      }

      # the source given in the tuple takes precedence
      iex> EctoShorts.CommonSchemas.put_metadata({"posts", EctoShorts.Schemas.PostAbstract}, state: :loaded, source: "custom_source", prefix: "custom_prefix")
      %EctoShorts.Schemas.PostAbstract{
        __meta__: %Ecto.Schema.Metadata{
          schema: EctoShorts.Schemas.PostAbstract,
          state: :loaded,
          source: "custom_source",
          prefix: "custom_prefix"
        }
      }
  """
  @spec put_metadata(sourceable() | schema_struct()) :: schema_struct()
  @spec put_metadata(sourceable() | schema_struct(), opts()) :: schema_struct()
  def put_metadata(sourceable_or_schema_struct, opts \\ [])

  def put_metadata(%_{__meta__: state} = schema_struct, opts) do
    Ecto.put_meta(schema_struct,
      context: opts[:context] || state.context,
      prefix: opts[:prefix] || state.prefix,
      source: opts[:source] || state.source,
      state: opts[:state] || state.state || :loaded
    )
  end

  def put_metadata(sourceable, opts) do
    sourceable |> create_struct() |> put_metadata(opts)
  end

  @doc """
  Builds a struct from a queryable, optionally overriding its source.

  ### Examples

      iex> EctoShorts.CommonSchemas.create_struct(EctoShorts.Schemas.Post)
      %EctoShorts.Schemas.Post{__meta__: %Ecto.Schema.Metadata{state: :built, schema: EctoShorts.Schemas.Post, source: "posts"}}

      iex> EctoShorts.CommonSchemas.create_struct({"custom_source", EctoShorts.Schemas.PostAbstract})
      %EctoShorts.Schemas.PostAbstract{__meta__: %Ecto.Schema.Metadata{state: :loaded, schema: EctoShorts.Schemas.PostAbstract,  source: "custom_source"}}
  """
  @spec create_struct(sourceable()) :: schema_struct()
  def create_struct({schema_source, schema_module}) do
    schema_module
    |> struct()
    |> put_metadata(
      state: :loaded,
      source: schema_source,
      prefix: get_schema_prefix(schema_module)
    )
  end

  def create_struct(schema_module) do
    struct(schema_module)
  end

  @doc """
  Builds an `Ecto.Changeset` given an Ecto queryable, Ecto schema, or
  Ecto changeset.

  This function resolves how to build the changeset based on the input
  type, and delegates to `create_changeset/4`.

  ## Examples

      iex> EctoShorts.CommonSchemas.create_changeset(EctoShorts.Schemas.Post, %{body: "example"})

      iex> EctoShorts.CommonSchemas.create_changeset({"custom_source", EctoShorts.Schemas.PostAbstract}, %{body: "example"})

      iex> EctoShorts.CommonSchemas.create_changeset(%EctoShorts.Schemas.Post{}, %{body: "example"})

      iex> changeset = EctoShorts.Schemas.Post.changeset(%EctoShorts.Schemas.Post{}, %{})
      ...> EctoShorts.CommonSchemas.create_changeset(changeset, %{body: "example"})
  """
  @spec create_changeset(changeset_input()) :: changeset()
  @spec create_changeset(changeset_input(), params()) :: changeset()
  @spec create_changeset(changeset_input(), params(), opts()) :: changeset()
  def create_changeset(changeset_input, params \\ %{}, opts \\ [])

  def create_changeset(
        %{data: %{__meta__: %{schema: schema_module}}} = changeset,
        params,
        opts
      ) do
    create_changeset(schema_module, changeset, params, opts)
  end

  def create_changeset(
        %{__meta__: %{schema: schema_module}} = struct,
        params,
        opts
      ) do
    create_changeset(schema_module, struct, params, opts)
  end

  def create_changeset(
        {schema_source, schema_module},
        params,
        opts
      ) do
    create_changeset(
      schema_module,
      create_struct({schema_source, schema_module}),
      params,
      opts
    )
  end

  def create_changeset(schema_module, params, opts) do
    create_changeset(
      schema_module,
      create_struct(schema_module),
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
          sourceable(),
          schema_struct() | changeset(),
          params(),
          opts()
        ) :: changeset()
  def create_changeset(sourceable, struct_or_changeset, params, opts) do
    sourceable
    |> normalize_schema_module()
    |> to_changeset(
      prepare_changeset_data(struct_or_changeset, sourceable),
      params,
      opts[:create_changeset]
    )
  end

  defp prepare_changeset_data(
         %{data: %{__meta__: _} = schema_struct} = changeset,
         {schema_source, _schema_module}
       ) do
    %{changeset | data: put_metadata(schema_struct, source: schema_source)}
  end

  defp prepare_changeset_data(
         %{__meta__: _} = schema_struct,
         {schema_source, _schema_module}
       ) do
    put_metadata(schema_struct, source: schema_source)
  end

  defp prepare_changeset_data(struct_or_changeset, _schema_module) do
    struct_or_changeset
  end

  defp normalize_schema_module({_, schema_module}), do: schema_module
  defp normalize_schema_module(schema_module), do: schema_module

  defp to_changeset(schema_module, struct_or_changeset, params, nil) do
    schema_module.changeset(struct_or_changeset, params)
  end

  defp to_changeset(_schema_module, struct_or_changeset, params, {module, fun, args}) do
    apply(module, fun, [struct_or_changeset, params] ++ args)
  end

  defp to_changeset(_schema_module, struct_or_changeset, params, {module, fun}) do
    apply(module, fun, [struct_or_changeset, params])
  end

  defp to_changeset(_schema_module, struct_or_changeset, params, module) when is_atom(module) do
    module.changeset(struct_or_changeset, params)
  end

  defp to_changeset(_schema_module, struct_or_changeset, params, fun) when is_function(fun, 2) do
    fun.(struct_or_changeset, params)
  end

  defp to_changeset(schema_module, struct_or_changeset, params, fun) when is_function(fun, 1) do
    struct_or_changeset
    |> schema_module.changeset(params)
    |> fun.()
  end

  defp to_changeset(schema_module, struct_or_changeset, params, changes) when is_map(changes) do
    schema_module.changeset(struct_or_changeset, Map.merge(params, changes))
  end
end
