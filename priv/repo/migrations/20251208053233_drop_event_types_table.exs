defmodule Churchapp.Repo.Migrations.DropEventTypesTable do
  use Ecto.Migration

  def change do
    drop_if_exists table(:event_types)
  end
end
