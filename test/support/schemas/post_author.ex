defmodule EctoShorts.Schemas.PostAuthor do
  use Ecto.Schema
  import Ecto.Changeset

  schema "posts_authors" do
    belongs_to :author, EctoShorts.Schemas.User
    belongs_to :post, EctoShorts.Schemas.Post

    timestamps()
  end

  @available_fields [
    :author_id,
    :post_id
  ]

  def changeset(schema_data_or_changeset, attrs \\ %{}) do
    schema_data_or_changeset
    |> cast(attrs, @available_fields)
    |> foreign_key_constraint(:author_id)
    |> foreign_key_constraint(:post_id)
    |> unique_constraint([:author_id, :post_id])
  end
end
