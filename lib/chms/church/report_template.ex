defmodule Chms.Church.ReportTemplate do
  @moduledoc """
  Report Template resource for saving and loading report configurations.
  Allows users to save filter settings, sorting preferences, and column selections
  for quick reuse.
  """
  use Ash.Resource,
    otp_app: :churchapp,
    domain: Chms.Church,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  alias Churchapp.Authorization.Checks

  postgres do
    table "report_templates"
    repo Churchapp.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [
        :name,
        :description,
        :resource_key,
        :filter_params,
        :sort_by,
        :sort_dir,
        :is_shared
      ]

      argument :created_by_id, :uuid, allow_nil?: false

      change manage_relationship(:created_by_id, :created_by, type: :append)
    end

    update :update do
      accept [
        :name,
        :description,
        :filter_params,
        :sort_by,
        :sort_dir,
        :is_shared
      ]
    end

    read :list_for_resource do
      argument :resource_key, :atom, allow_nil?: false

      filter expr(resource_key == ^arg(:resource_key))
    end

    read :list_visible do
      argument :resource_key, :atom, allow_nil?: false
      argument :user_id, :uuid, allow_nil?: false

      # Show templates that are either shared OR created by the current user
      filter expr(
               resource_key == ^arg(:resource_key) and
                 (is_shared == true or created_by_id == ^arg(:user_id))
             )
    end
  end

  policies do
    # Super admins bypass all policies
    bypass action_type([:create, :read, :update, :destroy]) do
      authorize_if {Checks.IsSuperAdmin, []}
    end

    # Admins can create templates
    policy action_type(:create) do
      authorize_if {Checks.HasRole, role: [:admin]}
    end

    # Users can read shared templates or their own templates
    policy action_type(:read) do
      authorize_if {Checks.HasRole, role: [:admin, :staff, :leader]}
    end

    # Users can only update/destroy their own templates (unless super_admin)
    policy action_type([:update, :destroy]) do
      authorize_if {Checks.HasRole, role: [:admin]}
      # Additional check in code: must be owner
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      constraints min_length: 1, max_length: 100
    end

    attribute :description, :string do
      constraints max_length: 500
    end

    attribute :resource_key, :atom do
      allow_nil? false
    end

    attribute :filter_params, :map do
      default %{}
    end

    attribute :sort_by, :atom

    attribute :sort_dir, :atom do
      default :asc
      constraints one_of: [:asc, :desc]
    end

    attribute :is_shared, :boolean do
      default false
      allow_nil? false
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :created_by, Churchapp.Accounts.User do
      allow_nil? false
      attribute_writable? true
    end
  end

  identities do
    identity :unique_name_per_user_resource, [:name, :created_by_id, :resource_key]
  end
end
