defmodule EctoShorts.Actions do
  @moduledoc """
  Actions for CRUD in ecto, these can be used by all schemas/queries

  Generally we can define our contexts to be very reusable by creating
  them to look something like this:

  ```elixir
  defmodule MyApp.Accounts do
    alias EctoShorts.Actions
    alias MyApp.Accounts.User

    def all_users(params), do: Actions.all(User, params)
    def find_user(params), do: Actions.find(User, params)
  end
  ```

  We're then able to use this context with all filters that are
  supported by `EctoShorts.CommonFilters` without having to create new queries

  ```elixir
  def do_something do
    MyApp.Accounts.all_user(%{
      first_name: %{ilike: "john"},
      age: %{gte: 18},
      priority_level: 5,
      address: %{country: "Canada"}
    })
  end
  ```

  You can read more on reusable ecto code [here](https://learn-elixir.dev/blogs/creating-reusable-ecto-code)

  ### Supporting multiple Repos

  To support multiple repos, what we can do is pass arguments to the last parameter
  of most `EctoShorts.Actions` calls

  #### Example

  ```elixir
  defmodule MyApp.Accounts do
    alias EctoShorts.Actions
    alias MyApp.Accounts.User

    def all_users(params), do: Actions.all(User, params, replica: MyApp.Repo.Replica)
    def create_user(params), do: Actions.find(User, params, repo: MyApp.Repo)
  end
  ```
  """
  @type id :: binary() | integer()
  @type source :: binary()
  @type field :: atom()
  @type params :: map()
  @type params_list :: list(params)
  @type query :: Ecto.Query.t()
  @type queryable :: Ecto.Queryable.t()
  @type source_queryable :: {source(), queryable()}
  @type changeset :: Ecto.Changeset.t()
  @type changesets :: list(changeset())
  @type schema :: Ecto.Schema.t()
  @type schemas :: list() | list(schema())
  @type opts :: Keyword.t()
  @type aggregate_options :: :avg | :count | :max | :min | :sum
  @type error_message :: ErrorMessage.t()
  @type schema_res :: {:ok, schema()} | {:error, any}

  alias EctoShorts.{
    Actions.Error,
    CommonFilters,
    CommonSchemas,
    Config,
    SchemaHelpers
  }

  @doc """
  Fetches a single record where the primary key matches the given `id`.

  ### Options

    * `:replica` - A module that uses `Ecto.Repo`. This option takes
      precedence over the `:repo` option and will be used if set.

    * `:repo` - A module that uses `Ecto.Repo`.

  See [Ecto.Repo.get/3](https://hexdocs.pm/ecto/Ecto.Repo.html#c:get/3) for more options.

  ### Examples

      iex> EctoSchemas.Actions.get(YourSchema, 1)
      iex> EctoSchemas.Actions.get(YourSchema, 1)
      iex> EctoSchemas.Actions.get({"source", YourSchema}, 1)
  """
  @spec get(
    query :: query() | queryable() | source_queryable(),
    id :: id(),
    options :: opts()
  ) :: schema() | nil
  @spec get(
    query :: query() | queryable() | source_queryable(),
    id :: id()
  ) :: schema() | nil
  def get(query, id, opts \\ []) do
    replica!(opts).get(query, id, opts)
  end

  @doc """
  Fetches all records matching the given query.

  See [Ecto.Repo.all/2](https://hexdocs.pm/ecto/Ecto.Repo.html#c:all/2) for more options.

  ### Examples

      iex> EctoSchemas.Actions.all(YourSchema)
      iex> EctoSchemas.Actions.all({"source", YourSchema})
      iex> EctoSchemas.Actions.all(%Ecto.Query{})
  """
  @spec all(query :: queryable() | source_queryable()) :: schemas()
  def all(query) do
    all(query, default_opts())
  end

  @doc """
  Fetches all records matching the given query.

  ### Filter Parameters

  When the parameters is a keyword list the options `:repo` and `:replica` can be set.

  See `EctoShorts.CommonFilters` for more information.

  ### Options

    * `:replica` - A module that uses `Ecto.Repo`. This option takes
      precedence over the `:repo` option and will be used if set.

    * `:repo` - A module that uses `Ecto.Repo`.

  See [Ecto.Repo.all/2](https://hexdocs.pm/ecto/Ecto.Repo.html#c:all/2) for more options.

  ### Examples

      iex> EctoSchemas.Actions.all(YourSchema, %{id: 1})
      iex> EctoSchemas.Actions.all(YourSchema, id: 1, repo: YourApp.Repo)
      iex> EctoSchemas.Actions.all(YourSchema, id: 1, replica: YourApp.Repo)
      iex> EctoSchemas.Actions.all({"source", YourSchema}, %{id: 1})
      iex> EctoSchemas.Actions.all({"source", YourSchema}, id: 1, repo: YourApp.Repo)
      iex> EctoSchemas.Actions.all({"source", YourSchema}, id: 1, replica: YourApp.Repo)
      iex> EctoSchemas.Actions.all(%Ecto.Query{}, %{id: 1})
      iex> EctoSchemas.Actions.all(%Ecto.Query{}, id: 1, repo: YourApp.Repo)
      iex> EctoSchemas.Actions.all(%Ecto.Query{}, id: 1, replica: YourApp.Repo)
  """
  @spec all(
    query :: query() | queryable() | source_queryable(),
    params_or_opts :: params() | opts()
  ) :: schemas()
  def all(query, params) when is_map(params) do
    all(query, params, default_opts())
  end

  def all(query, opts) do
    query_params =
      opts
      |> Keyword.drop([:repo, :replica])
      |> Map.new()

    if Enum.any?(query_params) do
      all(query, query_params, Keyword.take(opts, [:repo, :replica]))
    else
      all(query, %{}, Keyword.take(opts, [:repo, :replica]))
    end
  end

  @doc """
  Fetches all records matching the given query.

  ### Filter Parameters

  See `EctoShorts.CommonFilters` for more information.

  ### Options

    * `:replica` - A module that uses `Ecto.Repo`. This option takes
      precedence over the `:repo` option and will be used if set.

    * `:repo` - A module that uses `Ecto.Repo`.

    * `:order_by` - Orders the fields based on one or more fields.

  See [Ecto.Repo.all/2](https://hexdocs.pm/ecto/Ecto.Repo.html#c:all/2) for more options.

  ## Examples

      iex> EctoSchemas.Actions.all(YourSchema, %{id: 1}, prefix: "public")
      iex> EctoSchemas.Actions.all(YourSchema, %{id: 1}, repo: YourApp.Repo)
      iex> EctoSchemas.Actions.all(YourSchema, %{id: 1}, replica: YourApp.Repo)
      iex> EctoSchemas.Actions.all({"source", YourSchema}, %{id: 1}, prefix: "public")
      iex> EctoSchemas.Actions.all({"source", YourSchema}, repo: YourApp.Repo)
      iex> EctoSchemas.Actions.all({"source", YourSchema}, replica: YourApp.Repo)
      iex> EctoSchemas.Actions.all(%Ecto.Query{}, %{id: 1}, prefix: "public")
      iex> EctoSchemas.Actions.all(%Ecto.Query{}, repo: YourApp.Repo)
      iex> EctoSchemas.Actions.all(%Ecto.Query{}, replica: YourApp.Repo)
  """
  @spec all(
    query :: query() | queryable() | source_queryable(),
    params :: params(),
    opts :: opts()
  ) :: schemas()
  def all(query, params, opts)  do
    order_by = Keyword.get(opts, :order_by, nil)

    params = if order_by, do: Map.put(params || %{}, :order_by, order_by), else: params

    query
    |> CommonFilters.convert_params_to_filter(params)
    |> replica!(opts).all(opts)
  end

  @doc """
  Finds a schema with matching params. Can also accept a keyword options list.

  ### Options

    * `:replica` - A module that uses `Ecto.Repo`. This option takes
      precedence over the `:repo` option and will be used if set.

    * `:repo` - A module that uses `Ecto.Repo`.

  See [Ecto.Repo.all/2](https://hexdocs.pm/ecto/Ecto.Repo.html#c:one/2) for more options.

  ### Examples

      iex> EctoSchemas.Actions.find(YourSchema, %{id: 1})
      iex> EctoSchemas.Actions.find({"source", YourSchema}, %{id: 1})
      iex> EctoSchemas.Actions.find({"source", YourSchema}, %{id: 1}, repo: YourApp.Repo)
      iex> EctoSchemas.Actions.find({"source", YourSchema}, %{id: 1}, replica: YourApp.Repo)
      iex> EctoSchemas.Actions.find(%Ecto.Query{}, %{id: 1})
      iex> EctoSchemas.Actions.find(%Ecto.Query{}, %{id: 1}, repo: YourApp.Repo)
      iex> EctoSchemas.Actions.find(%Ecto.Query{}, %{id: 1}, replica: YourApp.Repo)
  """
  @spec find(
    query :: queryable() | source_queryable(),
    params :: params(),
    opts
  ) :: schema_res | {:error, any}
  @spec find(
    query :: queryable() | source_queryable(),
    params :: params()
  ) :: schema_res | {:error, any}
  def find(query, params, opts \\ [])

  def find(query, params, _options) when params === %{} and is_atom(query) do
    {:error, Error.call(:not_found, "no records found", %{
      query: query,
      params: params
    })}
  end

  def find(query, params, opts) do
    order_by = Keyword.get(opts, :order_by, nil)

    params = if order_by, do: Map.put(params || %{}, :order_by, order_by), else: params

    query
    |> CommonFilters.convert_params_to_filter(params)
    |> replica!(opts).one(opts)
    |> case do
      nil ->
        {:error, Error.call(:not_found, "no records found", %{
          query: query,
          params: params
        })}

      schema -> {:ok, schema}
    end
  end

  @doc """
  Creates a schema with given params. Can also accept a keyword options list.

  ### Options

    * `:repo` - A module that uses `Ecto.Repo`.

  See [Ecto.Repo.insert/2](https://hexdocs.pm/ecto/Ecto.Repo.html#c:insert/2) for more options.

  ### Examples

      iex> EctoSchemas.Actions.create(YourSchema, %{name: "example"})
      iex> EctoSchemas.Actions.create(YourSchema, %{name: "example"}, repo: YourApp.Repo)
      iex> EctoSchemas.Actions.create({"source", YourSchema}, %{name: "example"})
      iex> EctoSchemas.Actions.create({"source", YourSchema}, %{name: "example"}, repo: YourApp.Repo)
  """
  @spec create(
    query :: queryable() | source_queryable(),
    params :: params(),
    opts :: opts()
  ) :: {:ok, schema()} | {:error, changeset()}
  @spec create(
    query :: queryable() | source_queryable(),
    params :: params()
  ) :: {:ok, schema()} | {:error, changeset()}
  def create(query, params, opts \\ []) do
    query
    |> build_changeset(params, opts)
    |> repo!(opts).insert(opts)
  end

  @doc """
  Finds a schema by params or creates one if it isn't found.
  Can also accept a keyword options list.

  ### Options

    * `:replica` - A module that uses `Ecto.Repo`. This option takes
      precedence over the `:repo` option and will be used to
      fetch the record if set.

    * `:repo` - A module that uses `Ecto.Repo`.

  See `find/3` and `create/3` for more information.

  ### Examples

      iex> EctoSchemas.Actions.find_or_create(YourSchema, %{name: "great name"})
      iex> EctoSchemas.Actions.find_or_create(YourSchema, %{name: "great name"}, repo: YourApp.Repo)
      iex> EctoSchemas.Actions.find_or_create(YourSchema, %{name: "great name"}, replica: YourApp.Repo.replica())
      iex> EctoSchemas.Actions.find_or_create({"source", YourSchema}, %{name: "great name"})
      iex> EctoSchemas.Actions.find_or_create({"source", YourSchema}, %{name: "great name"}, repo: YourApp.Repo)
      iex> EctoSchemas.Actions.find_or_create({"source", YourSchema}, %{name: "great name"}, replica: YourApp.Repo.replica())
  """
  @spec find_or_create(
    query :: queryable() | source_queryable(),
    params :: params(),
    opts :: opts()
  ) :: {:ok, schema()} | {:error, changeset()}
  @spec find_or_create(
    query :: queryable() | source_queryable(),
    params :: params()
  ) :: {:ok, schema()} | {:error, changeset()}
  def find_or_create(query, params, opts \\ []) do
    queryable = CommonSchemas.get_schema_queryable(query)

    find_params = drop_associations(params, queryable)

    with {:error, %{code: :not_found}} <- find(query, find_params, opts) do
      create(query, params, opts)
    end
  end

  @doc """
  Finds a schema by params and updates it or creates with results of
  params/update_params merged. Can also accept a keyword options list.

  ### Options

    * `:replica` - A module that uses `Ecto.Repo`. This option takes
      precedence over the `:repo` option and will be used to
      fetch the record if set.

    * `:repo` - A module that uses `Ecto.Repo`.

  See `find/3` and `update/4` for more information.

  ### Examples

      iex> EctoSchemas.Actions.find_and_update(YourSchema, %{id: 1}, %{name: "great name"})
      iex> EctoSchemas.Actions.find_and_update(YourSchema, %{id: 1}, %{name: "great name"}, repo: YourApp.Repo)
      iex> EctoSchemas.Actions.find_and_update(YourSchema, %{id: 1}, %{name: "great name"}, replica: YourApp.Repo.replica())
      iex> EctoSchemas.Actions.find_and_update({"source", YourSchema}, %{id: 1}, %{name: "great name"})
      iex> EctoSchemas.Actions.find_and_update({"source", YourSchema}, %{id: 1}, %{name: "great name"}, repo: YourApp.Repo)
      iex> EctoSchemas.Actions.find_and_update({"source", YourSchema}, %{id: 1}, %{name: "great name"}, replica: YourApp.Repo.replica())
  """
  @spec find_and_update(
    query :: queryable() | source_queryable(),
    find_params :: params(),
    update_params :: params(),
    opts :: opts()
  ) :: {:ok, schema()} | {:error, changeset()}
  @spec find_and_update(
    query :: queryable() | source_queryable(),
    find_params :: params(),
    update_params :: params()
  ) :: {:ok, schema()} | {:error, changeset()}
  def find_and_update(query, find_params, update_params, opts \\ []) do
    with {:ok, schema_data} <- find(query, find_params, opts) do
      update(query, schema_data, update_params, opts)
    end
  end

  @doc """
  Finds a schema by params and updates it or creates with results of
  params/update_params merged. Can also accept a keyword options list.

  ### Options

    * `:replica` - A module that uses `Ecto.Repo`. This option takes
      precedence over the `:repo` option and will be used to
      fetch the record if set.

    * `:repo` - A module that uses `Ecto.Repo`.

  See `find/3`, `create/3` and `update/4` for more information.

  ### Examples

      iex> EctoSchemas.Actions.find_and_upsert(YourSchema, %{id: 1}, %{name: "great name"})
      iex> EctoSchemas.Actions.find_and_upsert(YourSchema, %{id: 1}, %{name: "great name"}, repo: YourApp.Repo)
      iex> EctoSchemas.Actions.find_and_upsert(YourSchema, %{id: 1}, %{name: "great name"}, replica: YourApp.Repo.replica())
      iex> EctoSchemas.Actions.find_and_upsert({"source", YourSchema}, %{id: 1}, %{name: "great name"})
      iex> EctoSchemas.Actions.find_and_upsert({"source", YourSchema}, %{id: 1}, %{name: "great name"}, repo: YourApp.Repo)
      iex> EctoSchemas.Actions.find_and_upsert({"source", YourSchema}, %{id: 1}, %{name: "great name"}, replica: YourApp.Repo.replica())
  """
  @spec find_and_upsert(
    query :: queryable() | source_queryable(),
    find_params :: params(),
    update_params :: params(),
    opts :: opts()
  ) :: {:ok, schema()} | {:error, changeset()}
  @spec find_and_upsert(
    query :: queryable() | source_queryable(),
    find_params :: params(),
    update_params :: params()
  ) :: {:ok, schema()} | {:error, changeset()}
  def find_and_upsert(query, find_params, update_params, opts \\ []) do
    case find(query, find_params, opts) do
      {:ok, schema_data} ->
        update(query, schema_data, update_params, opts)

      {:error, %{code: :not_found}} ->
        create_params = Map.merge(find_params, update_params)

        create(query, create_params, opts)

      e -> e
    end
  end

  @doc """
  Updates a schema with given updates. Can also accept a keyword options list.

  ### Options

    * `:replica` - A module that uses `Ecto.Repo`. This option takes
      precedence over the `:repo` option and will be used to
      fetch the record if set.

    * `:repo` - A module that uses `Ecto.Repo`.

  See `update/4` and [Ecto.Repo.get/3](https://hexdocs.pm/ecto/Ecto.Repo.html#c:get/3) for more options.

  ### Examples

      iex> EctoSchemas.Actions.update(YourSchema, %{id: 1}, %{name: "great name"})
      iex> EctoSchemas.Actions.update(YourSchema, %{id: 1}, %{name: "great name"}, repo: YourApp.Repo)
      iex> EctoSchemas.Actions.update(YourSchema, %{id: 1}, %{name: "great name"}, replica: YourApp.Repo.replica())
      iex> EctoSchemas.Actions.update({"source", YourSchema}, %{id: 1}, %{name: "great name"})
      iex> EctoSchemas.Actions.update({"source", YourSchema}, %{id: 1}, %{name: "great name"}, repo: YourApp.Repo)
      iex> EctoSchemas.Actions.update({"source", YourSchema}, %{id: 1}, %{name: "great name"}, replica: YourApp.Repo.replica())
  """
  @spec update(
    query :: queryable() | source_queryable(),
    id :: id(),
    updates :: params()
  ) :: {:ok, schema()} | {:error, error_message() | changeset()}
  @spec update(
    query :: queryable() | source_queryable(),
    id :: id(),
    updates :: params(),
    opts
  ) :: {:ok, schema()} | {:error, error_message() | changeset()}
  @spec update(
    query :: queryable() | source_queryable(),
    schema_data :: schema(),
    updates :: params()
  ) :: {:ok, schema()} | {:error, error_message() | changeset()}
  @spec update(
    query :: queryable() | source_queryable(),
    schema_data :: schema(),
    updates :: params(),
    opts
  ) :: {:ok, schema()} | {:error, error_message() | changeset()}
  def update(query, schema_data, update_params, opts \\ [])

  def update(query, schema_id, update_params, opts) when is_integer(schema_id) or is_binary(schema_id) do
    case get(query, schema_id, opts) do
      nil ->
        {:error, Error.call(
          :not_found,
          "No item found with id: #{schema_id}",
          %{
            schema: query,
            schema_id: schema_id,
            updates: update_params
          }
        )}
      schema_data -> update(query, schema_data, update_params, opts)
    end
  end

  def update(query, schema_data, update_params, opts) when is_list(update_params) do
    update_params = Map.new(update_params)

    update(query, schema_data, update_params, opts)
  end

  def update(query, schema_data, update_params, opts) do
    query
    |> build_changeset(schema_data, update_params, opts)
    |> repo!(opts).update(opts)
  end

  @doc """
  Deletes a record given existing data.

  ### Examples

      iex> EctoSchemas.Actions.delete(%YourSchema{})
      iex> EctoSchemas.Actions.delete([%YourSchema{}])
  """
  @spec delete(schema :: schema()) :: {:ok, schema()} | {:error, any()}
  @spec delete(schemas :: schemas()) :: {:ok, schemas()} | {:error, any()}
  def delete(%_{} = schema_data) do
    delete(schema_data, default_opts())
  end

  def delete(schema_data) when is_list(schema_data) do
    delete(schema_data, default_opts())
  end

  @doc """
  Similar to `delete/1` but can also accept a keyword options list.

  ### Options

    * `:repo` - A module that uses `Ecto.Repo`.

  See [Ecto.Repo.delete/2](https://hexdocs.pm/ecto/Ecto.Repo.html#c:delete/2) for more options.

  ### Examples

      iex> EctoSchemas.Actions.delete(%YourSchema{})
      iex> EctoSchemas.Actions.create(%YourSchema{}, repo: YourApp.Repo)
  """
  @spec delete(
    schema :: schema(),
    opts :: opts()
  ) :: {:ok, schema()} | {:error, any()}
  @spec delete(
    schemas :: schemas(),
    opts :: opts()
  ) :: {:ok, schemas()} | {:error, any()}
  @spec delete(
    query :: queryable() | source_queryable(),
    id :: id()
  ) :: {:ok, schema()} | {:error, any()}
  def delete(%Ecto.Changeset{} = changeset, opts) do
    case repo!(opts).delete(changeset, opts) do
      {:error, changeset} ->
        {:error, Error.call(
          :internal_server_error,
          "Error deleting #{inspect(changeset.data.__struct__)}",
          %{changeset: changeset}
        )}
      ok -> ok
    end
  end

  def delete(%queryable{} = schema_data, opts) do
    changeset = build_changeset(queryable, schema_data, %{}, opts)

    case repo!(opts).delete(changeset, opts) do
      {:error, changeset} ->
        {:error, Error.call(
          :internal_server_error,
          "Error deleting #{inspect(queryable)}",
          %{changeset: changeset, schema_data: schema_data}
        )}
      ok -> ok
    end
  end

  def delete(schema_data, opts) when is_list(schema_data) do
    schema_data |> Enum.map(&delete(&1, opts)) |> reduce_status_tuples()
  end

  def delete(query, id) when (is_binary(id) or is_integer(id)) do
    delete(query, id, default_opts())
  end

  @doc """
  Deletes a schema. Can also accept a keyword options list.

  ### Options

    * `:replica` - A module that uses `Ecto.Repo`. This option takes
      precedence over the `:repo` option and will be used to
      fetch the record if set.

    * `:repo` - A module that uses `Ecto.Repo`.

  See `find/3` and [Ecto.Repo.delete/2](https://hexdocs.pm/ecto/Ecto.Repo.html#c:delete/2) for more options.

  ### Examples

      iex> EctoSchemas.Actions.delete(YourSchema, 1)
      iex> EctoSchemas.Actions.delete(YourSchema, "binary_id")
      iex> EctoSchemas.Actions.delete(YourSchema, "binary_id", repo: YourApp.Repo)
      iex> EctoSchemas.Actions.delete({"source", YourSchema}, 1)
      iex> EctoSchemas.Actions.delete({"source", YourSchema}, "binary_id")
      iex> EctoSchemas.Actions.delete({"source", YourSchema}, "binary_id", repo: YourApp.Repo)
  """
  @spec delete(
    query :: queryable() | source_queryable(),
    id :: id(),
    opts :: opts()
  ) :: {:ok, schema()} | {:error, any()}
  def delete(query, id, opts) when (is_integer(id) or is_binary(id)) do
    with {:ok, schema_data} <- find(query, %{id: id}, opts) do
      repo!(opts).delete(schema_data, opts)
    end
  end

  @doc """
  Returns a lazy enumerable that emits all entries matching the given query.

  ### Options

    * `:replica` - A module that uses `Ecto.Repo`. This option takes
      precedence over the `:repo` option and will be used to
      fetch the record if set.

    * `:repo` - A module that uses `Ecto.Repo`.

  See [Ecto.Repo.stream/2](https://hexdocs.pm/ecto/Ecto.Repo.html#c:stream/2) for more options.

  ### Examples

      iex> EctoSchemas.Actions.stream(YourSchema, %{id: 1})
      iex> EctoSchemas.Actions.stream(YourSchema, %{id: 1}, repo: YourApp.Repo)
      iex> EctoSchemas.Actions.stream(YourSchema, %{id: 1}, replica: YourApp.Repo)
      iex> EctoSchemas.Actions.stream({"source", YourSchema}, %{id: 1})
      iex> EctoSchemas.Actions.stream({"source", YourSchema}, %{id: 1}, repo: YourApp.Repo)
      iex> EctoSchemas.Actions.stream({"source", YourSchema}, %{id: 1}, replica: YourApp.Repo)
  """
  @spec stream(
    query :: queryable() | source_queryable(),
    params :: params(),
    opts :: opts()
  ) :: schemas()
  @spec stream(
    query :: queryable() | source_queryable(),
    params :: params()
  ) :: schemas()
  def stream(query, params, opts \\ []) do
    query
    |> CommonSchemas.get_schema_query()
    |> CommonFilters.convert_params_to_filter(params)
    |> replica!(opts).stream(opts)
  end

  @doc """
  Calculate the given aggregate.

  ### Options

    * `:replica` - A module that uses `Ecto.Repo`. This option takes
      precedence over the `:repo` option and will be used to
      fetch the record if set.

    * `:repo` - A module that uses `Ecto.Repo`.

  See [Ecto.Repo.aggregate/4](https://hexdocs.pm/ecto/Ecto.Repo.html#c:aggregate/4) for more options.

  ### Examples

      iex> EctoSchemas.Actions.aggregate(YourSchema, %{id: 1}, :count, :id)
      iex> EctoSchemas.Actions.aggregate(YourSchema, %{id: 1}, :count, :id, repo: YourApp.Repo)
      iex> EctoSchemas.Actions.aggregate(YourSchema, %{id: 1}, :count, :id, replica: YourApp.Repo)
      iex> EctoSchemas.Actions.aggregate({"source", YourSchema}, %{id: 1}, :count, :id)
      iex> EctoSchemas.Actions.aggregate({"source", YourSchema}, %{id: 1}, :count, :id, repo: YourApp.Repo)
      iex> EctoSchemas.Actions.aggregate({"source", YourSchema}, %{id: 1}, :count, :id, replica: YourApp.Repo)
  """
  @spec aggregate(
    query :: query() | queryable() | source_queryable(),
    params :: params(),
    aggregate :: aggregate_options(),
    field :: field(),
    opts :: opts()
  ) :: any() | nil
  @spec aggregate(
    query :: query() | queryable() | source_queryable(),
    params :: params(),
    aggregate :: aggregate_options(),
    field :: field()
  ) :: any() | nil
  def aggregate(query, params, aggregate, field, opts \\ []) do
    query
    |> CommonSchemas.get_schema_query()
    |> CommonFilters.convert_params_to_filter(params)
    |> replica!(opts).aggregate(aggregate, field, opts)
  end

  @doc """
  Accepts a list of schemas and attempts to find them in the DB. Any missing Schemas will be created.
  Can also accept a keyword options list.

  ***Note: Relational filtering doesn't work on this function***

  ## Options
    * `:repo` - A module that uses the Ecto.Repo Module.
    * `:replica` - If you don't want to perform any reads against your Primary, you can specify a replica to read from.

  ## Examples
    iex> {:ok, records} = EctoSchemas.Actions.find_or_create_many(EctoSchemas.Accounts.User, [%{name: "foo"}, %{name: "bar}])
    iex> length(records) === 2
  """
  @spec find_or_create_many(
    query :: queryable() | source_queryable(),
    params_list :: params_list(),
    opts :: opts()
  ) :: {:ok, schemas()} | {:error, changesets()}
  @spec find_or_create_many(
    query :: queryable() | source_queryable(),
    params_list :: params_list()
  ) :: {:ok, schemas()} | {:error, changesets()}
  def find_or_create_many(query, param_list, opts) do
    queryable = CommonSchemas.get_schema_queryable(query)

    find_param_list =
      Enum.map(param_list, fn params ->
        drop_associations(params, queryable)
      end)

    {create_params, found_results} = find_many(query, find_param_list, opts)

    query
    |> multi_insert(param_list, create_params, opts)
    |> repo!(opts).transaction()
    |> case do
      {:ok, created_map} -> {:ok, merge_found(created_map, found_results)}
      error -> error
    end
  end

  def find_or_create_many(schema, param_list) do
    find_or_create_many(schema, param_list, default_opts())
  end

  defp find_many(schema, param_list, opts) do
    param_list
    |> Enum.map(fn params ->
      case find(schema, params, opts) do
        {:ok, schema_data} -> schema_data
        _ -> nil
      end
    end)
    |> Enum.with_index()
    |> Enum.split_with(fn {schema_data, _index} -> is_nil(schema_data) end)
  end

  defp multi_insert(queryable, param_list, create_params, opts) do
    Enum.reduce(create_params, Ecto.Multi.new(), fn {nil, i}, multi ->
      Ecto.Multi.insert(multi, i, fn _ ->
        build_changeset(queryable, Enum.at(param_list, i), opts)
      end)
    end)
  end

  defp build_changeset({source, queryable}, schema_data, params, opts) do
    schema_data = SchemaHelpers.build_struct(schema_data, source: source)

    build_changeset(queryable, schema_data, params, opts)
  end

  defp build_changeset(queryable, schema_data, params, opts) do
    case opts[:changeset] do
      nil ->
        queryable.changeset(schema_data, params)

      func when is_function(func, 2) ->
        func.(schema_data, params)

      func when is_function(func, 1) ->
        schema_data
        |> queryable.changeset(params)
        |> func.()
    end
  end

  defp build_changeset({source, queryable}, params, opts) do
    loaded_struct = CommonSchemas.get_loaded_struct({source, queryable})

    build_changeset(queryable, loaded_struct, params, opts)
  end

  defp build_changeset(queryable, params, opts) do
    if Code.ensure_loaded?(queryable) and function_exported?(queryable, :create_changeset, 1) do
      queryable.create_changeset(params)
    else
      struct = struct(queryable)

      build_changeset(queryable, struct, params, opts)
    end
  end

  defp drop_associations(params, queryable) do
    Map.drop(params, queryable.__schema__(:associations))
  end

  defp merge_found(created_map, found_results) do
    created_map
    |> Enum.map(fn {index, result} -> {result, index} end)
    |> Kernel.++(found_results)
    |> Enum.sort(&(elem(&1, 1) >= elem(&2, 1)))
    |> Enum.map(&elem(&1, 0))
  end

  defp reduce_status_tuples(status_tuples) do
    {status, res} =
      Enum.reduce(status_tuples, {:ok, []}, fn
        {:ok, _}, {:error, _} = e -> e
        {:ok, record}, {:ok, acc} -> {:ok, [record | acc]}
        {:error, error}, {:ok, _} -> {:error, [error]}
        {:error, e}, {:error, error_acc} -> {:error, [e | error_acc]}
      end)

    {status, Enum.reverse(res)}
  end

  defp repo!(opts) do
    with nil <- repo(opts) do
      raise ArgumentError, message: "ecto shorts must be configured with a repo. For further guidence consult the docs. https://hexdocs.pm/ecto_shorts/EctoShorts.html#module-config"
    end
  end

  # `replica!/1` will attempt to retrieve a repo from the replica key and default to
  # returning the value under the repo: key if no replica is found. If no repos are configured
  # an ArgumentError will be raised.
  defp replica!(opts) do
    with nil <- Keyword.get(opts, :replica),
      nil <- repo(opts) do
      raise ArgumentError, message: "ecto shorts must be configured with a repo. For further guidence consult the docs. https://hexdocs.pm/ecto_shorts/EctoShorts.html#module-config"
    end
  end

  defp repo([]) do
    Config.repo()
  end

  defp repo(opts) do
    default_opts()
    |> Keyword.merge(opts)
    |> Keyword.get(:repo)
  end

  defp default_opts, do: [repo: Config.repo()]
end
