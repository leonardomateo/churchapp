defmodule Chms.Church.AttendanceSessions do
  @moduledoc """
  Ash resource for managing attendance sessions.
  Each session represents a specific event (service, class, etc.) on a particular date/time.
  Sessions can be for any day of the week.
  """

  use Ash.Resource,
    otp_app: :churchapp,
    domain: Chms.Church,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  alias Churchapp.Authorization.Checks

  postgres do
    table "attendance_sessions"
    repo Churchapp.Repo

    references do
      reference :category, on_delete: :restrict
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [
        :session_datetime,
        :notes,
        :category_id
      ]

      change fn changeset, _context ->
        # Initialize total_present to 0
        Ash.Changeset.force_change_attribute(changeset, :total_present, 0)
      end
    end

    update :update do
      accept [
        :session_datetime,
        :notes,
        :category_id
      ]
    end

    update :update_total_present do
      require_atomic? false
      accept []
      argument :total, :integer, allow_nil?: false

      change fn changeset, _context ->
        total = Ash.Changeset.get_argument(changeset, :total)
        Ash.Changeset.force_change_attribute(changeset, :total_present, total)
      end
    end

    read :list_by_date_range do
      argument :start_date, :date, allow_nil?: false
      argument :end_date, :date, allow_nil?: false

      prepare build(sort: [session_datetime: :desc])

      filter expr(
               fragment("?::date", session_datetime) >= ^arg(:start_date) and
                 fragment("?::date", session_datetime) <= ^arg(:end_date)
             )
    end

    read :list_by_category do
      argument :category_id, :uuid, allow_nil?: false

      prepare build(sort: [session_datetime: :desc])

      filter expr(category_id == ^arg(:category_id))
    end

    read :list_recent do
      prepare build(sort: [session_datetime: :desc], limit: 50)
    end
  end

  policies do
    # Super admins bypass all policies
    bypass action_type([:create, :read, :update, :destroy]) do
      authorize_if {Checks.IsSuperAdmin, []}
    end

    # Read policy - staff, leaders can view sessions
    policy action_type(:read) do
      authorize_if {Checks.HasRole, role: [:admin, :staff, :leader]}
    end

    # Write policies - admins and staff can manage sessions
    policy action_type([:create, :update, :destroy]) do
      authorize_if {Checks.HasRole, role: [:admin, :staff]}
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :session_datetime, :utc_datetime do
      allow_nil? false
      description "Date and time of the session (supports any day of the week)"
    end

    attribute :notes, :string do
      allow_nil? true
      description "Optional notes about the session"
    end

    attribute :total_present, :integer do
      allow_nil? false
      default 0
      description "Total number of congregants marked present"
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :category, Chms.Church.AttendanceCategories do
      allow_nil? false
      attribute_writable? true
    end

    has_many :records, Chms.Church.AttendanceRecords do
      destination_attribute :session_id
    end
  end

  calculations do
    calculate :display_datetime, :string do
      description "Formatted datetime for display"

      calculation fn records, _context ->
        Enum.map(records, fn record ->
          dt = record.session_datetime
          day_name = Calendar.strftime(dt, "%A")
          date_str = Calendar.strftime(dt, "%b %d, %Y")
          time_str = Calendar.strftime(dt, "%I:%M %p")
          "#{day_name}, #{date_str} at #{time_str}"
        end)
      end
    end

    calculate :date_only, :date do
      description "Just the date portion of session_datetime"

      calculation fn records, _context ->
        Enum.map(records, fn record ->
          DateTime.to_date(record.session_datetime)
        end)
      end
    end
  end

  aggregates do
    count :attendance_count, :records do
      description "Total number of attendance records"
    end

    count :present_count, :records do
      description "Number of congregants marked present"
      filter expr(present == true)
    end
  end
end
