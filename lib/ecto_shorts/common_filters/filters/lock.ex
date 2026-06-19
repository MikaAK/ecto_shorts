defmodule EctoShorts.CommonFilters.Lock do
  @moduledoc since: "3.0.0"
  @moduledoc false

  alias EctoShorts.Config
  alias EctoShorts.QueryBinding
  alias EctoShorts.QueryProvider

  alias Ecto.Query
  require Ecto.Query

  @logger_prefix "EctoShorts.CommonFilters.Lock"

  def build_query(:lock, _source, query, selected_binding, params, opts) do
    if (is_map(params) and not is_struct(params)) or Keyword.keyword?(params) do
      case params[:name] do
        nil -> query
        name -> lock_expr(query, selected_binding, name, params, opts)
      end
    else
      raise EctoShorts.FilterError,
            "lock filter expects a map or keyword list with a :name key (e.g. %{name: :for_update}), got: #{inspect(params)}"
    end
  end

  defp query_provider(opts) do
    opts[:query_provider] || Config.query_provider_module()
  end

  ## Generated Functions

  {_, binding_patterns} = QueryBinding.query_binding_contracts(__MODULE__)

  for {quoted_binding_head, quoted_binding_body} <- binding_patterns do
    defp lock_expr(query, unquote(quoted_binding_head), :for_update, _values, _opts) do
      Query.lock(query, [unquote_splicing(quoted_binding_body)], "FOR UPDATE")
    end

    defp lock_expr(query, unquote(quoted_binding_head), :for_share, _values, _opts) do
      Query.lock(query, [unquote_splicing(quoted_binding_body)], "FOR SHARE")
    end
  end

  defp lock_expr(query, selected_binding, custom_name, params, opts) do
    values = params[:values] || %{}
    query_provider_module = query_provider(opts)

    if is_nil(query_provider_module) do
      EctoShorts.LogUtils.warning(
        @logger_prefix,
        "No query provider module configured for lock filter"
      )

      query
    else
      case QueryProvider.query_expression(
             query_provider_module,
             selected_binding,
             custom_name,
             values,
             opts
           ) do
        nil ->
          query

        {:ok, callback} ->
          if is_function(callback, 1) do
            case callback.(query) do
              next_query when is_struct(next_query, Ecto.Query) ->
                next_query

              other ->
                raise EctoShorts.FilterError,
                      "lock expression callback must return an Ecto.Query, got: #{inspect(other)}"
            end
          else
            raise EctoShorts.FilterError,
                  "lock expression resolved from QueryProvider must be a 1-arity function, got: #{inspect(callback)}"
          end

        {:error, reason} ->
          EctoShorts.LogUtils.warning(
            @logger_prefix,
            "Lock expression callback returned error for #{inspect(custom_name)}: #{inspect(reason)}"
          )

          query

        other ->
          raise EctoShorts.FilterError,
                "lock expression resolved from QueryProvider must return {:ok, function} | {:error, reason} | nil, got: #{inspect(other)}"
      end
    end
  end
end
