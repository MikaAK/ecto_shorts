defmodule EctoShorts.Actions do
  @moduledoc """
  Actions for CRUD in ecto, these can be used by all schemas/queries
  """

  @type query :: Ecto.Query | Ecto.Schema
  @type filter_params :: Keyword.t | map
  @type aggregate_options :: :avg | :count | :max | :min | :sum
  @type schema_list :: list(Ecto.Schema.t) | []
  @type schema_res :: {:ok, Ecto.Schema.t} | {:error, any}

  alias EctoShorts.{CommonFilters, Actions.Error, Config}

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
  @spec all(queryable :: query) :: schema_list
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
  @spec all(queryable :: query, params :: filter_params) :: schema_list
  def all(query, params) when is_map(params) do
    all(query, params, default_opts())
  end

  @spec all(queryable :: query, opts :: Keyword.t) :: schema_list
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
  @spec all(queryable :: query, params :: filter_params, opts :: Keyword.t) :: schema_list
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
  @spec find(queryable :: query, params :: filter_params, opts :: Keyword.t) :: schema_res
  @spec find(queryable :: query, params :: filter_params) :: schema_res
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
  @spec create(schema :: Ecto.Schema.t, params :: filter_params, opts :: Keyword.t) :: {:ok, Ecto.Schema.t} | {:error, Ecto.Changeset.t}
  @spec create(schema :: Ecto.Schema.t, params :: filter_params) :: {:ok, Ecto.Schema.t} | {:error, Ecto.Changeset.t}
  def create(schema, params, opts \\ []) do
    repo!(opts).insert(schema.create_changeset(params), opts)
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
  @spec find_or_create(Ecto.Schema.t, map, opts :: Keyword.t) :: {:ok, Ecto.Schema.t} | {:error, Ecto.Changeset.t}
  @spec find_or_create(Ecto.Schema.t, map) :: {:ok, Ecto.Schema.t} | {:error, Ecto.Changeset.t}
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
  @spec find_and_update(Ecto.Schema.t(), map, map, opts :: Keyword.t) :: {:ok, Ecto.Schema.t()} | {:error, Ecto.Changeset.t()}
  def find_and_update(schema, params, update_params, opts \\ []) do
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
    schema :: Ecto.Schema.t,
    schema_data :: map,
    updates :: Keyword.t,
    opts :: Keyword.t
  ) :: {:ok, Ecto.Schema.t} | {:error, Ecto.Changeset.t}
  @spec update(
    schema :: Ecto.Schema.t,
    schema_data :: map,
    updates :: Keyword.t
  ) :: {:ok, Ecto.Schema.t} | {:error, Ecto.Changeset.t}
  def update(schema, schema_data, updates, opts \\ [])

  @spec update(
    schema :: Ecto.Schema.t,
    id :: integer,
    updates :: map | Keyword.t,
    opts :: Keyword.t
  ) :: {:ok, Ecto.Schema.t} | {:error, Ecto.Changeset.t}
  @spec update(
    schema :: Ecto.Schema.t,
    id :: integer,
    updates :: map | Keyword.t
  ) :: {:ok, Ecto.Schema.t} | {:error, Ecto.Changeset.t}
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

  @spec update(
    schema :: Ecto.Schema.t,
    schema_data :: map,
    updates :: Keyword.t,
    opts :: Keyword.t
  ) :: {:ok, Ecto.Schema.t} | {:error, Ecto.Changeset.t}
  @spec update(
    schema :: Ecto.Schema.t,
    schema_data :: map,
    updates :: Keyword.t
  ) :: {:ok, Ecto.Schema.t} | {:error, Ecto.Changeset.t}
  def update(schema, schema_data, updates, opts) when is_list(updates) do
    update(schema, schema_data, Map.new(updates), opts)
  end

  @spec update(
    schema :: module,
    schema_data :: Ecto.Schema.t,
    updates :: map,
    opts :: Keyword.t
  ) :: {:ok, Ecto.Schema.t} | {:error, Ecto.Changeset.t}
  @spec update(
    schema :: module,
    schema_data :: Ecto.Schema.t,
    updates :: map
  ) :: {:ok, Ecto.Schema.t} | {:error, Ecto.Changeset.t}
  def update(schema, schema_data, updates, opts) do
    with {:ok, schema_data} <- repo!(opts).update(schema.changeset(schema_data, updates), opts) do
      {:ok, schema_data}
    else
      {:error, changeset} ->
        {:error, Error.call(:bad_request, "Error updating #{inspect(schema)}", %{
          changeset: changeset,
          schema: schema,
          schema_data: schema_data,
          updates: updates
        })}
    end
  end

  @doc """
  Deletes a schema

  ## Examples

      iex> user = create_user()
      iex> {:ok, schema} = EctoSchemas.Actions.delete(user)
      iex> schema.first_name === user.first_name
      true
  """
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
  @spec delete(schema_data :: Ecto.Schema.t, opts :: Keyword.t) :: {:ok, Ecto.Schema.t} | {:error, Ecto.Changeset.t}
  @spec delete(schema_data :: Ecto.Schema.t) :: {:ok, Ecto.Schema.t} | {:error, Ecto.Changeset.t}
  def delete(%schema{} = schema_data, opts) do
    case repo!(opts).delete(schema_data, opts) do
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

  @spec delete(schema :: Ecto.Schema.t, id :: integer) :: {:ok, Ecto.Schema.t} | {:error, Ecto.Changeset.t}
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
  @spec delete(schema :: Ecto.Schema.t, id :: integer, opts :: Keyword.t) :: {:ok, Ecto.Schema.t} | {:error, Ecto.Changeset.t}
  def delete(schema, id, opts) when is_atom(schema) and (is_integer(id) or is_binary(id)) do
    with {:ok, schema_data} <- find(schema, %{id: id}, opts) do
      repo!(opts).delete(schema_data, opts)
    end
  end

  @spec stream(queryable :: query, params :: filter_params, opts :: Keyword.t) :: Enum.t
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
    opts :: Keyword.t
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
    Ecto.Schema.t(),
    list(map),
    opts :: Keyword.t
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
        |> schema.create_changeset
      end)
    end)
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
