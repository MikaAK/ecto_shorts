defmodule EctoShorts.QueryBuilders do
  @moduledoc since: "3.0.0"
  @moduledoc """
  Resolves the active `QueryBuilder` adapter and dispatches `build_query/6`.

  This module is the adapter-selection layer for per-key query building,
  analogous to `EctoShorts.DynamicBuilders` for expression building. It
  resolves the active `EctoShorts.QueryBuilder` implementation from
  call-time opts, then application config, then the default
  (`EctoShorts.CommonFilters.Builder`), and delegates `build_query/6` to it.

  The default implementation — `EctoShorts.CommonFilters.Builder` — routes each
  filter key to the appropriate sub-module. Custom implementations receive
  every key and can delegate unhandled keys back to the default filter dispatch (see `EctoShorts.QueryBuilder`).

  ## Adapter resolution order

    1. `opts[:query_builder]` — per-call override
    2. `config :ecto_shorts, query_builder_module: MyModule` — application default
    3. `EctoShorts.CommonFilters.Builder` — framework default

  ## Examples

      EctoShorts.QueryBuilders.build_query(
        :where,
        Post,
        from(p in Post),
        {:as, nil},
        {:published, true},
        []
      )
  """

  alias EctoShorts.Config
  alias EctoShorts.LogUtils

  @default_adapter EctoShorts.CommonFilters.Builder

  @doc """
  Resolves the active `QueryBuilder` adapter and calls `build_query/6` on it.

  If the resolved adapter does not export `build_query/6`, logs a warning and
  returns the query unchanged. Raises `ArgumentError` if the configured value
  is not a module atom.
  """
  @spec build_query(
          filter :: atom(),
          source :: term(),
          query :: Ecto.Query.t(),
          selected_binding :: {:as, atom()} | {:at, pos_integer()},
          term :: term(),
          opts :: keyword()
        ) :: Ecto.Query.t()
  def build_query(filter, source, query, selected_binding, term, opts \\ []) do
    case adapter(opts) do
      module when is_atom(module) ->
        if Code.ensure_loaded?(module) and function_exported?(module, :build_query, 6) do
          module.build_query(filter, source, query, selected_binding, term, opts)
        else
          LogUtils.warning(
            "EctoShorts.QueryBuilders",
            "Module does not export the required function build_query/6: #{inspect(module)}"
          )

          query
        end

      term ->
        raise ArgumentError,
              "Expected :query_builder option to be a module, got: #{inspect(term)}"
    end
  end

  defp adapter(opts) do
    opts[:query_builder] ||
      Config.query_builder_module() ||
      @default_adapter
  end
end
