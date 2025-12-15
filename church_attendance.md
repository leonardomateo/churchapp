# Attendance Module Implementation Plan

## Overview

Build a full-featured Attendance Module with prepopulated categories (Services, Youth Class, Men Class, Women Class, Nursery Class, Baptism Class), user-creatable additional categories, flexible date/time picker for any day of the week, notes capability, and reporting features.

## Implementation Todos

| # | Task | Status | Dependencies |
|---|------|--------|--------------|
| 1 | Create AttendanceCategories, AttendanceSessions, AttendanceRecords Ash resources | pending | - |
| 2 | Add attendance resources to Chms.Church domain with code interfaces | pending | 1 |
| 3 | Generate and run database migrations for attendance tables | pending | 2 |
| 4 | Create seeds file with 6 prepopulated categories (Services, Youth, Men, Women, Nursery, Baptism) | pending | 3 |
| 5 | Create AttendanceCategorySelector component with search and color indicators | pending | 4 |
| 6 | Build admin LiveViews for category management with system category protection | pending | 5 |
| 7 | Create attendance index LiveView with session list and filters | pending | 6 |
| 8 | Build new/edit attendance LiveViews with any-day date picker and multi-select | pending | 7 |
| 9 | Create attendance show LiveView with details and notes | pending | 8 |
| 10 | Implement attendance reports LiveView with charts and CSV export | pending | 9 |
| 11 | Add routes to router and update navigation sidebar | pending | 10 |

## Architecture

```mermaid
erDiagram
    AttendanceCategories ||--o{ AttendanceSessions : has_many
    AttendanceSessions ||--o{ AttendanceRecords : has_many
    Congregants ||--o{ AttendanceRecords : has_many
    
    AttendanceCategories {
        uuid id PK
        string name
        string description
        string color
        boolean active
        boolean is_system
        integer display_order
        timestamps
    }
    
    AttendanceSessions {
        uuid id PK
        datetime session_datetime
        uuid category_id FK
        string notes
        integer total_present
        timestamps
    }
    
    AttendanceRecords {
        uuid id PK
        uuid session_id FK
        uuid congregant_id FK
        boolean present
        string notes
        timestamps
    }
```

## Prepopulated Categories (Seeds)

The following categories will be created via database seeds, allowing immediate use:

| Category | Color | Description |
|----------|-------|-------------|
| **Services** | `#06b6d4` (cyan) | General church services (any day) |
| **Youth Class** | `#8b5cf6` (purple) | Youth ministry classes |
| **Men Class** | `#3b82f6` (blue) | Men's ministry classes |
| **Women Class** | `#ec4899` (pink) | Women's ministry classes |
| **Nursery Class** | `#f59e0b` (amber) | Nursery/toddler care |
| **Baptism Class** | `#10b981` (emerald) | Baptism preparation classes |

These will have `is_system: true` flag to distinguish from user-created categories.
Users can still create unlimited additional categories via the web interface.

## Phase 1: Ash Resources

### 1.1 AttendanceCategories Resource

Create `lib/chms/church/attendance_categories.ex`:

- **Attributes**: name, description, color (hex), active, is_system (boolean), display_order
- **Actions**: create, read, update, deactivate, destroy, list_active
- **Validation**: Prevent deletion of system categories (soft delete only)
- **Policy**: Admin/Staff can manage, all authenticated users can read

### 1.2 AttendanceSessions Resource

Create `lib/chms/church/attendance_sessions.ex`:

- **Attributes**: session_datetime (utc_datetime - supports ANY day of week), notes, total_present
- **Relationships**: belongs_to category, has_many records
- **Actions**: create, read, update, destroy, list_by_date_range, list_by_category
- **Note**: The datetime picker allows selecting any day (Monday-Sunday) for services

### 1.3 AttendanceRecords Resource

Create `lib/chms/church/attendance_records.ex`:

- **Attributes**: present (boolean), notes
- **Relationships**: belongs_to session, belongs_to congregant
- **Actions**: create, read, update, destroy, bulk_create
- **Constraint**: Unique on session_id + congregant_id

### 1.4 Update Domain

Add resources and code interfaces to `lib/chms/church.ex`

## Phase 2: Database & Seeds

### 2.1 Migrations

Run `mix ash.codegen create_attendance_module` to generate:

- attendance_categories table
- attendance_sessions table  
- attendance_records table with foreign keys

### 2.2 Seeds File

Create `priv/repo/seeds/attendance_categories.exs`:

```elixir
# Prepopulated attendance categories
categories = [
  %{name: "Services", color: "#06b6d4", description: "General church services", is_system: true, display_order: 1},
  %{name: "Youth Class", color: "#8b5cf6", description: "Youth ministry classes", is_system: true, display_order: 2},
  %{name: "Men Class", color: "#3b82f6", description: "Men's ministry classes", is_system: true, display_order: 3},
  %{name: "Women Class", color: "#ec4899", description: "Women's ministry classes", is_system: true, display_order: 4},
  %{name: "Nursery Class", color: "#f59e0b", description: "Nursery and toddler care", is_system: true, display_order: 5},
  %{name: "Baptism Class", color: "#10b981", description: "Baptism preparation classes", is_system: true, display_order: 6}
]
```

## Phase 3: LiveView UI Components

### 3.1 Category Selector Component

Create `lib/churchapp_web/components/attendance_category_selector.ex`:

- Searchable dropdown with color indicators
- Shows prepopulated + user-created categories
- Option to create new category inline (modal)

### 3.2 Attendance Categories Management (Admin)

- `lib/churchapp_web/live/attendance_categories/index_live.ex` - List all categories with system badge
- `lib/churchapp_web/live/attendance_categories/new_live.ex` - Create new category
- `lib/churchapp_web/live/attendance_categories/edit_live.ex` - Edit category (restrict system category deletion)

### 3.3 Attendance Recording UI

- `lib/churchapp_web/live/attendance/index_live.ex` - List sessions with category/date filters
- `lib/churchapp_web/live/attendance/new_live.ex` - Create session with:
  - **Date/Time Picker** - Any day of the week (Mon-Sun)
  - **Category Selector** - Search prepopulated + custom categories
  - **Congregant Multi-Select** - Mark attendance
  - **Notes Field** - Session-level notes
- `lib/churchapp_web/live/attendance/show_live.ex` - View details
- `lib/churchapp_web/live/attendance/edit_live.ex` - Modify attendance

### 3.4 Reporting UI

Create `lib/churchapp_web/live/attendance/reports_live.ex`:

- Date range filter (any days)
- Category filter (all or specific)
- Statistics: total sessions, average attendance, trends
- Export to CSV
- Visual charts

## Phase 4: Routes

Add to `lib/churchapp_web/router.ex`:

```elixir
# In authenticated live_session
live "/attendance", AttendanceLive.IndexLive, :index
live "/attendance/new", AttendanceLive.NewLive, :new
live "/attendance/reports", AttendanceLive.ReportsLive, :reports
live "/attendance/:id", AttendanceLive.ShowLive, :show
live "/attendance/:id/edit", AttendanceLive.EditLive, :edit

# In admin live_session
live "/attendance-categories", AttendanceCategoriesLive.IndexLive, :index
live "/attendance-categories/new", AttendanceCategoriesLive.NewLive, :new
live "/attendance-categories/:id/edit", AttendanceCategoriesLive.EditLive, :edit
```

## Phase 5: Navigation & Theme

Update `lib/churchapp_web/components/layouts/app.html.heex`:

- Add "Attendance" link in main navigation
- Add "Attendance Categories" in admin section

All UI follows existing dark/light theme from `assets/css/app.css`.

## Key Features Summary

| Feature | Implementation |
|---------|---------------|
| **Prepopulated Categories** | 6 system categories seeded on deploy |
| **Custom Categories** | Users can create unlimited additional categories |
| **Any Day Support** | Date/time picker allows Mon-Sun selection |
| **Services Tracking** | "Services" category for general church services |
| **Class Tracking** | Dedicated categories for each class type |
| **Notes** | Session-level and individual record notes |
| **Reports** | Filter by date range, category, export CSV |

