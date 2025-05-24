defmodule EctoShorts.Actions do
  @moduledoc """
  A simplified interface for working with your Ecto schemas using a
  map-based, data-driven approach.

  `EctoShorts.Actions` lets you query, insert, update, and delete records
  using parameters instead of the traditional Ecto query and changeset APIs.
  You describe what you want to do, and the API takes care of building the
  necessary query expressions or changesets behind the scenes.

  This leads to cleaner, more maintainable code in your codebase.

  Instead of manually writing queries like this:

      EctoShorts.Schemas.Post |> where([u], u.body == "example") |> Repo.all()

  You can write:

      EctoShorts.Actions.all(EctoShorts.Schemas.Post, %{body: "example"})

  Similarly, data inserts and updates are simplified:

      EctoShorts.Actions.create(EctoShorts.Schemas.Post, %{title: "Hello", body: "World"})
      EctoShorts.Actions.update(EctoShorts.Schemas.Post, 1, %{title: "Updated Title"})

  Each function in this module works with maps. You define what you
  want using simple parameters, and the module handles building
  the query, resolving keys, or transforming data accordingly.

  ## Filter Parameters

  The core idea behind the API is to let you describe what you're looking
  for using data. Each map expresses a set of conditions, and the API
  translates those conditions into the appropriate Ecto query expressions
  for you.

  This means you don't need to write query logic directly. Instead, you
  focus on describing your intent, and EctoShorts handles the transformation.

  For example:

      %{body: "Jane"}
      # Matches records where `name` equals "Jane"

      %{title: %{ilike: "post"}}
      # Case-insensitive match on the `title` field

      %{comments: %{body: %{ilike: "example"}}}
      # Joins the `comments` association and applies a case-insensitive filter on the body

      %{inserted_at: %{gt: ~N[2023-01-01 00:00:00]}}
      # Matches records inserted after January 1, 2023

  You can compose deeply nested filters, use operators like `:gt`, `:lt`, `:in`,
  and filter on associated tables without needing to write `join` or `where`
  clauses manually.

  This approach makes your application logic simpler to write and easier to
  maintain, especially when filters are built dynamically from user input or
  external sources.

  ## Batching

  Batching lets you fetch many records at once using a list of maps. Each
  map represents a distinct set of criteria. Instead of running separate
  queries for each item, the API builds a single query using OR conditions
  to return everything in one operation.

  You describe what you want to find, and EctoShorts builds a single Ecto
  query to fetch all results.

  For example:

      EctoShorts.Actions.batch_find(EctoShorts.Schemas.Post, [
        %{author_id: 1, status: "published"},
        %{author_id: 2, status: "draft"}
      ])

  Each map describes its own match condition. The function returns all
  records that match at least one of them.

  Batching is especially helpful when resolving fields in GraphQL APIs,
  loading related data in bulk, or handling incoming parameters that
  need to be mapped to existing records efficiently.

  ## Multi API

  Multi operations let you group together several changes like inserts,
  updates, or deletes and run them inside a single database transaction.

  Each action is executed sequentially in the order provided. If any step
  fails (for example, due to a validation error), the entire set of changes
  is rolled back automatically.

  This makes the Multi API especially useful when you need to apply a group
  of related changes where all or nothing should happen.

  For example:

      EctoShorts.Actions.create_many(EctoShorts.Schemas.Post, [%{title: "example"}])

  Each entry is processed in order, and all changes are wrapped in a transaction.
  You stay focused on describing what changes need to happen, and the underlying
  logic is handled for you.

  ## Shared Options

  Most functions support these shared options:

    - `:repo` — Specifies the Ecto repo module to use. The options passed
      at runtime are checked first and then the application environment.
      If neither is present, an error is raised.

    - `:replica` — Routes read operations to a read replica. This is useful
      if your application uses replicas to offload traffic from the primary
      database.
  """

  alias EctoShorts.{
    Actions.Error,
    CommonFilters,
    CommonParams,
    CommonSchema,
    Config,
    Utils
  }

  @type multi :: Ecto.Multi.t()
  @type query :: Ecto.Query.t()
  @type schema :: Ecto.Queryable.t()
  @type source :: binary()
  @type schema_source :: {source(), schema()}
  @type queryable_input :: schema() | schema_source()
  @type query_input :: query() | queryable_input()
  @type changeset :: Ecto.Changeset.t()
  @type schema_data :: Ecto.Schema.t()
  @type changeset_input :: schema_data() | changeset()
  @type maybe_list_of_schema_data :: schema_data() | list(schema_data())
  @type schema_data_or_params :: schema_data() | map()
  @type load_data :: map() | Keyword.t() | {list(), list()}
  @type insert_all_response :: {non_neg_integer(), nil | [term()]}
  @type update_all_response :: {non_neg_integer(), nil | [term()]}
  @type delete_all_response :: {non_neg_integer(), nil | [term()]}

  @type preloads :: atom() | keyword() | list()
  @type aggregate_options :: :avg | :count | :max | :min | :sum

  @type match_keys :: atom() | list(atom())
  @type batch_id :: map()
  @type batch_params :: list(params() | {params(), params()} | {schema_data(), params()})
  @type batch_results :: %{optional(batch_id()) => schema_data()}

  @type id :: integer() | binary()
  @type key :: atom()
  @type params :: map()
  @type stream :: Enumerable.t()
  @type opts :: keyword()

  @doc group: "Schema API"
  @doc since: "2.5.0"
  @doc """
  Loads data into a schema or a map.
  """
  @spec load(schema_data_or_params(), load_data()) :: schema_data() | map()
  @spec load(schema_data_or_params(), load_data(), opts()) :: schema_data() | map()
  def load(schema_data_or_params, data, opts \\ []) do
    Config.repo!(opts).load(schema_data_or_params, data)
  end

  @doc group: "Query API"
  @doc since: "2.5.0"
  @doc """
  Returns `true` if there exists an entry that matches the given queryable
  otherwise `false`.

  ## Examples

      iex> EctoShorts.Actions.exists?(EctoShorts.Schemas.Post)
  """
  @spec exists?(schema()) :: maybe_list_of_schema_data()
  @spec exists?(schema(), opts()) :: maybe_list_of_schema_data()
  def exists?(schema, opts \\ []) do
    Config.replica!(opts).exists?(schema, opts)
  end

  @doc group: "Schema API"
  @doc since: "2.5.0"
  @doc """
  Preloads associations onto a struct or list of structs.

  ## Options

  This function supports the `:repo` option, which is described in
  the [Shared Options](#module-shared-options) section of the
  module documentation.

  ## Examples

      # Preload a single association on one record
      iex> EctoShorts.Actions.preload(%EctoShorts.Schemas.Post{}, [:comments])

      # Preload multiple associations on a list of records
      iex> EctoShorts.Actions.preload(%EctoShorts.Schemas.Post{}, [comments: :authors])
  """
  @spec preload(maybe_list_of_schema_data(), preloads(), opts()) :: maybe_list_of_schema_data()
  def preload(maybe_list_of_schema_data, preloads, opts \\ []) do
    opts = Keyword.merge(default_opts(), opts)

    Config.replica!(opts).preload(maybe_list_of_schema_data, preloads, opts)
  end

  @doc group: "Schema API"
  @doc since: "2.5.0"
  @doc """
  Reloads a given schema or schema list from the database.

  When using with lists, it is expected that all of the structs in the
  list belong to the same schema. Ordering is guaranteed to be kept.
  Results not found in the database will be returned as `nil`.

  ## Examples

      iex> {:ok, post} = EctoShorts.Actions.create(EctoShorts.Schemas.Post, %{body: "example"})
      ...> EctoShorts.Actions.reload(post)

      iex> {:ok, post} = EctoShorts.Actions.create(EctoShorts.Schemas.Post, %{body: "example"})
      ...> EctoShorts.Actions.reload([post])
  """
  @spec reload(maybe_list_of_schema_data()) :: maybe_list_of_schema_data()
  @spec reload(maybe_list_of_schema_data(), opts()) :: maybe_list_of_schema_data()
  def reload(maybe_list_of_schema_data, opts \\ []) do
    opts = Keyword.merge(default_opts(), opts)

    Config.replica!(opts).reload(maybe_list_of_schema_data, opts)
  end

  @doc group: "Schema API"
  @doc since: "2.5.0"
  @doc """
  Similar to `reload/2`, but raises when something is not found.

  When using with lists, ordering is guaranteed to be kept.

  ## Examples

      iex> {:ok, post} = EctoShorts.Actions.create(EctoShorts.Schemas.Post, %{body: "example"})
      ...> EctoShorts.Actions.reload!(post)

      iex> {:ok, post} = EctoShorts.Actions.create(EctoShorts.Schemas.Post, %{body: "example"})
      ...> EctoShorts.Actions.reload!([post])
  """
  @spec reload!(maybe_list_of_schema_data()) :: maybe_list_of_schema_data()
  @spec reload!(maybe_list_of_schema_data(), opts()) :: maybe_list_of_schema_data()
  def reload!(maybe_list_of_schema_data, opts \\ []) do
    opts = Keyword.merge(default_opts(), opts)

    Config.replica!(opts).reload!(maybe_list_of_schema_data, opts)
  end

  @doc group: "Batch API"
  @doc since: "2.5.0"
  @doc """
  Loads records that match a list of input parameters and returns
  them alongside each input.

  This function is useful when you have a list of values typically
  maps or `{input, context}` tuples and want to fetch all records
  that match them using a single database query.

  Each input is then returned along with its corresponding loaded
  record, allowing you to process the data in the same structure
  it was received.

  ## Options

  This function supports the `:repo` option, which is described in
  the [Shared Options](#module-shared-options) section of the
  module documentation.

  ## Examples

      # Find posts for a list of lookup maps
      iex> EctoShorts.Actions.batch_load(EctoShorts.Schemas.Post, [%{author_id: 1}, %{author_id: 2}])

      # Load users and preserve the original input
      iex> EctoShorts.Actions.batch_load(EctoShorts.Schemas.Post, [%{body: "example"}])
  """
  @spec batch_load(query_input(), match_keys(), batch_params()) :: batch_params()
  @spec batch_load(query_input(), match_keys(), batch_params(), opts()) :: batch_params()
  def batch_load(query_input, match_keys \\ :primary_key, params_list, opts \\ []) do
    match_keys = normalize_match_keys(query_input, match_keys)

    case filter_and_index_batch_params(params_list, query_input, match_keys) do
      {[], _} ->
        params_list

      {batch_params, batch_lookup} ->
        with batch_results <-
               batch(query_input, match_keys, batch_params, opts) do
          merge_batch_results(
            params_list,
            batch_lookup,
            batch_results
          )
        end
    end
  end

  @doc false
  def merge_batch_results(params_list, batch_lookup, batch_results) do
    Enum.reduce(batch_lookup, params_list, fn {batch_id, idx}, params_list ->
      record = Map.fetch!(batch_results, batch_id)

      case get_in(params_list, [Access.at!(idx)]) do
        {_, params} -> put_in(params_list, [Access.at!(idx)], {record, params})
        params -> put_in(params_list, [Access.at!(idx)], {record, params})
      end
    end)
  end

  @doc false
  def filter_and_index_batch_params(params_list, query_input, match_keys) do
    params_list
    |> Enum.with_index()
    |> Enum.reduce({[], %{}}, &prepare_batch_params(&1, query_input, match_keys, &2))
  end

  defp prepare_batch_params({{data, _}, _idx}, _query_input, _match_keys, {acc, metadata})
       when is_struct(data) do
    {acc, metadata}
  end

  defp prepare_batch_params({{params, _}, idx}, query_input, match_keys, {acc, metadata}) do
    prepare_batch_params({params, idx}, query_input, match_keys, {acc, metadata})
  end

  defp prepare_batch_params({data, _idx}, _query_input, _match_keys, {acc, metadata})
       when is_struct(data) do
    {acc, metadata}
  end

  defp prepare_batch_params({params, idx}, query_input, match_keys, {acc, metadata}) do
    if has_all_keys?(match_keys, params) do
      batch_id = match_id(query_input, match_keys, params)

      {[params | acc], Map.put(metadata, batch_id, idx)}
    else
      {acc, metadata}
    end
  end

  defp prepare_batch_params(_term, _query_input, _match_keys, {acc, metadata}) do
    {acc, metadata}
  end

  @doc group: "Batch API"
  @doc """
  Finds all records that match any of the given filter parameters.

  Each map in the list is treated as an individual filter using an
  OR condition, and the query returns all records that match at
  least one of them.

  ## Options

  This function supports the `:repo` and `:replica` options, which
  are described in the [Shared Options](#module-shared-options)
  section of the module documentation.

  ## Examples

      # Find all users matching any of the filter criteria
      iex> EctoShorts.Actions.batch_find(EctoShorts.Schemas.Post, [:title], [%{title: "finds_record_by_title_one"}, %{title: "or_title_two"}])
  """
  @spec batch_find(query_input(), match_keys(), list(params())) ::
          {:ok, list(schema_data())} | {:error, any()}
  @spec batch_find(query_input(), match_keys(), list(params()), opts()) ::
          {:ok, list(schema_data())} | {:error, any()}
  def batch_find(query_input, match_keys \\ :primary_key, params_list, opts \\ []) do
    match_keys = normalize_match_keys(query_input, match_keys)

    batch_results = batch(query_input, match_keys, params_list, opts)

    params_list
    |> Enum.with_index()
    |> Utils.reduce_all(fn {params, i} ->
      batch_id = match_id(query_input, match_keys, params)

      case Map.get(batch_results, batch_id) do
        nil ->
          {:error,
           Error.call(:not_found, "Record not found.", %{
             query: query_input,
             params: params_list,
             failed_value: params,
             position: i,
             match_keys: match_keys
           })}

        record ->
          {:ok, record}
      end
    end)
  end

  @doc group: "Batch API"
  @doc """
  Performs a batched query and returns a map of results keyed by input
  parameters.

  This function combines all parameter sets into a single query and returns
  a result map that preserves the association between the original inputs
  and the fetched records.

      EctoShorts.Actions.batch(
        EctoShorts.Schemas.Post,
        [:title],
        [
          %{title: "First Post"},
          %{title: "Second Post"}
        ]
      )

  Returns:

      %{
        %{title: "First Post"} => %EctoShorts.Schemas.Post{title: "First Post"},
        %{title: "Second Post"} => %EctoShorts.Schemas.Post{title: "Second Post"}
      }

  ## Composite keys

  You can specify a list of keys to match on using the `keys` argument:

      EctoShorts.Actions.batch(
        EctoShorts.Schemas.Post,
        [:org_id, :email],
        [
          %{org_id: 1, title: "admin@example.com"},
          %{org_id: 2, title: "editor@example.com"}
        ]
      )

  This ensures each input map is matched against all specified fields as a unique
  composite key.

  If no `keys` is provided, the schema's primary key is used automatically.
  If your schema does not define a primary key and no batch key is given,
  this function will raise an error.

  ## Examples

      iex> EctoShorts.Actions.batch(EctoShorts.Schemas.Post, [:title], [%{title: "post_title"}])
  """
  @spec batch(query_input(), match_keys(), list(params())) :: batch_results()
  @spec batch(query_input(), match_keys(), list(params()), opts()) :: batch_results()
  def batch(query_input, match_keys \\ :primary_key, params_list, opts \\ [])
      when is_list(params_list) do
    match_keys = normalize_match_keys(query_input, match_keys)

    {batch_results, duplicates} =
      query_input
      |> all(%{or_where: params_list}, opts)
      |> build_batch_results(query_input, match_keys)

    if duplicates === [] do
      batch_results
    else
      formatted_duplicates =
        duplicates
        |> Enum.group_by(& &1)
        |> Enum.map_join("\n", fn {k, v} -> "   - key=#{k}, count=#{length(v)}" end)

      raise """
      Expected one record to match the batch id.

      got:

      #{formatted_duplicates}
      """
    end
  end

  @doc false
  def build_batch_results(records, query_input, match_keys) do
    Enum.reduce(records, {%{}, []}, fn record, {batch_results, duplicates} ->
      batch_id = match_id(query_input, match_keys, record)

      case Map.get(batch_results, batch_id) do
        nil -> {Map.put(batch_results, batch_id, record), duplicates}
        _ -> {batch_results, [batch_id | duplicates]}
      end
    end)
  end

  @doc false
  def match_id(query_input, match_keys, data) do
    {_, schema} = CommonSchema.get_schema_source(query_input)

    if has_all_keys?(match_keys, data) do
      Map.take(data, match_keys)
    else
      raise ArgumentError,
            """
            Match keys not found.

            schema:

            #{inspect(schema)}

            keys:

            #{inspect(match_keys)}

            data:

            #{inspect(data, pretty: true)}
            """
    end
  end

  @doc false
  def normalize_match_keys(query_input, :primary_key) do
    case CommonSchema.get_schema_reflection(query_input, :primary_key) do
      [] -> [:id]
      key -> key
    end
  end

  def normalize_match_keys(_query_input, value) do
    case List.wrap(value) do
      [] -> [:id]
      key -> key
    end
  end

  defp has_all_keys?([], _data) do
    false
  end

  defp has_all_keys?(keys, data) do
    Enum.all?(keys, &(Map.get(data, &1) !== nil))
  end

  @doc group: "Schema API"
  @doc since: "2.5.0"
  @doc """
  Inserts multiple records into the database.

  Each entry in the `params_list` is validated using the schema's
  `changeset/2` function unless `validate: false` is passed.

  ## Conflict Handling

  If a record includes all primary key fields, it will be treated as
  an upsert.

  It automatically applies:

    * `:conflict_target` set to the primary key.

    * `:on_conflict` set to `{:replace, keys}` where `keys` are all
      fields except the primary key and `:inserted_at`.

  This allows partial updates on existing records during bulk inserts
  while skipping fields that cannot be `nil`.

  ## Preloading Existing Records

  Sometimes, you may need to preload existing records so that the
  changeset has access to required values:

    * If your changeset logic uses data from the existing row (e.g.
      to preserve an audit field).

    * If a required field cannot be overwritten by `nil`, and passing
      it directly would cause a constraint error.

  You can enable this behavior with the `:batch_load` option:

      EctoShorts.Actions.insert_all(EctoShorts.Schemas.Post, params_list, batch_load: :primary_key)

  This will call `batch_load/4` and transform each param into
  `{existing_record, new_params}` tuples when a match is found.

  ## Options

  See the [Shared Options](EctoShorts.Actions.html#module-shared-options).

  You can also pass any options accepted by [`Ecto.Repo.insert_all/3`](https://hexdocs.pm/ecto/Ecto.Repo.html#c:insert_all/3).

  ## Examples

      iex> EctoShorts.Actions.insert_all(EctoShorts.Schemas.Post, [%{id: 1, body: "Jane"}], batch_load: :primary_key)
  """
  @spec insert_all(query_input(), list(params())) ::
          {:ok, insert_all_response()} | {:error, any()}
  @spec insert_all(query_input(), list(params()), opts()) ::
          {:ok, insert_all_response()} | {:error, any()}
  def insert_all(query_input, params_list, opts \\ []) do
    {_, schema} = CommonSchema.get_schema_source(query_input)

    with {:ok, inserts, insert_opts} <-
           CommonParams.convert_to_insert_all_params(
             schema,
             maybe_batch_load(query_input, params_list, opts),
             opts
           ) do
      {:ok,
       Config.repo!(opts).insert_all(
         query_input,
         inserts,
         Keyword.merge(insert_opts, opts)
       )}
    end
  end

  defp maybe_batch_load(query_input, params_list, opts) do
    cond do
      opts[:batch_load] === true ->
        batch_load(query_input, :primary_key, params_list, opts)

      Keyword.has_key?(opts, :match_keys) ->
        batch_load(query_input, opts[:match_keys], params_list, opts)

      true ->
        params_list
    end
  end

  @doc group: "Schema API"
  @doc """
  Updates multiple records that match the given filter parameters.

  This function builds a query from the given schema or queryable, applies
  filters using the `find_params`, and performs a bulk update with the
  provided `update_params`.

  Unlike `update/4`, which works on a single struct or ID, this function
  updates all matching rows in one operation. This is useful when applying
  the same update across many records.

  ## Options

  See the [Shared Options](EctoShorts.Actions.html#module-shared-options).

  You can also pass any options accepted by [`Ecto.Repo.update_all/3`](https://hexdocs.pm/ecto/Ecto.Repo.html#c:update_all/3).

  ## Examples

      iex> EctoShorts.Actions.update_all(EctoShorts.Schemas.Post, %{published: false}, %{published: true})

      iex> EctoShorts.Actions.update_all(EctoShorts.Schemas.Post, %{title: "hello"}, %{title: "world"}, repo: EctoShorts.Repo)
  """
  @spec update_all(query_input(), params(), params()) :: update_all_response()
  @spec update_all(query_input(), params(), params(), opts()) :: update_all_response()
  def update_all(query_input, find_params, update_params, opts \\ []) do
    opts = Keyword.merge(default_opts(), opts)

    updates =
      query_input
      |> CommonSchema.get_schema_source()
      |> elem(1)
      |> CommonParams.convert_to_update_all_params(update_params, opts)

    query_input
    |> CommonFilters.convert_params_to_filter(find_params, opts)
    |> Config.repo!(opts).update_all(updates, opts)
  end

  @doc group: "Query API"
  @doc """
  Deletes all records that match the given filter parameters.

  This function builds a query from the provided schema or queryable,
  applies filters using the `params`, and removes all matching records
  from the database in a single operation.

  Unlike `delete/2`, which deletes one record at a time (by ID or struct),
  `delete_all/3` is more efficient for bulk deletions and does not call
  changesets or run validations.

  ## Options

  See the [Shared Options](EctoShorts.Actions.html#module-shared-options).

  You can also pass any options accepted by
  [`Ecto.Repo.delete_all/2`](https://hexdocs.pm/ecto/Ecto.Repo.html#c:delete_all/2).

  ## Examples

      iex> EctoShorts.Actions.delete_all(EctoShorts.Schemas.Post, %{published: false})

      iex> EctoShorts.Actions.delete_all(EctoShorts.Schemas.Post, %{published: true}, repo: EctoShorts.Repo)
  """
  @spec delete_all(query_input()) :: delete_all_response()
  @spec delete_all(query_input(), params()) :: delete_all_response()
  @spec delete_all(query_input(), params(), opts()) :: delete_all_response()
  def delete_all(query_input, params \\ %{}, opts \\ []) do
    opts = Keyword.merge(default_opts(), opts)

    query_input
    |> CommonFilters.convert_params_to_filter(params, opts)
    |> Config.repo!(opts).delete_all(opts)
  end

  @doc group: "Multi API"
  @doc """
  Finds or creates many records sequentially inside a transaction.

  This function accepts a list of maps where each map is used as both
  the `find_params` and `create_params`.

  ## Options

  See the [Shared Options](EctoShorts.Actions.html#module-shared-options).

  ## Examples

      iex> EctoShorts.Actions.find_or_create_many(EctoShorts.Schemas.Post, [%{title: "title_one", body: "example"}])
  """
  @spec find_or_create_many(query_input(), list(params())) ::
          {:ok, list(schema_data())} | {:error, any()}
  @spec find_or_create_many(query_input(), list(params()), opts()) ::
          {:ok, list(schema_data())} | {:error, any()}
  def find_or_create_many(query_input, params_list, opts \\ []) do
    opts = Keyword.merge(default_opts(), opts)

    query_input
    |> multi_find_or_create(params_list, opts)
    |> Config.repo!(opts).transaction(opts)
    |> handle_multi_response()
  end

  defp multi_find_or_create(query_input, params_list, opts) do
    params_list
    |> Enum.with_index()
    |> Enum.reduce(Ecto.Multi.new(), fn {params, idx}, multi ->
      Ecto.Multi.run(multi, {:find_or_create, idx}, fn repo, _changes_so_far ->
        case query_input
             |> CommonFilters.convert_params_to_filter(params, opts)
             |> repo.one(opts) do
          nil ->
            with {:error, changeset} <-
                   query_input
                   |> create_changeset(params, opts)
                   |> repo.insert(opts) do
              {:error,
               {:conflict, "Failed to create record.",
                %{
                  query: query_input,
                  params: params_list,
                  changeset: changeset,
                  failed_value: params,
                  position: idx
                }}}
            end

          record ->
            {:ok, record}
        end
      end)
    end)
  end

  @doc group: "Multi API"
  @doc since: "2.5.0"
  @doc """
  Finds and updates many records sequentially inside a transaction.

  Each item in the input list must be either:

    * A map – used as both the `find_params` and `update_params`, or
    * A tuple `{find_params, update_params}` – allows using separate values
      for looking up and updating a record.

  ## Options

  See the [Shared Options](EctoShorts.Actions.html#module-shared-options).

  ## Examples

      iex> EctoShorts.Actions.find_and_update_many(EctoShorts.Schemas.Post, [%{id: 1, body: "updated_body"}])

      iex> EctoShorts.Actions.find_and_update_many(EctoShorts.Schemas.Post, [{%{id: 2}, %{body: "Another Update"}}])
  """
  @spec find_and_update_many(query_input(), list(params() | {params(), params()})) ::
          {:ok, list(schema_data())} | {:error, any()}
  @spec find_and_update_many(query_input(), list(params() | {params(), params()})) ::
          {:ok, list(schema_data())} | {:error, any()}
  def find_and_update_many(query_input, params_list, opts \\ []) do
    opts = Keyword.merge(default_opts(), opts)

    query_input
    |> multi_find_and_update(params_list, opts)
    |> Config.repo!(opts).transaction(opts)
    |> handle_multi_response()
  end

  defp multi_find_and_update(query_input, params_list, opts) do
    params_list
    |> Enum.with_index()
    |> Enum.reduce(Ecto.Multi.new(), fn {args, idx}, multi ->
      {find_params, update_params} = unzip_find_params(args, query_input, opts)

      Ecto.Multi.run(multi, {:find_and_update, idx}, fn repo, _changes_so_far ->
        case query_input
             |> CommonFilters.convert_params_to_filter(find_params, opts)
             |> repo.one(opts) do
          nil ->
            {:error,
             {:not_found, "Record not found.",
              %{
                query: query_input,
                params: params_list,
                failed_value: find_params,
                position: idx
              }}}

          record ->
            with {:error, changeset} <-
                   query_input
                   |> create_changeset(record, Map.merge(find_params, update_params), opts)
                   |> repo.update(opts) do
              {:error,
               {:conflict, "Failed to update record.",
                %{
                  query: query_input,
                  params: params_list,
                  changeset: changeset,
                  failed_value: update_params,
                  position: idx
                }}}
            end
        end
      end)
    end)
  end

  @doc group: "Multi API"
  @doc since: "2.5.0"
  @doc """
  Finds and upserts many records sequentially inside a transaction.

  Each item must be either:

    * A map – used as both the `find_params` and `upsert_params`, or
    * A tuple `{find_params, upsert_params}` – used to separate the values
      for lookup and update/insert.

  If any step fails (e.g., validation errors or unexpected conflicts), the entire
  transaction is rolled back.

  ## Options

  See the [Shared Options](EctoShorts.Actions.html#module-shared-options).

  ## Examples

      iex> EctoShorts.Actions.find_and_upsert_many(EctoShorts.Schemas.Post, [%{title: "title_one", body: "example"}])

      iex> EctoShorts.Actions.find_and_upsert_many(EctoShorts.Schemas.Post, [{%{title: "title_two"}, %{body: "example"}}])
  """
  @spec find_and_upsert_many(query_input(), list(params() | {params(), params()})) ::
          {:ok, list(schema_data())} | {:error, any()}
  @spec find_and_upsert_many(query_input(), list(params() | {params(), params()}), opts()) ::
          {:ok, list(schema_data())} | {:error, any()}
  def find_and_upsert_many(query_input, params_list, opts \\ []) do
    opts = Keyword.merge(default_opts(), opts)

    query_input
    |> multi_find_and_upsert(params_list, opts)
    |> Config.repo!(opts).transaction(opts)
    |> handle_multi_response()
  end

  defp multi_find_and_upsert(query_input, params_list, opts) do
    params_list
    |> Enum.with_index()
    |> Enum.reduce(Ecto.Multi.new(), fn {args, idx}, multi ->
      {find_params, upsert_params} = unzip_find_params(args, query_input, opts)

      Ecto.Multi.run(multi, {:find_and_upsert, idx}, fn repo, _changes_so_far ->
        case query_input
             |> CommonFilters.convert_params_to_filter(find_params, opts)
             |> repo.one(opts) do
          nil ->
            with {:error, changeset} <-
                   query_input
                   |> create_changeset(Map.merge(find_params, upsert_params), opts)
                   |> repo.insert(opts) do
              {:error,
               {:conflict, "Failed to create record.",
                %{
                  query: query_input,
                  params: params_list,
                  changeset: changeset,
                  position: idx
                }}}
            end

          record ->
            with {:error, changeset} <-
                   query_input
                   |> create_changeset(record, Map.merge(find_params, upsert_params), opts)
                   |> repo.update(opts) do
              {:error,
               {:conflict, "Failed to update record.",
                %{
                  query: query_input,
                  params: params_list,
                  changeset: changeset,
                  failed_value: upsert_params,
                  position: idx
                }}}
            end
        end
      end)
    end)
  end

  defp unzip_find_params({find_params, params}, _query_input, _opts) do
    {find_params, params}
  end

  defp unzip_find_params(params, query_input, opts) do
    {maybe_filter_queryable_params(params, query_input, opts), params}
  end

  @doc group: "Multi API"
  @doc since: "2.5.0"
  @doc """
  Creates many records sequentially inside a transaction.

  ## Options

  See the [Shared Options](EctoShorts.Actions.html#module-shared-options).

  ## Examples

      iex> EctoShorts.Actions.create_many(EctoShorts.Schemas.Post, [%{title: "title_two", body: "example"}])
  """
  @spec create_many(queryable_input(), list(params())) ::
          {:ok, list(schema_data())} | {:error, any()}
  @spec create_many(queryable_input(), list(params()), opts()) ::
          {:ok, list(schema_data())} | {:error, any()}
  def create_many(query_input, params_list, opts \\ []) do
    opts = Keyword.merge(default_opts(), opts)

    query_input
    |> multi_insert(params_list, opts)
    |> Config.repo!(opts).transaction(opts)
    |> handle_multi_response()
  end

  defp multi_insert(query_input, params_list, opts) do
    params_list
    |> Enum.with_index()
    |> Enum.reduce(Ecto.Multi.new(), fn {params, idx}, multi ->
      Ecto.Multi.run(multi, {:create, idx}, fn repo, _changes_so_far ->
        with {:error, changeset} <-
               query_input
               |> create_changeset(params, opts)
               |> repo.insert(opts) do
          {:error,
           {:conflict, "Failed to create record.",
            %{
              query: query_input,
              params: params_list,
              changeset: changeset,
              failed_value: params,
              position: idx
            }}}
        end
      end)
    end)
  end

  @doc group: "Multi API"
  @doc since: "2.5.0"
  @doc """
  Finds many records sequentially inside a transaction.

  ## Options

  See the [Shared Options](EctoShorts.Actions.html#module-shared-options).

  ## Examples

      iex> EctoShorts.Actions.find_many(EctoShorts.Schemas.Post, [%{title: "title_one"}, %{title: "title_two"}])
  """
  @spec find_many(query_input(), list(params())) ::
          {:ok, list(schema_data())} | {:error, any()}
  @spec find_many(query_input(), list(params()), opts()) ::
          {:ok, list(schema_data())} | {:error, any()}
  def find_many(query_input, params_list, opts \\ []) do
    opts = Keyword.merge(default_opts(), opts)

    query_input
    |> multi_find(params_list, opts)
    |> Config.repo!(opts).transaction(opts)
    |> handle_multi_response()
  end

  defp multi_find(query_input, params_list, opts) do
    params_list
    |> Enum.with_index()
    |> Enum.reduce(Ecto.Multi.new(), fn {params, idx}, multi ->
      Ecto.Multi.run(multi, {:find, idx}, fn repo, _changes_so_far ->
        case query_input
             |> CommonFilters.convert_params_to_filter(params, opts)
             |> repo.one(opts) do
          nil ->
            {:error,
             {:not_found, "Record not found.",
              %{
                query: query_input,
                params: params_list,
                failed_value: params,
                position: idx
              }}}

          record ->
            {:ok, record}
        end
      end)
    end)
  end

  @doc group: "Multi API"
  @doc """
  Deletes many records sequentially inside a transaction given a
  list of structs or changesets.

  ## Options

  See the [Shared Options](EctoShorts.Actions.html#module-shared-options).

  ## Examples

      iex> {:ok, posts} = EctoShorts.Actions.create_many(EctoShorts.Schemas.Post, [%{title: "post_title_one"}, %{title: "post_title_two"}])
      ...> EctoShorts.Actions.delete_many(posts)
  """
  @spec delete_many(list(changeset_input())) ::
          {:ok, list(schema_data())} | {:error, any()}
  @spec delete_many(list(changeset_input()), opts()) ::
          {:ok, list(schema_data())} | {:error, any()}
  def delete_many(entries, opts \\ []) do
    opts = Keyword.merge(default_opts(), opts)

    entries
    |> multi_delete(opts)
    |> Config.repo!(opts).transaction(opts)
    |> handle_multi_response()
  end

  defp multi_delete(entries, opts) do
    entries
    |> Enum.with_index()
    |> Enum.reduce(Ecto.Multi.new(), fn {entry, idx}, multi ->
      Ecto.Multi.run(multi, {:create, idx}, fn repo, _changes_so_far ->
        with {:error, changeset} <-
               entry
               |> create_changeset(%{}, opts)
               |> repo.delete(opts) do
          {:error,
           {:conflict, "Failed to delete record.",
            %{
              query: CommonSchema.get_schema_metadata(entry),
              params: entries,
              changeset: changeset,
              failed_value: entry,
              position: idx
            }}}
        end
      end)
    end)
  end

  @doc group: "Query API"
  @doc """
  Finds a record using one set of parameters, and creates it using
  another if not found.

  This function allows you to use different values for searching and
  inserting. It first attempts to find a record using `find_params`.
  If no match is found, it merges `find_params` with `create_params`
  and inserts a new record.

  ## Options

  See the [Shared Options](EctoShorts.Actions.html#module-shared-options).

  ## Examples

      iex> EctoShorts.Actions.find_and_create(EctoShorts.Schemas.Post, %{title: "title_one"}, %{title: "title_one", body: "new_post"})
  """
  @spec find_and_create(query_input(), params(), params()) ::
          {:ok, schema_data()} | {:error, changeset() | any()}
  @spec find_and_create(query_input(), params(), params(), opts()) ::
          {:ok, schema_data()} | {:error, changeset() | any()}
  def find_and_create(query_input, find_params, create_params, opts \\ []) do
    with {:error, %{code: :not_found}} <- find(query_input, find_params, opts) do
      create(query_input, create_params, opts)
    end
  end

  @doc group: "Query API"
  @doc """
  Finds a record using `find_params` and updates it with the combined
  data from both `find_params` and `update_params`.

  If the record is not found, an error is returned.

  ## Options

  See the [Shared Options](EctoShorts.Actions.html#module-shared-options).

  ## Examples

      iex> EctoShorts.Actions.find_and_update(EctoShorts.Schemas.Post, %{id: 1}, %{body: "updated_body"})
  """
  @spec find_and_update(query_input(), params(), params()) ::
          {:ok, schema_data()} | {:error, changeset() | any()}
  @spec find_and_update(query_input(), params(), params(), opts()) ::
          {:ok, schema_data()} | {:error, changeset() | any()}
  def find_and_update(query_input, find_params, update_params, opts \\ []) do
    with {:ok, record} <- find(query_input, find_params, opts) do
      update(query_input, record, update_params, opts)
    end
  end

  @doc group: "Query API"
  @doc """
  Finds a record using `find_params` and updates it with `update_params`.
  If the record is not found, a new one is created using the combined
  params.

  If an update fails (e.g. due to validation errors), an error is
  returned. If a create fails, an error is also returned.

  ## Options

  See the [Shared Options](EctoShorts.Actions.html#module-shared-options).

  ## Examples

      iex> EctoShorts.Actions.find_and_upsert(EctoShorts.Schemas.Post, %{title: "fira@example.com"}, %{body: "post_body"})
  """
  @spec find_and_upsert(query_input(), params(), params()) ::
          {:ok, schema_data()} | {:error, changeset() | any()}
  @spec find_and_upsert(query_input(), params(), params(), opts()) ::
          {:ok, schema_data()} | {:error, changeset() | any()}
  def find_and_upsert(query_input, find_params, update_params, opts \\ []) do
    case find(query_input, find_params, opts) do
      {:ok, record} ->
        update(query_input, record, update_params, opts)

      {:error, %{code: :not_found}} ->
        create(query_input, Map.merge(find_params, update_params), opts)

      {:error, _} = e ->
        e
    end
  end

  @doc group: "Query API"
  @doc """
  Finds a record by the given parameters and deletes it.

  This function combines a `find/3` followed by a `delete/2`. If the
  record is found, it is deleted. If no matching record is found,
  an error is returned.

  ## Options

  See the [Shared Options](EctoShorts.Actions.html#module-shared-options).

  ## Examples

      iex> EctoShorts.Actions.find_and_delete(EctoShorts.Schemas.Post, %{id: 1})

      iex> EctoShorts.Actions.find_and_delete({"posts", EctoShorts.Schemas.Post}, %{title: "fira@example.com"}, repo: EctoShorts.Repo)
  """
  @spec find_and_delete(query_input(), params()) ::
          {:ok, schema_data()} | {:error, changeset() | any()}
  @spec find_and_delete(query_input(), params(), opts()) ::
          {:ok, schema_data()} | {:error, changeset() | any()}
  def find_and_delete(query_input, find_params, opts \\ []) do
    with {:ok, record} <- find(query_input, find_params, opts) do
      delete(record, opts)
    end
  end

  @doc group: "Query API"
  @doc """
  Finds a record by the given parameters or creates it if not found.

  This function checks if a record exists, and creates it if it does not.

  The same parameter map is used for both the find and create steps.

  ## Options

  See the [Shared Options](EctoShorts.Actions.html#module-shared-options).

  ### Additional Options

    * `:drop_associations` – When true (default), any schema associations
      in the parameter map will be excluded before the find query. This
      avoids unexpected behavior due to association joins during lookup.

  ## Examples

      iex> EctoShorts.Actions.find_or_create(EctoShorts.Schemas.Post, %{title: "example"})

      iex> EctoShorts.Actions.find_or_create({"posts", EctoShorts.Schemas.Post}, %{title: "fira@example.com"}, repo: EctoShorts.Repo)
  """
  @spec find_or_create(query_input(), params()) ::
          {:ok, schema_data()} | {:error, changeset() | any()}
  @spec find_or_create(query_input(), params(), opts()) ::
          {:ok, schema_data()} | {:error, changeset() | any()}
  def find_or_create(query_input, params, opts \\ []) do
    with {:error, %{code: :not_found}} <-
           find(
             query_input,
             maybe_filter_queryable_params(params, query_input, opts),
             opts
           ) do
      create(query_input, params, opts)
    end
  end

  @doc group: "Query API"
  @doc """
  Fetches a single record by its primary key.

  This is a convenience wrapper around [`Ecto.Repo.get/3`](https://hexdocs.pm/ecto/Ecto.Repo.html#c:get/3), with added support
  for using a replica repo when provided.

  ## Options

  See the [Shared Options](EctoShorts.Actions.html#module-shared-options).

  All options accepted by [`Ecto.Repo.get/3`](https://hexdocs.pm/ecto/Ecto.Repo.html#c:get/3) are also supported.

  ## Examples

      iex> EctoShorts.Actions.get(EctoShorts.Schemas.Post, 1)

      iex> EctoShorts.Actions.get(EctoShorts.Schemas.Post, 1, repo: EctoShorts.Repo)

      iex> EctoShorts.Actions.get({"posts", EctoShorts.Schemas.Post}, 1, replica: EctoShorts.Repo)
  """
  @spec get(query_input(), id()) :: schema_data() | nil
  @spec get(query_input(), id(), opts()) :: schema_data() | nil
  def get(query_input, id, opts \\ []) do
    opts = Keyword.merge(default_opts(), opts)

    Config.replica!(opts).get(query_input, id, opts)
  end

  @doc group: "Query API"
  @doc """
  Fetches all records using the given filters and options.

  This is a convenience version of `all/3` that accepts either a map of filters
  or a keyword list that mixes filters with options like `:repo` or `:replica`.

  If a map is given, it is treated as filter parameters.

  If a keyword list is given, all non-option keys are treated as filters, and
  recognized options like `:repo`, `:replica`, `:order_by`, and `:group_by` are extracted.

  ## Options

  See the [Shared Options](EctoShorts.Actions.html#module-shared-options).

  ## Examples

      iex> EctoShorts.Actions.all(EctoShorts.Schemas.Post, %{id: 1})

      iex> EctoShorts.Actions.all(EctoShorts.Schemas.Post, id: 1, repo: EctoShorts.Repo)

      iex> EctoShorts.Actions.all(EctoShorts.Schemas.Post, id: 1, replica: EctoShorts.Repo)
  """
  @spec all(query_input()) :: list(schema_data())
  @spec all(query_input(), params()) :: list(schema_data())
  @spec all(query_input(), opts()) :: list(schema_data())
  def all(query_input, params_or_opts \\ [])

  def all(query_input, params) when is_map(params) do
    all(query_input, params, [])
  end

  def all(query_input, opts) do
    params =
      opts
      |> Keyword.drop([:repo, :replica])
      |> Map.new()

    all(query_input, params, Keyword.take(opts, [:repo, :replica]))
  end

  @doc group: "Query API"
  @doc """
  Fetches all records matching the given query and filter parameters.

  ## Options

  See the [Shared Options](EctoShorts.Actions.html#module-shared-options).

  Additional supported options:

    * `:group_by` – Group results by one or more fields.
    * `:order_by` – Sort results by one or more fields.

  All options accepted by [`Ecto.Repo.all/2`](https://hexdocs.pm/ecto/Ecto.Repo.html#c:all/2) are also supported.

  ## Examples

      iex> EctoShorts.Actions.all(EctoShorts.Schemas.Post, %{published: true})

      iex> EctoShorts.Actions.all(EctoShorts.Schemas.Post, published: true, order_by: :inserted_at, repo: EctoShorts.Repo)

      iex> EctoShorts.Actions.all({"posts", EctoShorts.Schemas.Post}, %{published: true}, replica: EctoShorts.Repo)
  """
  @spec all(query_input(), params(), opts()) :: list(schema_data())
  def all(query_input, params, opts) do
    opts = Keyword.merge(default_opts(), opts)

    params =
      params
      |> put_order_by(opts)
      |> put_group_by(opts)

    opts = Keyword.drop(opts, [:order_by, :group_by])

    query_input
    |> CommonFilters.convert_params_to_filter(params, opts)
    |> Config.replica!(opts).all(opts)
  end

  @doc group: "Schema API"
  @doc """
  Inserts a new record into the database.

  This function builds a changeset from the given params and inserts it using
  the specified repo.

  If the schema defines `create_changeset/1` and no custom changeset builder
  is specified, it will be used automatically.

  ## Options

  See the [Shared Options](EctoShorts.Actions.html#module-shared-options).

  All options supported by [`Ecto.Repo.insert/2`](https://hexdocs.pm/ecto/Ecto.Repo.html#c:insert/2) are also accepted.

  ## Examples

      iex> EctoShorts.Actions.create(EctoShorts.Schemas.Post, %{body: "post_body"}, repo: EctoShorts.Repo)

      iex> EctoShorts.Actions.create({"posts", EctoShorts.Schemas.Post}, %{body: "post_body"}, repo: EctoShorts.Repo)
  """
  @spec create(queryable_input(), params()) ::
          {:ok, schema_data()} | {:error, changeset() | any()}
  @spec create(queryable_input(), params(), opts()) ::
          {:ok, schema_data()} | {:error, changeset() | any()}
  def create(query_input, params, opts \\ []) do
    opts = Keyword.merge(default_opts(), opts)

    query_input
    |> create_changeset(params, opts)
    |> Config.repo!(opts).insert(opts)
  end

  @doc group: "Query API"
  @doc """
  Fetches a single record that matches the given parameters.

  ## Options

  See the [Shared Options](EctoShorts.Actions.html#module-shared-options).

  All options accepted by [`Ecto.Repo.one/2`](https://hexdocs.pm/ecto/Ecto.Repo.html#c:one/2)
  are also supported.

  ## Examples

      iex> EctoShorts.Actions.find(EctoShorts.Schemas.Post, %{id: 1}, repo: EctoShorts.Repo)

      iex> EctoShorts.Actions.find(EctoShorts.Schemas.Post, %{title: "notfound@example.com"})

      iex> EctoShorts.Actions.find({"posts", EctoShorts.Schemas.Post}, %{id: 1})
  """
  @spec find(query_input(), params()) :: {:ok, schema_data()} | {:error, any()}
  @spec find(query_input(), params(), opts()) :: {:ok, schema_data()} | {:error, any()}
  def find(query_input, params, opts \\ [])

  def find(query_input, params, opts)
      when params === %{} and not is_struct(query_input, Ecto.Query) do
    {:error,
     Error.call(
       :not_found,
       "Record not found.",
       %{
         query: query_input,
         params: params
       },
       opts
     )}
  end

  def find(query_input, params, opts) do
    opts = Keyword.merge(default_opts(), opts)

    params =
      params
      |> put_order_by(opts)
      |> put_group_by(opts)

    opts = Keyword.drop(opts, [:order_by, :group_by])

    case query_input
         |> CommonFilters.convert_params_to_filter(params, opts)
         |> Config.replica!(opts).one(opts) do
      nil ->
        {:error,
         Error.call(
           :not_found,
           "Record not found.",
           %{
             query: query_input,
             params: params
           },
           opts
         )}

      record ->
        {:ok, record}
    end
  end

  @doc group: "Schema API"
  @doc """
  Updates a record using either an ID or an existing struct.

  This function allows you to provide either:

    * a primary key (e.g. `123`) — the record will be looked up by `id`
    * an existing struct — the update will be applied directly

  The provided `update_params` are passed through the schema's changeset
  logic and then persisted via [`Ecto.Repo.update/2`](https://hexdocs.pm/ecto/Ecto.Repo.html#c:update/2).

  ## Options

  See the [Shared Options](EctoShorts.Actions.html#module-shared-options).

  All options accepted by [`Ecto.Repo.update/2`](https://hexdocs.pm/ecto/Ecto.Repo.html#c:update/2)
  are also supported.

  ## Examples

      # Using a primary key:

      iex> EctoShorts.Actions.update(EctoShorts.Schemas.Post, 1, %{body: "New Name"})

      # Using a struct:

      iex> {:ok, post} = EctoShorts.Actions.create({"posts", EctoShorts.Schemas.PostAbstract}, %{body: "example"})
      ...> EctoShorts.Actions.update(EctoShorts.Schemas.Post, post, %{body: "updated_body"})

      # Using a tuple source:

      iex> {:ok, post} = EctoShorts.Actions.create({"posts", EctoShorts.Schemas.PostAbstract}, %{body: "example"})
      ...> EctoShorts.Actions.update({"posts", EctoShorts.Schemas.PostAbstract}, post, %{body: "updated_body"})
  """
  @spec update(query_input(), id() | schema_data(), params()) ::
          {:ok, schema_data()} | {:error, changeset() | any()}
  @spec update(query_input(), id() | schema_data(), params(), opts()) ::
          {:ok, schema_data()} | {:error, changeset() | any()}
  def update(query_input, id_or_schema_data, update_params, opts \\ [])

  def update(query_input, id, update_params, opts) when is_integer(id) or is_binary(id) do
    with {:ok, record} <- find(query_input, %{id: id}, opts) do
      update(query_input, record, update_params, opts)
    end
  end

  def update(query_input, schema_data, update_params, opts) when is_list(update_params) do
    update(query_input, schema_data, Map.new(update_params), opts)
  end

  def update(query_input, schema_data, update_params, opts) do
    opts = Keyword.merge(default_opts(), opts)

    query_input
    |> create_changeset(schema_data, update_params, opts)
    |> Config.repo!(opts).update(opts)
  end

  @doc group: "Schema API"
  @doc """
  Deletes one record when given a struct or changeset, or deletes many
  records when given a list of structs or changesets.

  When deleting many records, this function tries to delete each one
  individually. If any of them fail, the function doesn't stop and
  instead continues trying to delete the rest. Any errors that occur
  are collected and returned at the end.

  This function does **not** run inside a transaction. That means some
  records may be deleted successfully even if others fail. If you need
  an all-or-nothing guarantee where either everything is deleted or
  nothing is you can use `delete_many/3`, which wraps the operation in
  a transaction.

  ## Options

  See the [Shared Options](EctoShorts.Actions.html#module-shared-options).

  All options accepted by [`Ecto.Repo.delete/2`](https://hexdocs.pm/ecto/Ecto.Repo.html#c:delete/2)
  are also supported.

  ## Examples

      iex> {:ok, post} = EctoShorts.Actions.create(EctoShorts.Schemas.Post, %{body: "example"})
      ...> EctoShorts.Actions.delete(EctoShorts.Schemas.Post, post.id)

      iex> {:ok, post} = EctoShorts.Actions.create({"posts", EctoShorts.Schemas.PostAbstract}, %{body: "example"})
      ...> EctoShorts.Actions.delete({"posts", EctoShorts.Schemas.PostAbstract}, post.id)

      iex> {:ok, post} = EctoShorts.Actions.create(EctoShorts.Schemas.Post, %{body: "example"})
      ...> EctoShorts.Actions.delete([post])

      iex> {:ok, post} = EctoShorts.Actions.create(EctoShorts.Schemas.Post, %{body: "example"})
      ...> post |> EctoShorts.Schemas.Post.changeset(%{}) |> EctoShorts.Actions.delete()
  """
  @spec delete(changeset_input() | list(changeset_input())) ::
          {:ok, list(schema_data())} | {:error, list(changeset())} | {:error, any()}
  @spec delete(
          changeset_input() | list(changeset_input()),
          opts()
        ) :: {:ok, schema_data()} | {:error, changeset() | any()}
  def delete(entries, opts \\ [])

  def delete(%_{data: %_{__meta__: %{schema: queryable}}} = changeset, opts) do
    opts = Keyword.merge(default_opts(), opts)

    with {:error, changeset} <-
           queryable
           |> create_changeset(changeset, %{}, opts)
           |> Config.repo!(opts).delete(opts) do
      {:error,
       Error.call(
         :conflict,
         "Failed to delete record.",
         %{
           query: queryable,
           changeset: changeset
         },
         opts
       )}
    end
  end

  def delete(%_{__meta__: %{schema: queryable}} = schema_data, opts) do
    opts = Keyword.merge(default_opts(), opts)

    with {:error, changeset} <-
           queryable
           |> create_changeset(schema_data, %{}, opts)
           |> Config.repo!(opts).delete(opts) do
      {:error,
       Error.call(
         :conflict,
         "Failed to delete record.",
         %{
           query: queryable,
           changeset: changeset
         },
         opts
       )}
    end
  end

  def delete(entries, opts) when is_list(entries) do
    Utils.reduce_all(entries, fn entry ->
      delete(entry, opts)
    end)
  end

  def delete(query_input, id) when is_binary(id) or is_integer(id) do
    delete(query_input, id, [])
  end

  @doc group: "Schema API"
  @doc """
  Deletes a record using its primary key.

  If the record is not found, an error is returned.

  ## Options

  See the [Shared Options](EctoShorts.Actions.html#module-shared-options).

  All options accepted by [`Ecto.Repo.delete/2`](https://hexdocs.pm/ecto/Ecto.Repo.html#c:delete/2)
  are also supported.

  ## Examples

      iex> EctoShorts.Actions.delete(EctoShorts.Schemas.Post, 1, repo: EctoShorts.Repo)

      iex> EctoShorts.Actions.delete(EctoShorts.Schemas.Post, 1, replica: EctoShorts.Repo)

      iex> EctoShorts.Actions.delete({"posts", EctoShorts.Schemas.Post}, 1, repo: EctoShorts.Repo)
  """
  @spec delete(query_input(), id(), opts()) ::
          {:ok, schema_data()} | {:error, changeset() | any()}
  def delete(query_input, id, opts) when is_integer(id) or is_binary(id) do
    with {:ok, record} <- find(query_input, %{id: id}, opts) do
      delete(record, opts)
    end
  end

  @doc group: "Query API"
  @doc """
  Streams all records that match the given filters.

  This returns a lazy enumerable that can be used to iterate over large
  datasets without loading them all into memory at once.

  ## Options

  See the [Shared Options](EctoShorts.Actions.html#module-shared-options).

  All options accepted by [`Ecto.Repo.stream/2`](https://hexdocs.pm/ecto/Ecto.Repo.html#c:stream/2)
  are also supported.

  ## Examples

      iex> EctoShorts.Actions.stream(EctoShorts.Schemas.Post, %{published: true}, repo: EctoShorts.Repo)

      iex> EctoShorts.Actions.stream({"posts", EctoShorts.Schemas.Post}, %{published: true}, repo: EctoShorts.Repo)
  """
  @spec stream(query_input()) :: stream()
  @spec stream(query_input(), params()) :: stream()
  @spec stream(query_input(), params(), opts()) :: stream()
  def stream(query_input, params \\ %{}, opts \\ []) do
    opts = Keyword.merge(default_opts(), opts)

    query_input
    |> CommonFilters.convert_params_to_filter(params, opts)
    |> Config.repo!(opts).stream(opts)
  end

  @doc group: "Query API"
  @doc """
  Calculates an aggregate value from a filtered query.

  This function applies the given filter parameters and computes an
  aggregate (like `:count`, `:sum`, or `:avg`) over a specified field.

  ## Supported Aggregates

    * `:count` – count matching rows
    * `:sum` – sum of values in the field
    * `:avg` – average of values in the field
    * `:min` – minimum value in the field
    * `:max` – maximum value in the field

  ## Options

  See the [Shared Options](EctoShorts.Actions.html#module-shared-options).

  All options accepted by [`Ecto.Repo.aggregate/4`](https://hexdocs.pm/ecto/Ecto.Repo.html#c:aggregate/4)
  are also supported.

  ## Examples

      iex> EctoShorts.Actions.aggregate(EctoShorts.Schemas.Post, %{published: true}, :count, :id)

      iex> EctoShorts.Actions.aggregate(EctoShorts.Schemas.Post, %{published: true}, :avg, :views, repo: EctoShorts.Repo)
  """
  @spec aggregate(query_input()) :: any() | nil
  @spec aggregate(query_input(), params()) :: any() | nil
  @spec aggregate(query_input(), params(), aggregate_options()) :: any() | nil
  @spec aggregate(query_input(), params(), aggregate_options(), key()) :: any() | nil
  @spec aggregate(query_input(), params(), aggregate_options(), key(), opts()) :: any() | nil
  def aggregate(query_input, params \\ %{}, aggregate \\ :count, key \\ :id, opts \\ []) do
    opts = Keyword.merge(default_opts(), opts)

    query_input
    |> CommonFilters.convert_params_to_filter(params, opts)
    |> Config.replica!(opts).aggregate(aggregate, key, opts)
  end

  @doc group: "Transaction API"
  @doc since: "2.5.0"
  @doc """
  Runs a function or `Ecto.Multi` inside a database transaction.

  This function wraps the given operation in a transaction using the
  configured `:repo`. You can pass either a function or a pre-built
  `Ecto.Multi` struct.

  If a function is passed, it can be either:

    * a zero-arity function (`fn -> ... end`)
    * a one-arity function that receives the `repo` as its argument (`fn repo -> ... end`)

  By default, the transaction is automatically rolled back if the
  function executed inside the transaction returns `:error` or
  `{:error, reason}`.

  You can disable this behavior by passing `rollback_on_error: false`.

  All other values will commit the transaction.

  ## Options

  See the [Shared Options](EctoShorts.Actions.html#module-shared-options).

  All options accepted by [`Ecto.Repo.transaction/2`](https://hexdocs.pm/ecto/Ecto.Repo.html#c:transaction/2) are supported.

  ## Examples

      # Run a transactional function:

      iex> EctoShorts.Actions.transaction(fn ->
      ...>   EctoShorts.Actions.create(EctoShorts.Schemas.Post, %{body: "Jane"})
      ...> end)

      # Use a one-arity function:

      iex> EctoShorts.Actions.transaction(fn repo ->
      ...>   repo.insert!(%EctoShorts.Schemas.Post{body: "Jane"})
      ...> end)

      # Run a pre-built Ecto.Multi:

      iex> multi = Ecto.Multi.new()
      ...> Ecto.Multi.insert(multi, :user, EctoShorts.Schemas.Post.changeset(%EctoShorts.Schemas.Post{}, %{body: "Jane"}))
      ...> EctoShorts.Actions.transaction(multi)
  """
  @spec transaction(function() | multi()) :: {:ok, any()} | {:error, any()}
  @spec transaction(function() | multi(), opts()) :: {:ok, any()} | {:error, any()}
  def transaction(fun_or_multi, opts \\ [])

  def transaction(%_{} = multi, opts) do
    opts = Keyword.merge(default_opts(), opts)

    multi
    |> Config.repo!(opts).transaction(opts)
    |> handle_multi_response()
  end

  def transaction(fun, opts) do
    opts = Keyword.merge(default_opts(), opts)

    case Config.repo!(opts).transaction(
           fn repo -> execute_transaction_fun(fun, repo, opts) end,
           opts
         ) do
      {:error, :error} -> :error
      {:ok, :ok} -> :ok
      result -> result
    end
  end

  defp execute_transaction_fun(fun, repo, opts) do
    response =
      if is_function(fun, 1) do
        fun.(repo)
      else
        fun.()
      end

    if Keyword.get(opts, :rollback_on_error, true) do
      case response do
        :error ->
          repo.rollback(:error)

        {:error, reason} ->
          repo.rollback(reason)

        {:ok, value} ->
          value

        term ->
          term
      end
    else
      response
    end
  end

  defp handle_multi_response({
         :error,
         _failed_operation,
         {code, message, details},
         changes_so_far
       }) do
    details = Map.put(details, :changes_so_far, Map.values(changes_so_far))

    {:error, Error.call(code, message, details)}
  end

  defp handle_multi_response({:ok, operations}) do
    {:ok, Map.values(operations)}
  end

  @doc false
  def create_changeset(%_{} = struct_or_changeset, params, opts) do
    CommonSchema.create_changeset(struct_or_changeset, params, opts)
  end

  def create_changeset({source, schema}, params, opts) do
    if function_exported?(schema, :create_changeset, 1) and
         not Keyword.has_key?(opts, :create_changeset) do
      schema.create_changeset({source, params})
    else
      CommonSchema.create_changeset({source, schema}, params, opts)
    end
  end

  def create_changeset(schema, params, opts) do
    if function_exported?(schema, :create_changeset, 1) and
         not Keyword.has_key?(opts, :create_changeset) do
      schema.create_changeset(params)
    else
      CommonSchema.create_changeset(schema, params, opts)
    end
  end

  @doc false
  def create_changeset(queryable_input, struct_or_changeset, params, opts) do
    CommonSchema.create_changeset(queryable_input, struct_or_changeset, params, opts)
  end

  @doc false
  def maybe_filter_queryable_params(params, query_input, opts) do
    if Keyword.get(opts, :filter_queryable_params, true) do
      filter_queryable_params(params, query_input)
    else
      params
    end
  end

  @doc false
  def filter_queryable_params(params, query_input) do
    Map.take(params, CommonSchema.get_schema_reflection(query_input, :query_fields))
  end

  defp put_order_by(params, opts) do
    case Keyword.get(opts, :order_by) do
      nil -> params
      order_by -> Map.put(params, :order_by, order_by)
    end
  end

  defp put_group_by(params, opts) do
    case Keyword.get(opts, :group_by) do
      nil -> params
      group_by -> Map.put(params, :group_by, group_by)
    end
  end

  defp default_opts do
    reject_nil_values(
      repo: Config.repo(),
      replica: Config.replica()
    )
  end

  defp reject_nil_values(enum), do: Enum.reject(enum, &value_is_nil?/1)

  defp value_is_nil?({_key, nil}), do: true
  defp value_is_nil?({_key, _val}), do: false
end
