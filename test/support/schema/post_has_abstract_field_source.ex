defmodule EctoShorts.Schema.PostHasTupleFieldSource do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  schema "posts" do
    belongs_to :author, {"users", EctoShorts.Schema.UserAbstract}

    many_to_many :authors, {"users", EctoShorts.Schema.UserAbstract},
      join_through: EctoShorts.Schema.PostAuthor,
      join_keys: [post_id: :id, author_id: :id],
      unique: true

    has_many :comments, {"comments", EctoShorts.Schema.CommentAbstract}, foreign_key: :post_id
    has_many :comments_authors, through: [:comments, :author]

    field :title, :string
    field :body, :string
    field :published, :boolean
    field :published_at, :utc_datetime
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
    :published_at,
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
