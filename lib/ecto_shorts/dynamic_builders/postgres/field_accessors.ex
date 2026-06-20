defmodule EctoShorts.DynamicBuilders.Postgres.FieldAccessors do
  @moduledoc since: "3.0.0"
  @moduledoc """
  Compile-time generated field accessors for the Postgres dynamic builder.

  Generates one `field_dyn/2` clause per supported query binding position (and a
  `known_binding?/1` guard) from `EctoShorts.QueryBinding.query_binding_contracts/1`,
  so the other Postgres expression modules can resolve a dynamic field reference
  against the correct binding. This module is internal to the
  `Ecto.Adapters.Postgres` dynamic-builder pipeline (the only adapter that ships)
  and is exercised through `EctoShorts.CommonFilters` params rather than called
  directly.
  """

  alias EctoShorts.QueryBinding

  import Ecto.Query

  {target_binding_var, binding_patterns} = QueryBinding.query_binding_contracts(__MODULE__)

  for {quoted_binding_head, quoted_binding_body} <- binding_patterns do
    def field_dyn(unquote(quoted_binding_head), key) do
      dynamic(
        [unquote_splicing(quoted_binding_body)],
        field(unquote(target_binding_var), ^key)
      )
    end

    def known_binding?(unquote(quoted_binding_head)), do: true
  end

  def known_binding?(_selected_binding), do: false
end
