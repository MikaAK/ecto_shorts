defmodule EctoShorts.Repo.Migrations.CreateUserDatasTable do
  use Ecto.Migration

  def change do
    create table(:user_datas) do
      add :data, :jsonb
      add :creator_id, references(:users, on_delete: :nilify_all, on_update: :update_all)

      timestamps()
    end
  end
end
