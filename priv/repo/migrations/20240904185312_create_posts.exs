defmodule EctoShorts.Support.Repo.Migrations.CreatePosts do
  use Ecto.Migration

  def change do
    create table(:posts) do
      add :title, :text
      add :unique_identifier, :text
      add :likes, :integer

      add :user_id, references(:users,
        on_delete: :nilify_all,
        on_update: :update_all
      )

      timestamps()
    end

    create unique_index(:posts, :unique_identifier)
  end
end
