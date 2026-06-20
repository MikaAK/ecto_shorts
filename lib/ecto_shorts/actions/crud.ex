defmodule EctoShorts.Actions.CRUD do
  @moduledoc false

  alias Ecto.Changeset

  alias EctoShorts.Actions.Error
  alias EctoShorts.Actions.Source

  alias EctoShorts.{
    CommonFilters,
    Config,
    CommonSchema
  }

  @doc false
  def preload(data, preloads, opts) do
    Config.replica!(opts).preload(data, preloads, opts)
  end

  @doc false
  def exists?(%Source{} = source, params, opts) do
    with {:ok, queryable, input_params} <- resolve_source(source, params, opts) do
      exists?(queryable, input_params, opts)
    end
  end

  def exists?(source, params, opts) do
    source
    |> CommonFilters.convert_params_to_filter(params, opts)
    |> Config.replica!(opts).exists?(opts)
  end

  @doc false
  def all(queryable) do
    all(queryable, %{}, [])
  end

  def all(%Source{} = source, params) when is_map(params) and not is_struct(params) do
    with {:ok, queryable, input_params} <- resolve_source(source, params, []) do
      all(queryable, input_params, [])
    end
  end

  def all(queryable, params) when is_map(params) and not is_struct(params) do
    all(queryable, params, [])
  end

  def all(queryable, params) when is_list(params) do
    all(queryable, params, [])
  end

  def all(%Source{} = source, params, opts) do
    with {:ok, queryable, input_params} <- resolve_source(source, params, opts) do
      all(queryable, input_params, opts)
    end
  end

  def all(queryable, params, opts) do
    params =
      params
      |> put_param(opts, :order_by)
      |> put_param(opts, :group_by)

    records =
      queryable
      |> CommonFilters.convert_params_to_filter(params, opts)
      |> Config.replica!(opts).all(opts)

    case opts[:preload] do
      nil -> records
      [] -> records
      preloads -> preload(records, preloads, opts)
    end
  end

  @doc false
  def create(%Source{} = source, params, opts) do
    with {:ok, queryable, input_params} <- resolve_source(source, params, opts) do
      create(queryable, input_params, opts)
    end
  end

  def create(schema, params, opts) do
    schema
    |> CommonSchema.create_changeset(params, opts)
    |> Config.repo!(opts).insert(opts)
    |> handle_response_preload(opts)
  end

  @doc false
  def get(queryable, id, opts) do
    result = Config.replica!(opts).get(queryable, id, opts)

    case opts[:preload] do
      nil -> result
      [] -> result
      _preloads when result === nil -> nil
      preloads -> preload(result, preloads, opts)
    end
  end

  @doc false
  def find(%Source{} = source, params, opts) do
    with {:ok, queryable, input_params} <- resolve_source(source, params, opts) do
      find(queryable, input_params, opts)
    end
  end

  def find(query, params, opts)
      when (params === %{} or params === []) and not is_struct(query, Ecto.Query) do
    {:error,
     Error.call(
       :not_found,
       "record not found.",
       %{
         query: query,
         params: params
       },
       opts
     )}
  end

  def find(source, params, opts) do
    params =
      params
      |> put_param(opts, :order_by)
      |> put_param(opts, :group_by)

    opts = Keyword.drop(opts, [:order_by, :group_by])

    case source
         |> CommonFilters.convert_params_to_filter(params, opts)
         |> Config.replica!(opts).one(opts) do
      nil ->
        {:error,
         Error.call(
           :not_found,
           "record not found.",
           %{
             query: source,
             params: params
           },
           opts
         )}

      record ->
        {:ok,
         case opts[:preload] do
           nil -> record
           [] -> record
           preloads -> preload(record, preloads, opts)
         end}
    end
  end

  @doc false
  def update(queryable, id, params, opts) when is_integer(id) or is_binary(id) do
    with {:ok, record} <- find(queryable, %{id: id}, opts) do
      update(queryable, record, params, opts)
    end
  end

  def update(queryable, schema_struct, params, opts) do
    changeset =
      queryable
      |> CommonSchema.create_changeset(schema_struct, params, opts)
      |> maybe_apply_optimistic_lock(queryable, opts)

    result = Config.repo!(opts).update(changeset, opts)
    handle_response_preload(result, opts)
  rescue
    Ecto.StaleEntryError ->
      {:error,
       Error.call(
         :stale,
         "record has been modified by another process.",
         %{
           schema: CommonSchema.get_schema(queryable),
           struct: schema_struct
         },
         opts
       )}
  end

  @doc false
  def delete(data) do
    delete(data, [])
  end

  def delete(%{data: %{__meta__: %{schema: schema}}} = changeset, opts) do
    do_delete(changeset, schema, opts)
  end

  def delete(%{__meta__: %{schema: schema}} = schema_struct, opts) do
    do_delete(schema_struct, schema, opts)
  end

  def delete(records_or_changesets, opts) when is_list(records_or_changesets) do
    with {:ok, results} <-
           Enum.reduce_while(records_or_changesets, {:ok, []}, fn entry, {:ok, acc} ->
             case delete(entry, opts) do
               {:ok, result} -> {:cont, {:ok, [result | acc]}}
               {:error, reason} -> {:halt, {:error, reason}}
             end
           end) do
      {:ok, Enum.reverse(results)}
    end
  end

  def delete(queryable, id, opts) when is_integer(id) or is_binary(id) do
    with {:ok, record} <- find(queryable, %{id: id}, opts) do
      delete(record, opts)
    end
  end

  def delete(_queryable, %_{} = struct_or_changeset, opts) do
    delete(struct_or_changeset, opts)
  end

  @doc false
  def stream(%Source{} = source, params, opts) do
    with {:ok, queryable, input_params} <- resolve_source(source, params, opts) do
      stream(queryable, input_params, opts)
    end
  end

  def stream(queryable, params, opts) do
    queryable
    |> CommonFilters.convert_params_to_filter(params, opts)
    |> Config.replica!(opts).stream(opts)
  end

  @doc false
  def aggregate(%Source{} = source, params, aggregate, key, opts) do
    with {:ok, queryable, input_params} <- resolve_source(source, params, opts) do
      aggregate(queryable, input_params, aggregate, key, opts)
    end
  end

  def aggregate(queryable, params, aggregate, key, opts) do
    queryable
    |> CommonFilters.convert_params_to_filter(params, opts)
    |> Config.replica!(opts).aggregate(aggregate, key, opts)
  end

  @doc false
  def find_and_create(%Source{} = source, find_params, create_params, opts) do
    with {:ok, queryable, clean_find_params} <- resolve_source(source, find_params, opts) do
      find_and_create(queryable, clean_find_params, create_params, opts)
    end
  end

  def find_and_create(queryable, find_params, create_params, opts) do
    with {:error, _} <- find(queryable, find_params, Keyword.delete(opts, :preload)) do
      create(queryable, create_params, opts)
    end
  end

  @doc false
  def find_and_update(%Source{} = source, find_params, update_params, opts) do
    with {:ok, queryable, clean_find_params} <- resolve_source(source, find_params, opts) do
      find_and_update(queryable, clean_find_params, update_params, opts)
    end
  end

  def find_and_update(source, find_params, update_params, opts) do
    with {:ok, record} <- find(source, find_params, Keyword.delete(opts, :preload)) do
      update(source, record, update_params, opts)
    end
  end

  @doc false
  def find_and_upsert(%Source{} = source, find_params, upsert_params, opts) do
    with {:ok, queryable, clean_find_params} <- resolve_source(source, find_params, opts) do
      find_and_upsert(queryable, clean_find_params, upsert_params, opts)
    end
  end

  def find_and_upsert(source, find_params, upsert_params, opts)
      when is_map(find_params) and not is_struct(find_params) do
    find_and_upsert(source, Map.to_list(find_params), upsert_params, opts)
  end

  def find_and_upsert(source, find_params, upsert_params, opts)
      when is_map(upsert_params) and not is_struct(upsert_params) do
    find_and_upsert(source, find_params, Map.to_list(upsert_params), opts)
  end

  def find_and_upsert(source, find_params, upsert_params, opts) do
    case find(source, find_params, Keyword.delete(opts, :preload)) do
      {:ok, record} -> update(source, record, upsert_params, opts)
      {:error, _} -> create(source, Keyword.merge(find_params, upsert_params), opts)
    end
  end

  @doc false
  def find_and_delete(%Source{} = source, find_params, opts) do
    with {:ok, queryable, clean_find_params} <- resolve_source(source, find_params, opts) do
      find_and_delete(queryable, clean_find_params, opts)
    end
  end

  def find_and_delete(source, find_params, opts) do
    with {:ok, record} <- find(source, find_params, opts) do
      delete(record, opts)
    end
  end

  @doc false
  def find_or_create(%Source{} = source, params, opts) do
    with {:ok, queryable, input_params} <- resolve_source(source, params, opts) do
      find_or_create(queryable, input_params, opts)
    end
  end

  def find_or_create(source, params, opts)
      when is_map(params) and not is_struct(params) do
    find_or_create(source, Map.to_list(params), opts)
  end

  def find_or_create(source, params, opts) do
    fields = CommonSchema.get_query_fields(opts, source)
    find_params = Keyword.take(params, fields)

    result =
      with {:error, _} <- find(source, find_params, Keyword.delete(opts, :preload)) do
        source
        |> CommonSchema.get_schema_source()
        |> create(params, opts)
      end

    handle_response_preload(result, opts)
  end

  @doc false
  def resolve_source(%Source{} = source, params, opts) do
    from_key = if is_map(params), do: params[:from], else: Keyword.get(params, :from)

    case Source.fetch(source, from_key) do
      {:ok, queryable} ->
        input_params =
          if is_map(params),
            do: Map.delete(params, :from),
            else: Keyword.delete(params, :from)

        {:ok, queryable, input_params}

      :error ->
        {:error, Error.call(:not_found, "source not found.", %{from: from_key}, opts)}
    end
  end

  @doc false
  def handle_response_preload({:ok, value}, opts) do
    {:ok,
     case opts[:preload] do
       nil -> value
       [] -> value
       preloads -> preload(value, preloads, opts)
     end}
  end

  def handle_response_preload(other, _opts), do: other

  defp do_delete(schema_data, schema, opts) do
    with {:error, failed_changeset} <-
           schema
           |> CommonSchema.create_changeset(schema_data, opts)
           |> Config.repo!(opts).delete(opts) do
      {:error,
       Error.call(
         :conflict,
         "failed to delete record.",
         %{
           schema: schema,
           changeset: failed_changeset
         },
         opts
       )}
    end
  end

  defp put_param(enum, opts, key) do
    case Keyword.get(opts, key) do
      nil ->
        enum

      value ->
        if is_map(enum) do
          Map.put(enum, key, value)
        else
          enum ++ [{key, value}]
        end
    end
  end

  defp maybe_apply_optimistic_lock(changeset, queryable, opts) do
    case resolve_optimistic_lock(queryable, opts) do
      false ->
        changeset

      {field, incrementer} when is_atom(field) and is_function(incrementer, 1) ->
        Changeset.optimistic_lock(changeset, field, incrementer)

      field when is_atom(field) ->
        Changeset.optimistic_lock(changeset, field)
    end
  end

  defp resolve_optimistic_lock(queryable, opts) do
    case Keyword.fetch(opts, :optimistic_lock) do
      {:ok, value} ->
        value

      :error ->
        schema = CommonSchema.get_schema(queryable)

        if schema !== nil and function_exported?(schema, :optimistic_lock, 0) do
          schema.optimistic_lock()
        else
          false
        end
    end
  end
end
