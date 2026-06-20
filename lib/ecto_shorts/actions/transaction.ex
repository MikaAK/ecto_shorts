defmodule EctoShorts.Actions.Transaction do
  @moduledoc since: "3.0.0"
  @moduledoc """
  Wraps Ecto.Repo.transaction/2 for `EctoShorts.Actions.transaction/2` and
  `EctoShorts.Actions.transact/2`.

  Handles the strict (`transact`) mode — unwrapping `{:ok, {:ok, value}}` and
  rolling back on an `{:error, reason}` returned by the transaction function —
  and normalizes the transaction response into the EctoShorts result shape. It
  is internal machinery reached through `EctoShorts.Actions` rather than called
  directly.
  """

  alias EctoShorts.Config

  @doc false
  def normalize_transaction_response(result, opts) do
    unwrap? = Keyword.get(opts, :strict, true)

    case {unwrap?, result} do
      {_, {:error, :error}} ->
        :error

      {_, {:ok, :ok}} ->
        :ok

      {true, {:ok, {:error, _} = error}} ->
        error

      {true, {:ok, {:ok, _} = response}} ->
        response

      {_, other} ->
        other
    end
  end

  @doc false
  def eval_transaction_fun(fun, repo, opts) do
    response = call_transaction_fun(fun, repo)

    if Keyword.get(opts, :strict, true) do
      maybe_rollback(response, repo)
    else
      response
    end
  end

  @doc false
  def run_transaction(fun_or_multi, opts) do
    Config.repo!(opts).transaction(fun_or_multi, opts)
  end

  defp call_transaction_fun(fun, repo) when is_function(fun, 1), do: fun.(repo)
  defp call_transaction_fun(fun, _repo) when is_function(fun, 0), do: fun.()

  defp maybe_rollback(:error, repo), do: repo.rollback(:error)
  defp maybe_rollback({:error, reason}, repo), do: repo.rollback(reason)
  defp maybe_rollback({:ok, value}, _repo), do: value
  defp maybe_rollback(term, _repo), do: term
end
