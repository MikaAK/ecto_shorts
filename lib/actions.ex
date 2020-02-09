defmodule EctoShorts.Actions do
  @moduledoc """
  Actions for crud in ecto, this can be used by all schemas/queries
  """

  @type queryable :: module | Ecto.Query.t()
  @type id :: pos_integer()
  @type filter_params :: Keyword.t() | map
  @type aggregate_options :: :avg | :count | :max | :min | :sum
  @type schema_res :: {:ok, Ecto.Schema.t()} | {:error, String.t()}

  alias EctoShorts.{CommonFilters, Repo, Actions.Error, QueryBuilder}

  @spec get(module, id) :: Ecto.Schema.t() | nil
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
  def get(schema, id), do: Repo.get(schema, id)

  @spec all(queryable) :: [Ecto.Schema.t()]
  @doc """
  Gets a collection of schemas from the database

  ## Examples

      iex> EctoSchemas.Actions.all(EctoSchemas.Accounts.User)
      []
  """
  def all(query), do: Repo.all(query)

  @spec all(queryable, params :: filter_params) :: [Ecto.Schema.t()]
  @doc """
  Gets a collection of schemas from the database but allows for a filter

  ## Examples

      iex> Enum.each(1..4, fn _ -> create_user() end)
      iex> length(EctoSchemas.Actions.all(EctoSchemas.Accounts.User, first: 3)) === 3
      true
  """
  def all(query, params), do: Repo.all(CommonFilters.convert_params_to_filter(query, params))

  @spec find(queryable, params :: filter_params) :: schema_res
  @doc """
  Finds a schema with matching params

  ## Examples

      iex> user = create_user()
      iex> {:ok, schema} = EctoSchemas.Actions.find(EctoSchemas.Accounts.User, first_name: user.first_name)
      iex> schema.first_name === user.first_name
      true
  """
  def find(query, params) do
    repo_query = query |> CommonFilters.convert_params_to_filter(params) |> Ecto.Query.first()

    case Repo.one(repo_query) do
      nil ->
        {:error,
         Error.call(:not_found, "no records found", %{
           query: query,
           params: params
         })}

      schema ->
        {:ok, schema}
    end
  end

  @spec create(module, map) :: {:ok, Ecto.Schema.t()} | {:error, Ecto.Changeset.t()}
  @doc """
  Creates a schema with given params

  ## Examples

      iex> {:ok, schema} = EctoSchemas.Actions.create(EctoSchemas.Accounts.User, user_params(first_name: "TEST"))
      iex> schema.first_name
      "TEST"
      iex> {:error, changeset} = EctoSchemas.Actions.create(EctoSchemas.Accounts.User, Map.delete(user_params(), :first_name))
      iex> "can't be blank" in errors_on(changeset).first_name
      true
  """
  def create(schema, params), do: Repo.insert(schema.create_changeset(params))

  @spec find_or_create(Ecto.Query.t(), map) ::
          {:ok, Ecto.Schema.t()} | {:error, Ecto.Changeset.t()}
   @doc "Finds a schema by params or creates one if it isn't found"
  def find_or_create(query, params) do
    with {:error, _} <- find(query, params) do
      schema = QueryBuilder.query_schema(query)
      create(schema, params)
    end
  end

  @spec update(
          schema :: module,
          id :: integer,
          updates :: map | Keyword.t()
        ) :: {:ok, Ecto.Schema.t()} | {:error, Ecto.Changeset.t()}
  @doc """
  Updates a schema with given updates

  ## Examples

      iex> user = create_user()
      iex> {:ok, schema} = EctoSchemas.Actions.update(EctoSchemas.Accounts.User, user, first_name: user.first_name)
      iex> schema.first_name === user.first_name
      true
  """
  def update(schema, schema_id, updates) when is_integer(schema_id) do
    case get(schema, schema_id) do
      nil ->
        {:error,
         Error.call(
           :not_found,
           "No item found with id: #{schema_id}",
           %{
             schema: schema,
             schema_id: schema_id,
             updates: updates
           }
         )}

      schema_data ->
        update(schema, schema_data, updates)
    end
  end

  @spec update(
          schema :: module,
          schema_data :: map,
          updates :: Keyword.t()
        ) :: {:ok, Ecto.Schema.t()} | {:error, Ecto.Changeset.t()}
  def update(schema, schema_data, updates) when is_list(updates) do
    res = schema.changeset(schema_data, Map.new(updates))

    with {:ok, schema_data} <- Repo.update(res) do
      {:ok, schema_data}
    else
      {:error, e} ->
        {:error,
         Error.call(:bad_request, e, %{
           schema: schema,
           schema_data: schema_data,
           updates: updates
         })}
    end
  end

  @spec update(
          schema :: module,
          schema_data :: Ecto.Schema.t(),
          updates :: map
        ) :: {:ok, Ecto.Schema.t()} | {:error, Ecto.Changeset.t()}
  def update(schema, schema_data, updates) do
    with {:ok, schema_data} <- Repo.update(schema.changeset(schema_data, updates)) do
      {:ok, schema_data}
    else
      {:error, e} ->
        {:error,
         Error.call(:bad_request, e, %{
           schema: schema,
           schema_data: schema_data,
           updates: updates
         })}
    end
  end

  @spec delete(schema_data :: Ecto.Schema.t()) ::
          {:ok, Ecto.Schema.t()} | {:error, Ecto.Changeset.t()}
  @doc """
  Deletes a schema

  ## Examples

      iex> user = create_user()
      iex> {:ok, schema} = EctoSchemas.Actions.delete(user)
      iex> schema.first_name === user.first_name
      true
  """
  def delete(schema_data) do
    case Repo.delete(schema_data) do
      {:error, e} ->
        {:error,
         Error.call(
           :internal_server_error,
           e,
           %{schema_data: schema_data}
         )}

      ok ->
        ok
    end
  end

  @spec delete(schema :: Ecto.Schema.t(), id :: integer) ::
          {:ok, Ecto.Schema.t()} | {:error, Ecto.Changeset.t()}
  @doc """
  Deletes a schema

  ## Examples

      iex> user = create_user()
      iex> {:ok, schema} = EctoSchemas.Actions.delete(EctoSchemas.Accounts.User, user.id)
      iex> schema.first_name === user.first_name
      true
  """
  def delete(schema, id) do
    with {:ok, schema_data} <- find(schema, %{id: id}) do
      Repo.delete(schema_data)
    end
  end

  @spec stream(Ecto.Query.t(), params :: filter_params) :: Enum.t()
  @doc "Gets a collection of schemas from the database but allows for a filter"
  def stream(query, params) do
    Repo.stream(CommonFilters.convert_params_to_filter(query, params))
  end

  @spec aggregate(
          Ecto.Query.t(),
          params :: filter_params,
          agg_opts :: aggregate_options,
          field :: atom,
          opts :: Keyword.t()
        ) :: term
  @spec aggregate(
          Ecto.Query.t(),
          params :: filter_params,
          agg_opts :: aggregate_options,
          field :: atom
        ) :: term
  def aggregate(schema, params, aggregate, field, opts \\ []) do
    Repo.aggregate(
      CommonFilters.convert_params_to_filter(schema, params),
      aggregate,
      field,
      opts
    )
  end
end
