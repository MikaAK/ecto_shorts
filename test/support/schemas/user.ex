defmodule EctoShorts.Schemas.User do
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

    has_many :comments, EctoShorts.Schemas.Comment, foreign_key: :author_id, on_replace: :delete

    has_many :books, EctoShorts.Schemas.Book, foreign_key: :author_id, on_replace: :delete

    timestamps()
  end

  @available_fields [:age, :first_name, :last_name]

  def changeset(schema_data_or_changeset, attrs \\ %{}) do
    cast(schema_data_or_changeset, attrs, @available_fields)
  end
end
