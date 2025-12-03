defmodule Churchapp.Repo.Migrations.AddMinistriesToCongregants do
  use Ecto.Migration

  def up do
    alter table(:congregants) do
      add :ministries, {:array, :text}
    end
  end

  def down do
    alter table(:congregants) do
      remove :ministries
    end
  end
end
