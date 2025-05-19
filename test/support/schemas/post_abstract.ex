defmodule EctoShorts.Schemas.PostAbstract do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  schema "abstract table: posts" do
    belongs_to :author, EctoShorts.Schemas.User

    field :title, :string
    field :body, :string
    field :published, :boolean
    field :tags, {:array, :string}
    field :views, :integer
    field :permalink, :string

    field :notes, :string, source: :custom_string_field

    has_many :comments, EctoShorts.Schemas.Comment, foreign_key: :post_id

    timestamps()
  end

  @available_fields [
    :title,
    :body,
    :notes,
    :permalink,
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
