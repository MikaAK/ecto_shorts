defmodule EctoShorts.Schemas.CommentAbstract do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  schema "abstract table: comments" do
    belongs_to :author, EctoShorts.Schemas.User
    belongs_to :post, EctoShorts.Schemas.Post

    field :body, :string
    field :replies, :integer
    field :tags, {:array, :string}

    # has_one :post_permalink, through: [:post, :permalink]

    timestamps()
  end

  @available_fields [
    :author_id,
    :body,
    :post_id,
    :replies,
    :tags
  ]

  def changeset(model_or_changeset, attrs \\ %{}) do
    model_or_changeset
    |> cast(attrs, @available_fields)
    |> validate_length(:body, min: 3)
  end
end
