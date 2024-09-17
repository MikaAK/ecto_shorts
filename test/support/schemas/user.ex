defmodule EctoShorts.Support.Schemas.User do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field :email, :string

    has_many :comments, EctoShorts.Support.Schemas.Comment

    many_to_many :posts, EctoShorts.Support.Schemas.Post,
      join_through: EctoShorts.Support.Schemas.UserPost

    timestamps()
  end

  @available_attributes [:email]

  def changeset(model_or_changeset, attrs \\ %{}) do
    cast(model_or_changeset, attrs, @available_attributes)
  end
end
