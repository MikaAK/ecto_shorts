defmodule EctoShorts.CommonSchema do
  @moduledoc since: "3.0.0"
  @moduledoc """
  Normalizes sources, introspects schemas, and builds structs and changesets.

  Use this module when you need to work with Ecto schemas in a flexible way
  that accepts multiple source formats (schema modules, table names, tuples,
  structs, changesets, or queries) and provides a consistent API for
  introspection and struct creation.

  ## Inspect schema metadata

  The simplest use is to normalize a source into a `{table_name, schema}` tuple:

      iex> EctoShorts.CommonSchema.normalize_source(EctoShorts.Schema.Post)
      {nil, EctoShorts.Schema.Post}

      iex> EctoShorts.CommonSchema.normalize_source("posts")
      {"posts", nil}

      iex> EctoShorts.CommonSchema.normalize_source({"posts", EctoShorts.Schema.Post})
      {"posts", EctoShorts.Schema.Post}

  Convert a source to an `Ecto.Query`:

      iex> EctoShorts.CommonSchema.to_query(EctoShorts.Schema.Post)
      #Ecto.Query<from p0 in EctoShorts.Schema.Post>

  Extract the schema module from any source:

      iex> EctoShorts.CommonSchema.get_schema(EctoShorts.Schema.Post)
      EctoShorts.Schema.Post

      iex> EctoShorts.CommonSchema.get_schema(%EctoShorts.Schema.Post{})
      EctoShorts.Schema.Post

  Build a struct from a source:

      iex> EctoShorts.CommonSchema.build_struct(EctoShorts.Schema.Post)
      %EctoShorts.Schema.Post{...}

  Create a changeset with validation:

      iex> EctoShorts.CommonSchema.create_changeset(EctoShorts.Schema.Post, %{title: "Hi"}, [])
      #Ecto.Changeset<...>

  ## Accepted source forms

  Most functions accept any of these as a `source` argument:

  | Form                          | Example                                      | Table name | Schema module         |
  |-------------------------------|----------------------------------------------|------------|-----------------------|
  | Schema module                 | `EctoShorts.Schema.Post`                     | from schema| `Post`                |
  | Table name string             | `"posts"`                                    | `"posts"`  | `nil`                 |
  | `{table_name, schema}` tuple  | `{"posts", Post}`                            | `"posts"`  | `Post`                |
  | `{nil, schema}` tuple         | `{nil, Post}`                                | `nil`      | `Post`                |
  | `{table_name, nil}` tuple     | `{"posts", nil}`                             | `"posts"`  | `nil`                 |
  | Schema struct                 | `%Post{}`                                    | from meta  | `Post`                |
  | Changeset                     | `Ecto.Changeset.change(%Post{})`             | from meta  | `Post`                |
  | Query                         | `from p in Post`                             | from query | `Post`                |

  The `{table_name, schema}` tuple form is the normalized representation used
  internally. All other forms are converted to this tuple by `normalize_source/1`.

  ## Source resolution flow

  When you pass a source to any function in this module, it follows this flow:

  1. **Normalize** - convert the source to a `{table_name, schema}` tuple via
     `normalize_source/1`.
  2. **Extract** - pull out the table name or schema module as needed.
  3. **Use** - pass the normalized values to Ecto functions.

  For example, `to_query/1` normalizes the source, then delegates to
  `Ecto.Queryable.to_query/1` with the appropriate form:

      to_query(Post)
      # normalize_source(Post) -> {nil, Post}
      # Queryable.to_query(Post) -> #Ecto.Query<...>

      to_query("posts")
      # normalize_source("posts") -> {"posts", nil}
      # Queryable.to_query("posts") -> #Ecto.Query<...>

      to_query({"custom_posts", Post})
      # normalize_source({"custom_posts", Post}) -> {"custom_posts", Post}
      # Queryable.to_query({"custom_posts", Post}) -> #Ecto.Query<...>

  ## Polymorphic associations

  This module supports [polymorphic associations](https://hexdocs.pm/ecto/Ecto.Schema.html#belongs_to/3-polymorphic-associations)
  by accepting a `{table_name, schema}` tuple in place of a schema module.
  This lets you query different tables using a shared schema definition.

  ### When to use polymorphic associations

  Use polymorphic associations when you have multiple tables with the same
  structure but different names, and you want to use one schema module to
  work with all of them.

  **Example scenario:** You have `posts` and `archived_posts` tables with
  identical columns, and you want to use the same `Post` schema for both.

      defmodule Post do
        use Ecto.Schema
        schema "posts" do
          field :title, :string
          field :body, :text
        end
      end

      # Query the posts table using the Post schema:
      EctoShorts.Actions.all(Post, %{})

      # Query the archived_posts table using the same Post schema:
      EctoShorts.Actions.all({"archived_posts", Post}, %{})

  The explicit table name in the tuple overrides the table name defined in
  the schema (`"posts"`), so the query runs against `archived_posts` instead.

  ### Polymorphic tuple precedence

  When both a table name and a schema are provided in a `{table_name, schema}`
  tuple, the explicit `table_name` takes precedence over the table name
  defined in the schema module.

      # Schema defines "posts" as the table:
      Post.__schema__(:source)
      # "posts"

      # Tuple overrides to "archived_posts":
      EctoShorts.CommonSchema.get_schema_source({"archived_posts", Post})
      # {"archived_posts", Post}

  ### Schemaless queries

  When you pass a table name string without a schema (`"posts"` or
  `{"posts", nil}`), you are performing a schemaless query. This is useful
  when you want to query a table that has no corresponding schema module.

      # Query the "posts" table without a schema:
      EctoShorts.CommonSchema.to_query("posts")
      # #Ecto.Query<from p0 in "posts">

  Schemaless queries have no field validation and no type information, so
  all field names are accepted as-is and all values are treated as scalars.

  See `EctoShorts.CommonFilters` moduledoc section "Schemaless queries" for
  more details on the limitations and requirements.

  ## Schema introspection

  Use `get_schema_reflection/2` and `get_schema_reflection/3` to call the
  schema's `__schema__/1` or `__schema__/2` reflection functions:

      iex> EctoShorts.CommonSchema.get_schema_reflection(EctoShorts.Schema.Post, :source)
      "posts"

      iex> EctoShorts.CommonSchema.get_schema_reflection(EctoShorts.Schema.Post, :fields)
      [:id, :title, :body, :published, :inserted_at, :updated_at]

      iex> EctoShorts.CommonSchema.get_schema_reflection(EctoShorts.Schema.Post, :type, :title)
      :string

  These functions return `nil` when the source has no schema (for example,
  when the source is a bare table name string).

  ## Struct creation

  Build a schema struct from any source:

      iex> EctoShorts.CommonSchema.build_struct(EctoShorts.Schema.Post)
      %EctoShorts.Schema.Post{id: nil, title: nil, ...}

      iex> EctoShorts.CommonSchema.build_struct({"custom_posts", EctoShorts.Schema.Post})
      %EctoShorts.Schema.Post{__meta__: %{source: "custom_posts", ...}, ...}

  The struct includes metadata (`:source`, `:state`, `:prefix`) set via
  `Ecto.put_meta/2`. Use `put_schema_metadata/2` to update metadata on an
  existing struct.

  ## Changeset creation

  Create a changeset from various source and data combinations:

      # From a schema module and params:
      EctoShorts.CommonSchema.create_changeset(Post, %{title: "Hello"}, [])

      # From a struct and params:
      EctoShorts.CommonSchema.create_changeset(%Post{}, %{title: "Hello"}, [])

      # From a changeset and params:
      changeset = Ecto.Changeset.change(%Post{})
      EctoShorts.CommonSchema.create_changeset(changeset, %{title: "Hello"}, [])

      # From a {source, schema} tuple and params:
      EctoShorts.CommonSchema.create_changeset({"custom_posts", Post}, %{title: "Hello"}, [])

  By default, `create_changeset/3` calls the schema's `changeset/2` function
  if it exists, or falls back to `Ecto.Changeset.change/2`. Override this
  with the `:changeset` option:

      # Use a custom changeset function:
      EctoShorts.CommonSchema.create_changeset(
        Post,
        %{title: "Hello"},
        changeset: fn struct, params -> MyApp.custom_changeset(struct, params) end
      )

  The `:changeset` option accepts a 1-arity, 2-arity, or 3-arity function.
  See `create_changeset/3` for details.

  ## Common patterns

  **Pattern 1: Accept flexible source input**

  When writing a function that works with schemas, accept any source form
  and normalize it:

      def my_function(source, params) do
        {table_name, schema} = EctoShorts.CommonSchema.normalize_source(source)
        # Now you have both table_name and schema available
      end

  **Pattern 2: Extract just the schema module**

  When you only need the schema module and do not care about the table name:

      def my_function(source) do
        schema = EctoShorts.CommonSchema.get_schema(source)
        if schema do
          schema.__schema__(:fields)
        else
          []
        end
      end

  **Pattern 3: Build a query from any source**

  When you need an `Ecto.Query` struct:

      def my_function(source) do
        query = EctoShorts.CommonSchema.to_query(source)
        # Now you can use Ecto.Query functions on query
      end

  See also `EctoShorts.CommonQuery`, `EctoShorts.CommonFilters`, and
  `EctoShorts.CommonChanges`.
  """

  @moduledoc groups: [
               %{
                 title: "Source resolution",
                 description:
                   "Functions that convert sources to queries or normalize source tuples."
               },
               %{
                 title: "Schema introspection",
                 description: "Functions that inspect schema metadata, fields, and prefixes."
               },
               %{
                 title: "Struct and changeset",
                 description:
                   "Functions that build schema structs, update metadata, and create changesets."
               }
             ]
  alias Ecto.Changeset
  alias Ecto.Queryable
  alias EctoShorts.CommonQuery

  @type source ::
          module()
          | {binary(), module()}
          | binary()
          | Ecto.Query.t()
          | struct()
          | Ecto.Changeset.t()
  @type normalized_source :: {binary() | nil, module() | nil}
  @type params :: map() | keyword()
  @type opts :: keyword()

  @doc group: "Source resolution"
  @doc """
  Converts a source into an `Ecto.Query`.

  Accepts an `Ecto.Query` (returned as-is), a schema module, a table name
  string, or a `{table_name, schema}` tuple. Normalizes the source via
  `normalize_source/1` before conversion.

  Returns an `Ecto.Query` struct.

  ## Examples

      iex> EctoShorts.CommonSchema.to_query(EctoShorts.Schema.Post)
      #Ecto.Query<from p0 in EctoShorts.Schema.Post>

      iex> EctoShorts.CommonSchema.to_query("posts")
      #Ecto.Query<from p0 in "posts">

      iex> EctoShorts.CommonSchema.to_query({"custom_posts", EctoShorts.Schema.Post})
      #Ecto.Query<from p0 in {"custom_posts", EctoShorts.Schema.Post}>

      iex> query = from p in EctoShorts.Schema.Post
      ...> EctoShorts.CommonSchema.to_query(query)
      #Ecto.Query<from p0 in EctoShorts.Schema.Post>

  See also `normalize_source/1`, `get_schema/1`, and `EctoShorts.CommonQuery`.
  """
  @spec to_query(source) :: Ecto.Query.t()
  def to_query(%Ecto.Query{} = query), do: query

  def to_query(source) do
    case normalize_source(source) do
      {nil, schema} -> Queryable.to_query(schema)
      {table_name, nil} -> Queryable.to_query(table_name)
      {table_name, schema} -> Queryable.to_query({table_name, schema})
    end
  end

  @doc group: "Source resolution"
  @doc """
  Normalizes a source into a `{table_name, schema}` tuple.

  Accepts a schema module, a table name string, a `{table_name, schema}`
  tuple, a schema struct, a changeset, or an `Ecto.Query`. Returns a
  `{binary() | nil, module() | nil}` tuple.

  Raises `ArgumentError` if the source cannot be recognized.

  ## Examples

      iex> EctoShorts.CommonSchema.normalize_source(EctoShorts.Schema.Post)
      {nil, EctoShorts.Schema.Post}

      iex> EctoShorts.CommonSchema.normalize_source("posts")
      {"posts", nil}

      iex> EctoShorts.CommonSchema.normalize_source({"custom_posts", EctoShorts.Schema.Post})
      {"custom_posts", EctoShorts.Schema.Post}

      iex> EctoShorts.CommonSchema.normalize_source({nil, EctoShorts.Schema.Post})
      {nil, EctoShorts.Schema.Post}

      iex> EctoShorts.CommonSchema.normalize_source(%EctoShorts.Schema.Post{})
      {"posts", EctoShorts.Schema.Post}

      iex> changeset = Ecto.Changeset.change(%EctoShorts.Schema.Post{})
      ...> EctoShorts.CommonSchema.normalize_source(changeset)
      {"posts", EctoShorts.Schema.Post}

  See also `to_query/1`, `get_schema/1`, and `get_schema_source/1`.
  """
  @spec normalize_source(source) :: normalized_source
  def normalize_source(%{data: %{__meta__: %{source: source, schema: schema}}}) do
    {source, schema}
  end

  def normalize_source(%{__meta__: %{source: source, schema: schema}}) do
    {source, schema}
  end

  def normalize_source(%Ecto.Query{} = query) do
    query
    |> CommonQuery.get_query_source()
    |> normalize_source()
  end

  def normalize_source({nil, schema_module})
      when is_atom(schema_module) and schema_module !== nil do
    {nil, schema_module}
  end

  def normalize_source({table_name, nil}) when is_binary(table_name) and table_name !== "" do
    {table_name, nil}
  end

  def normalize_source({table_name, schema_module})
      when is_binary(table_name) and table_name !== "" and is_atom(schema_module) and
             schema_module !== nil do
    {table_name, schema_module}
  end

  def normalize_source(schema_module) when is_atom(schema_module) and schema_module !== nil do
    {nil, schema_module}
  end

  def normalize_source(table_name) when is_binary(table_name) and table_name !== "" do
    {table_name, nil}
  end

  def normalize_source(term) do
    raise ArgumentError, """
    Expected source to be one of the following:

    - `Ecto.Query.t()` - An Ecto.Query struct
    - `binary()` - The table name as a string
    - `Ecto.Schema.t()` - An Ecto.Schema module
    - `{binary(), Ecto.Schema.t()}` - The table name and the Ecto.Schema module
    - `{nil, Ecto.Schema.t()}` - No table name and an Ecto.Schema module
    - `{binary(), nil}` - The table name and no Ecto.Schema module

    got:

    #{inspect(term)}
    """
  end

  @doc group: "Source resolution"
  @doc """
  Extracts the schema module from a source.

  Returns the schema module atom, or `nil` if no schema is present.

  ## Examples

      iex> EctoShorts.CommonSchema.get_schema(EctoShorts.Schema.Post)
      EctoShorts.Schema.Post

      iex> EctoShorts.CommonSchema.get_schema("posts")
      nil

      iex> EctoShorts.CommonSchema.get_schema({"custom_posts", EctoShorts.Schema.Post})
      EctoShorts.Schema.Post

      iex> EctoShorts.CommonSchema.get_schema({"posts", nil})
      nil

      iex> EctoShorts.CommonSchema.get_schema(%EctoShorts.Schema.Post{})
      EctoShorts.Schema.Post

  See also `normalize_source/1`, `get_schema_source/1`, and `to_query/1`.
  """
  @spec get_schema(source) :: module() | nil
  def get_schema(source) do
    case normalize_source(source) do
      {_, schema} when is_atom(schema) and schema !== nil ->
        schema

      _ ->
        nil
    end
  end

  @doc group: "Schema introspection"
  @doc """
  Returns a `{source, schema}` tuple where `source`
  is the database table name string or `nil` and `schema` is an
  Ecto schema module.

  ## Examples

      iex> EctoShorts.CommonSchema.get_schema_source(%EctoShorts.Schema.Post{})
      {"posts", EctoShorts.Schema.Post}

      iex> EctoShorts.CommonSchema.get_schema_source({"posts", EctoShorts.Schema.PostAbstract})
      {"posts", EctoShorts.Schema.PostAbstract}

      iex> EctoShorts.CommonSchema.get_schema_source(EctoShorts.Schema.Post)
      {"posts", EctoShorts.Schema.Post}

      iex> EctoShorts.CommonSchema.get_schema_source("posts")
      nil

  Returns `nil` for bare table name strings and any value that cannot be
  resolved to a `{source, schema}` pair.

  See also `normalize_source/1` and `get_schema/1`.
  """
  @spec get_schema_source(source) :: {binary(), module()} | nil
  def get_schema_source(%{from: _, joins: _} = query) do
    CommonQuery.get_query_source(query)
  end

  def get_schema_source(%{data: %{__meta__: %{schema: schema, source: source}}} = _changeset) do
    {source, schema}
  end

  def get_schema_source(%{__meta__: %{schema: schema, source: source}} = _schema_struct) do
    {source, schema}
  end

  def get_schema_source({source, schema})
      when is_nil(source) or (is_binary(source) and is_atom(schema) and schema !== nil) do
    {source, schema}
  end

  def get_schema_source(schema) when is_atom(schema) and schema !== nil do
    {schema.__schema__(:source), schema}
  end

  def get_schema_source(_) do
    nil
  end

  @doc group: "Schema introspection"
  @doc """
  Returns the `prefix` defined in the schema, if any.

  ## Examples

      iex> EctoShorts.CommonSchema.get_schema_prefix(EctoShorts.Schema.PostHasSchemaPrefix)
      "custom_schema_prefix"

      iex> EctoShorts.CommonSchema.get_schema_prefix({"posts", EctoShorts.Schema.PostAbstractHasSchemaPrefix})
      "custom_schema_prefix"

      iex> EctoShorts.CommonSchema.get_schema_prefix(%EctoShorts.Schema.PostHasSchemaPrefix{})
      "custom_schema_prefix"

  See also `get_schema_source/1` and `get_schema_metadata/1`.
  """
  @spec get_schema_prefix(source) :: binary() | nil
  def get_schema_prefix(%{data: %{__meta__: %{prefix: prefix}}}) do
    prefix
  end

  def get_schema_prefix(%{__meta__: %{prefix: prefix}}) do
    prefix
  end

  def get_schema_prefix(source) do
    with schema when schema !== nil <- get_schema(source) do
      schema.__schema__(:prefix)
    end
  end

  @doc group: "Schema introspection"
  @doc """
  Returns the `Ecto.Schema.Metadata` struct from the given schema struct.

  ## Examples

      iex> EctoShorts.CommonSchema.get_schema_metadata(%EctoShorts.Schema.Post{})
      %Ecto.Schema.Metadata{schema: EctoShorts.Schema.Post, source: "posts", state: :built}

      iex> changeset = Ecto.Changeset.change(%EctoShorts.Schema.Post{})
      ...> EctoShorts.CommonSchema.get_schema_metadata(changeset)
      %Ecto.Schema.Metadata{schema: EctoShorts.Schema.Post, source: "posts", state: :built}

  See also `put_schema_metadata/2` and `get_schema_prefix/1`.
  """
  @spec get_schema_metadata(source) :: Ecto.Schema.Metadata.t()
  def get_schema_metadata(%{data: %{__meta__: meta}} = _changeset), do: meta
  def get_schema_metadata(%{__meta__: meta} = _schema_struct), do: meta
  def get_schema_metadata(source), do: source |> build_struct() |> get_schema_metadata()

  @doc group: "Schema introspection"
  @doc """
  Invokes the `__schema__/1` reflection function with one argument.

  Returns the result of calling `schema.__schema__(arg)`, or `nil` when
  the source has no schema.

  ## Examples

      iex> EctoShorts.CommonSchema.get_schema_reflection(EctoShorts.Schema.Post, :source)
      "posts"

      iex> EctoShorts.CommonSchema.get_schema_reflection(EctoShorts.Schema.Post, :fields)
      [:id, :title, :body, :published, :views, :inserted_at, :updated_at]

      iex> EctoShorts.CommonSchema.get_schema_reflection(EctoShorts.Schema.Post, :primary_key)
      [:id]

      iex> EctoShorts.CommonSchema.get_schema_reflection("posts", :fields)
      nil

  See also `get_schema_reflection/3`, `get_query_fields/2`, and `get_schema/1`.
  """
  @spec get_schema_reflection(source, atom()) :: term()
  def get_schema_reflection(source, arg) do
    with schema when schema !== nil <- get_schema(source) do
      schema.__schema__(arg)
    end
  end

  @doc group: "Schema introspection"
  @doc """
  Invokes the `__schema__/2` reflection function with two arguments.

  Returns the result of calling `schema.__schema__(arg1, arg2)`, or `nil`
  when the source has no schema.

  ## Examples

      iex> EctoShorts.CommonSchema.get_schema_reflection(EctoShorts.Schema.Post, :type, :title)
      :string

      iex> EctoShorts.CommonSchema.get_schema_reflection(EctoShorts.Schema.Post, :type, :views)
      :integer

      iex> EctoShorts.CommonSchema.get_schema_reflection(EctoShorts.Schema.Post, :association, :author)
      %Ecto.Association.BelongsTo{...}

      iex> EctoShorts.CommonSchema.get_schema_reflection("posts", :type, :title)
      nil

  See also `get_schema_reflection/2`, `get_query_fields/2`, and `get_schema/1`.
  """
  @spec get_schema_reflection(source, atom(), atom()) :: term()
  def get_schema_reflection(source, arg1, arg2) do
    with schema when schema !== nil <- get_schema(source) do
      schema.__schema__(arg1, arg2)
    end
  end

  @doc group: "Schema introspection"
  @doc """
  Returns the list of fields to use when building insert or update maps.

  Checks the `:query_fields` option in `opts` first. When absent, falls back
  to `schema.__schema__(:query_fields)`, which is the list of fields that Ecto
  considers writable (all fields except virtual and read-only ones).

  This is the field list used internally by `EctoShorts.CommonParams` when
  converting params for `insert_all` and `update_all`.

  ## Examples

      iex> EctoShorts.CommonSchema.get_query_fields([], EctoShorts.Schema.Post)
      [:id, :title, :body, :published, :views, :inserted_at, :updated_at]

      iex> EctoShorts.CommonSchema.get_query_fields([query_fields: [:title, :body]], EctoShorts.Schema.Post)
      [:title, :body]

  See also `get_schema_reflection/2`.
  """
  @spec get_query_fields(keyword(), source) :: list(atom())
  def get_query_fields(opts, source) do
    Keyword.get(opts, :query_fields, get_schema_reflection(source, :query_fields))
  end

  @doc group: "Struct and changeset"
  @doc """
  Updates the metadata on a schema struct.

  Accepts a source or a schema struct. When given a source, builds a
  struct first. Merges the provided attributes into the existing
  metadata.

  ## Options

    * `:context` - the Ecto context.
    * `:prefix` - the database prefix.
    * `:source` - the table name.
    * `:state` - the Ecto state (`:built`, `:loaded`, etc.).

  ## Examples

      iex> post = %EctoShorts.Schema.Post{}
      ...> updated = EctoShorts.CommonSchema.put_schema_metadata(post, state: :loaded, source: "archived_posts")
      ...> updated.__meta__.state
      :loaded

      iex> post = %EctoShorts.Schema.Post{}
      ...> updated = EctoShorts.CommonSchema.put_schema_metadata(post, prefix: "tenant_1")
      ...> updated.__meta__.prefix
      "tenant_1"

  See also `get_schema_metadata/1` and `create_schema_struct/1`.
  """
  @spec put_schema_metadata(source | struct(), keyword() | map()) :: struct()
  def put_schema_metadata(source_or_schema_struct, attrs \\ %{})

  def put_schema_metadata(%{__meta__: meta} = schema_struct, attrs) do
    Ecto.put_meta(schema_struct,
      context: attrs[:context] || meta.context,
      prefix: attrs[:prefix] || meta.prefix,
      source: attrs[:source] || meta.source,
      state: attrs[:state] || meta.state || :loaded
    )
  end

  def put_schema_metadata(source, attrs) do
    source
    |> build_struct()
    |> put_schema_metadata(attrs)
  end

  @doc group: "Struct and changeset"
  @doc """
  Creates a schema struct from a source.

  Alias for `build_struct/1`.

  See also `build_struct/1` and `put_schema_metadata/2`.
  """
  @spec create_schema_struct(source) :: struct()
  def create_schema_struct(source) do
    build_struct(source)
  end

  @doc group: "Struct and changeset"
  @doc """
  Builds a schema struct from a source.

  Accepts a `{source, schema}` tuple or any source that can be normalized.
  Returns a struct with metadata set.

  ## Examples

      iex> struct = EctoShorts.CommonSchema.build_struct(EctoShorts.Schema.Post)
      ...> struct.__struct__
      EctoShorts.Schema.Post

      iex> struct = EctoShorts.CommonSchema.build_struct({"custom_posts", EctoShorts.Schema.Post})
      ...> struct.__meta__.source
      "custom_posts"

      iex> struct = EctoShorts.CommonSchema.build_struct({nil, EctoShorts.Schema.Post})
      ...> struct.__struct__
      EctoShorts.Schema.Post

  See also `create_schema_struct/1`, `put_schema_metadata/2`, and `normalize_source/1`.
  """
  @spec build_struct(source) :: struct()
  def build_struct({nil, schema}) do
    struct(schema)
  end

  def build_struct({source, schema}) do
    schema
    |> struct()
    |> put_schema_metadata(state: :loaded, source: source, prefix: get_schema_prefix(schema))
  end

  def build_struct(source) do
    source
    |> normalize_source()
    |> build_struct()
  end

  @doc group: "Struct and changeset"
  @doc """
  Builds an `Ecto.Changeset` from various source/data/params combinations.

  Both 3-arity and 4-arity variants accept schema modules,
  `{source, schema}` tuples, schema structs, changesets, or plain param maps
  in flexible combinations. The goal is to always produce a changeset
  regardless of how the caller provides the data.

  When the `:changeset` option is present in `opts`, it is used instead of
  the schema's default `changeset/2`. It can be a 1-arity function
  (receives the built changeset), 2-arity (receives data and params), or
  3-arity (receives schema, data, and params).

  If no `:changeset` option is given and the schema exports `changeset/2`,
  that function is called. Otherwise falls back to `Ecto.Changeset.change/2`.

  Returns an `Ecto.Changeset`.

  ## Options

  * `:changeset` - a 1-arity, 2-arity, or 3-arity function to call instead
    of the schema's `changeset/2`.
  * `:query_fields` - list of field atoms to restrict to when creating the
    schema struct from params.

  See also `create_schema_struct/1` and `EctoShorts.CommonChanges`.
  """
  @spec create_changeset(term(), term(), keyword()) :: Ecto.Changeset.t()
  def create_changeset(%{data: %{__meta__: %{schema: schema}}} = changeset, params, opts) do
    create_changeset(schema, changeset, params, opts)
  end

  def create_changeset(%{__meta__: %{schema: schema}} = schema_struct, params, opts) do
    create_changeset(schema, schema_struct, params, opts)
  end

  def create_changeset({source, schema}, %{data: %{__meta__: _}} = changeset, opts) do
    create_changeset(schema, put_source(changeset, {source, schema}), %{}, opts)
  end

  def create_changeset({source, schema}, %{__meta__: _} = schema_struct, opts) do
    create_changeset(schema, put_source(schema_struct, {source, schema}), %{}, opts)
  end

  def create_changeset({source, schema}, params, opts) do
    create_changeset(schema, build_struct({source, schema}), params, opts)
  end

  def create_changeset(schema, %{data: %{__meta__: _}} = changeset, opts) do
    create_changeset(schema, changeset, %{}, opts)
  end

  def create_changeset(schema, %{__meta__: _} = schema_struct, opts) do
    create_changeset(schema, schema_struct, %{}, opts)
  end

  def create_changeset(schema, params, opts) do
    create_changeset(schema, build_struct(schema), params, opts)
  end

  # ---

  def create_changeset({source, schema}, %{__meta__: _} = schema_struct, params, opts) do
    create_changeset(schema, put_source(schema_struct, {source, schema}), params, opts)
  end

  def create_changeset({source, schema}, %{data: %{__meta__: _}} = changeset, params, opts) do
    create_changeset(schema, put_source(changeset, {source, schema}), params, opts)
  end

  def create_changeset(schema, data_or_changeset, params, opts) do
    if Keyword.has_key?(opts, :changeset) do
      apply_changeset!(schema, data_or_changeset, params, opts[:changeset])
    else
      if function_exported?(schema, :changeset, 2) do
        cast_params = if Keyword.keyword?(params), do: Map.new(params), else: params
        schema.changeset(data_or_changeset, cast_params)
      else
        Changeset.change(data_or_changeset, params)
      end
    end
  end

  defp apply_changeset!(schema, data_or_changeset, params, callback) do
    case callback do
      fun when is_function(fun, 3) ->
        validate_changeset!(fun.(schema, data_or_changeset, params))

      fun when is_function(fun, 2) ->
        validate_changeset!(fun.(data_or_changeset, params))

      fun when is_function(fun, 1) ->
        changeset =
          if function_exported?(schema, :changeset, 2) do
            schema.changeset(data_or_changeset, params)
          else
            Changeset.change(data_or_changeset, params)
          end

        validate_changeset!(fun.(changeset))

      term ->
        raise ArgumentError,
              "Expected the value for option :changeset to be a 1-arity, 2-arity, or 3-arity function, got: #{inspect(term)}"
    end
  end

  defp validate_changeset!(%Changeset{} = changeset), do: changeset

  defp validate_changeset!(term) do
    raise "Expected an Ecto.Changeset, got: #{inspect(term)}"
  end

  defp put_source(%{data: schema_struct} = changeset, {source, schema}) do
    %{changeset | data: put_schema_metadata(schema_struct, source: source, schema: schema)}
  end

  defp put_source(%{__meta__: _} = schema_struct, {source, schema}) do
    put_schema_metadata(schema_struct, source: source, schema: schema)
  end
end
