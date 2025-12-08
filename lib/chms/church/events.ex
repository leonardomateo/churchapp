defmodule Chms.Church.Events do
  @moduledoc """
  Ash resource for church events and services.

  Supports recurring events using RRULE (iCalendar standard) format.
  """
  use Ash.Resource,
    otp_app: :churchapp,
    domain: Chms.Church,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  alias Churchapp.Authorization.Checks

  postgres do
    table "events"
    repo Churchapp.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [
        :title,
        :description,
        :event_type,
        :start_time,
        :end_time,
        :all_day,
        :location,
        :color,
        :is_recurring,
        :recurrence_rule,
        :recurrence_end_date
      ]

      # Validate end_time is after start_time
      validate compare(:end_time, greater_than: :start_time),
        message: "must be after start time"

      change fn changeset, _context ->
        # Set default color based on event type if not provided
        case Ash.Changeset.get_attribute(changeset, :color) do
          nil ->
            event_type = Ash.Changeset.get_attribute(changeset, :event_type)
            default_color = default_color_for_type(event_type)
            Ash.Changeset.force_change_attribute(changeset, :color, default_color)

          _ ->
            changeset
        end
      end

      # Validate recurrence_rule is provided when is_recurring is true
      validate fn changeset, _context ->
        is_recurring = Ash.Changeset.get_attribute(changeset, :is_recurring)
        recurrence_rule = Ash.Changeset.get_attribute(changeset, :recurrence_rule)

        if is_recurring == true && (is_nil(recurrence_rule) || recurrence_rule == "") do
          {:error, field: :recurrence_rule, message: "is required for recurring events"}
        else
          :ok
        end
      end
    end

    update :update do
      accept [
        :title,
        :description,
        :event_type,
        :start_time,
        :end_time,
        :all_day,
        :location,
        :color,
        :is_recurring,
        :recurrence_rule,
        :recurrence_end_date
      ]

      # Validate end_time is after start_time
      validate compare(:end_time, greater_than: :start_time),
        message: "must be after start time"

      # Validate recurrence_rule is provided when is_recurring is true
      validate fn changeset, _context ->
        is_recurring = Ash.Changeset.get_attribute(changeset, :is_recurring)
        recurrence_rule = Ash.Changeset.get_attribute(changeset, :recurrence_rule)

        if is_recurring == true && (is_nil(recurrence_rule) || recurrence_rule == "") do
          {:error, field: :recurrence_rule, message: "is required for recurring events"}
        else
          :ok
        end
      end
    end

    read :list_in_range do
      argument :start_date, :utc_datetime, allow_nil?: false
      argument :end_date, :utc_datetime, allow_nil?: false

      filter expr(
               (start_time >= ^arg(:start_date) and start_time <= ^arg(:end_date)) or
                 (is_recurring == true and
                    (is_nil(recurrence_end_date) or recurrence_end_date >= ^arg(:start_date)))
             )
    end

    read :list_by_type do
      argument :event_type, :atom, allow_nil?: false

      filter expr(event_type == ^arg(:event_type))
    end
  end

  policies do
    # Super admins bypass all policies
    bypass action_type([:create, :read, :update, :destroy]) do
      authorize_if {Checks.IsSuperAdmin, []}
    end

    # Read policy - authenticated users can view events
    policy action_type(:read) do
      authorize_if {Checks.HasRole, role: [:admin, :staff, :leader, :member]}
    end

    # Write policies - admins and staff can manage events
    policy action_type([:create, :update, :destroy]) do
      authorize_if {Checks.HasRole, role: [:admin, :staff]}
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :title, :string do
      allow_nil? false
      constraints min_length: 1, max_length: 255
    end

    attribute :description, :string do
      constraints max_length: 2000
    end

    attribute :event_type, :atom do
      constraints one_of: [:service, :midweek_service, :special_service]
      allow_nil? false
      default :service
    end

    attribute :start_time, :utc_datetime do
      allow_nil? false
    end

    attribute :end_time, :utc_datetime do
      allow_nil? false
    end

    attribute :all_day, :boolean do
      default false
      allow_nil? false
    end

    attribute :location, :string do
      constraints max_length: 255
    end

    attribute :color, :string do
      constraints max_length: 7
      # Hex color code (e.g., "#06b6d4")
    end

    attribute :is_recurring, :boolean do
      default false
      allow_nil? false
    end

    attribute :recurrence_rule, :string do
      # RRULE string (e.g., "FREQ=WEEKLY;BYDAY=SU")
      constraints max_length: 500
    end

    attribute :recurrence_end_date, :date do
      # Optional end date for recurring events
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  identities do
    identity :unique_event, [:title, :start_time]
  end

  @doc """
  Returns the default color for a given event type.
  """
  def default_color_for_type(:service), do: "#06b6d4"
  def default_color_for_type(:midweek_service), do: "#8b5cf6"
  def default_color_for_type(:special_service), do: "#f59e0b"
  def default_color_for_type(_), do: "#06b6d4"

  @doc """
  Returns a human-readable label for an event type.
  """
  def event_type_label(:service), do: "Sunday Service"
  def event_type_label(:midweek_service), do: "Midweek Service"
  def event_type_label(:special_service), do: "Special Service"
  def event_type_label(_), do: "Event"

  @doc """
  Returns all available event types with their labels and colors.
  """
  def event_types do
    [
      %{type: :service, label: "Sunday Service", color: "#06b6d4"},
      %{type: :midweek_service, label: "Midweek Service", color: "#8b5cf6"},
      %{type: :special_service, label: "Special Service", color: "#f59e0b"}
    ]
  end
end
