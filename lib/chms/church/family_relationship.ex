defmodule Chms.Church.FamilyRelationship do
  use Ash.Resource,
    otp_app: :churchapp,
    domain: Chms.Church,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  alias Churchapp.Authorization.Checks

  postgres do
    table "family_relationships"
    repo Churchapp.Repo

    references do
      reference :congregant, on_delete: :delete
      reference :related_congregant, on_delete: :delete
      reference :family_relationship_type, on_delete: :restrict
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:congregant_id, :related_congregant_id, :family_relationship_type_id]
    end
  end

  policies do
    bypass action_type([:create, :read, :destroy]) do
      authorize_if {Checks.IsSuperAdmin, []}
    end

    policy action_type(:read) do
      authorize_if {Checks.HasRole, role: [:admin, :staff, :leader, :member]}
    end

    policy action_type([:create, :destroy]) do
      authorize_if {Checks.HasRole, role: [:admin, :staff]}
    end
  end

  attributes do
    uuid_primary_key :id
    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :congregant, Chms.Church.Congregants do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :related_congregant, Chms.Church.Congregants do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :family_relationship_type, Chms.Church.FamilyRelationshipType do
      allow_nil? false
      attribute_writable? true
    end
  end

  identities do
    identity :unique_relationship, [
      :congregant_id,
      :related_congregant_id,
      :family_relationship_type_id
    ]
  end
end
