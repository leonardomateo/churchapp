defmodule Chms.Church.FamilyRelationshipType do
  use Ash.Resource,
    otp_app: :churchapp,
    domain: Chms.Church,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  alias Churchapp.Authorization.Checks

  postgres do
    table "family_relationship_types"
    repo Churchapp.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:name, :display_name, :inverse_name, :sort_order, :is_active]
    end

    update :update do
      accept [:display_name, :inverse_name, :sort_order, :is_active]
    end

    read :list_active do
      filter expr(is_active == true)
      prepare build(sort: [sort_order: :asc, display_name: :asc])
    end
  end

  policies do
    bypass action_type([:create, :read, :update, :destroy]) do
      authorize_if {Checks.IsSuperAdmin, []}
    end

    policy action_type(:read) do
      authorize_if {Checks.HasRole, role: [:admin, :staff, :leader, :member]}
    end

    policy action_type([:create, :update, :destroy]) do
      authorize_if {Checks.HasRole, role: [:admin]}
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      description "Unique identifier (e.g., 'father')"
    end

    attribute :display_name, :string do
      allow_nil? false
      description "Display name (e.g., 'Father')"
    end

    attribute :inverse_name, :string do
      allow_nil? true
      description "Name of the inverse relationship type (e.g., 'son')"
    end

    attribute :sort_order, :integer do
      default 0
      allow_nil? false
    end

    attribute :is_active, :boolean do
      default true
      allow_nil? false
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  identities do
    identity :unique_name, [:name]
  end
end
