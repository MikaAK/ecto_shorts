defmodule EctoShorts.TestDynamicBuilderAdapter do
  @moduledoc false

  import Ecto.Query

  def operators, do: []

  def operator?(key), do: key in operators()

  def build_dynamic(_source, _selected_binding, key, _expr) do
    dynamic([q], field(q, ^key) == ^:override)
  end
end
