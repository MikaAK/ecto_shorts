defmodule EctoShorts.TestPayloadProbeAdapter do
  @moduledoc false

  import Ecto.Query

  def operators, do: [:exists]

  def operator?(key), do: key in operators()

  def build_dynamic(_source, _selected_binding, key, expr) do
    send(self(), {:payload_probe_expr, key, expr})
    dynamic([q], not is_nil(field(q, ^:id)))
  end
end
