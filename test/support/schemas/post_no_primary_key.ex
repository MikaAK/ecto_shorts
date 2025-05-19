defmodule EctoShorts.Schemas.PostNoPrimaryKey do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false

  schema "posts" do
    field :title, :string

    timestamps()
  end

  @available_fields [:title]

  def changeset(model_or_changeset, attrs \\ %{}) do
    cast(model_or_changeset, attrs, @available_fields)
  end
end
