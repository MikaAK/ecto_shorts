defmodule EctoShorts.Schemas.Book do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false

  schema "books" do
    belongs_to :author, EctoShorts.Schemas.User, on_replace: :delete

    field :title, :string

    timestamps()
  end

  @available_fields [:author_id, :title]

  def changeset(model_or_changeset, attrs \\ %{}) do
    cast(model_or_changeset, attrs, @available_fields)
  end
end
