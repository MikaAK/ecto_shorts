defmodule EctoShorts.Support.Schemas.UserAvatar do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  schema "user_avatars" do
    field :name, :string
    field :description, :string

    belongs_to :user, EctoShorts.Support.Schemas.User

    timestamps()
  end

  @available_fields [
    :name,
    :description
  ]

  def changeset(model_or_changeset, attrs \\ %{}) do
    cast(model_or_changeset, attrs, @available_fields)
  end
end
