defmodule EctoShorts.Schemas.PostHasQueryBuilder do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  alias Ecto.Query
  require Ecto.Query

  schema "posts" do
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

  def changeset(model_or_changeset, attrs \\ %{}) do
    model_or_changeset
    |> cast(attrs, @available_fields)
    |> foreign_key_constraint(:author_id)
    |> no_assoc_constraint(:comments)
    |> unique_constraint(:permalink)
  end

  @filters ~w(custom_schema_filter)a

  def filters, do: @filters

  def build_query(query, _binding_alias, :custom_schema_filter, value, _opts) do
    Query.where(query, ^[published: value])
  end
end
