defmodule EctoShorts.Support.Schemas.Post do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  schema "posts" do
    field :title, :string
    field :unique_identifier, :string

    has_many :comments, EctoShorts.Support.Schemas.Comment

    timestamps()
  end

  @available_attributes [:title, :unique_identifier]

  def changeset(model_or_changeset, attrs \\ %{}) do
    model_or_changeset
    |> cast(attrs, @available_attributes)
    |> no_assoc_constraint(:comments)
    |> unique_constraint(:unique_identifier)
  end

  def create_changeset(attrs \\ %{}) do
    changeset(%__MODULE__{}, attrs)
  end
end
