defmodule EctoShorts.Actions do
  @moduledoc """
  Data-driven CRUD, bulk, batch, and transaction helpers.

  This module is the public action boundary for EctoShorts. It wraps common
  `Ecto.Repo` operations in a consistent API and delegates query building to
  `EctoShorts.CommonFilters`.

  The API is split into five groups:

  * CRUD helpers such as `all/3`, `find/3`, `create/3`, `update/4`, and
    `delete/1`
  * bulk helpers such as `insert_all/3`, `update_all/4`, and `delete_all/3`
  * multi helpers such as `create_many/3`, `find_many/3`, and `update_many/3`
  * batch helpers such as `batch/5` and `batch_find/4`
  * transaction helpers such as `transaction/2` and `transact/2`

  Read helpers accept the public `EctoShorts.CommonFilters` language. Write
  helpers build changesets through the schema unless the function family is
  explicitly bulk-oriented.

  In general:

  * reads use the configured `:replica`
  * writes use the configured `:repo`
  * `:preload` is applied after the main operation for helpers that return
    structs
  * bulk helpers run repo-native bulk operations
  * multi helpers compose per-record operations inside an `Ecto.Multi`

  ## Examples

      alias EctoShorts.Actions
      alias EctoShorts.Schema.Post

      {:ok, post} = Actions.create(Post, %{title: "Hello", body: "World"})
      {:ok, post} = Actions.find(Post, %{id: 1})
      posts = Actions.all(Post, %{published: true, order_by: [desc: :inserted_at]})
      {:ok, post} = Actions.update(Post, post, %{title: "Updated"})
      {:ok, _post} = Actions.delete(post)

  ## Errors

  This API uses `ErrorMessage` for error payloads by default. See `EctoShorts.Actions.Error`
  for information on custom error adapters.
  """

  @moduledoc groups: [
               %{
                 title: "CRUD",
                 description: "Single-record create, read, update, and delete operations."
               },
               %{title: "Bulk", description: "Multi-row operations without transactions."},
               %{
                 title: "Multi",
                 description: "Transactional multi-record operations using Ecto.Multi."
               },
               %{title: "Batch", description: "Keyed grouping and lookup helpers."},
               %{title: "Transaction", description: "Transaction wrappers."}
             ]

  alias EctoShorts.Actions.Batch
  alias EctoShorts.Actions.Bulk
  alias EctoShorts.Actions.CRUD
  alias EctoShorts.Actions.Multi
  alias EctoShorts.Actions.Source
  alias EctoShorts.Actions.Transaction

  alias EctoShorts.{CommonFilters, Config}

  @typedoc """
  Query source accepted by the public read helpers.

  This is usually a schema module, an `{source, schema}` tuple, a prebuilt
  `Ecto.Query.t()`, or an `EctoShorts.Actions.Source.t()` key-value lookup
  struct. When a `Source.t()` is passed, the caller must include a `:from` key
  in params whose value matches a key in the source's store.
  """
  @type queryable :: module() | {binary(), module()} | Ecto.Query.t() | Source.t()

  @typedoc """
  Public parameter container used by the Actions API.

  Read helpers interpret these values with `EctoShorts.CommonFilters`. Write
  helpers interpret them as attribute maps or keyword lists.
  """
  @type params :: map() | keyword()

  @typedoc """
  Keyword options accepted by Actions helpers.
  """
  @type opts :: keyword()

  @typedoc """
  Primary-key shape accepted by the id-based helpers.
  """
  @type id :: integer() | binary()

  @typedoc """
  Grouping shape used by `batch/5`.
  """
  @type cardinality :: :one | :many

  @cardinalities [:one, :many]

  @doc group: "CRUD"
  @doc since: "3.0.0"
  @doc """
  Preloads associations in the given struct or structs.

  This delegates to `c:Ecto.Repo.preload/3` on the configured replica repo.
  `preloads` accepts the same shapes as `Ecto.Repo.preload/3`, including
  atoms, lists, keyword lists, and `{assoc, query}` tuples.

  ## Examples

      post = EctoShorts.Actions.preload(post, :author)
      posts = EctoShorts.Actions.preload(posts, [:author, :comments])
      post = EctoShorts.Actions.preload(post, author: :profile)

  See `c:Ecto.Repo.preload/3` for the full list of supported options.
  See also `all/3` and `EctoShorts.CommonChanges.preload_change_assoc/3`.
  """
  @spec preload(struct() | list(term()), term(), opts) :: struct() | list(term())
  def preload(data, preloads, opts \\ []) do
    CRUD.preload(data, preloads, opts)
  end

  @doc group: "CRUD"
  @doc since: "3.0.0"
  @doc """
  Returns `true` if at least one record matches `params`, `false` otherwise.

  This builds a query with `EctoShorts.CommonFilters` and delegates to
  `c:Ecto.Repo.exists?/2` on the configured replica repo.

  ## Examples

      true = EctoShorts.Actions.exists?(EctoShorts.Schema.Post, %{published: true})

  See also `find/3` and `all/3`.
  """
  @spec exists?(queryable, params, opts) :: boolean()
  def exists?(source, params, opts \\ []) do
    CRUD.exists?(source, params, opts)
  end

  @doc group: "CRUD"
  @doc """
  Fetches all records for the given queryable.

  Equivalent to `all(queryable, %{}, [])`.

  See also `all/2`, `all/3`, and `find/3`.
  """
  @spec all(queryable) :: list(term())
  def all(queryable), do: CRUD.all(queryable)

  @doc group: "CRUD"
  @doc """
  Fetches all records using either a params map or the keyword shorthand form.

  When the second argument is a map it is used as filter params and
  forwarded to `all/3` with an empty opts list.

  When it is a keyword list, `:repo`, `:replica`, and
  `:dynamic_builder` are extracted as options; every other key is
  treated as a filter param and passed to `all/3`.

  This shorthand is best when you want a filter-only keyword list such as
  `[published: true, limit: 10]`. Use `all/3` when you want to separate
  query params from runtime options explicitly.

  Raises `ArgumentError` if the second argument is neither a map nor a
  keyword list.

  ## Examples

      posts = EctoShorts.Actions.all(EctoShorts.Schema.Post, %{published: true})
      posts = EctoShorts.Actions.all(EctoShorts.Schema.Post, replica: MyApp.Repo)
      posts = EctoShorts.Actions.all(EctoShorts.Schema.Post, [published: true, limit: 10])

  See also `all/1`, `all/3`, and `find/3`.
  """
  @spec all(queryable, params | opts) :: list(term())
  def all(queryable, params_or_opts), do: CRUD.all(queryable, params_or_opts)

  @doc group: "CRUD"
  @doc """
  Fetches all records matching `params`.

  This is the main list-read helper. It builds an `Ecto.Query` with
  `EctoShorts.CommonFilters`, runs `c:Ecto.Repo.all/2`, and optionally
  preloads the returned structs.

  ## Options

  * `:order_by` - merged into `params` before query building
  * `:group_by` - merged into `params` before query building
  * `:preload` - applied after the query returns

  All other options are forwarded to `c:Ecto.Repo.all/2`.

  ## Examples

      posts =
        EctoShorts.Actions.all(
          EctoShorts.Schema.Post,
          %{published: true},
          order_by: :title,
          preload: [:comments]
        )

  See also `find/3`, `stream/3`, and `EctoShorts.CommonFilters`.
  """
  @spec all(queryable, params, opts) :: list(term())
  def all(queryable, params, opts), do: CRUD.all(queryable, params, opts)

  @doc group: "CRUD"
  @doc """
  Inserts a new record built from `params`.

  Builds a changeset via the schema's `changeset/2` (or the
  `:changeset` option) and delegates to `c:Ecto.Repo.insert/2`.

  ## Options

  * `:preload` - applied after the insert succeeds

  ## Examples

      iex> EctoShorts.Actions.create(EctoShorts.Schema.Post, %{title: "Hello", body: "World"}, repo: EctoShorts.Repo)
      {:ok, %EctoShorts.Schema.Post{title: "Hello", body: "World", ...}}

  See also `find/3`, `update/4`, and `EctoShorts.CommonChanges`.
  """
  @spec create(module(), params, opts) :: {:ok, struct()} | {:error, term()}
  def create(schema, params, opts \\ []) do
    CRUD.create(schema, params, opts)
  end

  @doc group: "CRUD"
  @doc """
  Fetches a single record by primary key.

  Returns the struct or `nil`. Delegates to `c:Ecto.Repo.get/3` on
  the configured replica repo.

  ## Options

  * `:preload` - applied after the record is loaded; `nil` is returned
    unchanged when nothing is found

  ## Examples

      post = EctoShorts.Actions.get(EctoShorts.Schema.Post, 1)

  See also `find/3` and `all/3`.
  """
  @spec get(queryable, id, opts) :: struct() | nil
  def get(queryable, id, opts \\ []) do
    CRUD.get(queryable, id, opts)
  end

  @doc group: "CRUD"
  @doc """
  Finds a single record matching `params`.

  Returns `{:ok, struct}` when a record is found, or
  `{:error, %ErrorMessage{code: :not_found}}` otherwise. When `params`
  is an empty map and `queryable` is not an `Ecto.Query`, the error is
  returned immediately without querying.

  `find/3` uses `c:Ecto.Repo.one/2`, so callers should pass filters that
  identify at most one row.

  ## Options

  * `:order_by` - merged into `params` before query building
  * `:group_by` - merged into `params` before query building
  * `:preload` - applied after the record is found

  ## Examples

      iex> EctoShorts.Actions.find(EctoShorts.Schema.Post, %{id: 1})
      {:ok, %EctoShorts.Schema.Post{id: 1, ...}}

      iex> EctoShorts.Actions.find(EctoShorts.Schema.Post, %{})
      {:error, %ErrorMessage{code: :not_found, message: "record not found."}}

  See also `all/3`, `create/3`, and `find_or_create/3`.
  """
  @spec find(queryable, params, opts) :: {:ok, struct()} | {:error, term()}
  def find(queryable, params, opts \\ []) do
    CRUD.find(queryable, params, opts)
  end

  @doc group: "CRUD"
  @doc """
  Updates a record by id or by struct.

  When `id_or_schema_struct` is an integer or binary, the record is
  fetched with `find/3` first. When it is a struct, the changeset is
  built and updated directly.

  Returns `{:ok, struct}`, `{:error, changeset}`,
  `{:error, %ErrorMessage{code: :not_found}}`, or
  `{:error, %ErrorMessage{code: :stale}}` when optimistic locking
  detects a concurrent modification.

  ## Options

  * `:optimistic_lock` - an atom, a `{field, incrementer}` tuple, or `false`
  * `:preload` - applied after the update succeeds

  ## Optimistic locking

  When optimistic locking is active, the changeset is piped through
  `Ecto.Changeset.optimistic_lock/3` before calling `c:Ecto.Repo.update/2`.
  If the record has been modified by another process since it was fetched,
  `Ecto.StaleEntryError` is rescued and converted to
  `{:error, %ErrorMessage{code: :stale}}`.

  To enable locking, either define `optimistic_lock/0` on your schema:

      defmodule MyApp.Post do
        def optimistic_lock, do: :lock_version
      end

  Or pass the option explicitly:

      Actions.update(Post, post, params, optimistic_lock: :lock_version)

  ## Examples

      {:ok, post} =
        EctoShorts.Actions.update(
          EctoShorts.Schema.Post,
          1,
          %{title: "New"},
          repo: EctoShorts.Repo
        )

      {:ok, post} = EctoShorts.Actions.update(EctoShorts.Schema.Post, post, %{title: "New"})

  See also `find_and_update/4`, `create/3`, and `EctoShorts.CommonChanges`.
  """
  @spec update(module(), id | struct(), params, opts) :: {:ok, struct()} | {:error, term()}
  def update(queryable, id_or_schema_struct, params, opts \\ []) do
    CRUD.update(queryable, id_or_schema_struct, params, opts)
  end

  @doc group: "CRUD"
  @doc """
  Deletes a struct, changeset, or list of either.

  A delete changeset is built via the schema's `changeset/2` and
  deleted through the configured repo. When given a list, stops on
  the first failure (already-deleted entries are not rolled back).

  ## Examples

      {:ok, deleted} = EctoShorts.Actions.delete(post)
      {:ok, deleted_list} = EctoShorts.Actions.delete([post1, post2])

  See also `delete/2`, `delete/3`, and `find_and_delete/3`.
  """
  @spec delete(struct() | Ecto.Changeset.t() | [struct() | Ecto.Changeset.t()]) ::
          {:ok, struct() | list(term())} | {:error, term()}
  def delete(data), do: CRUD.delete(data)

  @doc group: "CRUD"
  @doc """
  Deletes a struct, changeset, or list of either with options.

  When `data` is a list, entries are deleted sequentially and the function
  stops on the first error. Earlier successful deletes are not rolled back.

  See `delete/1` for return values. See also `delete/3` and
  `find_and_delete/3`.
  """
  @spec delete(
          queryable | struct() | Ecto.Changeset.t() | [struct() | Ecto.Changeset.t()],
          id | opts
        ) ::
          {:ok, struct() | list(term())} | {:error, term()}
  def delete(data, opts) do
    CRUD.delete(data, opts)
  end

  @doc group: "CRUD"
  @doc """
  Deletes a record by id.

  Fetches the record with `find/3`, then deletes it.

  ## Examples

      {:ok, deleted} = EctoShorts.Actions.delete(EctoShorts.Schema.Post, 1)

  See also `delete/1`, `delete_all/3`, and `find_and_delete/3`.
  """
  @spec delete(queryable, id, opts) :: {:ok, struct()} | {:error, term()}
  def delete(queryable, id, opts) do
    CRUD.delete(queryable, id, opts)
  end

  @doc group: "CRUD"
  @doc """
  Returns a stream of records matching `params`.

  Wraps `c:Ecto.Repo.stream/2` with filter support. The stream must be
  consumed inside a transaction (see `transact/2` or `transaction/2`).

  ## Options

  * `:max_rows` (default: `500`) - rows fetched per batch
  * `:repo` - the `Ecto.Repo` to use. Defaults to `EctoShorts.Config.repo/0`.

  ## Examples

      EctoShorts.Actions.transact(fn ->
        EctoShorts.Schema.Post
        |> EctoShorts.Actions.stream(%{published: true})
        |> Stream.each(&process_post/1)
        |> Stream.run()
      end)

      EctoShorts.Actions.transact(fn ->
        EctoShorts.Schema.Post
        |> EctoShorts.Actions.stream(%{}, max_rows: 1000)
        |> Stream.each(&process_post/1)
        |> Stream.run()
      end)

  See also `all/3`, `transact/2`, and `EctoShorts.CommonFilters`.
  """
  @spec stream(queryable, params, opts) :: Enumerable.t()
  def stream(queryable, params \\ %{}, opts \\ []) do
    CRUD.stream(queryable, params, opts)
  end

  @doc group: "CRUD"
  @doc """
  Runs an aggregate on filtered records.

  Delegates to `c:Ecto.Repo.aggregate/4` on the configured replica repo.

  ## Examples

      count = EctoShorts.Actions.aggregate(EctoShorts.Schema.Post, %{published: true})
      total = EctoShorts.Actions.aggregate(EctoShorts.Schema.Post, %{}, :sum, :views)

  See also `all/3` and `exists?/3`.
  """
  @spec aggregate(queryable, params, atom(), atom(), opts) :: term()
  def aggregate(queryable, params \\ %{}, aggregate \\ :count, key \\ :id, opts \\ []) do
    CRUD.aggregate(queryable, params, aggregate, key, opts)
  end

  @doc group: "CRUD"
  @doc since: "3.0.0"
  @doc """
  Finds a record matching `find_params`, or creates one with `create_params`.

  This first calls `find/3`. If nothing is found, it creates a new record with
  `create_params`.

  ## Examples

      {:ok, post} = EctoShorts.Actions.find_and_create(
        EctoShorts.Schema.Post,
        %{title: "Hello"},
        %{title: "Hello", body: "World"}
      )

  ## Options

  * `:preload` - applied to the final struct

  See also `find_or_create/3`, `find_and_update/4`, and `create/3`.
  """
  @spec find_and_create(module(), params, params, opts) :: {:ok, struct()} | {:error, term()}
  def find_and_create(queryable, find_params, create_params, opts \\ []) do
    CRUD.find_and_create(queryable, find_params, create_params, opts)
  end

  @doc group: "CRUD"
  @doc """
  Finds a record matching `find_params` and updates it with `update_params`.

  Returns `{:ok, struct}`, `{:error, changeset}`, or
  `{:error, %ErrorMessage{code: :not_found}}`.

  ## Examples

      {:ok, post} = EctoShorts.Actions.find_and_update(
        EctoShorts.Schema.Post,
        %{id: 1},
        %{title: "Updated"}
      )

  ## Options

  * `:preload` - applied after the update succeeds

  See also `update/4`, `find_and_upsert/4`, and `find/3`.
  """
  @spec find_and_update(module(), params, params, opts) :: {:ok, struct()} | {:error, term()}
  def find_and_update(source, find_params, update_params, opts \\ []) do
    CRUD.find_and_update(source, find_params, update_params, opts)
  end

  @doc group: "CRUD"
  @doc """
  Finds a record matching `find_params` and updates it, or creates one.

  When found, updates with `upsert_params`. When not found, creates a
  record from `Map.merge(find_params, upsert_params)`.

  ## Examples

      {:ok, post} = EctoShorts.Actions.find_and_upsert(
        EctoShorts.Schema.Post,
        %{title: "Hello"},
        %{body: "Updated body"}
      )

  ## Options

  * `:preload` - applied to the final struct

  See also `find_and_update/4`, `find_or_create/3`, and `create/3`.
  """
  @spec find_and_upsert(module(), params, params, opts) :: {:ok, struct()} | {:error, term()}
  def find_and_upsert(source, find_params, upsert_params, opts \\ []) do
    CRUD.find_and_upsert(source, find_params, upsert_params, opts)
  end

  @doc group: "CRUD"
  @doc since: "3.0.0"
  @doc """
  Finds a record matching `find_params` and deletes it.

  ## Examples

      {:ok, deleted} = EctoShorts.Actions.find_and_delete(EctoShorts.Schema.Post, %{title: "Hello"})

  See also `delete/1`, `delete_all/3`, and `find/3`.
  """
  @spec find_and_delete(module(), params, opts) :: {:ok, struct()} | {:error, term()}
  def find_and_delete(source, find_params, opts \\ []) do
    CRUD.find_and_delete(source, find_params, opts)
  end

  @doc group: "CRUD"
  @doc """
  Finds a record by the schema's query fields, or creates one.

  The lookup filters `params` to the schema's query fields. When no
  record matches, creates one from the full `params` map.

  ## Examples

      {:ok, post} = EctoShorts.Actions.find_or_create(
        EctoShorts.Schema.Post,
        %{title: "Hello", body: "World"}
      )

  ## Options

  * `:preload` - applied once to the final result, whether it was found or
    created

  ## Notes

  `:preload` is intentionally withheld from the internal `find/3` call and
  applied to the final result instead. This ensures a single preload pass
  covers both the found path and the created path, rather than preloading
  during the lookup and then discarding that work on the create path.

  See also `find_and_create/4`, `find_or_create_many/3`, and `create/3`.
  """
  @spec find_or_create(module(), params, opts) :: {:ok, struct()} | {:error, term()}
  def find_or_create(source, params, opts \\ []) do
    CRUD.find_or_create(source, params, opts)
  end

  @doc group: "Transaction"
  @doc since: "3.0.0"
  @doc """
  Runs `fun_or_multi` in a transaction without further result normalization.

  This is the lower-level transaction helper in the Actions API. Use it when
  you want the repo transaction shape preserved. In particular, a function that
  returns `{:ok, value}` will produce `{:ok, {:ok, value}}`.

  ## Examples

      {:ok, _} = EctoShorts.Actions.transaction(fn ->
        EctoShorts.Actions.create(EctoShorts.Schema.Post, %{title: "Hello"})
      end)

  See also `transact/2` and `create_many/3`.
  """
  @spec transaction((... -> term()) | Ecto.Multi.t(), opts) :: {:ok, term()} | {:error, term()}
  def transaction(fun_or_multi, opts \\ []) do
    Transaction.run_transaction(fun_or_multi, opts)
  end

  @doc group: "Transaction"
  @doc since: "3.0.0"
  @doc """
  Runs a transaction and normalizes the return value.

  When given an `Ecto.Multi`, normalizes the multi response into
  `{:ok, [struct]}` or `{:error, reason}`. When given a 0- or 1-arity
  function, wraps it in a transaction. With `:strict` (default `true`),
  `{:error, reason}` triggers a rollback and `{:ok, value}` is
  unwrapped.

  This is the higher-level transaction boundary to prefer when you want your
  caller-facing code to stay inside the usual Actions success/error contract.

  ## Options

  * `:strict` (default: `true`) - roll back on `{:error, reason}` and unwrap
    `{:ok, value}`

  See also `transaction/2` and `create_many/3`.
  """
  @spec transact((... -> term()) | Ecto.Multi.t(), opts) :: {:ok, term()} | {:error, term()}
  def transact(fun_or_multi, opts \\ [])

  def transact(%Ecto.Multi{} = multi, opts) do
    multi
    |> transaction(opts)
    |> Multi.handle_multi_response(opts)
  end

  def transact(fun, opts) when is_function(fun) do
    fn repo -> Transaction.eval_transaction_fun(fun, repo, opts) end
    |> transaction(opts)
    |> Transaction.normalize_transaction_response(opts)
  end

  @doc group: "Batch"
  @doc since: "3.0.0"
  @doc """
  Batches records by key(s) and cardinality.

  Returns a map keyed by batch key value (or a map of values for
  composite keys). Each value is a struct (`:one`) or list of structs
  (`:many`). Returns `%{}` when `params` is empty or when none of the
  provided entries contain the requested batch key(s).

  Raises `ArgumentError` when `:one` cardinality finds multiple records
  for a single batch key.

  ## Options

  * `:preload` - applied to each grouped result after loading

  ## Examples

      EctoShorts.Actions.batch(
        Post,
        [%{author_id: 1}, %{author_id: 2}],
        :author_id,
        :many
      )
      EctoShorts.Actions.batch(Post, [%{id: 1}, %{id: 2}], :id, :one)

      EctoShorts.Actions.batch(PostTag, [%{post_id: 1, tag_id: 5}], [:post_id, :tag_id], :one)
  """
  @spec batch(module(), list(params()), atom() | list(atom()), cardinality, opts) :: map()
  def batch(schema, params, batch_keys \\ :id, cardinality \\ :many, opts \\ [])

  def batch(_schema, [], _batch_keys, _cardinality, _opts) do
    %{}
  end

  def batch(schema, params, batch_keys, cardinality, opts)
      when is_list(batch_keys) and cardinality in @cardinalities do
    batch_keys = Enum.uniq(batch_keys)

    case Batch.build_batch_params(schema, params, batch_keys, opts) do
      [] ->
        %{}

      batch_params ->
        schema
        |> CommonFilters.convert_params_to_filter(batch_params, opts)
        |> Config.repo!(opts).all(opts)
        |> Enum.group_by(&Map.take(&1, batch_keys))
        |> Batch.handle_batch_response(cardinality, batch_keys, opts)
    end
  end

  def batch(schema, params, batch_key, cardinality, opts)
      when cardinality in @cardinalities do
    values =
      params
      |> Enum.map(&Batch.normalize_batch_key(&1, batch_key))
      |> Enum.uniq()

    schema
    |> CommonFilters.convert_params_to_filter(%{batch_key => values}, opts)
    |> Config.repo!(opts).all(opts)
    |> Enum.group_by(&Batch.normalize_batch_key(&1, batch_key))
    |> Batch.handle_batch_response(cardinality, batch_key, opts)
  end

  @doc group: "Batch"
  @doc since: "3.0.0"
  @doc """
  Batch-fetches records and zips them into the original entries.

  Looks up records by `keys` using `batch/5` with `:one` cardinality.
  Each matched record is zipped into the corresponding entry while preserving
  the original list order.

  The live supported entry shapes include:

  * `{struct, params}` tuples, which are passed through unchanged
  * `{lookup_params, params}` tuples, which become `{resolved_struct, params}`
  * bare maps or keyword lists, which become `{resolved_struct, original_params}`
  * `nil`, which is preserved unchanged

  Unmatched entries are returned unchanged.

  ## Examples

      entries = [%{permalink: "existing", title: "Updated"}]
      [{post, params}] = EctoShorts.Actions.batch_find(EctoShorts.Schema.Post, entries, :permalink)
  """
  @spec batch_find(module(), [map()], atom() | list(atom()), opts) :: [map()]
  def batch_find(schema, entries, keys, opts \\ []) do
    {params_list, index_to_key} = Batch.extract_lookup_params(entries, keys)

    key_fields = Batch.normalize_key_fields(keys)

    fetched_records = batch(schema, params_list, key_fields, :one, opts)

    Enum.reduce(index_to_key, entries, fn {index, batch_key}, acc ->
      case Map.get(fetched_records, batch_key) do
        nil ->
          acc

        record ->
          current_entry = get_in(acc, [Access.at!(index)])
          updated_entry = Batch.zip_batch_result(current_entry, record)
          put_in(acc, [Access.at!(index)], updated_entry)
      end
    end)
  end

  @doc group: "Bulk"
  @doc since: "3.0.0"
  @doc """
  Inserts many records via `c:Ecto.Repo.insert_all/3`.

  This helper prepares the insert set first, then performs one
  `c:Ecto.Repo.insert_all/3` call. By default, each entry is validated through
  the schema's `changeset/2` before the repo call. Validation can be skipped
  with `validate: false`.

  The accepted entry shapes come from `EctoShorts.CommonParams` and include
  maps, keyword lists, structs, changesets, and `{struct, params}` tuples.

  When `:batch_find` is set, entries are first resolved through `batch_find/4`
  before the insert payload is built.

  ## Options

  * `:batch_find` - batch-resolve matching records before preparing inserts
  * `:validate` - set to `false` to skip changeset validation
  * `:on_conflict_replace` - `:none`, `:insert_keys`, or a list of fields
  * `:on_conflict` - forwarded directly to `c:Ecto.Repo.insert_all/3`
  * `:conflict_target` - forwarded directly to `c:Ecto.Repo.insert_all/3`

  When at least one prepared insert contains all primary-key fields and the
  caller does not provide an explicit `:on_conflict`, the default conflict
  options are derived from the schema primary key and
  `:on_conflict_replace`.

  See `EctoShorts.CommonParams.convert_to_insert_params/3` for
  timestamp and validation options, and
  `EctoShorts.CommonParams.build_on_conflict_options/3` for conflict
  resolution details.
  """
  @spec insert_all(module() | {binary(), module()}, list(term()), opts()) ::
          {:ok, {non_neg_integer(), nil | list(term())}} | {:error, term()}
  def insert_all(source, params_list, opts \\ []) do
    params_list =
      if Keyword.has_key?(opts, :batch_find) do
        batch_find(source, params_list, opts[:batch_find], opts)
      else
        params_list
      end

    Bulk.insert_all(source, params_list, opts)
  end

  @doc group: "Bulk"
  @doc since: "3.0.0"
  @doc """
  Updates all records matching `find_params`.

  Supports `:set`, `:inc`, `:push`, and `:pull` operations in
  `update_params`. Returns `{count, nil}`.

  ## Examples

      EctoShorts.Actions.update_all(Post, %{published: false}, %{title: "Draft"})
      EctoShorts.Actions.update_all(Post, %{id: 1}, %{views: {:inc, 1}})

  See also `EctoShorts.CommonParams.convert_to_update_params/3`
  and `update_many/3`.
  """
  @spec update_all(module() | {binary(), module()}, params(), params(), opts()) ::
          {non_neg_integer(), nil}
  def update_all(source, find_params, update_params, opts \\ []) do
    Bulk.update_all(source, find_params, update_params, opts)
  end

  @doc group: "Bulk"
  @doc since: "3.0.0"
  @doc """
  Deletes all records matching `params`.

  ## Examples

      EctoShorts.Actions.delete_all(Post, %{published: false})
      EctoShorts.Actions.delete_all(Post)

  See also `delete_many/3` and `EctoShorts.CommonFilters`.
  """
  @spec delete_all(queryable(), params(), opts()) :: {non_neg_integer(), nil}
  def delete_all(queryable, params \\ %{}, opts \\ []) do
    Bulk.delete_all(queryable, params, opts)
  end

  @doc group: "Multi"
  @doc since: "3.0.0"
  @doc """
  Creates many records in a single transaction.

  Each record is inserted individually inside an `Ecto.Multi`. Any
  failure rolls back the entire transaction.

  ## Examples

      {:ok, posts} = EctoShorts.Actions.create_many(EctoShorts.Schema.Post, [
        %{title: "Post 1", body: "Body 1"},
        %{title: "Post 2", body: "Body 2"}
      ])

  ## Options

  * `:preload` - applied after the transaction succeeds

  See also `create/3`, `insert_all/3`, and `transact/2`.
  """
  @spec create_many(module(), list(params()), opts()) :: {:ok, list(term())} | {:error, term()}
  def create_many(schema, params_list, opts \\ []) when is_list(params_list) do
    result = run_multi(Multi.build_create_many_multi(schema, params_list, opts), opts)
    CRUD.handle_response_preload(result, opts)
  end

  @doc group: "Multi"
  @doc since: "3.0.0"
  @doc """
  Finds many records in a single transaction.

  Each lookup runs inside an `Ecto.Multi`. A `nil` result rolls back
  the transaction with a `:not_found` error.

  ## Examples

      {:ok, posts} = EctoShorts.Actions.find_many(EctoShorts.Schema.Post, [%{id: 1}, %{id: 2}])

  ## Options

  * `:preload` - applied after the transaction succeeds

  See also `find/3`, `find_or_create_many/3`, and `transact/2`.
  """
  @spec find_many(module(), list(params()), opts()) :: {:ok, list(term())} | {:error, term()}
  def find_many(schema, params_list, opts \\ []) when is_list(params_list) do
    result = run_multi(Multi.build_find_many_multi(schema, params_list, opts), opts)
    CRUD.handle_response_preload(result, opts)
  end

  @doc group: "Multi"
  @doc since: "3.0.0"
  @doc """
  Updates many records in a single transaction.

  Entries can be `{find_params, update_params}` tuples or maps with an
  `:id` key. Raises `ArgumentError` for unrecognized shapes.

  ## Examples

      {:ok, posts} = EctoShorts.Actions.update_many(EctoShorts.Schema.Post, [
        {%{id: 1}, %{title: "Updated 1"}},
        {%{id: 2}, %{title: "Updated 2"}}
      ])

  ## Options

  * `:preload` - applied after the transaction succeeds

  See also `update/4`, `find_and_update/4`, and `update_all/4`.
  """
  @spec update_many(module(), list(term()), opts()) :: {:ok, list(term())} | {:error, term()}
  def update_many(schema, entries, opts \\ []) when is_list(entries) do
    result = run_multi(Multi.build_update_many_multi(schema, entries, opts), opts)
    CRUD.handle_response_preload(result, opts)
  end

  @doc group: "Multi"
  @doc since: "3.0.0"
  @doc """
  Deletes many records in a single transaction.

  Entries can be structs, filter param maps, or raw id values.

  ## Examples

      {:ok, deleted} = EctoShorts.Actions.delete_many(EctoShorts.Schema.Post, [post1, post2])

  ## Options

  * `:preload` - applied after the transaction succeeds

  See also `delete/1`, `delete_all/3`, and `transact/2`.
  """
  @spec delete_many(module(), list(term()), opts()) :: {:ok, list(term())} | {:error, term()}
  def delete_many(schema, records, opts \\ []) when is_list(records) do
    result = run_multi(Multi.build_delete_many_multi(schema, records, opts), opts)
    CRUD.handle_response_preload(result, opts)
  end

  @doc group: "Multi"
  @doc since: "3.0.0"
  @doc """
  Finds or creates many records in a single transaction.

  For each entry, finds a matching record or creates one from the
  same params.

  ## Examples

      {:ok, posts} = EctoShorts.Actions.find_or_create_many(EctoShorts.Schema.Post, [
        %{title: "Post 1", body: "Body 1"},
        %{title: "Post 2", body: "Body 2"}
      ])

  ## Options

  * `:preload` - applied after the transaction succeeds

  See also `find_or_create/3`, `create_many/3`, and `find_many/3`.
  """
  @spec find_or_create_many(module(), list(params()), opts()) ::
          {:ok, list(term())} | {:error, term()}
  def find_or_create_many(schema, params_list, opts \\ []) when is_list(params_list) do
    result = run_multi(Multi.build_find_or_create_multi(schema, params_list, opts), opts)
    CRUD.handle_response_preload(result, opts)
  end

  @doc group: "Multi"
  @doc since: "3.0.0"
  @doc """
  Finds and upserts many records in a single transaction.

  Entries can be `{find_params, upsert_params}` tuples or maps with an
  `:id` key. Raises `ArgumentError` for unrecognized shapes.

  ## Examples

      {:ok, posts} = EctoShorts.Actions.find_and_upsert_many(EctoShorts.Schema.Post, [
        {%{id: 1}, %{title: "Updated"}},
        {%{title: "New"}, %{body: "New body"}}
      ])

  ## Options

  * `:preload` - applied after the transaction succeeds

  See also `find_and_upsert/4`, `update_many/3`, and `find_or_create_many/3`.
  """
  @spec find_and_upsert_many(module(), list(term()), opts()) ::
          {:ok, list(term())} | {:error, term()}
  def find_and_upsert_many(schema, entries, opts \\ []) when is_list(entries) do
    result = run_multi(Multi.build_upsert_multi(schema, entries, opts), opts)
    CRUD.handle_response_preload(result, opts)
  end

  defp run_multi(multi, opts) do
    multi
    |> transaction(opts)
    |> Multi.handle_multi_response(opts)
  end
end
