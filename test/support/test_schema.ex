defmodule EctoShorts.Support.TestSchema do
  use Ecto.Schema
  import Ecto.Changeset

  schema "ecto_shorts" do
    field :label, :string
  end

  def changeset(schema, attrs \\ %{}) do
    schema
    |> cast(attrs, [:label])
  end

  def create_changeset(attrs \\ %{}) do
    changeset(%__MODULE__{}, attrs)
  end
end
