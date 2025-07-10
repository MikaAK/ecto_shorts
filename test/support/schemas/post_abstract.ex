defmodule EctoShorts.Schemas.PostAbstract do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  schema "abstract table: posts" do
    belongs_to :author, EctoShorts.Schemas.User

    many_to_many :authors, EctoShorts.Schemas.User,
      join_through: EctoShorts.Schemas.PostAuthor,
      join_keys: [post_id: :id, author_id: :id],
      unique: true

    has_many :comments, EctoShorts.Schemas.Comment, foreign_key: :post_id

    has_many :comments_authors, through: [:comments, :author]

    field :title, :string
    field :body, :string
    field :published, :boolean
    field :notes, :string, source: :custom_string_field
    field :tags, {:array, :string}
    field :views, :integer
    field :permalink, :string

    timestamps()
  end

  @available_fields [
    :body,
    :notes,
    :permalink,
    :published,
    :title,
    :tags,
    :author_id,
    :views
  ]

  def changeset(schema_data_or_changeset, attrs \\ %{}) do
    schema_data_or_changeset
    |> cast(attrs, @available_fields)
    |> no_assoc_constraint(:comments)
    |> unique_constraint(:permalink)
  end
end
