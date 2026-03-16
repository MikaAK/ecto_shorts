defmodule EctoShorts.CommonParams.Placeholders do
  @moduledoc since: "3.0.0"
  @moduledoc """
  Replaces matching field values with placeholder tuples for `insert_all`.

  When a field's value matches the configured placeholder value, it is
  replaced with `{:placeholder, field_name}`. Conflict behaviour is
  controlled by the `:on_placeholder_conflict` option.
  """

  def put_placeholders(data, placeholders, opts) do
    Enum.reduce(placeholders, data, &put_placeholder(&1, &2, opts))
  end

  defp put_placeholder({key, placeholder_value}, data, opts) do
    if Map.has_key?(data, key) do
      if Map.get(data, key) === placeholder_value do
        put_placeholder(data, key)
      else
        on_placeholder_conflict(data, key, opts)
      end
    else
      data
    end
  end

  defp on_placeholder_conflict(input, key, opts) do
    case Keyword.get(opts, :on_placeholder_conflict, :nothing) do
      {:replace, keys} ->
        if Enum.member?(keys, key) do
          put_placeholder(input, key)
        else
          input
        end

      :replace_all ->
        put_placeholder(input, key)

      :nothing ->
        input

      term ->
        raise ArgumentError,
              "Expected the value for option :on_placeholder_conflict to be one of " <>
                "[:replace, :replace_all, :nothing], got: #{inspect(term)}"
    end
  end

  defp put_placeholder(input, key), do: Map.put(input, key, {:placeholder, key})
end
