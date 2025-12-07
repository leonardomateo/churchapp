defmodule Chms.Church.ReportCategoryEntries do
  @moduledoc """
  Ash resource for individual category line items within a Week Ending Report.
  Each entry links a report to a category with an amount.
  """

  use Ash.Resource,
    otp_app: :churchapp,
    domain: Chms.Church,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  alias Churchapp.Authorization.Checks

  postgres do
    table "report_category_entries"
    repo Churchapp.Repo

    references do
      reference :week_ending_report, on_delete: :delete
      reference :report_category, on_delete: :restrict
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [
        :week_ending_report_id,
        :report_category_id,
        :amount
      ]
    end

    update :update do
      accept [
        :amount
      ]
    end

    create :bulk_create do
      argument :entries, {:array, :map} do
        allow_nil? false
      end

      change fn changeset, _context ->
        # This action is for creating multiple entries at once
        # The actual bulk creation is handled at the domain level
        changeset
      end
    end
  end

  policies do
    # Super admins bypass all policies
    bypass action_type([:create, :read, :update, :destroy]) do
      authorize_if {Checks.IsSuperAdmin, []}
    end

    # Read policy - admins can view entries
    policy action_type(:read) do
      authorize_if {Checks.HasRole, role: [:admin]}
    end

    # Write policies - only admins can manage entries
    policy action_type([:create, :update, :destroy]) do
      authorize_if {Checks.HasRole, role: [:admin]}
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :amount, :decimal do
      constraints precision: 10, scale: 2, min: 0
      allow_nil? false
      default Decimal.new(0)
      description "Amount for this category in the report"
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :week_ending_report, Chms.Church.WeekEndingReports do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :report_category, Chms.Church.ReportCategories do
      allow_nil? false
      attribute_writable? true
    end
  end

  identities do
    # Each category can only appear once per report
    identity :unique_category_per_report, [:week_ending_report_id, :report_category_id]
  end
end
