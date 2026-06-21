defmodule EctoShorts.Schema.PostWithLock do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  schema "posts_with_lock" do
    field :title, :string
    field :lock_version, :integer, default: 1

    timestamps()
  end

  @available_fields [:title, :lock_version]

  def changeset(schema_data_or_changeset, attrs \\ %{}) do
    cast(schema_data_or_changeset, attrs, @available_fields)
  end

  def optimistic_lock, do: :lock_version
end
