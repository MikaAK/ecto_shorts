defmodule EctoShorts.CommonFilters.Parser do
  @moduledoc """
  Parser for common filter structures.
  """

  @typedoc """
  A two-arity predicate consulted at every `{key, value}` pair during
  normalizeing. Returning `false` emits the pair as-is and stops recursion
  into `value`.
  """
  @type predicate :: (any(), any() -> boolean())

  @doc """
  Extracts entries from a nested map structure into a list of key-value pairs.

  ## Examples

      iex> EctoShorts.CommonFilters.Parser.extract_entries(%{"a" => 1, "b" => %{"c" => 2}})
      [{"a", 1}, {"b", %{"c" => 2}}]
  """
  def extract_entries(entries) do
    reduce_container(entries, [])
  end

  defp reduce_container(entries, acc) when is_map(entries) and not is_struct(entries) do
    entries
    |> Map.to_list()
    |> reduce_container(acc)
  end

  defp reduce_container([], acc) do
    acc
  end

  defp reduce_container([head | tail], acc) do
    reduce_container(tail, reduce_container(head, acc))
  end

  defp reduce_container({key, entries}, acc) when is_map(entries) and not is_struct(entries) do
    reduce_container({key, Map.to_list(entries)}, acc)
  end

  defp reduce_container({key, entries}, acc) when is_list(entries) do
    if Keyword.keyword?(entries) do
      Enum.reduce(entries, acc, fn entry, acc ->
        reduce_container({key, entry}, acc)
      end)
    else
      apply_operation(key, {nil, entries}, acc)
    end
  end

  defp reduce_container({key, value}, acc) do
    case value do
      {op, {k2, {k3, v3}}} ->
        apply_operation(key, {op, {k2, {k3, v3}}}, acc)

      {op, entries} when op in [:==] ->
        Enum.reduce(entries, acc, fn entry, acc ->
          reduce_container({key, {op, entry}}, acc)
        end)

      {op, entries} when is_map(entries) and not is_struct(entries) ->
        Enum.reduce(entries, acc, fn entry, acc ->
          reduce_container({key, {op, entry}}, acc)
        end)

      {op, entries} when is_list(entries) ->
        if Keyword.keyword?(entries) do
          Enum.reduce(entries, acc, fn entry, acc ->
            reduce_container({key, {op, entry}}, acc)
          end)
        else
          apply_operation(key, {op, entries}, acc)
        end

      value ->
        apply_operation(key, value, acc)
    end
  end

  defp apply_operation(key, value, acc) do
    # This is where you would define the behavior for a key-operation-value tuple
    case value do
      {op, value} -> [{key, {op, value}} | acc]
      value -> [{key, value} | acc]
    end
  end

  @doc """
  Default predicate that always returns true, allowing all pairs to be expanded.
  """
  def default_predicate(_key, _value), do: true

  @doc """
  Flattens a nested map structure into a list of key-value pairs.

  An optional `predicate` of arity two is consulted at every `{key, value}`
  pair before expansion. Returning `true` (the default) descends into
  `value`; returning `false` emits the pair unchanged and halts further
  recursion at that branch.

  ## Examples

      iex> EctoShorts.CommonFilters.Parser.normalize(%{"a" => 1, "b" => %{"c" => 2}})
      [{"a", 1}, {"b", {"c", 2}}]

      iex> EctoShorts.CommonFilters.Parser.normalize(%{"a" => 1, "b" => %{"c" => 2, "d" => 3}})
      [{"a", 1}, {"b", {"c", 2}}, {"b", {"d", 3}}]

      iex> stop_at_c = fn key, _value -> key != "c" end
      ...> EctoShorts.CommonFilters.Parser.normalize(%{"a" => 1, "b" => %{"c" => %{"d" => 2}}}, stop_at_c)
      [{"a", 1}, {"b", {"c", %{"d" => 2}}}]
  """
  @spec normalize(any()) :: list()
  @spec normalize(any(), predicate()) :: list()
  @spec normalize(any(), predicate(), list()) :: list()
  def normalize(entries, predicate \\ &default_predicate/2, acc \\ [])
      when is_function(predicate, 2) do
    do_normalize(entries, predicate, acc)
  end

  defp do_normalize(map, predicate, acc) when is_map(map) and not is_struct(map) do
    map
    |> Map.to_list()
    |> do_normalize(predicate, acc)
  end

  defp do_normalize([], _predicate, acc) do
    acc
  end

  defp do_normalize([head | rest], predicate, acc) do
    do_normalize(head, predicate, do_normalize(rest, predicate, acc))
  end

  defp do_normalize({key, value}, predicate, acc) do
    if predicate.(key, value) do
      value
      |> normalize(predicate, [])
      |> reverse()
      |> prepend_key(acc, key)
    else
      [{key, value} | acc]
    end
  end

  defp do_normalize(value, _predicate, acc) do
    [value | acc]
  end

  defp prepend_key([], acc, _key) do
    acc
  end

  defp prepend_key([entry | rest], acc, key) do
    prepend_key(rest, [{key, entry} | acc], key)
  end

  defp reverse(items), do: do_reverse(items, [])
  defp do_reverse([], acc), do: acc
  defp do_reverse([a], acc), do: [a | acc]
  defp do_reverse([a, b], acc), do: [b, a | acc]
  defp do_reverse([a, b, c], acc), do: [c, b, a | acc]
  defp do_reverse([h | t], acc), do: do_reverse(t, [h | acc])
end
