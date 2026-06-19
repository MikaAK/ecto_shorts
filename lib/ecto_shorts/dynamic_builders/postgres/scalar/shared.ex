defmodule EctoShorts.DynamicBuilders.Postgres.Scalar.Shared do
  # Helpers used by more than one scalar operator-family sub-module.
  # nil_field_dyn?/2 and not_nil_dyn/2 are called by both Comparison (scalar nil
  # checks) and Aggregate (aggregate nil checks), so they live here rather than
  # in either family module.
  @moduledoc false
  @moduledoc since: "3.0.0"

  alias EctoShorts.DynamicBuilders.Postgres.FieldAccessors

  import Ecto.Query

  def nil_field_dyn?(binding, key) do
    f = FieldAccessors.field_dyn(binding, key)
    dynamic([], is_nil(^f))
  end

  def not_nil_dyn(binding, key) do
    f = FieldAccessors.field_dyn(binding, key)
    dynamic([], not is_nil(^f))
  end
end
