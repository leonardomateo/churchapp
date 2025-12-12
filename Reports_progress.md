# Reporting Module Implementation Progress

This document tracks the implementation progress of the Church Management System reporting module.

## PHASE 1: Core Infrastructure & Basic Reporting ✅ COMPLETED

**Duration:** Implemented
**Deliverable:** Basic reports with CSV export

### Completed Items

- [x] **Step 1.1: Resource Configuration Module** (`lib/chms/church/reports/resource_config.ex`)
  - Created configuration registry with 5 resource definitions:
    - Congregants (with member_id, name, status, contact info, location filters)
    - Contributions (with type, amount, date, contributor filters)
    - Ministry Funds (with ministry name, transaction type, amount, date filters)
    - Week Ending Reports (with report name, date range filters)
    - Events (with title, location, dates, recurring status filters)
  - Each resource includes fields, filters, sortable columns, preloads, and role permissions
  - Extensible design - adding new resources only requires editing this one file

- [x] **Step 1.2: Query Builder Module** (`lib/chms/church/reports/query_builder.ex`)
  - Dynamic Ash query construction with filter application
  - Implemented 11 filter types:
    - `:search_filter` - Multi-mode search for congregants (member ID, name)
    - `:contribution_search_filter` - Search in type and contributor name
    - `:ministry_search_filter` - Search in ministry name and notes
    - `:event_search_filter` - Search in event title and location
    - `:text_search_filter` - Generic text search with contains
    - `:enum_filter` - Enum field filtering (status, gender, etc.)
    - `:string_filter` - Exact string matching
    - `:boolean_filter` - Boolean field filtering
    - `:date_range_filter` - Date range with >= and <=
    - `:datetime_range_filter` - Datetime range with start/end of day conversion
    - `:number_range_filter` - Numeric range with Decimal support
  - Sorting with validation against sortable fields
  - Pagination with offset/limit and metadata (total count, pages)

- [x] **Step 1.3: Reports LiveView** (`lib/churchapp_web/live/admin/reports/index_live.ex`)
  - Main reporting interface with complete state management
  - Event handlers for:
    - Resource selection
    - Filter updates (with debounce for text inputs)
    - Sorting (toggle asc/desc)
    - Pagination
    - Report generation
    - CSV export
    - Clear filters
  - Deep linking support via `handle_params/3` - shareable URLs with filters
  - Always passes `actor: current_user` to all Ash operations
  - Loading states and error handling
  - Admin-only access with `require_admin` mount hook

- [x] **Step 1.4: Report UI Components** (`lib/churchapp_web/components/report_components.ex`)
  - Resource selector dropdown
  - Dynamic filters panel with polymorphic filter inputs:
    - Text inputs with 300ms debounce
    - Select dropdowns with formatted options
    - Date inputs with DatePicker hook for auto-hide
    - Number inputs with decimal support
    - Boolean checkboxes
  - Results table with sortable headers and visual sort indicators
  - Field value formatter supporting:
    - Currency ($XX.XX format)
    - DateTime (YYYY-MM-DD HH:MM:SS)
    - Date (YYYY-MM-DD)
    - Boolean (Yes/No)
    - Arrays (semicolon-separated)
    - Atoms (capitalized, spaces)
    - Computed fields (e.g., congregant names for contributions)
  - Pagination component with ellipsis for large page counts
  - Loading spinner
  - Active filters display
  - Dark/light theme compatible styling

- [x] **Step 1.5: CSV Export Module** (`lib/chms/church/reports/export/csv_export.ex`)
  - Generates CSV files from report results
  - Filters to exportable fields only
  - Header row with field labels
  - Proper CSV escaping (quotes, commas, newlines)
  - Value formatting by type (currency, dates, booleans, etc.)
  - Handles computed fields (e.g., contributor names)

- [x] **Step 1.6: Client-side Download Hook** (`assets/js/app.js`)
  - Added `ReportDownload` hook for generic file downloads
  - Supports multiple MIME types (CSV, PDF ready for Phase 2)
  - Creates blob, triggers download, and cleans up URL
  - Registered in LiveSocket hooks

- [x] **Step 1.7: Router Integration** (`lib/churchapp_web/router.ex`)
  - Added route: `live("/reports", Admin.ReportsLive.IndexLive, :index)`
  - Placed in admin scope with `require_admin` mount hook
  - URL: `/admin/reports`

- [x] **Step 1.8: Navigation Menu Integration** (`lib/churchapp_web/components/layouts/app.html.heex`)
  - Added "Reports" link in Administration section
  - Present in both desktop and mobile sidebars
  - Shows for admin and super_admin roles only
  - Uses `hero-chart-bar-square` icon
  - Active state highlighting when on reports page

### Phase 1 Features Summary

✅ **Working Features:**
- Admin-only access to reports
- 5 reportable resources (Congregants, Contributions, Ministry Funds, Week Ending Reports, Events)
- Dynamic resource selection
- Context-sensitive filters per resource (11 filter types)
- Real-time filter application with debounce
- Sortable columns with visual indicators
- Pagination with metadata
- CSV export with proper formatting
- Deep linking (shareable filtered report URLs)
- Dark/light theme support
- Mobile responsive design
- Loading states
- Empty states
- Error handling

### Files Created (8 new files)

1. `lib/chms/church/reports/resource_config.ex` (398 lines)
2. `lib/chms/church/reports/query_builder.ex` (331 lines)
3. `lib/churchapp_web/live/admin/reports/index_live.ex` (408 lines)
4. `lib/churchapp_web/components/report_components.ex` (372 lines)
5. `lib/chms/church/reports/export/csv_export.ex` (101 lines)
6. `assets/js/app.js` (added ReportDownload hook - ~15 lines)
7. `lib/churchapp_web/router.ex` (added 1 route)
8. `lib/churchapp_web/components/layouts/app.html.heex` (added navigation links - ~24 lines)

### Files Modified (3 files)

1. `assets/js/app.js` - Added ReportDownload hook and registered it
2. `lib/churchapp_web/router.ex` - Added reports route
3. `lib/churchapp_web/components/layouts/app.html.heex` - Added navigation links

### Phase 1 Testing Checklist

Test these items to verify Phase 1 implementation:

- [ ] Only admin/super_admin can access /admin/reports
- [ ] Resource dropdown shows all 5 resources
- [ ] Selecting resource displays correct filters for that resource
- [ ] Text filters apply correctly with debounce
- [ ] Select filters apply correctly
- [ ] Date filters apply correctly
- [ ] Date pickers auto-hide after selection
- [ ] Sorting toggles asc/desc with visual indicator
- [ ] Pagination works with ellipsis for large datasets
- [ ] Clear filters resets all values and refreshes results
- [ ] CSV export downloads with correct data and formatting
- [ ] CSV export handles special characters (quotes, commas, newlines)
- [ ] Dark/light theme works correctly
- [ ] Mobile responsive layout works
- [ ] Deep linking works (copy URL with filters, paste in new tab)
- [ ] Loading states display during query execution
- [ ] Empty states show appropriate messages
- [ ] Navigation links highlight correctly when on reports page

### Known Limitations (to be addressed in future phases)

- No PDF export (Phase 2)
- No print functionality (Phase 2)
- No report templates/saved configurations (Phase 3)
- No chart visualizations (Phase 4)
- No custom column selection (Phase 5)
- No advanced filter logic (AND/OR groups) (Phase 5)
- No aggregate functions (Phase 5)
- No comparison reports (Phase 5)
- No scheduled reports (Phase 6)

---

## PHASE 2: Advanced Export & Print ✅ COMPLETED

**Duration:** Implemented
**Deliverable:** PDF export and print functionality

### Completed Items

- [x] **Step 2.1: PDF Export Implementation** (`lib/chms/church/reports/export/pdf_export.ex`)
  - Created PDF export module with professional HTML template generation
  - Uses `pdf_generator` library (requires wkhtmltopdf system dependency)
  - Graceful fallback to browser print-to-PDF when wkhtmltopdf is not available
  - Features:
    - Professional report header with title, subtitle, and generation date
    - Filter summary section showing applied filters
    - Data table with styled headers and alternating row colors
    - Footer with generation timestamp
    - Landscape A4 page orientation
    - Print-optimized CSS with proper page breaks

- [x] **Step 2.2: Print Functionality** (`lib/churchapp_web/live/admin/reports/index_live.ex`)
  - Added `handle_event("print_report", ...)` event handler
  - Opens print-ready HTML in new browser window
  - Automatically triggers browser print dialog
  - Window closes after printing

- [x] **Step 2.3: Print Styles** (`assets/css/app.css`)
  - Added `@media print` styles for reports
  - Hides navigation, buttons, and filters during print
  - Forces white background and proper table styling
  - Landscape page orientation

- [x] **Step 2.4: Update Export Menu** (`lib/churchapp_web/live/admin/reports/index_live.ex`)
  - Export dropdown now includes:
    - "Export as CSV" (existing)
    - "Export as PDF" (new)
    - "Print Report" (new)
  - Visual separator between export and print options

- [x] **Step 2.5: Enhanced ReportDownload Hook** (`assets/js/app.js`)
  - Extended hook to handle base64-encoded PDF binary downloads
  - Added `print_report` event handler for browser printing
  - Opens new window with print-ready HTML
  - Automatic print dialog and window cleanup

### Phase 2 Features Summary

✅ **Working Features:**
- PDF export with professional formatting
- Print functionality via browser
- Filter summary in exports
- Total record count in exports
- Professional report header and footer
- Proper HTML escaping in exports
- Graceful fallback when wkhtmltopdf not installed
- Dark/light theme compatible export menu

### Files Created (1 new file)

1. `lib/chms/church/reports/export/pdf_export.ex` (400 lines)

### Files Modified (3 files)

1. `mix.exs` - Added `{:pdf_generator, "~> 0.6"}` dependency
2. `lib/churchapp_web/live/admin/reports/index_live.ex` - Added PDF export and print handlers, updated export menu
3. `assets/js/app.js` - Extended ReportDownload hook with base64 and print support
4. `assets/css/app.css` - Added reports print styles

### Phase 2 Testing Checklist

Test these items to verify Phase 2 implementation:

- [ ] PDF export generates properly formatted document (if wkhtmltopdf installed)
- [ ] PDF export falls back to browser print-to-PDF (if wkhtmltopdf not installed)
- [ ] PDF includes report header and title
- [ ] PDF shows filter summary when filters applied
- [ ] PDF tables have proper formatting
- [ ] Print opens browser print dialog
- [ ] Print view shows clean, professional layout
- [ ] Export menu shows all three options (CSV, PDF, Print)
- [ ] Export menu styling works in dark/light themes

### Dependencies Added

- `pdf_generator ~> 0.6` - Requires wkhtmltopdf to be installed on the system
  - Optional: Without wkhtmltopdf, PDF export falls back to browser print-to-PDF

---

## PHASE 3: Report Templates ✅ COMPLETED

**Duration:** Implemented
**Deliverable:** Save/load report configurations

### Completed Items

- [x] **Step 3.1: Create ReportTemplate Resource** (`lib/chms/church/report_template.ex`)
  - Created Ash resource for storing report templates
  - Attributes:
    - `name` - Template name (required, max 100 chars)
    - `description` - Optional description (max 500 chars)
    - `resource_key` - Atom identifying the resource type
    - `filter_params` - Map storing filter values
    - `sort_by` - Sort field atom
    - `sort_dir` - Sort direction (:asc or :desc)
    - `is_shared` - Boolean for sharing with all admins
    - `created_by_id` - Reference to creator (User)
  - Actions:
    - `create` - Create new template with creator relationship
    - `update` - Update template properties
    - `read` - Standard read
    - `destroy` - Delete template
    - `list_for_resource` - Filter templates by resource_key
    - `list_visible` - Get templates visible to user (owned or shared)
  - Policies:
    - Super admins bypass all policies
    - Admins can create templates
    - Admins/staff/leaders can read templates
    - Update/destroy limited to owners or super_admin
  - Unique identity on (name, created_by_id, resource_key)

- [x] **Step 3.2: Generate Migration** (`priv/repo/migrations/[timestamp]_create_report_templates.exs`)
  - Created table with all attributes
  - Foreign key to users table
  - Unique index for preventing duplicate names per user per resource

- [x] **Step 3.3: Add to Church Domain** (`lib/chms/church.ex`)
  - Added ReportTemplate resource to domain
  - Defined domain-level functions:
    - `create_report_template/2`
    - `list_report_templates/1`
    - `list_report_templates_for_resource/2`
    - `list_visible_report_templates/3`
    - `update_report_template/3`
    - `destroy_report_template/2`
    - `get_report_template_by_id/2`

- [x] **Step 3.4: Add Template Management to Reports LiveView** (`lib/churchapp_web/live/admin/reports/index_live.ex`)
  - Added template-related assigns:
    - `:templates` - List of templates for current resource
    - `:show_save_template_modal` - Modal visibility
    - `:show_manage_templates_modal` - Manage modal visibility
    - `:template_form` - Form data for save/edit
    - `:editing_template_id` - ID of template being edited
  - Added event handlers:
    - `show_save_template_modal` - Opens save template modal
    - `close_save_template_modal` - Closes save modal
    - `show_manage_templates` - Opens manage templates modal
    - `close_manage_templates` - Closes manage modal
    - `save_template` - Creates new template with current filters
    - `load_template` - Applies template filters to report
    - `edit_template` - Opens edit form for template
    - `update_template` - Updates existing template
    - `delete_template` - Deletes template with ownership check
    - `toggle_template_share` - Toggles is_shared flag
  - Helper functions:
    - `load_templates/2` - Loads visible templates for resource
    - `build_template_form/2` - Builds form for new template
    - `build_template_form_for_edit/1` - Builds form from existing template
    - `apply_template_filters/2` - Applies template settings to socket
  - Templates auto-load when resource is selected

- [x] **Step 3.5: Create Template UI Components** (`lib/churchapp_web/components/report_components.ex`)
  - `template_selector/1` - Dropdown for quick template loading
  - `save_template_modal/1` - Modal for creating/editing templates
    - Name input (required)
    - Description textarea (optional)
    - Share with admins checkbox
    - Info box explaining what gets saved
    - Cancel and Save/Update buttons
  - `manage_templates_modal/1` - Modal for viewing all templates
    - Lists all visible templates
    - Empty state when no templates
  - `template_card/1` - Individual template display
    - Shows name with shared/private badge
    - Optional description
    - Creation date and ownership info
    - Action buttons: Load, Edit, Share Toggle, Delete
    - Owner-only actions for edit/delete/share
  - Updated render to include:
    - Template selector dropdown (when templates exist)
    - Save Template button
    - Manage Templates button (when templates exist)
    - Both modals with conditional rendering

### Phase 3 Features Summary

✅ **Working Features:**
- Save current report configuration as template
- Templates store filters, sort field, and sort direction
- Private templates (visible only to creator)
- Shared templates (visible to all admins)
- Quick-load template from dropdown
- Full template management (create, edit, delete)
- Toggle sharing on/off
- Ownership-based permissions (only owner can edit/delete)
- Super admin can modify any template
- Templates automatically loaded when resource selected
- Unique constraint prevents duplicate names per user per resource

### Files Created (2 new files)

1. `lib/chms/church/report_template.ex` (~120 lines)
2. `priv/repo/migrations/20251212021152_create_report_templates.exs` (auto-generated)

### Files Modified (3 files)

1. `lib/chms/church.ex` - Added ReportTemplate resource and domain functions
2. `lib/churchapp_web/live/admin/reports/index_live.ex` - Added template management logic and UI
3. `lib/churchapp_web/components/report_components.ex` - Added template UI components (~280 lines)

### Phase 3 Testing Checklist

Test these items to verify Phase 3 implementation:

- [ ] Save Template button appears when resource is selected
- [ ] Save template modal opens with empty form
- [ ] Template name is required
- [ ] Template saves successfully with current filters
- [ ] Saved template appears in dropdown
- [ ] Loading template applies filters correctly
- [ ] Loading template generates report automatically
- [ ] Manage Templates modal shows all templates
- [ ] Template cards show shared/private status
- [ ] Edit template loads existing values
- [ ] Update template saves changes
- [ ] Delete template removes with confirmation
- [ ] Toggle share changes visibility status
- [ ] Shared templates visible to other admins
- [ ] Non-shared templates only visible to creator
- [ ] Owner-only actions hidden for non-owners
- [ ] Super admin can modify any template

---

## PHASE 4: Charts & Visualizations ✅ COMPLETED

**Duration:** Implemented
**Deliverable:** Chart view with multiple visualization types

### Completed Items

- [x] **Step 4.1: Add Chart View to Reports LiveView** (`lib/churchapp_web/live/admin/reports/index_live.ex`)
  - Added chart-related assigns to state:
    - `:view_mode` - Toggle between :table and :chart views
    - `:selected_chart` - Currently selected chart type
    - `:chart_data` - Processed data for charts
    - `:chart_data_json` - JSON-encoded chart data for JavaScript hooks
  - Added event handlers:
    - `toggle_view` - Switch between table and chart views
    - `select_chart` - Change the selected chart type
  - Added helper functions:
    - `has_charts?/1` - Check if resource has chart configurations
    - `maybe_prepare_chart_data/1` - Conditionally prepare chart data
    - `prepare_chart_data/1` - Process results into chart format
    - `aggregate_chart_data/2` - Group and aggregate data based on chart config
    - `format_group_label/1` - Format labels for chart display

- [x] **Step 4.2: Add Chart Configurations to ResourceConfig** (`lib/chms/church/reports/resource_config.ex`)
  - Added chart configurations for all 5 resources:

  **Congregants Charts:**
  - Status Distribution (pie) - Distribution by status
  - Gender Distribution (doughnut) - Distribution by gender
  - By Country (bar) - Grouped by country
  - By State (horizontal bar) - Grouped by state
  - By City (horizontal bar) - Grouped by city
  - Leaders vs Non-Leaders (pie) - Proportion of leaders

  **Contributions Charts:**
  - By Type (pie) - Distribution by contribution type
  - Revenue by Type (bar) - Total revenue per type (sum aggregate)
  - Monthly Revenue (bar) - Revenue by month (sum aggregate)

  **Ministry Funds Charts:**
  - Revenue vs Expense (pie) - Transaction type distribution
  - By Ministry (horizontal bar) - Transaction count per ministry
  - Amount by Ministry (horizontal bar) - Sum of amounts per ministry
  - Amount by Type (doughnut) - Sum by transaction type

  **Week Ending Reports Charts:**
  - Weekly Totals (bar) - Grand totals by week

  **Events Charts:**
  - All Day vs Timed (pie) - All-day event distribution
  - Recurring vs One-Time (doughnut) - Recurring status distribution
  - By Location (horizontal bar) - Events per location
  - Events by Month (bar) - Monthly event count

- [x] **Step 4.3: Create Chart Components Module** (`lib/churchapp_web/components/report_chart_components.ex`)
  - Created comprehensive chart components:
    - `view_mode_toggle/1` - Toggle buttons for Table/Chart view
    - `chart_selector/1` - Dropdown to select chart type
    - `chart_display/1` - Canvas container with correct hook (PieChart, DoughnutChart, BarChart)
    - `chart_stats/1` - Summary statistics panel (total, categories, largest item)
    - `empty_chart_state/1` - Empty state when no data
    - `chart_view/1` - Complete chart view container
  - Components leverage existing Chart.js hooks from dashboard
  - Supports currency formatting, horizontal bars, tooltips

- [x] **Step 4.4: Update Reports LiveView Render** (`lib/churchapp_web/live/admin/reports/index_live.ex`)
  - Added view mode toggle in actions bar (only shows when charts available)
  - Conditional rendering based on view_mode:
    - `:table` - Shows results table with pagination
    - `:chart` - Shows chart view with selector and visualization
  - Charts update automatically when filters change

### Phase 4 Features Summary

✅ **Working Features:**
- Toggle between table and chart views
- Multiple chart types per resource (pie, doughnut, bar)
- Horizontal bar chart support
- Currency formatting in charts
- Chart selector dropdown for switching chart types
- Summary statistics panel (total, categories, largest)
- Automatic chart data preparation from query results
- Support for count aggregation (default)
- Support for sum aggregation (for currency fields)
- Support for average aggregation
- Special grouping for datetime fields (monthly grouping)
- Label formatting for atoms, booleans, strings
- Dark/light theme compatibility via existing hooks
- Empty state handling
- Maximum 20 categories displayed (top values)

### Files Created (1 new file)

1. `lib/churchapp_web/components/report_chart_components.ex` (~260 lines)

### Files Modified (2 files)

1. `lib/chms/church/reports/resource_config.ex` - Added chart configurations for all 5 resources (~160 lines added)
2. `lib/churchapp_web/live/admin/reports/index_live.ex` - Added chart state, events, helpers, and render updates (~150 lines added)

### Phase 4 Testing Checklist

Test these items to verify Phase 4 implementation:

- [ ] Toggle between table and chart view works
- [ ] Charts display correct data
- [ ] Chart colors work in dark/light mode
- [ ] Chart selector shows available chart types
- [ ] Pie charts show percentages in tooltips
- [ ] Bar charts show proper labels and values
- [ ] Horizontal bar charts display correctly
- [ ] Currency values display with $ symbol
- [ ] Charts update when filters change
- [ ] Empty data shows appropriate message
- [ ] Summary statistics show correct values
- [ ] Monthly grouping works for datetime fields

### Chart Types by Resource

| Resource | Chart Types Available |
|----------|----------------------|
| Congregants | 6 charts (pie, doughnut, bar, horizontal bar) |
| Contributions | 3 charts (pie, bar with sum aggregation) |
| Ministry Funds | 4 charts (pie, doughnut, horizontal bar) |
| Week Ending Reports | 1 chart (bar with sum aggregation) |
| Events | 4 charts (pie, doughnut, bar, horizontal bar) |

---

## PHASE 5: Advanced Features ✅ COMPLETED

**Duration:** Implemented
**Deliverable:** Custom columns, aggregates, comparison reports

### Completed Items

- [x] **Phase 5.1: Custom Column Selection** (`lib/churchapp_web/live/admin/reports/index_live.ex`, `lib/churchapp_web/components/report_components.ex`)
  - Added column selection modal to show/hide columns
  - State management for visible columns
  - Event handlers:
    - `show_column_modal` - Opens column selection modal
    - `close_column_modal` - Closes modal
    - `toggle_column` - Toggles individual column visibility
    - `reset_columns` - Resets to default exportable columns
    - `select_all_columns` - Shows all columns
    - `deselect_all_columns` - Hides all columns
  - Columns button shows count of visible columns
  - Field type labels in column modal
  - Sortable field indicators
  - Column order preserved based on resource config

- [x] **Phase 5.3: Aggregate Functions** (`lib/churchapp_web/live/admin/reports/index_live.ex`, `lib/churchapp_web/components/report_components.ex`)
  - Added aggregates toggle button in actions bar
  - State management for aggregate visibility and data
  - Automatic aggregate calculation when enabled
  - Aggregates for numeric fields (currency, integer, decimal, float):
    - Sum
    - Average
    - Minimum
    - Maximum
    - Count
  - Aggregates for non-numeric fields:
    - Count
    - Unique count
  - Aggregates displayed in table footer row
  - Aggregates recalculate when columns change
  - Currency formatting for monetary aggregates

- [x] **Phase 5.4: Comparison Reports** (`lib/churchapp_web/live/admin/reports/comparison_live.ex`)
  - New LiveView for period-over-period comparison
  - Route: `/admin/reports/comparison`
  - Features:
    - Select two date ranges for comparison
    - Quick preset buttons:
      - This vs Last Month
      - This vs Last Quarter
      - This vs Last Year
      - YTD Comparison
    - Summary cards showing record counts and changes
    - Detailed field comparisons table for numeric fields
    - Color-coded differences (green for increase, red for decrease)
    - Percentage change calculations
    - Trend indicators (arrows up/down)
  - Link to comparison reports from main reports page

### Phase 5 Features Summary

✅ **Working Features:**
- Custom column selection with modal UI
- Select/deselect all columns
- Reset to default columns
- Column count indicator
- Aggregate functions toggle
- Sum, average, min, max for numeric fields
- Count and unique count for all fields
- Aggregates in table footer
- Period comparison reports
- Preset date range buttons
- Field-by-field comparisons
- Percentage change calculations
- Visual change indicators

### Files Created (1 new file)

1. `lib/churchapp_web/live/admin/reports/comparison_live.ex` (~600 lines)

### Files Modified (3 files)

1. `lib/churchapp_web/live/admin/reports/index_live.ex` - Added column selection, aggregates, link to comparison (~200 lines added)
2. `lib/churchapp_web/components/report_components.ex` - Added column modal, aggregates row (~200 lines added)
3. `lib/churchapp_web/router.ex` - Added comparison route

### Phase 5 Testing Checklist

Test these items to verify Phase 5 implementation:

- [ ] Columns button shows column count
- [ ] Column selection modal opens and closes
- [ ] Toggle individual columns shows/hides them in table
- [ ] Select All shows all columns
- [ ] Deselect All hides all columns
- [ ] Reset to Default restores exportable columns
- [ ] Aggregates button appears when results exist
- [ ] Aggregates toggle shows/hides footer row
- [ ] Numeric fields show sum, avg, min, max
- [ ] Non-numeric fields show count, unique count
- [ ] Currency aggregates display with $ symbol
- [ ] Comparison Reports link navigates correctly
- [ ] Resource selection works in comparison view
- [ ] Period 1 and Period 2 date inputs work
- [ ] Preset buttons populate dates correctly
- [ ] Generate Comparison fetches and calculates data
- [ ] Summary cards show record counts
- [ ] Field comparisons table shows differences
- [ ] Green/red colors indicate increase/decrease
- [ ] Percentage changes calculate correctly

### Implementation Notes

**Phase 5.2 (Advanced Filter Logic AND/OR) was deferred** - The existing filter implementation handles most use cases. Advanced filter groups with AND/OR logic can be added in a future iteration if needed.

---

## PHASE 6: Scheduled Reports ⏳ NOT STARTED

**Duration:** 3-4 days (estimated)
**Deliverable:** Automated report generation and email delivery

---

## PHASE 7: Testing & Documentation ⏳ NOT STARTED

**Duration:** 2-3 days (estimated)
**Deliverable:** Comprehensive test coverage and updated documentation

---

## Summary

**Phase 1 Status:** ✅ COMPLETED
**Phase 2 Status:** ✅ COMPLETED
**Phase 3 Status:** ✅ COMPLETED
**Phase 4 Status:** ✅ COMPLETED
**Phase 5 Status:** ✅ COMPLETED
**Total Progress:** 5/7 phases (71%)
**Next Phase:** Phase 6 - Scheduled Reports

Phases 1-5 deliver a comprehensive reporting system with export capabilities, template management, data visualizations, and advanced features. Users can now:
- Select from 5 different resource types
- Apply context-sensitive filters
- Sort and paginate results
- Export to CSV format
- Export to PDF format (with wkhtmltopdf) or print-to-PDF via browser
- Print reports directly
- Share filtered reports via URL
- Save report configurations as reusable templates
- Share templates with other admins
- Quickly load templates to reproduce reports
- Manage saved templates (edit, delete, toggle sharing)
- Toggle between table and chart views
- Visualize data with pie, doughnut, and bar charts
- View aggregated data (counts, sums, averages)
- See summary statistics for chart data
- **Select which columns to display in the report**
- **View aggregate statistics (sum, avg, min, max) in table footer**
- **Compare data between two time periods**
- **Use preset date ranges for quick comparisons**
- **See color-coded change indicators and percentages**

The foundation is solid and extensible, making it easy to add new resources and continue with scheduled reports in subsequent phases.
