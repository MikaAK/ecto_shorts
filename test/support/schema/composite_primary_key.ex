defmodule EctoShorts.Schema.CompositePrimaryKey do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false

  schema "composite_primary_keys" do
    belongs_to :comment, EctoShorts.Schema.Comment, primary_key: true
    belongs_to :post, EctoShorts.Schema.Post, primary_key: true
    field :role, :string

    timestamps()
  end

  @available_fields [
    :comment_id,
    :post_id,
    :role
  ]

  def changeset(schema_data_or_changeset, attrs \\ %{}) do
    cast(schema_data_or_changeset, attrs, @available_fields)
  end
end
