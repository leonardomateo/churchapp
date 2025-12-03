defmodule Chms.Church.Contributions do
  use Ash.Resource,
    otp_app: :churchapp,
    domain: Chms.Church,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "contributions"
    repo Churchapp.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [
        :congregant_id,
        :contribution_type,
        :revenue,
        :notes,
        :contribution_date
      ]
    end

    update :update do
      accept [
        :congregant_id,
        :contribution_type,
        :revenue,
        :notes,
        :contribution_date
      ]
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :contribution_type, :string do
      allow_nil? false
      # This will allow custom types as well as predefined ones
    end

    attribute :revenue, :decimal do
      constraints precision: 10, scale: 2
      allow_nil? false
    end

    attribute :notes, :string

    attribute :contribution_date, :date do
      default &Date.utc_today/0
      allow_nil? false
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :congregant, Chms.Church.Congregants do
      allow_nil? false
      attribute_writable? true
    end
  end
end
