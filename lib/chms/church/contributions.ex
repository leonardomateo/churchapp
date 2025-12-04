defmodule Chms.Church.Contributions do
  use Ash.Resource,
    otp_app: :churchapp,
    domain: Chms.Church,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  alias Churchapp.Authorization.Checks

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

  policies do
    # Super admins can do anything
    policy action_type([:create, :read, :update, :destroy]) do
      authorize_if {Checks.IsSuperAdmin, []}
    end

    # Admins and authorized staff can manage contributions
    policy action_type([:create, :update, :destroy]) do
      authorize_if {Checks.HasRole, role: [:admin, :staff]}
      authorize_if {Checks.HasPermission, permission: :manage_contributions}
    end

    # Staff and leaders can view contributions
    policy action_type(:read) do
      authorize_if {Checks.HasRole, role: [:admin, :staff, :leader]}
      authorize_if {Checks.HasPermission, permission: :view_contributions}
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

    attribute :contribution_date, :utc_datetime_usec do
      default &DateTime.utc_now/0
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
