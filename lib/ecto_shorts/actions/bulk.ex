defmodule EctoShorts.Actions.Bulk do
  @moduledoc since: "3.0.0"
  @moduledoc """
  Bulk insert, update, and delete operations for Ecto schemas.

  Wraps `c:Ecto.Repo.insert_all/3`, `c:Ecto.Repo.update_all/3`, and
  `c:Ecto.Repo.delete_all/2`, delegating param conversion to
  `EctoShorts.CommonParams` and filtering to `EctoShorts.CommonFilters`. It is
  the engine behind the `insert_all`/`update_all`/`delete_all` entry points in
  `EctoShorts.Actions` and is reached through them rather than called directly.
  """

  # Bulk insert, update, and delete operations for Ecto schemas.
  #
  # Provides efficient batch operations using Ecto's insert_all, update_all,
  # and delete_all methods with proper parameter conversion and error handling.

  alias EctoShorts.{
    CommonFilters,
    Config,
    CommonParams,
    CommonSchema
  }

  @doc false
  def insert_all(source, params_list, opts) do
    with {:ok, inserts} <- CommonParams.convert_to_insert_params(source, params_list, opts) do
      on_conflict_options = CommonParams.build_on_conflict_options(source, inserts, opts)

      {:ok,
       Config.repo!(opts).insert_all(
         source,
         inserts,
         Keyword.merge(on_conflict_options, opts)
       )}
    end
  end

  @doc false
  def update_all(source, find_params, update_params, opts) do
    updates =
      source
      |> CommonSchema.get_schema_source()
      |> CommonParams.convert_to_update_params(update_params, opts)

    source
    |> CommonFilters.convert_params_to_filter(find_params, opts)
    |> Config.repo!(opts).update_all(updates, opts)
  end

  @doc false
  def delete_all(queryable, params, opts) do
    queryable
    |> CommonFilters.convert_params_to_filter(params, opts)
    |> Config.repo!(opts).delete_all(opts)
  end
end
