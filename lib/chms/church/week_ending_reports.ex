defmodule Chms.Church.WeekEndingReports do
  @moduledoc """
  Ash resource for Week Ending Reports.
  Each report covers a specific date range and contains category entries with amounts.
  The grand total is calculated dynamically from all category entries.
  """

  use Ash.Resource,
    otp_app: :churchapp,
    domain: Chms.Church,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  alias Churchapp.Authorization.Checks

  postgres do
    table "week_ending_reports"
    repo Churchapp.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [
        :week_start_date,
        :week_end_date,
        :report_name,
        :notes
      ]

      # Auto-generate report name if not provided
      change fn changeset, _context ->
        case Ash.Changeset.get_attribute(changeset, :report_name) do
          nil ->
            start_date = Ash.Changeset.get_attribute(changeset, :week_start_date)
            end_date = Ash.Changeset.get_attribute(changeset, :week_end_date)

            if start_date && end_date do
              name = "Week Ending - #{Calendar.strftime(end_date, "%m/%d/%Y")}"
              Ash.Changeset.force_change_attribute(changeset, :report_name, name)
            else
              changeset
            end

          "" ->
            start_date = Ash.Changeset.get_attribute(changeset, :week_start_date)
            end_date = Ash.Changeset.get_attribute(changeset, :week_end_date)

            if start_date && end_date do
              name = "Week Ending - #{Calendar.strftime(end_date, "%m/%d/%Y")}"
              Ash.Changeset.force_change_attribute(changeset, :report_name, name)
            else
              changeset
            end

          _ ->
            changeset
        end
      end

      # Validate date range
      validate fn changeset, _context ->
        start_date = Ash.Changeset.get_attribute(changeset, :week_start_date)
        end_date = Ash.Changeset.get_attribute(changeset, :week_end_date)

        cond do
          is_nil(start_date) or is_nil(end_date) ->
            :ok

          Date.compare(end_date, start_date) == :lt ->
            {:error,
             Ash.Error.Changes.InvalidAttribute.exception(
               field: :week_end_date,
               message: "End date must be on or after start date"
             )}

          true ->
            :ok
        end
      end

      # Validate no overlapping date ranges
      validate fn changeset, _context ->
        start_date = Ash.Changeset.get_attribute(changeset, :week_start_date)
        end_date = Ash.Changeset.get_attribute(changeset, :week_end_date)

        if start_date && end_date do
          case check_overlapping_reports(nil, start_date, end_date) do
            {:ok, []} ->
              :ok

            {:ok, overlapping} ->
              report_names = Enum.map_join(overlapping, ", ", & &1.report_name)

              {:error,
               Ash.Error.Changes.InvalidAttribute.exception(
                 field: :week_start_date,
                 message: "Date range overlaps with existing report(s): #{report_names}"
               )}

            {:error, _} ->
              :ok
          end
        else
          :ok
        end
      end
    end

    update :update do
      require_atomic? false

      accept [
        :week_start_date,
        :week_end_date,
        :report_name,
        :notes
      ]

      # Validate date range
      validate fn changeset, _context ->
        start_date = Ash.Changeset.get_attribute(changeset, :week_start_date)
        end_date = Ash.Changeset.get_attribute(changeset, :week_end_date)

        cond do
          is_nil(start_date) or is_nil(end_date) ->
            :ok

          Date.compare(end_date, start_date) == :lt ->
            {:error,
             Ash.Error.Changes.InvalidAttribute.exception(
               field: :week_end_date,
               message: "End date must be on or after start date"
             )}

          true ->
            :ok
        end
      end

      # Validate no overlapping date ranges (excluding current report)
      validate fn changeset, _context ->
        report_id = Ash.Changeset.get_data(changeset, :id)
        start_date = Ash.Changeset.get_attribute(changeset, :week_start_date)
        end_date = Ash.Changeset.get_attribute(changeset, :week_end_date)

        if start_date && end_date do
          case check_overlapping_reports(report_id, start_date, end_date) do
            {:ok, []} ->
              :ok

            {:ok, overlapping} ->
              report_names = Enum.map_join(overlapping, ", ", & &1.report_name)

              {:error,
               Ash.Error.Changes.InvalidAttribute.exception(
                 field: :week_start_date,
                 message: "Date range overlaps with existing report(s): #{report_names}"
               )}

            {:error, _} ->
              :ok
          end
        else
          :ok
        end
      end
    end

    read :list_recent do
      prepare build(sort: [week_end_date: :desc], limit: 50)
    end
  end

  policies do
    # Super admins bypass all policies
    bypass action_type([:create, :read, :update, :destroy]) do
      authorize_if {Checks.IsSuperAdmin, []}
    end

    # Read policy - admins can view reports
    policy action_type(:read) do
      authorize_if {Checks.HasRole, role: [:admin]}
    end

    # Write policies - only admins can manage reports
    policy action_type([:create, :update, :destroy]) do
      authorize_if {Checks.HasRole, role: [:admin]}
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :week_start_date, :date do
      allow_nil? false
      description "Start date of the reporting period"
    end

    attribute :week_end_date, :date do
      allow_nil? false
      description "End date of the reporting period"
    end

    attribute :report_name, :string do
      allow_nil? true
      description "Optional name for the report (auto-generated if empty)"
    end

    attribute :notes, :string do
      allow_nil? true
      description "Optional notes or comments about the report"
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    has_many :category_entries, Chms.Church.ReportCategoryEntries do
      destination_attribute :week_ending_report_id
    end
  end

  calculations do
    calculate :date_range_display, :string do
      description "Formatted date range for display"

      calculation fn records, _context ->
        Enum.map(records, fn record ->
          start_str = Calendar.strftime(record.week_start_date, "%b %d")
          end_str = Calendar.strftime(record.week_end_date, "%b %d, %Y")
          "#{start_str} - #{end_str}"
        end)
      end
    end
  end

  aggregates do
    sum :grand_total, :category_entries, :amount do
      description "Sum of all category entry amounts"
      default Decimal.new(0)
    end
  end

  defp check_overlapping_reports(exclude_id, start_date, end_date) do
    require Ash.Query

    try do
      # Get all reports
      all_reports = Ash.read!(__MODULE__)

      # Filter for overlapping date ranges
      overlapping =
        all_reports
        |> Enum.filter(fn report ->
          # Skip the current report if we're updating
          if exclude_id && report.id == exclude_id do
            false
          else
            # Check for overlap:
            # New range overlaps if: new_start <= existing_end AND new_end >= existing_start
            Date.compare(start_date, report.week_end_date) != :gt and
              Date.compare(end_date, report.week_start_date) != :lt
          end
        end)

      {:ok, overlapping}
    rescue
      e -> {:error, e}
    end
  end
end
