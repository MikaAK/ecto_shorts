defmodule EctoShorts.TestQueryProvider do
  @moduledoc false

  import Ecto.Query

  def query_expression(_selected_binding, :active_users, params, _opts) do
    params = normalize_params(params)

    with {:ok, min_age} <- fetch_integer(params, :min_age) do
      {:ok, from(u in fragment("SELECT * FROM users WHERE age >= ?", ^min_age), select: u)}
    end
  end

  def query_expression(_selected_binding, :for_update, _params, _opts) do
    {:ok, fn query -> from(q in query, lock: "FOR UPDATE") end}
  end

  def query_expression(_selected_binding, :for_share, _params, _opts) do
    {:ok, fn query -> from(q in query, lock: "FOR SHARE") end}
  end

  def query_expression(_selected_binding, :provider_for_update, _params, _opts) do
    {:ok, fn query -> from(q in query, lock: "FOR UPDATE") end}
  end

  def query_expression(_selected_binding, :for_update_with_clause, params, _opts) do
    params = normalize_params(params)

    with {:ok, clause} <- fetch_string(params, :clause) do
      case clause do
        "SKIP LOCKED" ->
          {:ok, fn query -> from(q in query, lock: fragment("FOR UPDATE SKIP LOCKED")) end}

        _ ->
          {:error, {:unsupported_clause, clause}}
      end
    end
  end

  def query_expression(_selected_binding, :post_window, _params, _opts) do
    {:ok, [partition_by: [:author_id], order_by: [desc: :inserted_at]]}
  end

  def query_expression(_selected_binding, :error_fragment, _params, _opts) do
    {:error, :forced_error}
  end

  def query_expression(_selected_binding, :legacy_active_users, params, _opts) do
    params = normalize_params(params)

    with {:ok, min_age} <- fetch_integer(params, :min_age) do
      from(u in fragment("SELECT * FROM users WHERE age >= ?", ^min_age), select: u)
    end
  end

  def query_expression(_selected_binding, :legacy_for_update, _params, _opts) do
    fn query -> from(q in query, lock: "FOR UPDATE") end
  end

  def query_expression(_selected_binding, :callback_bad_return, _params, _opts) do
    {:ok, fn _query -> :not_a_query end}
  end

  def query_expression(_selected_binding, :callback_not_function, _params, _opts) do
    {:ok, :not_a_function}
  end

  def query_expression(_selected_binding, _source_key, _params, _opts) do
    {:error, :unsupported_fragment_key}
  end

  defp normalize_params(params) when is_map(params), do: Map.to_list(params)
  defp normalize_params(params), do: params

  defp fetch_integer(params, key) do
    case Keyword.get(params, key) do
      value when is_integer(value) -> {:ok, value}
      _ -> {:error, {:missing_or_invalid, key}}
    end
  end

  defp fetch_string(params, key) do
    case Keyword.get(params, key) do
      value when is_binary(value) and value !== "" -> {:ok, value}
      _ -> {:error, {:missing_or_invalid, key}}
    end
  end
end
