defmodule EctoShorts.Schemas.PostHasAbstractFieldSource do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  schema "posts" do
    belongs_to :author, {"users", EctoShorts.Schemas.UserAbstract}

    many_to_many :authors, {"users", EctoShorts.Schemas.UserAbstract},
      join_through: EctoShorts.Schemas.PostAuthor,
      join_keys: [post_id: :id, author_id: :id],
      unique: true

    has_many :comments, {"comments", EctoShorts.Schemas.CommentAbstract}, foreign_key: :post_id

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

  def changeset(model_or_changeset, attrs \\ %{}) do
    model_or_changeset
    |> cast(attrs, @available_fields)
    |> no_assoc_constraint(:comments)
    |> unique_constraint(:permalink)
  end
end
