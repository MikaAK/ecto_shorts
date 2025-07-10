defmodule EctoShorts.Schemas.PostAbstractHasSchemaPrefix do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  @schema_prefix "custom_schema_prefix"

  schema "abstract table: posts" do
    field :title, :string

    timestamps()
  end

  @available_fields [:title]

  def changeset(schema_data_or_changeset, attrs \\ %{}) do
    cast(schema_data_or_changeset, attrs, @available_fields)
  end
end
