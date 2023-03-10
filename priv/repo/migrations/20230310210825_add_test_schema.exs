defmodule EctoShorts.Repo.Migrations.AddTestSchema do
  use Ecto.Migration

  def change do
    create table(:ecto_shorts) do
      add :label, :text
    end
  end
end
