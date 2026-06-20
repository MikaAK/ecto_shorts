defmodule EctoShorts.Types do
  @moduledoc """
  Casts and dumps a value through an `Ecto.Type`.

  Used internally to normalize filter param values into their database
  representation before query construction; a `nil` type returns the value
  unchanged, and any cast/dump failure falls back to the original value. It is
  exercised through `EctoShorts.CommonFilters` params rather than called
  directly.
  """

  alias Ecto.Type

  @doc """
  Casts then dumps `value` using the given Ecto `type`, returning the dumped
  value. A `nil` type, or a cast/dump failure, returns `value` unchanged.

      iex> EctoShorts.Types.cast(:integer, "42")
      42

      iex> EctoShorts.Types.cast(nil, "unchanged")
      "unchanged"
  """
  def cast(nil, value), do: value

  def cast(type, value) do
    with {:ok, cast} <- Type.cast(type, value),
         {:ok, dumped} <- Type.dump(type, cast) do
      dumped
    else
      _ -> value
    end
  end
end
