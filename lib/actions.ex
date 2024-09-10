defmodule EctoShorts.Actions do
  @moduledoc """
  Actions for CRUD in ecto, these can be used by all schemas/queries

  Generally we can define our contexts to be very reusable by creating
  them to look something like this:


      defmodule MyApp.Accounts do
        alias EctoShorts.Actions
        alias MyApp.Accounts.User

        def all_users(params), do: Actions.all(User, params)
        def find_user(params), do: Actions.find(User, params)
      end

  We're then able to use this context with all filters that are
  supported by `EctoShorts.CommonFilters` without having to create new queries


      def do_something do
        MyApp.Accounts.all_user(%{
          first_name: %{ilike: "john"},
          age: %{gte: 18},
          priority_level: 5,
          address: %{country: "Canada"}
        })
      end


  You can read more on reusable ecto code [here](https://learn-elixir.dev/blogs/creating-reusable-ecto-code)

  ### Supporting multiple Repos

  To support multiple repos, what we can do is pass arguments to the last parameter
  of most `EctoShorts.Actions` calls

  #### Example

      defmodule MyApp.Accounts do
        alias EctoShorts.Actions
        alias MyApp.Accounts.User

        @repo [repo: MyApp.Repo.Replica1]

        def all_users(params), do: Actions.all(User, params, @repo)
        def find_user(params), do: Actions.find(User, params, @repo)
      end
  """

  @type query :: Ecto.Query.t() | Ecto.Schema.t()| module()
  @type filter_params :: Keyword.t | map
  @type opts :: Keyword.t
  @type aggregate_options :: :avg | :count | :max | :min | :sum
  @type schema_list :: list(Ecto.Schema.t)
  @type schema_res :: {:ok, Ecto.Schema.t} | {:error, any}

  alias EctoShorts.{Actions.Error, CommonFilters, Config}

  @doc """
  Gets a schema from the database

  ## Examples

      iex> user = create_user()
      iex> %{id: id} = EctoSchemas.Actions.get(EctoSchemas.Accounts.User, user.id)
      iex> id === user.id
      true
      iex> EctoSchemas.Actions.get(EctoSchemas.Accounts.User, 2504390) # ID nonexistant
      nil
  """
  @spec get(queryable :: query, id :: term, options :: Keyword.t) :: Ecto.Schema.t | nil
  @spec get(queryable :: query, id :: term) :: Ecto.Schema.t | nil
  def get(schema, id, opts \\ []) do
    replica!(opts).get(schema, id, opts)
  end

  @doc """
  Gets a collection of schemas from the database

  ## Examples

      iex> EctoSchemas.Actions.all(EctoSchemas.Accounts.User)
      []
  """
  @spec all(queryable :: query) :: list()
  def all(query) do
    all(query, default_opts())
  end

  @doc """
  Gets a collection of schemas from the database but allows for a filter or
  an options list.

  ## Options
    * `:repo` - A module that uses the Ecto.Repo Module.

  ## Examples

      iex> Enum.each(1..4, fn _ -> create_user() end)
      iex> length(EctoSchemas.Actions.all(EctoSchemas.Accounts.User, first: 3)) === 3
      true

      iex> Enum.each(1..4, fn _ -> create_user() end)
      iex> length(EctoSchemas.Actions.all(EctoSchemas.Accounts.User, repo: MyApp.MyRepoModule.Repo)) === 3
      true
  """
  @spec all(queryable :: query, filter_params | opts) :: list()
  def all(query, params) when is_map(params) do
    all(query, params, default_opts())
  end

  def all(query, opts) do
    query_params = Keyword.drop(opts, [:repo, :replica])

    if Enum.any?(query_params) do
      all(query, query_params, default_opts())
    else
      all(query, %{}, Keyword.take(opts, [:repo, :replica]))
    end
  end

  @doc """
  Similar to `all/2` but can also accept a keyword options list.

  ## Options
    * `:repo` - A module that uses the Ecto.Repo Module.

  ## Examples

    iex> Enum.each(1..4, fn _ -> create_user() end)
    iex> length(EctoSchemas.Actions.all(EctoSchemas.Accounts.User, first: 3, repo: MyApp.MyRepoModule.Repo)) === 3
    true
  """
  @spec all(queryable :: query, params :: filter_params, opts) :: list()
  def all(query, params, opts)  do
    order_by = Keyword.get(opts, :order_by, nil)

    params = if order_by, do: Map.put(params || %{}, :order_by, order_by), else: params

    replica!(opts).all(
      CommonFilters.convert_params_to_filter(query, params),
      opts
    )
  end

  @doc """
  Finds a schema with matching params. Can also accept a keyword options list.

  ## Options
    * `:repo` - A module that uses the Ecto.Repo Module.

  ## Examples

      iex> user = create_user()
      iex> {:ok, schema} = EctoSchemas.Actions.find(EctoSchemas.Accounts.User, first_name: user.first_name)
      iex> schema.first_name === user.first_name
      true

      iex> user = create_user()
      iex> {:ok, schema} = EctoSchemas.Actions.find(EctoSchemas.Accounts.User, first_name: user.first_name, repo: MyApp.MyRepoModule.Repo)
      iex> schema.first_name === user.first_name
      true
  """
  @spec find(queryable :: query, params :: filter_params, opts) :: schema_res | {:error, any}
  @spec find(queryable :: query, params :: filter_params) :: schema_res | {:error, any}
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

  ## Options
    * `:repo` - A module that uses the Ecto.Repo Module.

  ## Examples

      iex> {:ok, schema} = EctoSchemas.Actions.create(EctoSchemas.Accounts.User, user_params(first_name: "TEST"))
      iex> schema.first_name
      "TEST"
      iex> {:error, changeset} = EctoSchemas.Actions.create(EctoSchemas.Accounts.User, Map.delete(user_params(), :first_name))
      iex> "can't be blank" in errors_on(changeset).first_name
      true

  ## Examples

      iex> {:ok, schema} = EctoSchemas.Actions.create(EctoSchemas.Accounts.User, user_params(first_name: "TEST"), repo: MyApp.MyRepoModule.Repo)
      iex> schema.first_name
      true
  """
  @spec create(schema :: module(), params :: filter_params, opts) :: {:ok, Ecto.Schema.t} | {:error, Ecto.Changeset.t}
  @spec create(schema :: module(), params :: filter_params) :: {:ok, Ecto.Schema.t} | {:error, Ecto.Changeset.t}
  def create(schema, params, opts \\ []) do
    repo!(opts).insert(create_changeset(params, schema), opts)
  end

  @doc """
  Finds a schema by params or creates one if it isn't found.
  Can also accept a keyword options list.

  ***Note: Relational filtering doesn't work on this function***

  ## Options
    * `:repo` - A module that uses the Ecto.Repo Module.
    * `:replica` - If you don't want to perform any reads against your Primary, you can specify a replica to read from.

  ## Examples
      iex> {:ok, schema} = EctoSchemas.Actions.find_or_create(EctoSchemas.Accounts.User, %{name: "great name"})

      iex> {:ok, schema} = EctoSchemas.Actions.find_or_create(EctoSchemas.Accounts.User, %{name: "great name"}, repo: MyApp.MyRepoModule.Repo, replica: MyApp.MyRepoModule.Repo.replica())
  """
  @spec find_or_create(query(), map, opts) :: {:ok, Ecto.Schema.t} | {:error, Ecto.Changeset.t}
  @spec find_or_create(query(), map) :: {:ok, Ecto.Schema.t} | {:error, Ecto.Changeset.t}
  def find_or_create(schema, params, opts \\ []) do
    find_params = Map.drop(params, schema.__schema__(:associations))

    with {:error, %{code: :not_found}} <- find(schema, find_params, opts) do
      create(schema, params, opts)
    end
  end

  @doc """
  Finds a schema by params and updates it or creates with results of
  params/update_params merged. Can also accept a keyword options list.

  ***Note: Relational filtering doesn't work on this function***

  ## Options
    * `:repo` - A module that uses the Ecto.Repo Module.
    * `:replica` - If you don't want to perform any reads against your Primary, you can specify a replica to read from.

  ## Examples
      iex> {:ok, schema} = EctoSchemas.Actions.find_and_update(EctoSchemas.Accounts.User, %{email: "some_email"}, %{name: "great name"})

      iex> {:ok, schema} = EctoSchemas.Actions.find_and_update(EctoSchemas.Accounts.User, %{email: "some_email"}, %{name: "great name}, repo: MyApp.MyRepoModule.Repo, replica: MyApp.MyRepoModule.Repo.replica())
  """
  @spec find_and_update(query(), map, map, opts) :: {:ok, Ecto.Schema.t()} | {:error, any()}
  def find_and_update(schema, params, update_params, opts \\ []) do
    find_params = Map.drop(params, schema.__schema__(:associations))

    with {:ok, transaction} <- find(schema, find_params, opts) do
      update(schema, transaction, update_params, opts)
    end
  end

  @doc """
  Finds a schema by params and updates it or creates with results of
  params/update_params merged. Can also accept a keyword options list.

  ***Note: Relational filtering doesn't work on this function***

  ## Options
    * `:repo` - A module that uses the Ecto.Repo Module.
    * `:replica` - If you don't want to perform any reads against your Primary, you can specify a replica to read from.

  ## Examples
      iex> {:ok, schema} = EctoSchemas.Actions.find_and_upsert(EctoSchemas.Accounts.User, %{email: "some_email"}, %{name: "great name"})

      iex> {:ok, schema} = EctoSchemas.Actions.find_and_upsert(EctoSchemas.Accounts.User, %{email: "some_email"}, %{name: "great name}, repo: MyApp.MyRepoModule.Repo, replica: MyApp.MyRepoModule.Repo.replica())
  """
  @spec find_and_upsert(query(), map, map, opts) :: {:ok, Ecto.Schema.t()} | {:error, any()}
  def find_and_upsert(schema, params, update_params, opts \\ []) do
    find_params = Map.drop(params, schema.__schema__(:associations))

    case find(schema, find_params, opts) do
      {:ok, transaction} -> update(schema, transaction, update_params, opts)
      {:error, %{code: :not_found}} -> create(schema, Map.merge(params, update_params), opts)
      e -> e
    end
  end

  @doc """
  Updates a schema with given updates. Can also accept a keyword options list.

  ## Options
    * `:repo` - A module that uses the Ecto.Repo Module.
    * `:replica` - If you don't want to perform any reads against your Primary, you can specify a replica to read from.

  ## Examples

      iex> user = create_user()
      iex> {:ok, schema} = EctoSchemas.Actions.update(EctoSchemas.Accounts.User, user, first_name: user.first_name)
      iex> schema.first_name === user.first_name
      true

      iex> user = create_user()
      iex> {:ok, schema} = EctoSchemas.Actions.update(EctoSchemas.Accounts.User, 1, first_name: user.first_name, repo: MyApp.MyRepoModule.Repo, replica: MyApp.MyRepoModule.Repo.replica())
      iex> schema.first_name === user.first_name
      true
  """
  @spec update(
    schema :: Ecto.Schema.t() | module(),
    id :: pos_integer | String.t(),
    updates :: map() | Keyword.t()
  ) :: {:ok, Ecto.Schema.t} | {:error, Ecto.Changeset.t}
  @spec update(
    schema :: Ecto.Schema.t() | module(),
    id :: pos_integer | String.t(),
    updates :: map() | Keyword.t(),
    opts
  ) :: {:ok, Ecto.Schema.t} | {:error, Ecto.Changeset.t}
  @spec update(
    schema :: Ecto.Schema.t() | module(),
    schema_data :: Ecto.Schema.t(),
    updates :: map() | Keyword.t()
  ) :: {:ok, Ecto.Schema.t} | {:error, Ecto.Changeset.t}
  @spec update(
    schema :: Ecto.Schema.t() | module(),
    schema_data :: Ecto.Schema.t(),
    updates :: map() | Keyword.t(),
    opts
  ) :: {:ok, Ecto.Schema.t} | {:error, Ecto.Changeset.t}

  def update(schema, schema_data, updates, opts \\ [])

  def update(schema, schema_id, updates, opts) when is_integer(schema_id) or is_binary(schema_id) do
    case get(schema, schema_id, opts) do
      nil ->
        {:error, Error.call(
          :not_found,
          "No item found with id: #{schema_id}",
          %{
            schema: schema,
            schema_id: schema_id,
            updates: updates
          }
        )}
      schema_data -> update(schema, schema_data, updates, opts)
    end
  end

  def update(schema, schema_data, updates, opts) when is_list(updates) do
    update(schema, schema_data, Map.new(updates), opts)
  end

  def update(schema, schema_data, updates, opts) do
    repo!(opts).update(schema.changeset(schema_data, updates), opts)
  end

  @doc """
  Deletes a schema

  ## Examples

      iex> user = create_user()
      iex> {:ok, schema} = EctoSchemas.Actions.delete(user)
      iex> schema.first_name === user.first_name
      true
  """

  @spec delete(schema_data :: Ecto.Schema.t | schema_list() | module()) :: {:ok, Ecto.Schema.t} | {:error, any()}
  def delete(%_{} = schema_data) do
    delete(schema_data, default_opts())
  end
  def delete(schema_data) when is_list(schema_data) do
    delete(schema_data, default_opts())
  end

  @doc """
  Similar to `delete/1` but can also accept a keyword options list.

  ## Options
    * `:repo` - A module that uses the Ecto.Repo Module.

  ## Examples

      iex> user = create_user()
      iex> {:ok, schema} = EctoSchemas.Actions.delete(user, repo: MyApp.MyRepoModule.Repo)
      iex> schema.first_name === user.first_name
      true
  """
  @spec delete(schema_data :: Ecto.Schema.t | schema_list() | module(), opts) :: {:ok, Ecto.Schema.t} | {:error, any()}
  def delete(%schema{} = schema_data, opts) do
    # The schema data is wrapped in a changeset before delete
    # so that ecto can apply the constraint error to the
    # changeset instead of raising `Ecto.ConstraintError`.
    changeset = changeset(schema, schema_data, %{})

    case repo!(opts).delete(changeset, opts) do
      {:error, changeset} ->
        {:error, Error.call(
          :internal_server_error,
          "Error deleting #{inspect(schema)}",
          %{changeset: changeset, schema_data: schema_data}
        )}
      ok -> ok
    end
  end

  def delete(schema_data, opts) when is_list(schema_data) do
    schema_data |> Enum.map(&delete(&1, opts)) |> reduce_status_tuples
  end

  @spec delete(schema :: module(), id :: integer) :: {:ok, Ecto.Schema.t} | {:error, any()}
  def delete(schema, id) when is_atom(schema) and (is_binary(id) or is_integer(id)) do
    delete(schema, id, default_opts())
  end

  @doc """
  Deletes a schema. Can also accept a keyword options list.

  ## Options
    * `:repo` - A module that uses the Ecto.Repo Module.

  ## Examples

      iex> user = create_user()
      iex> {:ok, schema} = EctoSchemas.Actions.delete(EctoSchemas.Accounts.User, user.id)
      iex> schema.first_name === user.first_name
      true

      iex> user = create_user()
      iex> {:ok, schema} = EctoSchemas.Actions.delete(EctoSchemas.Accounts.User, user.id)
      iex> schema.first_name === user.first_name
      true
  """
  @spec delete(schema :: module(), id :: integer, opts) :: {:ok, Ecto.Schema.t} | {:error, any()}
  def delete(schema, id, opts) when is_atom(schema) and (is_integer(id) or is_binary(id)) do
    with {:ok, schema_data} <- find(schema, %{id: id}, opts) do
      repo!(opts).delete(schema_data, opts)
    end
  end

  @spec stream(queryable :: query, params :: filter_params, opts) :: Enum.t
  @spec stream(queryable :: query, params :: filter_params) :: Enum.t
  @doc "Gets a collection of schemas from the database but allows for a filter"
  def stream(query, params, opts \\ []) do
    repo!(opts).stream(
      CommonFilters.convert_params_to_filter(query, params),
      opts
    )
  end

  @spec aggregate(
    queryable :: query,
    params :: filter_params,
    agg_opts :: aggregate_options,
    field :: atom,
    opts
  ) :: term
  @spec aggregate(
    queryable :: query,
    params :: filter_params,
    agg_opts :: aggregate_options,
    field :: atom
  ) :: term
  def aggregate(schema, params, aggregate, field, opts \\ []) do
    repo!(opts).aggregate(
      CommonFilters.convert_params_to_filter(schema, params),
      aggregate,
      field,
      opts
    )
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
    query(),
    list(map),
    opts
  ) :: {:ok, list(Ecto.Schema.t())} | {:error, list(Ecto.Changeset.t())}
  def find_or_create_many(schema, param_list, opts) do
    find_param_list = Enum.map(param_list, &Map.drop(&1, schema.__schema__(:associations)))

    {create_params, found_results} = find_many(schema, find_param_list, opts)

    schema
    |> multi_insert(param_list, create_params)
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
        {:ok, result} -> result
        _ -> nil
      end
    end)
    |> Enum.with_index()
    |> Enum.split_with(fn {result, _index} -> is_nil(result) end)
  end

  defp multi_insert(schema, param_list, create_params) do
    Enum.reduce(create_params, Ecto.Multi.new(), fn {nil, i}, multi ->
      Ecto.Multi.insert(multi, i, fn _ ->
        param_list
        |> Enum.at(i)
        |> create_changeset(schema)
      end)
    end)
  end

  defp changeset(schema, schema_data, params) do
    schema.changeset(schema_data, params)
  end

  defp create_changeset(params, schema) do
    if Code.ensure_loaded?(schema) and function_exported?(schema, :create_changeset, 1) do
      schema.create_changeset(params)
    else
      schema_data = struct(schema)

      changeset(schema, schema_data, params)
    end
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
    with nil <- Keyword.get(opts, :replica, repo(opts)) do
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
