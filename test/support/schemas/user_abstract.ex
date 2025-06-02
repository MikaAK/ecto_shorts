defmodule EctoShorts.Schemas.UserAbstract do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field :first_name, :string
    field :last_name, :string
    field :age, :integer

    many_to_many :posts, EctoShorts.Schemas.Post,
      join_through: EctoShorts.Schemas.PostAuthor,
      join_keys: [author_id: :id, post_id: :id],
      unique: true

    has_many :comments, EctoShorts.Schemas.Comment, foreign_key: :author_id

    timestamps()
  end

  @available_fields [:age, :first_name, :last_name]

  def changeset(model_or_changeset, attrs \\ %{}) do
    cast(model_or_changeset, attrs, @available_fields)
  end
end
