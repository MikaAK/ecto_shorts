defmodule EctoShorts.Repo.Migrations.CreateBooksTable do
  use Ecto.Migration

  def change do
    create table(:books, primary_key: false) do
      add :title, :string
      add :author_id, references(:users)

      timestamps()
    end
  end
end
