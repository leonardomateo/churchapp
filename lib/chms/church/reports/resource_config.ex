defmodule Chms.Church.Reports.ResourceConfig do
  @moduledoc """
  Central registry for all reportable resources.
  Each resource configuration defines fields, filters, and display options.
  """

  @doc """
  Returns all available resources for reporting.
  """
  def all_resources do
    [
      congregants_config(),
      contributions_config(),
      ministry_funds_config(),
      week_ending_reports_config(),
      events_config()
    ]
  end

  @doc """
  Get a specific resource configuration by key.
  """
  def get_resource(key) when is_atom(key) do
    all_resources()
    |> Enum.find(&(&1.key == key))
  end

  def get_resource(_), do: nil

  # Congregants Resource Configuration
  defp congregants_config do
    %{
      key: :congregants,
      name: "Congregants",
      module: Chms.Church.Congregants,
      domain_function: :list_congregants,
      icon: "hero-users",
      fields: [
        %{key: :member_id, label: "Member ID", type: :integer, exportable: true},
        %{key: :first_name, label: "First Name", type: :string, exportable: true},
        %{key: :last_name, label: "Last Name", type: :string, exportable: true},
        %{key: :gender, label: "Gender", type: :atom, exportable: true},
        %{key: :status, label: "Status", type: :atom, exportable: true},
        %{key: :mobile_tel, label: "Mobile Phone", type: :string, exportable: true},
        %{key: :home_tel, label: "Home Phone", type: :string, exportable: true},
        %{key: :city, label: "City", type: :string, exportable: true},
        %{key: :state, label: "State", type: :string, exportable: true},
        %{key: :country, label: "Country", type: :string, exportable: true},
        %{key: :dob, label: "Date of Birth", type: :date, exportable: true},
        %{key: :member_since, label: "Member Since", type: :date, exportable: true},
        %{key: :is_leader, label: "Leader", type: :boolean, exportable: true}
      ],
      filters: [
        %{
          key: :search,
          label: "Search",
          type: :text,
          placeholder: "Search by name or member ID...",
          query_builder: :search_filter
        },
        %{
          key: :status,
          label: "Status",
          type: :select,
          options: [:member, :visitor, :honorific, :deceased],
          query_builder: :enum_filter,
          field: :status
        },
        %{
          key: :gender,
          label: "Gender",
          type: :select,
          options: [:male, :female],
          query_builder: :enum_filter,
          field: :gender
        },
        %{
          key: :is_leader,
          label: "Leaders Only",
          type: :boolean,
          query_builder: :boolean_filter,
          field: :is_leader
        },
        %{
          key: :member_since_from,
          label: "Member Since (From)",
          type: :date,
          query_builder: :date_range_filter,
          field: :member_since,
          operator: :gte
        },
        %{
          key: :member_since_to,
          label: "Member Since (To)",
          type: :date,
          query_builder: :date_range_filter,
          field: :member_since,
          operator: :lte
        },
        %{
          key: :city,
          label: "City",
          type: :text,
          placeholder: "Filter by city...",
          query_builder: :text_search_filter,
          field: :city
        },
        %{
          key: :state,
          label: "State",
          type: :text,
          placeholder: "Filter by state...",
          query_builder: :text_search_filter,
          field: :state
        },
        %{
          key: :country,
          label: "Country",
          type: :text,
          placeholder: "Filter by country...",
          query_builder: :text_search_filter,
          field: :country
        }
      ],
      sortable_fields: [:member_id, :first_name, :last_name, :member_since, :city, :state],
      default_sort: {:first_name, :asc},
      preloads: [],
      required_roles: [:admin, :super_admin, :staff, :leader, :member]
    }
  end

  # Contributions Resource Configuration
  defp contributions_config do
    %{
      key: :contributions,
      name: "Contributions",
      module: Chms.Church.Contributions,
      domain_function: :list_contributions,
      icon: "hero-currency-dollar",
      fields: [
        %{key: :contribution_type, label: "Type", type: :string, exportable: true},
        %{key: :revenue, label: "Amount", type: :currency, exportable: true},
        %{key: :contribution_date, label: "Date", type: :datetime, exportable: true},
        %{key: :notes, label: "Notes", type: :string, exportable: true},
        %{
          key: :congregant_name,
          label: "Contributor",
          type: :string,
          exportable: true,
          computed: true
        }
      ],
      filters: [
        %{
          key: :search,
          label: "Search",
          type: :text,
          placeholder: "Search by type or contributor...",
          query_builder: :contribution_search_filter
        },
        %{
          key: :contribution_type,
          label: "Type",
          type: :text,
          placeholder: "Filter by type...",
          query_builder: :text_search_filter,
          field: :contribution_type
        },
        %{
          key: :date_from,
          label: "Date From",
          type: :date,
          query_builder: :datetime_range_filter,
          field: :contribution_date,
          operator: :gte
        },
        %{
          key: :date_to,
          label: "Date To",
          type: :date,
          query_builder: :datetime_range_filter,
          field: :contribution_date,
          operator: :lte
        },
        %{
          key: :amount_min,
          label: "Min Amount",
          type: :number,
          query_builder: :number_range_filter,
          field: :revenue,
          operator: :gte
        },
        %{
          key: :amount_max,
          label: "Max Amount",
          type: :number,
          query_builder: :number_range_filter,
          field: :revenue,
          operator: :lte
        }
      ],
      sortable_fields: [:contribution_type, :revenue, :contribution_date],
      default_sort: {:contribution_date, :desc},
      preloads: [:congregant],
      required_roles: [:admin, :super_admin, :staff, :leader]
    }
  end

  # Ministry Funds Resource Configuration
  defp ministry_funds_config do
    %{
      key: :ministry_funds,
      name: "Ministry Funds",
      module: Chms.Church.MinistryFunds,
      domain_function: :list_ministry_funds,
      icon: "hero-building-library",
      fields: [
        %{key: :ministry_name, label: "Ministry", type: :string, exportable: true},
        %{key: :transaction_type, label: "Type", type: :atom, exportable: true},
        %{key: :amount, label: "Amount", type: :currency, exportable: true},
        %{key: :transaction_date, label: "Date", type: :datetime, exportable: true},
        %{key: :notes, label: "Notes", type: :string, exportable: true}
      ],
      filters: [
        %{
          key: :search,
          label: "Search",
          type: :text,
          placeholder: "Search by ministry name or notes...",
          query_builder: :ministry_search_filter
        },
        %{
          key: :ministry_name,
          label: "Ministry",
          type: :text,
          placeholder: "Filter by ministry...",
          query_builder: :text_search_filter,
          field: :ministry_name
        },
        %{
          key: :transaction_type,
          label: "Transaction Type",
          type: :select,
          options: [:revenue, :expense],
          query_builder: :enum_filter,
          field: :transaction_type
        },
        %{
          key: :date_from,
          label: "Date From",
          type: :date,
          query_builder: :datetime_range_filter,
          field: :transaction_date,
          operator: :gte
        },
        %{
          key: :date_to,
          label: "Date To",
          type: :date,
          query_builder: :datetime_range_filter,
          field: :transaction_date,
          operator: :lte
        },
        %{
          key: :amount_min,
          label: "Min Amount",
          type: :number,
          query_builder: :number_range_filter,
          field: :amount,
          operator: :gte
        },
        %{
          key: :amount_max,
          label: "Max Amount",
          type: :number,
          query_builder: :number_range_filter,
          field: :amount,
          operator: :lte
        }
      ],
      sortable_fields: [:ministry_name, :transaction_type, :amount, :transaction_date],
      default_sort: {:transaction_date, :desc},
      preloads: [],
      required_roles: [:admin, :super_admin, :staff, :leader]
    }
  end

  # Week Ending Reports Resource Configuration
  defp week_ending_reports_config do
    %{
      key: :week_ending_reports,
      name: "Week Ending Reports",
      module: Chms.Church.WeekEndingReports,
      domain_function: :list_week_ending_reports,
      icon: "hero-document-text",
      fields: [
        %{key: :report_name, label: "Report Name", type: :string, exportable: true},
        %{key: :week_start_date, label: "Week Start", type: :date, exportable: true},
        %{key: :week_end_date, label: "Week End", type: :date, exportable: true},
        %{key: :grand_total, label: "Grand Total", type: :currency, exportable: true},
        %{key: :notes, label: "Notes", type: :string, exportable: true}
      ],
      filters: [
        %{
          key: :search,
          label: "Search",
          type: :text,
          placeholder: "Search by report name...",
          query_builder: :text_search_filter,
          field: :report_name
        },
        %{
          key: :week_start_from,
          label: "Week Start From",
          type: :date,
          query_builder: :date_range_filter,
          field: :week_start_date,
          operator: :gte
        },
        %{
          key: :week_start_to,
          label: "Week Start To",
          type: :date,
          query_builder: :date_range_filter,
          field: :week_start_date,
          operator: :lte
        },
        %{
          key: :week_end_from,
          label: "Week End From",
          type: :date,
          query_builder: :date_range_filter,
          field: :week_end_date,
          operator: :gte
        },
        %{
          key: :week_end_to,
          label: "Week End To",
          type: :date,
          query_builder: :date_range_filter,
          field: :week_end_date,
          operator: :lte
        }
      ],
      sortable_fields: [:report_name, :week_start_date, :week_end_date, :grand_total],
      default_sort: {:week_end_date, :desc},
      preloads: [:grand_total],
      required_roles: [:admin, :super_admin]
    }
  end

  # Events Resource Configuration
  defp events_config do
    %{
      key: :events,
      name: "Events",
      module: Chms.Church.Events,
      domain_function: :list_events,
      icon: "hero-calendar",
      fields: [
        %{key: :title, label: "Title", type: :string, exportable: true},
        %{key: :description, label: "Description", type: :string, exportable: true},
        %{key: :start_time, label: "Start Time", type: :datetime, exportable: true},
        %{key: :end_time, label: "End Time", type: :datetime, exportable: true},
        %{key: :all_day, label: "All Day", type: :boolean, exportable: true},
        %{key: :location, label: "Location", type: :string, exportable: true},
        %{key: :is_recurring, label: "Recurring", type: :boolean, exportable: true}
      ],
      filters: [
        %{
          key: :search,
          label: "Search",
          type: :text,
          placeholder: "Search by title or location...",
          query_builder: :event_search_filter
        },
        %{
          key: :all_day,
          label: "All Day Events",
          type: :boolean,
          query_builder: :boolean_filter,
          field: :all_day
        },
        %{
          key: :is_recurring,
          label: "Recurring Events",
          type: :boolean,
          query_builder: :boolean_filter,
          field: :is_recurring
        },
        %{
          key: :start_from,
          label: "Start From",
          type: :date,
          query_builder: :datetime_range_filter,
          field: :start_time,
          operator: :gte
        },
        %{
          key: :start_to,
          label: "Start To",
          type: :date,
          query_builder: :datetime_range_filter,
          field: :start_time,
          operator: :lte
        },
        %{
          key: :location,
          label: "Location",
          type: :text,
          placeholder: "Filter by location...",
          query_builder: :text_search_filter,
          field: :location
        }
      ],
      sortable_fields: [:title, :start_time, :end_time, :location],
      default_sort: {:start_time, :desc},
      preloads: [],
      required_roles: [:admin, :super_admin, :staff, :leader, :member]
    }
  end
end
