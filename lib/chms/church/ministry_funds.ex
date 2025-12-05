defmodule Chms.Church.MinistryFunds do
  @moduledoc """
  Ash resource for managing ministry financial transactions.
  Tracks revenue and expense transactions for church ministries with automatic balance calculations.
  """

  use Ash.Resource,
    otp_app: :churchapp,
    domain: Chms.Church,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  alias Churchapp.Authorization.Checks

  postgres do
    table "ministry_funds"
    repo Churchapp.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [
        :ministry_name,
        :transaction_type,
        :amount,
        :transaction_date,
        :notes
      ]
    end

    update :update do
      accept [
        :ministry_name,
        :transaction_type,
        :amount,
        :transaction_date,
        :notes
      ]
    end
  end

  policies do
    # Super admins bypass all policies
    bypass action_type([:create, :read, :update, :destroy]) do
      authorize_if {Checks.IsSuperAdmin, []}
    end

    # Read policy - who can view ministry funds
    policy action_type(:read) do
      authorize_if {Checks.HasRole, role: [:admin, :staff, :leader]}
      authorize_if {Checks.HasPermission, permission: :view_ministry_funds}
    end

    # Write policies - who can manage ministry funds
    policy action_type([:create, :update, :destroy]) do
      authorize_if {Checks.HasRole, role: [:admin, :staff]}
      authorize_if {Checks.HasPermission, permission: :manage_ministry_funds}
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :ministry_name, :string do
      allow_nil? false
      description "Name of the ministry this transaction belongs to"
    end

    attribute :transaction_type, :atom do
      constraints one_of: [:revenue, :expense]
      allow_nil? false
      description "Type of transaction: revenue (income) or expense (outgoing)"
    end

    attribute :amount, :decimal do
      constraints precision: 10, scale: 2, min: 0
      allow_nil? false
      description "Transaction amount (always positive, type determines if revenue or expense)"
    end

    attribute :transaction_date, :utc_datetime_usec do
      default &DateTime.utc_now/0
      allow_nil? false
      description "Date and time when the transaction occurred"
    end

    attribute :notes, :string do
      description "Additional notes or description for this transaction"
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end
end
