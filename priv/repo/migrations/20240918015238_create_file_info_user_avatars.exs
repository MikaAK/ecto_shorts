defmodule EctoShorts.Support.Repo.Migrations.CreateFileInfoUserAvatars do
  use Ecto.Migration

  def change do
    create table(:file_info_user_avatars) do
      add :name, :text
      add :content_length, :integer
      add :unique_identifier, :text

      add :assoc_id, references(:user_avatars,
        on_delete: :restrict,
        on_update: :update_all
      )

      add :user_id, references(:users,
        on_delete: :delete_all,
        on_update: :update_all
      )

      timestamps()
    end

    create index(:file_info_user_avatars, :assoc_id)
    create index(:file_info_user_avatars, :user_id)
    create unique_index(:file_info_user_avatars, [:unique_identifier])
    create unique_index(:file_info_user_avatars, [:user_id, :assoc_id])
  end
end
