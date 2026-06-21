defmodule EctoShorts.Schema.EnumParent do
  @moduledoc false
  use Ecto.Schema

  schema "enum_parents" do
    has_one :enum_schema, EctoShorts.Schema.EnumSchema
  end
end
