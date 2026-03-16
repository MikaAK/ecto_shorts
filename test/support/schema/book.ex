defmodule EctoShorts.Schema.Book do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false

  schema "books" do
    belongs_to :author, EctoShorts.Schema.User, on_replace: :delete

    field :title, :string

    timestamps()
  end

  @available_fields [:author_id, :title]

  def changeset(schema_data_or_changeset, attrs \\ %{}) do
    cast(schema_data_or_changeset, attrs, @available_fields)
  end
end
