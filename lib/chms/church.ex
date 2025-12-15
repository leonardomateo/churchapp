defmodule Chms.Church do
  use Ash.Domain,
    otp_app: :churchapp,
    extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource Chms.Church.Congregants do
      define :create_congregant, action: :create
      define :list_congregants, action: :read
      define :update_congregant, action: :update
      define :destroy_congregant, action: :destroy
      define :get_congregant_by_id, action: :read, get_by: [:id]
      define :get_congregant_by_member_id, action: :read, get_by: [:member_id]
    end

    resource Chms.Church.Contributions do
      define :create_contribution, action: :create
      define :list_contributions, action: :read
      define :update_contribution, action: :update
      define :destroy_contribution, action: :destroy
      define :get_contribution_by_id, action: :read, get_by: [:id]
    end

    resource Chms.Church.MinistryFunds do
      define :create_ministry_fund, action: :create
      define :list_ministry_funds, action: :read
      define :update_ministry_fund, action: :update
      define :destroy_ministry_fund, action: :destroy
      define :get_ministry_fund_by_id, action: :read, get_by: [:id]
    end

    # Week Ending Reports
    resource Chms.Church.ReportCategories do
      define :create_report_category, action: :create
      define :list_report_categories, action: :read
      define :list_active_report_categories, action: :list_active
      define :list_report_categories_by_group, action: :list_by_group, args: [:group]
      define :update_report_category, action: :update
      define :deactivate_report_category, action: :deactivate
      define :destroy_report_category, action: :destroy
      define :get_report_category_by_id, action: :read, get_by: [:id]
      define :get_report_category_by_name, action: :read, get_by: [:name]
    end

    resource Chms.Church.WeekEndingReports do
      define :create_week_ending_report, action: :create
      define :list_week_ending_reports, action: :read
      define :list_recent_week_ending_reports, action: :list_recent
      define :update_week_ending_report, action: :update
      define :destroy_week_ending_report, action: :destroy
      define :get_week_ending_report_by_id, action: :read, get_by: [:id]
    end

    resource Chms.Church.ReportCategoryEntries do
      define :create_report_category_entry, action: :create
      define :list_report_category_entries, action: :read
      define :update_report_category_entry, action: :update
      define :destroy_report_category_entry, action: :destroy
      define :get_report_category_entry_by_id, action: :read, get_by: [:id]
    end

    # Events / Calendar
    resource Chms.Church.Events do
      define :create_event, action: :create
      define :list_events, action: :read
      define :list_events_in_range, action: :list_in_range, args: [:start_date, :end_date]
      define :update_event, action: :update
      define :destroy_event, action: :destroy
      define :get_event_by_id, action: :read, get_by: [:id]
    end

    # Family Relationships
    resource Chms.Church.FamilyRelationshipType do
      define :create_family_relationship_type, action: :create
      define :list_family_relationship_types, action: :read
      define :list_active_family_relationship_types, action: :list_active
      define :update_family_relationship_type, action: :update
      define :destroy_family_relationship_type, action: :destroy
      define :get_family_relationship_type_by_id, action: :read, get_by: [:id]
      define :get_family_relationship_type_by_name, action: :read, get_by: [:name]
    end

    resource Chms.Church.FamilyRelationship do
      define :create_family_relationship, action: :create
      define :list_family_relationships, action: :read
      define :destroy_family_relationship, action: :destroy
      define :get_family_relationship_by_id, action: :read, get_by: [:id]
    end

    # Attendance Module
    resource Chms.Church.AttendanceCategories do
      define :create_attendance_category, action: :create
      define :list_attendance_categories, action: :read
      define :list_active_attendance_categories, action: :list_active
      define :update_attendance_category, action: :update
      define :deactivate_attendance_category, action: :deactivate
      define :destroy_attendance_category, action: :destroy
      define :get_attendance_category_by_id, action: :read, get_by: [:id]
      define :get_attendance_category_by_name, action: :read, get_by: [:name]
    end

    resource Chms.Church.AttendanceSessions do
      define :create_attendance_session, action: :create
      define :list_attendance_sessions, action: :read
      define :list_recent_attendance_sessions, action: :list_recent

      define :list_attendance_sessions_by_date_range,
        action: :list_by_date_range,
        args: [:start_date, :end_date]

      define :list_attendance_sessions_by_category,
        action: :list_by_category,
        args: [:category_id]

      define :update_attendance_session, action: :update
      define :update_attendance_session_total, action: :update_total_present, args: [:total]
      define :destroy_attendance_session, action: :destroy
      define :get_attendance_session_by_id, action: :read, get_by: [:id]
    end

    resource Chms.Church.AttendanceRecords do
      define :create_attendance_record, action: :create
      define :list_attendance_records, action: :read
      define :list_attendance_records_by_session, action: :list_by_session, args: [:session_id]

      define :list_attendance_records_by_congregant,
        action: :list_by_congregant,
        args: [:congregant_id]

      define :update_attendance_record, action: :update
      define :destroy_attendance_record, action: :destroy
      define :get_attendance_record_by_id, action: :read, get_by: [:id]
    end
  end
end
