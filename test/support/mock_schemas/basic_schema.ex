defmodule EctoShorts.Support.MockSchemas.BasicSchema do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  schema "basic_schemas" do
    field :body, :string

    timestamps()
  end

  @available_fields [:body]

  def changeset(model_or_changeset, attrs \\ %{}) do
    cast(model_or_changeset, attrs, @available_fields)
  end
end
