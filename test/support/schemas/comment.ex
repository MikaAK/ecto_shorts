defmodule EctoShorts.Support.Schemas.Comment do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  schema "comments" do
    field :body, :string
    field :count, :integer
    field :tags, {:array, :string}

    belongs_to :post, EctoShorts.Support.Schemas.Post

    belongs_to :user, EctoShorts.Support.Schemas.User

    timestamps()
  end

  @available_attributes [:body, :count, :post_id, :user_id]

  def changeset(model_or_changeset, attrs \\ %{}) do
    model_or_changeset
    |> cast(attrs, @available_attributes)
    |> validate_length(:body, min: 3)
  end
end
