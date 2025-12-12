# Reporting Module Implementation Plan

## Executive Summary

This document outlines a comprehensive, enterprise-grade reporting system for the Church Management System. The system provides admins with powerful tools to generate customizable reports with advanced filtering, visualization, export, and scheduling capabilities.

### Core Features
- Dynamic filtering with context-sensitive options
- Multiple export formats (CSV, PDF)
- Print functionality with optimized layouts
- Chart visualizations (pie, bar, line charts)
- Report templates (save/load configurations)
- Aggregate functions (sum, average, count)
- Comparison reports (period-over-period analysis)
- Scheduled reports with email delivery
- Extensible architecture (easy to add new resources)

### Timeline & Scope
- **Total Effort:** 21-30 development days
- **Files to Create:** 21 new files
- **Files to Modify:** 4 existing files
- **New Dependencies:** 2 (pdf_generator, oban)

---

## Architecture Overview

### Design Pattern: Configuration Registry

The system uses a **Resource Configuration Registry** pattern where all reportable resources are defined in a single configuration module. This design makes the system highly extensible - adding a new resource requires editing only one file.

### Key Components

1. **Resource Config Module** - Central registry defining all reportable resources
2. **Query Builder Module** - Dynamic Ash query construction based on filters
3. **Reports LiveView** - Main UI for resource selection and report generation
4. **Report Components** - Reusable UI components (filters, tables, charts)
5. **Export Modules** - CSV and PDF generation
6. **Template System** - Save/load report configurations
7. **Scheduler Worker** - Automated report generation and email delivery

### Initial Resources (5)
- Congregants
- Contributions
- Ministry Funds
- Week Ending Reports
- Events

---

## PHASE 1: Core Infrastructure & Basic Reporting

**Duration:** 5-7 days
**Deliverable:** Basic reports with CSV export

### Phase 1 Goals
- Implement resource configuration registry
- Build dynamic query builder
- Create main reports LiveView
- Add basic filtering, sorting, pagination
- Implement CSV export

### Step 1.1: Resource Configuration Module
**File:** `lib/chms/church/reports/resource_config.ex` (400 lines)

Create configuration registry with definitions for 5 resources:

**Structure:**
```elixir
defmodule Chms.Church.Reports.ResourceConfig do
  # Returns all available resources
  def all_resources do
    [
      congregants_config(),
      contributions_config(),
      ministry_funds_config(),
      week_ending_reports_config(),
      events_config()
    ]
  end

  # Get specific resource by key
  def get_resource(key)

  # Individual resource configs
  defp congregants_config()
  defp contributions_config()
  # ... etc
end
```

**Each resource config includes:**
- `key` - Unique identifier (atom)
- `name` - Display name
- `module` - Ash resource module
- `domain_function` - Function to list resources
- `icon` - Heroicon name
- `fields` - Displayable fields with types and formatting
- `filters` - Available filters with query builder types
- `sortable_fields` - Columns that support sorting
- `default_sort` - Default sort field and direction
- `preloads` - Relationships to eager load
- `required_roles` - Authorization roles

**Example - Congregants Config:**
```elixir
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
      %{key: :status, label: "Status", type: :atom, exportable: true},
      # ... more fields
    ],
    filters: [
      %{key: :search, label: "Search", type: :text,
        placeholder: "Search by name or member ID...",
        query_builder: :search_filter},
      %{key: :status, label: "Status", type: :select,
        options: [:member, :visitor, :honorific, :deceased],
        query_builder: :enum_filter},
      # ... more filters
    ],
    sortable_fields: [:member_id, :first_name, :last_name, :member_since],
    default_sort: {:first_name, :asc},
    preloads: [],
    required_roles: [:admin, :super_admin, :staff, :leader, :member]
  }
end
```

### Step 1.2: Query Builder Module
**File:** `lib/chms/church/reports/query_builder.ex` (300 lines)

Dynamic Ash query construction with filter application:

**Main Functions:**
```elixir
# Main entry point
def build_and_execute(resource_config, params, actor)

# Query construction
defp build_base_query(resource_config, actor)
defp apply_filters(query, resource_config, params)
defp apply_sorting(query, resource_config, params)
defp execute_with_pagination(query, params, actor)
```

**Filter Types Implemented:**
- `:search_filter` - Multi-mode search (ID, single word, multi-word) for congregants
- `:contribution_search_filter` - Search in contribution type and contributor name
- `:ministry_search_filter` - Search in ministry name and notes
- `:event_search_filter` - Search in event title and location
- `:text_search_filter` - Generic text search with contains
- `:enum_filter` - Enum field filtering (e.g., status, gender)
- `:string_filter` - Exact string matching
- `:boolean_filter` - Boolean field filtering
- `:date_range_filter` - Date range with >= and <=
- `:datetime_range_filter` - Datetime range with start/end of day conversion
- `:number_range_filter` - Numeric range with Decimal support

**Pattern from existing codebase:**
Follow `contributions/index_live.ex` patterns for filter implementation, including date conversion and search logic.

### Step 1.3: Reports LiveView
**File:** `lib/churchapp_web/live/admin/reports/index_live.ex` (500+ lines)

Main reporting interface with state management and event handling.

**State Management:**
```elixir
- :available_resources       # List from ResourceConfig
- :selected_resource_key      # Currently selected (nil initially)
- :selected_resource_config   # Full config for selected resource
- :filter_params              # Map of current filter values
- :sort_by, :sort_dir         # Sorting state
- :page, :per_page            # Pagination (25 per page default)
- :results                    # Query results
- :metadata                   # Total count, pages, etc.
- :loading                    # Loading indicator
- :show_export_menu           # Export dropdown visibility
```

**Event Handlers:**
```elixir
def handle_event("select_resource", %{"resource" => key}, socket)
def handle_event("update_filter", %{"filter" => key, "value" => val}, socket)
def handle_event("clear_filters", _params, socket)
def handle_event("sort", %{"field" => field}, socket)
def handle_event("paginate", %{"page" => page}, socket)
def handle_event("generate_report", _params, socket)
def handle_event("export_csv", _params, socket)
def handle_event("toggle_export_menu", _params, socket)
```

**Key Implementation Details:**
- Use `handle_params/3` for deep linking support (shareable URLs with filters)
- Always pass `actor: socket.assigns.current_user` to all Ash operations
- Reset pagination to page 1 when filters change
- Show loading state during query execution
- Handle empty results gracefully

### Step 1.4: Report UI Components
**File:** `lib/churchapp_web/components/report_components.ex` (400 lines)

Reusable components for the reports interface:

**Components to Implement:**

1. **Resource Selector** - Dropdown to select resource
2. **Filters Panel** - Dynamic filter rendering
3. **Filter Input** - Polymorphic input based on type:
   - `:text` → text input with debounce (300ms)
   - `:select` → dropdown with options
   - `:select_dynamic` → dropdown with runtime-loaded options
   - `:date` → date input with `phx-hook="DatePicker"` for auto-hide
   - `:number` → number input with step
   - `:boolean` → checkbox
4. **Results Table** - Table with sortable headers
5. **Field Value Formatter** - Format values by type:
   - `:currency` → `$#{Decimal.to_string(value)}`
   - `:datetime` → `Calendar.strftime(value, "%Y-%m-%d %H:%M:%S")`
   - `:date` → `Date.to_string(value)`
   - `:boolean` → "Yes" / "No"
   - `:array` → `Enum.join(value, "; ")`
6. **Pagination Component** - Reuse `pagination_range/2` pattern with ellipsis
7. **Export Menu** - Dropdown with export options
8. **Loading Spinner** - Show during query execution
9. **Active Filters Display** - Show applied filters as tags

**Theme Support:**
- Use existing color classes: `bg-dark-800`, `border-dark-700`, `text-white`
- Automatic light/dark mode via CSS variables
- All date inputs use `phx-hook="DatePicker"` for auto-hide

### Step 1.5: CSV Export Module
**File:** `lib/chms/church/reports/export/csv_export.ex` (100 lines)

Generate CSV files from report results:

```elixir
defmodule Chms.Church.Reports.Export.CsvExport do
  def generate(resource_config, results)

  defp get_field_value(result, field)
  defp format_value(value, field)
  defp escape_csv_value(value)
end
```

**Features:**
- Filter to exportable fields only
- Header row with field labels
- Proper CSV escaping (quotes, commas, newlines)
- Format values appropriately (currency, dates, booleans)

### Step 1.6: Client-side Download Hook
**File:** `assets/js/app.js` (~15 lines)

Add download hook for CSV/PDF:

```javascript
const ReportDownload = {
  mounted() {
    this.handleEvent("download", ({content, filename, mime_type}) => {
      const blob = new Blob([content], { type: mime_type })
      const url = window.URL.createObjectURL(blob)
      const link = document.createElement('a')
      link.href = url
      link.download = filename
      document.body.appendChild(link)
      link.click()
      document.body.removeChild(link)
      window.URL.revokeObjectURL(url)
    })
  }
}

// Add to existing Hooks object
Hooks.ReportDownload = ReportDownload
```

### Step 1.7: Router Integration
**File:** `lib/churchapp_web/router.ex` (1 line)

Add route in admin scope (after line 122):

```elixir
# Reports
live("/reports", Admin.ReportsLive.IndexLive, :index)
```

### Step 1.8: Navigation Menu Integration
**File:** `lib/churchapp_web/components/layouts/app.html.heex` (~30 lines total)

Add "Reports" link in Administration section for both desktop and mobile:

**Desktop sidebar (after line 121):**
```heex
<.link
  navigate={~p"/admin/reports"}
  class={[
    "flex items-center px-3 py-2 text-sm font-medium rounded-md transition-colors",
    if(String.starts_with?(@current_path || "", "/admin/reports"),
      do: "bg-primary-500/10 text-primary-500",
      else: "text-gray-400 hover:bg-dark-700 hover:text-white"
    )
  ]}
>
  <.icon name="hero-chart-bar-square" class="mr-3 h-5 w-5 flex-shrink-0" />
  Reports
</.link>
```

**Mobile sidebar:** Add identical link in mobile navigation (around line 256-299)

### Phase 1 Testing Checklist
- [ ] Only admin/super_admin can access /admin/reports
- [ ] Resource dropdown shows all 5 resources
- [ ] Selecting resource displays correct filters
- [ ] Filters apply correctly and update results
- [ ] Date pickers auto-hide after selection
- [ ] Sorting toggles asc/desc with visual indicator
- [ ] Pagination works with ellipsis
- [ ] Clear filters resets all values
- [ ] CSV export downloads correct data
- [ ] Dark/light theme works
- [ ] Mobile responsive
- [ ] Deep linking works

---

## PHASE 2: Advanced Export & Print

**Duration:** 2-3 days
**Deliverable:** PDF export and print functionality

### Phase 2 Goals
- Add PDF export capability
- Implement print-optimized view
- Create professional report layouts

### Step 2.1: PDF Export Implementation
**File:** `lib/chms/church/reports/export/pdf_export.ex` (200 lines)

**Dependency:** Add `{:pdf_generator, "~> 0.6"}` to `mix.exs`

Implement PDF generation with:
- Church header with logo
- Report title and generation date
- Filter summary section
- Data table with borders and alternating row colors
- Page numbers and footer
- Landscape orientation support for wide tables
- Page break handling for long reports
- Theme-aware styling

```elixir
defmodule Chms.Church.Reports.Export.PdfExport do
  def generate(resource_config, results, filters)

  defp build_html_template(config, results, filters)
  defp generate_pdf_from_html(html)
  defp format_header(config)
  defp format_table(config, results)
  defp format_footer()
end
```

### Step 2.2: Print Functionality
**File:** Update `lib/churchapp_web/live/admin/reports/index_live.ex`

Add print event handler:
```elixir
def handle_event("print_report", _params, socket) do
  {:noreply, push_event(socket, "print", %{})}
end
```

Add print hook to assets/js/app.js:
```javascript
const PrintReport = {
  mounted() {
    this.handleEvent("print", () => {
      window.print()
    })
  }
}
```

### Step 2.3: Print Styles
**File:** `assets/css/app.css` (~50 lines)

Add print-specific CSS:

```css
@media print {
  /* Hide navigation, buttons, filters */
  .no-print,
  nav,
  .sidebar,
  button,
  .pagination,
  .filter-panel {
    display: none !important;
  }

  /* Optimize table for printing */
  table {
    page-break-inside: avoid;
    width: 100%;
  }

  tr {
    page-break-inside: avoid;
    page-break-after: auto;
  }

  thead {
    display: table-header-group;
  }

  /* Full page width */
  .print-full-width {
    width: 100%;
    max-width: none;
  }

  /* Church header for print */
  .print-header {
    display: block;
    text-align: center;
    margin-bottom: 2rem;
  }

  /* Page breaks */
  .page-break {
    page-break-after: always;
  }
}
```

### Step 2.4: Update Export Menu
Add PDF and Print options to export dropdown in UI.

### Phase 2 Testing Checklist
- [ ] PDF export generates properly formatted document
- [ ] PDF includes church header and logo
- [ ] PDF shows filter summary
- [ ] PDF tables have proper formatting
- [ ] Print opens browser print dialog
- [ ] Print view hides unnecessary UI elements
- [ ] Print layout is clean and professional
- [ ] Page breaks work correctly for long reports

---

## PHASE 3: Report Templates

**Duration:** 2-3 days
**Deliverable:** Save/load report configurations

### Phase 3 Goals
- Create ReportTemplate Ash resource
- Implement template save/load functionality
- Add template management UI
- Support template sharing between admins

### Step 3.1: Create ReportTemplate Resource
**File:** `lib/chms/church/report_template.ex` (150 lines)

```elixir
defmodule Chms.Church.ReportTemplate do
  use Ash.Resource,
    data_layer: AshPostgres.DataLayer,
    domain: Chms.Church

  attributes do
    uuid_primary_key :id
    attribute :name, :string, allow_nil?: false
    attribute :description, :string
    attribute :resource_key, :atom, allow_nil?: false
    attribute :filter_params, :map, default: %{}
    attribute :sort_by, :atom
    attribute :sort_dir, :atom, default: :asc
    attribute :is_shared, :boolean, default: false
    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :created_by, Churchapp.Accounts.User
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:name, :description, :resource_key, :filter_params,
              :sort_by, :sort_dir, :is_shared]
      argument :created_by_id, :uuid, allow_nil?: false
      change relate_actor(:created_by)
    end

    update :update do
      accept [:name, :description, :filter_params, :sort_by, :sort_dir, :is_shared]
    end
  end

  policies do
    policy action_type([:read, :create, :update, :destroy]) do
      authorize_if actor_attribute_equals(:role, [:admin, :super_admin])
    end
  end

  postgres do
    table "report_templates"
    repo Churchapp.Repo
  end
end
```

### Step 3.2: Generate Migration
**File:** `priv/repo/migrations/[timestamp]_create_report_templates.exs`

Run: `mix ash.codegen --name create_report_templates`

### Step 3.3: Add Template Management to Reports LiveView
**File:** Update `lib/churchapp_web/live/admin/reports/index_live.ex`

**Add to state:**
```elixir
- :templates                      # Available templates for current resource
- :show_save_template_modal       # Boolean
- :show_manage_templates_modal    # Boolean
- :template_form                  # AshPhoenix.Form for template
- :editing_template_id            # ID of template being edited
```

**Add event handlers:**
```elixir
def handle_event("load_template", %{"id" => id}, socket)
def handle_event("show_save_template_modal", _params, socket)
def handle_event("save_template", %{"form" => params}, socket)
def handle_event("show_manage_templates", _params, socket)
def handle_event("edit_template", %{"id" => id}, socket)
def handle_event("delete_template", %{"id" => id}, socket)
def handle_event("toggle_template_share", %{"id" => id}, socket)
```

**Helper functions:**
```elixir
defp load_templates(socket)
defp apply_template_filters(socket, template)
```

### Step 3.4: Template UI Components
Add to `report_components.ex`:

1. **Template Selector Dropdown** - Shows saved templates for current resource
2. **Save Template Modal** - Form to save current configuration
3. **Manage Templates Modal** - List, edit, delete templates
4. **Template Card** - Display template with actions

**Features:**
- Show template name, description, created date
- Indicate if template is shared
- Quick load button
- Edit/delete actions
- Share toggle (admin only)

### Phase 3 Testing Checklist
- [ ] Save template persists current filters and sort
- [ ] Load template applies filters correctly
- [ ] Template list shows only relevant resource templates
- [ ] Shared templates visible to all admins
- [ ] Non-shared templates visible only to creator
- [ ] Edit template updates configuration
- [ ] Delete template removes from database
- [ ] Template sharing toggle works

---

## PHASE 4: Charts & Visualizations

**Duration:** 3-4 days
**Deliverable:** Chart view with multiple visualization types

### Phase 4 Goals
- Add table/chart view toggle
- Implement resource-specific charts
- Create chart components
- Ensure theme compatibility

### Step 4.1: Add Chart View to Reports LiveView
**File:** Update `lib/churchapp_web/live/admin/reports/index_live.ex`

**Add to state:**
```elixir
- :view_mode          # :table or :chart
- :selected_chart     # Current chart type
- :chart_data         # Processed data for charts
```

**Add event handlers:**
```elixir
def handle_event("toggle_view", %{"mode" => mode}, socket)
def handle_event("select_chart", %{"type" => type}, socket)
```

**Add helper functions:**
```elixir
defp prepare_chart_data(results, chart_type, resource_config)
defp aggregate_for_chart(results, group_by, value_field)
```

### Step 4.2: Create Chart Components
**File:** `lib/churchapp_web/components/report_chart_components.ex` (300 lines)

Leverage existing Chart.js integration from dashboard:

```elixir
defmodule ChurchappWeb.ReportChartComponents do
  use Phoenix.Component

  def chart_selector(assigns)    # Toggle between chart types
  def report_pie_chart(assigns)  # Pie chart for distributions
  def report_bar_chart(assigns)  # Bar chart for comparisons
  def report_line_chart(assigns) # Line chart for trends
end
```

**Chart Types by Resource:**

**Congregants:**
- Pie: Status distribution
- Bar: Members by country/state
- Line: Growth over time (with date filter)

**Contributions:**
- Pie: Type distribution
- Bar: Monthly contributions
- Line: Revenue trend

**Ministry Funds:**
- Bar: Revenue vs Expense by ministry
- Pie: Expense breakdown

**Events:**
- Bar: Events by month
- Pie: All-day vs timed

### Step 4.3: Chart Data Processing
Implement aggregation logic for each chart type:

```elixir
# Pie chart - group and count
def prepare_pie_data(results, group_field) do
  results
  |> Enum.group_by(&Map.get(&1, group_field))
  |> Enum.map(fn {label, items} ->
    %{label: label, value: length(items)}
  end)
end

# Bar chart - group and sum
def prepare_bar_data(results, group_field, sum_field) do
  results
  |> Enum.group_by(&Map.get(&1, group_field))
  |> Enum.map(fn {label, items} ->
    total = Enum.reduce(items, Decimal.new(0), fn item, acc ->
      Decimal.add(acc, Map.get(item, sum_field))
    end)
    %{label: label, value: total}
  end)
end

# Line chart - time series
def prepare_line_data(results, date_field, value_field) do
  results
  |> Enum.sort_by(&Map.get(&1, date_field))
  |> Enum.map(fn item ->
    %{date: Map.get(item, date_field), value: Map.get(item, value_field)}
  end)
end
```

### Phase 4 Testing Checklist
- [ ] Toggle between table and chart view works
- [ ] Charts display correct data
- [ ] Chart colors work in dark/light mode
- [ ] Chart selector shows available chart types
- [ ] Pie charts show percentages
- [ ] Bar charts show proper labels
- [ ] Line charts show trends over time
- [ ] Charts update when filters change
- [ ] Empty data shows appropriate message

---

## PHASE 5: Advanced Features

**Duration:** 4-5 days
**Deliverable:** Custom columns, advanced filters, aggregates, comparison

### Phase 5.1: Custom Column Selection

**Duration:** 1 day

**File:** Update `lib/churchapp_web/live/admin/reports/index_live.ex`

**Add to state:**
```elixir
- :visible_columns    # List of field keys to display
- :column_order       # Ordered list of field keys
- :show_column_modal  # Boolean
```

**Add event handlers:**
```elixir
def handle_event("show_column_modal", _params, socket)
def handle_event("toggle_column", %{"field" => field}, socket)
def handle_event("reorder_columns", %{"order" => order}, socket)
def handle_event("reset_columns", _params, socket)
```

**UI Component:**
- Modal with checkbox list of all fields
- Drag-and-drop to reorder (use Phoenix.LiveView.JS or SortableJS)
- Save preferences in session or user preferences table
- "Reset to Default" button

### Phase 5.2: Advanced Filter Logic (AND/OR)

**Duration:** 1-2 days

**File:** Update `lib/chms/church/reports/query_builder.ex`

**Current:** Simple filters combined with AND
**New:** Support filter groups with AND/OR logic

**Data Structure:**
```elixir
%{
  filter_groups: [
    %{
      operator: :and,  # or :or
      filters: [
        %{field: :status, value: "member"},
        %{field: :gender, value: "male"}
      ]
    },
    %{
      operator: :and,
      filters: [
        %{field: :status, value: "visitor"},
        %{field: :member_since, operator: :gte, value: "2024-01-01"}
      ]
    }
  ],
  group_operator: :or  # How to combine groups
}
```

**UI Changes:**
- "Add Filter Group" button
- Visual grouping with indentation/borders
- Group operator selector (AND/OR)
- Delete group button

### Phase 5.3: Aggregate Functions

**Duration:** 1 day

**File:** Update `lib/churchapp_web/live/admin/reports/index_live.ex`

**Add to state:**
```elixir
- :show_aggregates    # Boolean toggle
- :aggregates         # Calculated aggregate values
```

**Implement aggregation:**
```elixir
defp calculate_aggregates(results, visible_columns, field_configs) do
  Enum.reduce(visible_columns, %{}, fn field_key, acc ->
    field_config = Enum.find(field_configs, & &1.key == field_key)

    values = case field_config.type do
      type when type in [:integer, :decimal, :float] ->
        calculate_numeric_aggregates(results, field_key)
      _ ->
        calculate_count_aggregates(results, field_key)
    end

    Map.put(acc, field_key, values)
  end)
end

defp calculate_numeric_aggregates(results, field) do
  values = Enum.map(results, &Map.get(&1, field)) |> Enum.reject(&is_nil/1)

  %{
    sum: Enum.reduce(values, Decimal.new(0), &Decimal.add/2),
    avg: calculate_average(values),
    min: Enum.min(values, fn -> nil end),
    max: Enum.max(values, fn -> nil end),
    count: length(values)
  }
end
```

**UI:**
- Toggle button to show/hide aggregates
- Footer row in table with aggregate values
- Include aggregates in CSV/PDF exports

### Phase 5.4: Comparison Reports

**Duration:** 1-2 days

**File:** `lib/churchapp_web/live/admin/reports/comparison_live.ex` (400 lines)

New LiveView for side-by-side comparison:

**State:**
```elixir
- :selected_resource_key
- :selected_resource_config
- :period1_start, :period1_end
- :period2_start, :period2_end
- :period1_results
- :period2_results
- :comparison_data
- :filter_params
```

**Features:**
- Select resource
- Define two date ranges
- Apply same filters to both periods
- Show side-by-side results
- Calculate differences (absolute and percentage)
- Color-code increases (green) and decreases (red)
- Export comparison report

**Add route:**
```elixir
live("/reports/comparison", Admin.ReportsLive.ComparisonLive, :index)
```

### Phase 5 Testing Checklist
- [ ] Custom columns show/hide correctly
- [ ] Column reordering persists
- [ ] Advanced filter groups work correctly
- [ ] AND/OR logic produces expected results
- [ ] Aggregates calculate correctly
- [ ] Aggregate toggle works
- [ ] Aggregates included in exports
- [ ] Comparison view loads correctly
- [ ] Comparison calculates differences accurately
- [ ] Comparison highlights changes appropriately

---

## PHASE 6: Scheduled Reports

**Duration:** 3-4 days
**Deliverable:** Automated report generation and email delivery

### Phase 6 Goals
- Create ReportSchedule resource
- Implement scheduler worker with Oban
- Build schedule management UI
- Configure email delivery

### Step 6.1: Add Oban Dependency
**File:** `mix.exs`

Add dependency:
```elixir
{:oban, "~> 2.15"}
```

Configure Oban in `config/config.exs`:
```elixir
config :churchapp, Oban,
  repo: Churchapp.Repo,
  queues: [default: 10, reports: 5],
  plugins: [Oban.Plugins.Pruner]
```

### Step 6.2: Create ReportSchedule Resource
**File:** `lib/chms/church/report_schedule.ex` (150 lines)

```elixir
defmodule Chms.Church.ReportSchedule do
  use Ash.Resource,
    data_layer: AshPostgres.DataLayer,
    domain: Chms.Church

  attributes do
    uuid_primary_key :id
    attribute :name, :string, allow_nil?: false
    attribute :description, :string
    attribute :resource_key, :atom, allow_nil?: false
    attribute :filter_params, :map, default: %{}
    attribute :sort_by, :atom
    attribute :sort_dir, :atom, default: :asc
    attribute :schedule_type, :atom  # :daily, :weekly, :monthly
    attribute :schedule_time, :time, allow_nil?: false
    attribute :schedule_day, :integer  # 1-7 for weekly, 1-31 for monthly
    attribute :recipients, {:array, :string}, default: []
    attribute :export_format, :atom, default: :csv  # :csv or :pdf
    attribute :is_active, :boolean, default: true
    attribute :last_run_at, :utc_datetime
    attribute :next_run_at, :utc_datetime
    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :created_by, Churchapp.Accounts.User
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:name, :description, :resource_key, :filter_params,
              :sort_by, :sort_dir, :schedule_type, :schedule_time,
              :schedule_day, :recipients, :export_format, :is_active]
      change relate_actor(:created_by)
      change {CalculateNextRun, []}
    end

    update :update do
      accept [:name, :description, :filter_params, :sort_by, :sort_dir,
              :schedule_type, :schedule_time, :schedule_day, :recipients,
              :export_format, :is_active]
      change {CalculateNextRun, []}
    end

    update :mark_run do
      accept []
      change set_attribute(:last_run_at, &DateTime.utc_now/0)
      change {CalculateNextRun, []}
    end
  end

  policies do
    policy action_type([:read, :create, :update, :destroy]) do
      authorize_if actor_attribute_equals(:role, [:admin, :super_admin])
    end
  end

  calculations do
    calculate :next_run_formatted, :string do
      calculation fn records, _ ->
        Enum.map(records, fn record ->
          case record.next_run_at do
            nil -> "Not scheduled"
            dt -> Calendar.strftime(dt, "%Y-%m-%d %H:%M")
          end
        end)
      end
    end
  end

  postgres do
    table "report_schedules"
    repo Churchapp.Repo
  end
end
```

### Step 6.3: Generate Migration
Run: `mix ash.codegen --name create_report_schedules`

### Step 6.4: Create Scheduler Worker
**File:** `lib/chms/workers/report_scheduler.ex` (200 lines)

```elixir
defmodule Chms.Workers.ReportScheduler do
  use Oban.Worker, queue: :reports, max_attempts: 3

  alias Chms.Church.ReportSchedule
  alias Chms.Church.Reports.{ResourceConfig, QueryBuilder}
  alias Chms.Church.Reports.Export.{CsvExport, PdfExport}

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"schedule_id" => schedule_id}}) do
    schedule = Ash.get!(ReportSchedule, schedule_id)

    if schedule.is_active do
      # Generate report
      resource_config = ResourceConfig.get_resource(schedule.resource_key)

      params = Map.merge(schedule.filter_params, %{
        sort_by: schedule.sort_by,
        sort_dir: schedule.sort_dir,
        page: 1,
        per_page: 10000  # Large number for full export
      })

      # Use system actor for scheduled reports
      actor = get_system_actor()

      {:ok, results, _metadata} =
        QueryBuilder.build_and_execute(resource_config, params, actor)

      # Export to requested format
      {content, filename, mime_type} = case schedule.export_format do
        :csv ->
          csv = CsvExport.generate(resource_config, results)
          {csv, "#{schedule.resource_key}_report_#{Date.utc_today()}.csv", "text/csv"}

        :pdf ->
          pdf = PdfExport.generate(resource_config, results, params)
          {pdf, "#{schedule.resource_key}_report_#{Date.utc_today()}.pdf", "application/pdf"}
      end

      # Send email to recipients
      Enum.each(schedule.recipients, fn email ->
        send_report_email(email, schedule.name, content, filename, mime_type)
      end)

      # Update last_run_at and next_run_at
      schedule
      |> Ash.Changeset.for_update(:mark_run)
      |> Ash.update!()

      :ok
    else
      {:cancel, "Schedule is inactive"}
    end
  end

  defp get_system_actor do
    # Get system/admin user for scheduled operations
    Ash.get!(Churchapp.Accounts.User,
             [email: "system@church.org"],
             actor: nil)
  end

  defp send_report_email(recipient, report_name, content, filename, mime_type) do
    # Use existing mailer setup
    Churchapp.Mailer.deliver(
      to: recipient,
      subject: "Scheduled Report: #{report_name}",
      body: "Please find attached your scheduled report.",
      attachments: [{filename, content, mime_type}]
    )
  end
end
```

### Step 6.5: Schedule Management UI
**File:** `lib/churchapp_web/live/admin/reports/schedules_live.ex` (300 lines)

New LiveView for managing schedules:

**State:**
```elixir
- :schedules           # List of all schedules
- :show_form_modal     # Boolean
- :editing_schedule    # Schedule being edited
- :form                # AshPhoenix.Form
- :available_resources # From ResourceConfig
```

**Event Handlers:**
```elixir
def handle_event("new_schedule", _params, socket)
def handle_event("edit_schedule", %{"id" => id}, socket)
def handle_event("save_schedule", %{"form" => params}, socket)
def handle_event("delete_schedule", %{"id" => id}, socket)
def handle_event("toggle_active", %{"id" => id}, socket)
def handle_event("run_now", %{"id" => id}, socket)
```

**Features:**
- List all schedules with details
- Create/edit schedule form
- Toggle active status
- "Run Now" button for immediate execution
- Delete schedule
- Show last run and next run times

**Add route:**
```elixir
live("/reports/schedules", Admin.ReportsLive.SchedulesLive, :index)
```

### Step 6.6: Add Schedule Button to Reports UI
Update main reports LiveView to include "Schedule This Report" button that:
- Opens modal with pre-filled current filters
- Saves as new schedule
- Links to schedules management page

### Step 6.7: Cron Job for Checking Schedules
**File:** `lib/chms/application.ex`

Add Oban cron plugin to check for due schedules:

```elixir
config :churchapp, Oban,
  plugins: [
    {Oban.Plugins.Cron,
     crontab: [
       # Check every 5 minutes for due schedules
       {"*/5 * * * *", Chms.Workers.CheckSchedules}
     ]}
  ]
```

**File:** `lib/chms/workers/check_schedules.ex`

```elixir
defmodule Chms.Workers.CheckSchedules do
  use Oban.Worker, queue: :default

  @impl Oban.Worker
  def perform(_job) do
    now = DateTime.utc_now()

    # Find schedules that are due
    schedules = Chms.Church.ReportSchedule
    |> Ash.Query.filter(is_active == true)
    |> Ash.Query.filter(next_run_at <= ^now)
    |> Ash.read!()

    # Enqueue a job for each due schedule
    Enum.each(schedules, fn schedule ->
      %{schedule_id: schedule.id}
      |> Chms.Workers.ReportScheduler.new()
      |> Oban.insert()
    end)

    :ok
  end
end
```

### Phase 6 Testing Checklist
- [ ] Create schedule saves to database
- [ ] Schedule form validates all fields
- [ ] Recipients field accepts comma-separated emails
- [ ] Next run time calculates correctly
- [ ] Scheduled job executes at correct time
- [ ] Report generates with correct filters
- [ ] Email sends to all recipients
- [ ] Attachment format matches selection (CSV/PDF)
- [ ] Schedule updates last_run_at after execution
- [ ] Toggle active/inactive works
- [ ] "Run Now" executes immediately
- [ ] Delete schedule removes from database

---

## PHASE 7: Testing & Documentation

**Duration:** 2-3 days
**Deliverable:** Comprehensive test coverage and updated documentation

### Step 7.1: Write Test Files

**Create test files:**

1. **`test/churchapp_web/live/admin/reports/index_live_test.exs`**
   - Mount with admin user (success)
   - Mount with non-admin user (redirect)
   - Resource selection updates state
   - Filter application triggers query
   - Sorting changes update results
   - Pagination works correctly
   - CSV export generates correct output
   - PDF export generates valid PDF

2. **`test/churchapp_web/live/admin/reports/comparison_live_test.exs`**
   - Mount and initial state
   - Period selection
   - Comparison calculations
   - Difference highlighting

3. **`test/churchapp_web/live/admin/reports/schedules_live_test.exs`**
   - Schedule CRUD operations
   - Toggle active status
   - Run now functionality

4. **`test/chms/church/reports/query_builder_test.exs`**
   - Each filter type
   - Sorting logic
   - Pagination calculations
   - Multiple filters combined

5. **`test/chms/church/reports/export/csv_export_test.exs`**
   - CSV generation
   - Field formatting
   - CSV escaping

6. **`test/chms/church/reports/export/pdf_export_test.exs`**
   - PDF generation
   - PDF structure validation

7. **`test/chms/workers/report_scheduler_test.exs`**
   - Job execution
   - Email sending
   - Schedule updates

### Step 7.2: Manual Testing

Complete the full testing checklist from all phases:

**Core Features:**
- [ ] Authorization works correctly
- [ ] All 5 resources available
- [ ] Filters work for each resource
- [ ] Sorting works correctly
- [ ] Pagination handles edge cases
- [ ] CSV export downloads
- [ ] Date pickers auto-hide

**Advanced Export:**
- [ ] PDF export works
- [ ] Print view is clean
- [ ] Both formats include correct data

**Templates:**
- [ ] Save/load templates
- [ ] Shared templates work
- [ ] Template management works

**Charts:**
- [ ] All chart types display
- [ ] Charts work in both themes
- [ ] Charts update with filters

**Advanced Features:**
- [ ] Custom columns work
- [ ] Advanced filters work
- [ ] Aggregates calculate correctly
- [ ] Comparison view works

**Scheduled Reports:**
- [ ] Schedules create correctly
- [ ] Jobs execute on time
- [ ] Emails send successfully

**Cross-cutting:**
- [ ] Dark/light mode works everywhere
- [ ] Mobile responsive
- [ ] No console errors
- [ ] Deep linking works

### Step 7.3: Update Documentation

**File:** `CLAUDE.md` - Add comprehensive Reports section:

```markdown
### Reports Module

The reporting system provides admins with powerful tools to generate customizable reports with advanced filtering, visualization, and export capabilities.

#### Features

**Core:**
- Dynamic filtering with context-sensitive options
- Sorting and pagination
- CSV and PDF export
- Print functionality with optimized layouts
- Deep linking (shareable URLs with filters)

**Advanced:**
- Chart visualizations (pie, bar, line charts)
- Report templates (save/load configurations)
- Custom column selection with reordering
- Advanced filter logic (AND/OR groups)
- Aggregate functions (sum, average, count, min, max)
- Comparison reports (period-over-period analysis)
- Scheduled reports with email delivery

#### Access

- **URL:** `/admin/reports`
- **Roles:** Admin and Super Admin only
- **Routes:**
  - `/admin/reports` - Main reports interface
  - `/admin/reports/comparison` - Comparison view
  - `/admin/reports/schedules` - Schedule management

#### Adding a New Resource

To add a new reportable resource:

1. Edit `lib/chms/church/reports/resource_config.ex`
2. Create config function (e.g., `families_config/0`)
3. Define fields, filters, sortable columns
4. Add to `all_resources/0` list
5. UI automatically adapts - no other changes needed

Example:
```elixir
defp families_config do
  %{
    key: :families,
    name: "Families",
    module: Chms.Church.Families,
    domain_function: :list_families,
    icon: "hero-home",
    fields: [...],
    filters: [...],
    sortable_fields: [...],
    default_sort: {:family_name, :asc},
    preloads: [:members],
    required_roles: [:admin, :super_admin]
  }
end
```

#### Scheduled Reports

Configure automated reports via `/admin/reports/schedules`:
- Daily, weekly, or monthly schedules
- Multiple email recipients
- CSV or PDF format
- Preserves filters and sorting
- Automatic execution via Oban background jobs

#### Architecture

**Configuration Registry Pattern:**
- All resources defined in single config module
- Dynamic query building based on configuration
- Extensible filter system
- Type-safe with Ash framework

**Key Modules:**
- `Chms.Church.Reports.ResourceConfig` - Resource definitions
- `Chms.Church.Reports.QueryBuilder` - Dynamic query construction
- `Chms.Church.Reports.Export.CsvExport` - CSV generation
- `Chms.Church.Reports.Export.PdfExport` - PDF generation
- `Chms.Workers.ReportScheduler` - Scheduled execution
```

### Step 7.4: Create User Guide
**File:** `docs/reports_user_guide.md` (optional)

Create user-facing documentation with screenshots showing:
- How to generate reports
- How to apply filters
- How to save templates
- How to schedule reports
- Tips and best practices

---

## File Summary

### New Files (21 total)

**Core Reporting (Phase 1):**
1. `lib/chms/church/reports/resource_config.ex` - 400 lines
2. `lib/chms/church/reports/query_builder.ex` - 300 lines
3. `lib/churchapp_web/live/admin/reports/index_live.ex` - 500+ lines
4. `lib/churchapp_web/components/report_components.ex` - 400 lines
5. `lib/chms/church/reports/export/csv_export.ex` - 100 lines

**Advanced Export (Phase 2):**
6. `lib/chms/church/reports/export/pdf_export.ex` - 200 lines

**Report Templates (Phase 3):**
7. `lib/chms/church/report_template.ex` - 150 lines
8. `priv/repo/migrations/[timestamp]_create_report_templates.exs` - Auto-generated

**Charts (Phase 4):**
9. `lib/churchapp_web/components/report_chart_components.ex` - 300 lines

**Advanced Features (Phase 5):**
10. `lib/churchapp_web/live/admin/reports/comparison_live.ex` - 400 lines

**Scheduled Reports (Phase 6):**
11. `lib/chms/church/report_schedule.ex` - 150 lines
12. `priv/repo/migrations/[timestamp]_create_report_schedules.exs` - Auto-generated
13. `lib/chms/workers/report_scheduler.ex` - 200 lines
14. `lib/chms/workers/check_schedules.ex` - 50 lines
15. `lib/churchapp_web/live/admin/reports/schedules_live.ex` - 300 lines

**Test Files (Phase 7):**
16. `test/churchapp_web/live/admin/reports/index_live_test.exs`
17. `test/churchapp_web/live/admin/reports/comparison_live_test.exs`
18. `test/churchapp_web/live/admin/reports/schedules_live_test.exs`
19. `test/chms/church/reports/query_builder_test.exs`
20. `test/chms/church/reports/export/csv_export_test.exs`
21. `test/chms/church/reports/export/pdf_export_test.exs`
22. `test/chms/workers/report_scheduler_test.exs`

### Modified Files (5 total)

23. `lib/churchapp_web/router.ex` - Add 3 routes
24. `lib/churchapp_web/components/layouts/app.html.heex` - Add menu links (desktop + mobile)
25. `assets/js/app.js` - Add download and print hooks
26. `assets/css/app.css` - Add print styles
27. `lib/chms/application.ex` - Add Oban configuration

### Dependencies (2 total)

28. `mix.exs` - Add `{:pdf_generator, "~> 0.6"}`
29. `mix.exs` - Add `{:oban, "~> 2.15"}`

---

## Implementation Strategy

### Recommended Approach: Phased Rollout

**Option 1: MVP First (Recommended)**
1. Implement Phase 1 (5-7 days)
2. Deploy and gather user feedback
3. Implement Phases 2-3 (4-6 days)
4. Deploy second version
5. Implement Phases 4-6 (7-11 days)
6. Final deployment with all features

**Benefits:**
- Early user validation
- Reduced risk
- Faster time to value
- Iterative improvement based on feedback

**Option 2: Full Implementation**
- Implement all phases sequentially (21-30 days)
- Single large deployment
- More comprehensive initial release

### Development Environment Setup

Before starting implementation:

1. **Install dependencies:**
   ```bash
   mix deps.get
   ```

2. **Ensure database is up to date:**
   ```bash
   mix ecto.migrate
   ```

3. **Test authentication:**
   - Log in as super_admin@church.org
   - Verify access to /admin routes

4. **Review existing patterns:**
   - Read `contributions/index_live.ex` for filtering patterns
   - Review `dashboard/index_live.ex` for chart integration
   - Check `calendar/index_live.ex` for FullCalendar usage

---

## Key Technical Decisions

### 1. Configuration Registry vs Behavior
**Chosen:** Configuration Registry
**Reason:** Easier to add resources (single file edit), better for non-developers, more maintainable

### 2. Query Building
**Chosen:** Dynamic Ash Query builder
**Reason:** Type-safe, follows codebase patterns, leverages Ash optimizations

### 3. Pagination Size
**Chosen:** 25 items per page
**Reason:** Reports need more data visible than CRUD pages

### 4. Export Strategy
**Chosen:** Server-side generation
**Reason:** Consistent with existing iCal pattern, handles large datasets better

### 5. Scheduling
**Chosen:** Oban job queue
**Reason:** Battle-tested, excellent error handling, built-in monitoring

---

## Performance Considerations

- **Pagination:** Always limit queries to prevent memory issues
- **Debouncing:** Text filters debounce at 300ms
- **Selective Preloads:** Only load relationships when needed
- **Query Optimization:** Leverage Ash's query optimization
- **Export Limits:** Consider max 10,000 rows for exports
- **Background Jobs:** Long-running reports should use background processing
- **Caching:** Consider caching frequently-run reports

---

## Security & Authorization

- **Route Protection:** All admin routes require `on_mount: :require_admin`
- **Actor Pattern:** Every Ash query passes `actor: current_user`
- **Role Checking:** Template resources check admin role
- **Query Authorization:** Ash policies enforce data access
- **SQL Injection:** Impossible with Ash query builder
- **Email Validation:** Validate recipient emails in schedules
- **Rate Limiting:** Consider rate limits on exports and schedules

---

## Extensibility

The system is designed for easy extension:

### Adding a New Resource
1. Edit one file (`resource_config.ex`)
2. Add configuration function
3. No UI changes needed

### Adding a New Filter Type
1. Add to `query_builder.ex`
2. Add handler in `apply_filter/4`
3. Available automatically

### Adding a New Export Format
1. Create new export module
2. Add to export menu
3. Update scheduler worker

### Adding a New Chart Type
1. Add component in `report_chart_components.ex`
2. Add data preparation function
3. Add to chart selector

---

## Success Criteria

### Phase 1 (MVP)
✅ Basic reports working for all 5 resources
✅ Filtering, sorting, pagination functional
✅ CSV export downloads correct data
✅ Authorization properly enforced
✅ Mobile responsive

### Phase 2 (Advanced Export)
✅ PDF export generates professional documents
✅ Print functionality works cleanly

### Phase 3 (Templates)
✅ Templates save and load correctly
✅ Sharing works between admins

### Phase 4 (Charts)
✅ Charts display appropriate visualizations
✅ Theme compatibility works

### Phase 5 (Advanced)
✅ Custom columns function properly
✅ Advanced filters produce correct results
✅ Aggregates calculate accurately
✅ Comparison shows meaningful differences

### Phase 6 (Scheduling)
✅ Schedules execute reliably
✅ Emails deliver successfully
✅ Schedule management UI intuitive

### Phase 7 (Quality)
✅ All tests pass
✅ Documentation complete
✅ No console errors
✅ Performance acceptable

---

## Maintenance & Support

### Monitoring
- Monitor Oban dashboard for job failures
- Track report generation times
- Monitor email delivery success rates
- Log export downloads for usage analytics

### Common Issues
- **Slow queries:** Add database indexes on frequently filtered fields
- **Large exports:** Implement streaming exports for very large datasets
- **Email failures:** Configure proper SMTP settings and retry logic
- **Memory issues:** Reduce pagination size or implement result streaming

### Future Enhancements
- **Excel export:** Add XLSX format support
- **Dashboard widgets:** Embed reports in dashboard
- **Report sharing:** Share reports with non-admin users
- **API access:** Expose reports via REST API
- **Multi-language:** i18n support for labels and messages
- **Custom SQL:** Allow advanced users to write custom queries
- **Audit trail:** Track who generated which reports

---

## Appendix: Code Examples

### Example: Adding a Families Resource

**Step 1:** Edit `lib/chms/church/reports/resource_config.ex`

```elixir
defp families_config do
  %{
    key: :families,
    name: "Families",
    module: Chms.Church.Families,
    domain_function: :list_families,
    icon: "hero-home",
    fields: [
      %{key: :family_name, label: "Family Name", type: :string, exportable: true},
      %{key: :head_of_household, label: "Head of Household", type: :string, exportable: true},
      %{key: :member_count, label: "Members", type: :integer, exportable: true},
      %{key: :created_at, label: "Created", type: :datetime, exportable: true}
    ],
    filters: [
      %{key: :search, label: "Search", type: :text,
        placeholder: "Search families...",
        query_builder: :text_search_filter, field: :family_name},
      %{key: :min_members, label: "Min Members", type: :number,
        query_builder: :number_range_filter, field: :member_count, operator: :gte}
    ],
    sortable_fields: [:family_name, :member_count, :created_at],
    default_sort: {:family_name, :asc},
    preloads: [:members],
    required_roles: [:admin, :super_admin]
  }
end

def all_resources do
  [
    congregants_config(),
    contributions_config(),
    ministry_funds_config(),
    week_ending_reports_config(),
    events_config(),
    families_config()  # Add here
  ]
end
```

**That's it!** The UI automatically adapts to show Families in the resource dropdown with all configured filters and fields.

---

## Conclusion

This implementation plan provides a comprehensive roadmap for building an enterprise-grade reporting system. The phased approach allows for iterative development and early user feedback while maintaining a clear path to full functionality.

The system's extensible architecture ensures that adding new resources and features remains straightforward, making it a sustainable long-term solution for the church's reporting needs.
