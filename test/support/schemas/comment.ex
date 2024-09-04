defmodule EctoShorts.Support.Schemas.Comment do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  schema "comments" do
    field :body, :string
    field :count, :integer

    belongs_to :post, EctoShorts.Support.Schemas.Post

    timestamps()
  end

  @available_attributes [:body, :count, :post_id]

  def changeset(model_or_changeset, attrs \\ %{}) do
    model_or_changeset
    |> cast(attrs, @available_attributes)
    |> validate_length(:body, min: 3)
  end
end
