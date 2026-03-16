defmodule EctoShorts.Schema.UserAbstract do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  schema "abstract table: users" do
    field :first_name, :string
    field :last_name, :string
    field :age, :integer

    many_to_many :posts, EctoShorts.Schema.Post,
      join_through: EctoShorts.Schema.PostAuthor,
      join_keys: [author_id: :id, post_id: :id],
      unique: true

    has_many :comments, EctoShorts.Schema.Comment, foreign_key: :author_id

    timestamps()
  end

  @available_fields [:age, :first_name, :last_name]

  def changeset(schema_data_or_changeset, attrs \\ %{}) do
    cast(schema_data_or_changeset, attrs, @available_fields)
  end
end
