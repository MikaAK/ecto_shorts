defmodule EctoShorts.Schema.EnumSchema do
  @moduledoc false
  use Ecto.Schema

  schema "enum_test" do
    field :status, Ecto.Enum, values: [draft: 0, published: 1, archived: 2]
    field :views, :integer
  end
end
