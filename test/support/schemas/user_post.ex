defmodule EctoShorts.Support.Schemas.UserPost do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false

  schema "users_posts" do
    belongs_to :post, EctoShorts.Support.Schemas.Post
    belongs_to :user, EctoShorts.Support.Schemas.User

    timestamps()
  end

  @available_attributes [:post_id, :user_id]

  def changeset(model_or_changeset, attrs \\ %{}) do
    cast(model_or_changeset, attrs, @available_attributes)
  end
end
