defmodule EctoShorts.CommonFilters.PutQueryPrefix do
  @moduledoc since: "3.0.0"
  @moduledoc """
  Implements the `:put_query_prefix` structural filter for `EctoShorts.CommonFilters`.

  Sets the schema search path prefix on the query using
  `Ecto.Query.put_query_prefix/2`. Useful for multi-tenant applications that
  organise tenants by PostgreSQL schema. The value should be a binary prefix
  string. Used via params, not called directly:

      EctoShorts.Actions.all(Post, %{put_query_prefix: "tenant_acme"})

  See `EctoShorts.QueryBuilder` for the `build_query/6` callback contract.
  """

  alias Ecto.Query
  require Ecto.Query

  def build_query(:put_query_prefix, _source, query, _selected_binding, prefix, _opts) do
    Query.put_query_prefix(query, prefix)
  end
end
