defmodule EctoShorts.Schemas.UserData do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  schema "data_stores" do
    field :data, :map
    belongs_to :creator, EctoShorts.Schemas.User
  end

  @available_fields [
    :data,
    :creator_id
  ]

  def changeset(model_or_changeset, attrs \\ %{}) do
    cast(model_or_changeset, attrs, @available_fields)
  end
end
