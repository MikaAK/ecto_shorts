defmodule EctoShorts.Schema.UserData do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  schema "data_stores" do
    field :data, :map
    field :typed_map, {:map, :string}
    belongs_to :creator, EctoShorts.Schema.User
  end

  @available_fields [
    :data,
    :typed_map,
    :creator_id
  ]

  def changeset(schema_data_or_changeset, attrs \\ %{}) do
    cast(schema_data_or_changeset, attrs, @available_fields)
  end
end
