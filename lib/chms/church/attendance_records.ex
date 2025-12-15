defmodule Chms.Church.AttendanceRecords do
  @moduledoc """
  Ash resource for individual attendance records.
  Each record represents a congregant's attendance for a specific session.
  """

  use Ash.Resource,
    otp_app: :churchapp,
    domain: Chms.Church,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  alias Churchapp.Authorization.Checks

  postgres do
    table "attendance_records"
    repo Churchapp.Repo

    references do
      reference :session, on_delete: :delete
      reference :congregant, on_delete: :delete
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [
        :present,
        :notes,
        :session_id,
        :congregant_id
      ]
    end

    update :update do
      accept [
        :present,
        :notes
      ]
    end

    create :bulk_create do
      argument :records, {:array, :map}, allow_nil?: false

      change fn changeset, context ->
        records = Ash.Changeset.get_argument(changeset, :records)
        session_id = Ash.Changeset.get_attribute(changeset, :session_id)

        # Create each record
        Enum.each(records, fn record_data ->
          Ash.create!(
            __MODULE__,
            Map.put(record_data, :session_id, session_id),
            domain: Chms.Church,
            actor: context.actor
          )
        end)

        changeset
      end
    end

    read :list_by_session do
      argument :session_id, :uuid, allow_nil?: false

      filter expr(session_id == ^arg(:session_id))
    end

    read :list_by_congregant do
      argument :congregant_id, :uuid, allow_nil?: false

      prepare build(sort: [inserted_at: :desc])

      filter expr(congregant_id == ^arg(:congregant_id))
    end
  end

  policies do
    # Super admins bypass all policies
    bypass action_type([:create, :read, :update, :destroy]) do
      authorize_if {Checks.IsSuperAdmin, []}
    end

    # Read policy - staff and leaders can view records
    policy action_type(:read) do
      authorize_if {Checks.HasRole, role: [:admin, :staff, :leader]}
    end

    # Write policies - admins and staff can manage records
    policy action_type([:create, :update, :destroy]) do
      authorize_if {Checks.HasRole, role: [:admin, :staff]}
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :present, :boolean do
      allow_nil? false
      default true
      description "Whether the congregant was present"
    end

    attribute :notes, :string do
      allow_nil? true
      description "Optional notes about this attendance record"
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :session, Chms.Church.AttendanceSessions do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :congregant, Chms.Church.Congregants do
      allow_nil? false
      attribute_writable? true
    end
  end

  identities do
    identity :unique_session_congregant, [:session_id, :congregant_id]
  end
end
