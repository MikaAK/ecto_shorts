defmodule EctoShorts.Repo.Migrations.CreatePosts do
  use Ecto.Migration

  def change do
    create table(:posts) do
      add :title, :text
      add :unique_identifier, :text

      timestamps()
    end

    create unique_index(:posts, :unique_identifier)
  end
end
