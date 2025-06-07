defmodule EctoShorts.TestQueryBuilder do
  @moduledoc false

  alias Ecto.Query
  require Ecto.Query

  @behaviour EctoShorts.QueryBuilder

  @filters ~w(limit)a

  @impl EctoShorts.QueryBuilder
  def filters, do: @filters

  @impl EctoShorts.QueryBuilder
  def build_query(query, binding_alias, schema, key, value, opts \\ [])

  def build_query(query, binding_alias, _schema, :limit, value, _opts) do
    if binding_alias do
      Query.limit(query, [{^binding_alias, q}], ^value)
    else
      Query.limit(query, [q], ^value)
    end
  end
end
