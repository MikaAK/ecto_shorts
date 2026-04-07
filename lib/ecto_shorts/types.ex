defmodule EctoShorts.Types do
  @moduledoc false

  alias Ecto.Type

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
