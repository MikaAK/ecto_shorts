defmodule EctoShorts.DynamicBuilders.Postgres.FieldAccessors do
  @moduledoc since: "3.0.0"
  @moduledoc false

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
