defmodule EctoShorts.Support.Repo.Migrations.CreateUserAvatars do
  use Ecto.Migration

  def change do
    create table(:user_avatars) do
      add :name, :text
      add :description, :text

      add :user_id, references(:users,
        on_delete: :delete_all,
        on_update: :update_all
      )

      timestamps()
    end

    create index(:user_avatars, :user_id)
  end
end
