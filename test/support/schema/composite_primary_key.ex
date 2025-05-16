defmodule EctoShorts.Schema.CompositePrimaryKey do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false

  schema "composite_primary_keys" do
    field :comment_id, :id, primary_key: true
    field :post_id, :id, primary_key: true
    field :role, :string

    timestamps()
  end

  @available_fields [
    :comment_id,
    :post_id,
    :role
  ]

  def changeset(model_or_changeset, attrs \\ %{}) do
    cast(model_or_changeset, attrs, @available_fields)
  end
end
