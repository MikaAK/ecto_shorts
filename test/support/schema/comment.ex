defmodule EctoShorts.Schema.Comment do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  schema "comments" do
    belongs_to :author, EctoShorts.Schema.User
    belongs_to :post, EctoShorts.Schema.Post

    field :body, :string
    field :published, :boolean
    field :published_at, :naive_datetime
    field :replies, :integer
    field :tags, {:array, :string}

    # has_one :post_permalink, through: [:post, :permalink]

    timestamps()
  end

  @available_fields [
    :author_id,
    :body,
    :post_id,
    :published,
    :published_at,
    :replies,
    :tags
  ]

  def changeset(schema_data_or_changeset, attrs \\ %{}) do
    schema_data_or_changeset
    |> cast(attrs, @available_fields)
    |> validate_length(:body, min: 3)
  end
end
