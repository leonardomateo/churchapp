# Family Relationship Feature Plan

## Overview
Create a family relationship feature allowing congregants to be linked to other congregants through defined relationship types (father, mother, brother, sister, son, daughter, spouse, etc.). Relationships are bidirectional and managed through a lookup table with admin CRUD capabilities.

---

## Phase 1: Database Schema & Ash Resources

### Step 1.1: Create FamilyRelationshipTypes Resource (Lookup Table)
- Create new Ash resource `Chms.Church.FamilyRelationshipTypes`
- Attributes:
  - `id` (UUID primary key)
  - `name` (string, unique identifier - e.g., "father")
  - `display_name` (string - e.g., "Father")
  - `inverse_name` (string - references the inverse relationship type name, e.g., "son" is inverse of "father")
  - `sort_order` (integer, default 0)
  - `is_active` (boolean, default true - soft delete)
  - Timestamps
- Actions: create, read, update, destroy, list_active
- Policies: super_admin bypass, read for admin/staff, write for admin only

### Step 1.2: Create FamilyRelationship Resource (Junction Table)
- Create new Ash resource `Chms.Church.FamilyRelationship`
- Attributes:
  - `id` (UUID primary key)
  - Timestamps
- Relationships:
  - `belongs_to :congregant` (the source congregant)
  - `belongs_to :related_congregant` (the related congregant)
  - `belongs_to :family_relationship_type` (the type of relationship)
- Identity: unique constraint on (congregant_id, related_congregant_id, family_relationship_type_id)
- Actions: create, read, destroy (no update - delete and recreate)
- Policies: Follow Congregants resource pattern

### Step 1.3: Update Domain Definition
- Add both resources to `Chms.Church` domain
- Define convenience functions for both resources

### Step 1.4: Update Congregants Resource
- Add relationship: `has_many :family_relationships` through FamilyRelationship

### Step 1.5: Generate and Run Migration
- Run `mix ash.codegen --name add_family_relationships`
- Review generated migration
- Run `mix ecto.migrate` or `mix ash.reset`

---

## Phase 2: Seed Default Family Relationship Types

### Step 2.1: Define Default Family Relationship Types
Create seeds for common family relationship types with inverses:
- Father / Son or Daughter
- Mother / Son or Daughter
- Spouse / Spouse (self-inverse)
- Brother / Brother or Sister
- Sister / Brother or Sister
- Son / Father or Mother
- Daughter / Father or Mother
- Grandfather / Grandson or Granddaughter
- Grandmother / Grandson or Granddaughter
- Uncle / Nephew or Niece
- Aunt / Nephew or Niece
- Cousin / Cousin (self-inverse)

### Step 2.2: Add to seeds.exs
- Add family relationship types seeding logic to `priv/repo/seeds.exs`
- Ensure idempotent seeding (skip if already exists)

---

## Phase 3: Admin CRUD for Family Relationship Types

### Step 3.1: Create Admin LiveViews
- `FamilyRelationshipTypesLive.IndexLive` - List, search, delete with confirmation
- `FamilyRelationshipTypesLive.NewLive` - Create form
- `FamilyRelationshipTypesLive.EditLive` - Update form
- Location: `lib/churchapp_web/live/family_relationship_types/`

### Step 3.2: Add Admin Routes
- Add routes under `/admin` scope in router:
  - `/admin/family-relationship-types` (index)
  - `/admin/family-relationship-types/new` (create)
  - `/admin/family-relationship-types/:id/edit` (edit)

### Step 3.3: UI Features
- Search functionality
- Sort by display_name or sort_order
- Inverse relationship selection dropdown
- Active/inactive toggle
- Delete confirmation modal
- Follow existing admin UI patterns (dark theme)

---

## Phase 4: Family Relationship Selector Component

### Step 4.1: Create FamilyRelationshipSelector Component
- Create `lib/churchapp_web/components/family_relationship_selector.ex`
- Follow MinistrySelector pattern for multi-select mode
- Features:
  - Dropdown with search/filter capability
  - Two-step selection: first select family relationship type, then select related congregant
  - Display selected relationships as removable tags
  - Support adding multiple relationships

### Step 4.2: Component Structure
- Props: `relationships` (current relationships), `family_relationship_types`, `congregants`, `field`, `actor`
- State: `selected_relationships`, `show_add_modal`, `selected_type`, `search_query`
- Events: `add_relationship`, `remove_relationship`, `select_type`, `select_congregant`, `search`

---

## Phase 5: Integrate into Congregant Forms

### Step 5.1: Update New Congregant LiveView
- Add FamilyRelationshipSelector component to create form
- Handle relationship creation after congregant is saved
- Pass available family relationship types and congregants
- Store pending relationships in socket assigns

### Step 5.2: Update Edit Congregant LiveView
- Add FamilyRelationshipSelector component to edit form
- Load existing relationships on mount
- Handle add/remove relationship events
- Create/delete relationships in database
- Display current relationships as editable tags

### Step 5.3: Form Submission Handling
- On congregant create: create relationships after successful save
- On congregant update: handle relationship changes (add/remove)

---

## Phase 6: Display Relationships on Show Page

### Step 6.1: Update Show Congregant LiveView
- Load congregant's family relationships with preloading
- Display relationships as styled tags
- Group by family relationship type for clarity
- Each tag shows: family relationship type + related congregant name
- Tags are clickable links to related congregant's profile

### Step 6.2: Relationship Tag Styling
- Follow existing ministry tag pattern
- Responsive layout with flex-wrap
- Empty state message when no relationships

---

## File Summary

### New Files to Create
- `lib/chms/church/family_relationship_types.ex` - FamilyRelationshipTypes resource
- `lib/chms/church/family_relationship.ex` - FamilyRelationship junction table resource
- `lib/churchapp_web/components/family_relationship_selector.ex` - Selector component
- `lib/churchapp_web/live/family_relationship_types/index_live.ex` - Admin index
- `lib/churchapp_web/live/family_relationship_types/new_live.ex` - Admin create
- `lib/churchapp_web/live/family_relationship_types/edit_live.ex` - Admin edit

### Files to Modify
- `lib/chms/church.ex` - Add resources and domain functions
- `lib/chms/church/congregants.ex` - Add relationship
- `lib/churchapp_web/router.ex` - Add admin routes
- `lib/churchapp_web/live/congregants/new_live.ex` - Add selector
- `lib/churchapp_web/live/congregants/edit_live.ex` - Add selector
- `lib/churchapp_web/live/congregants/show_live.ex` - Display relationships
- `priv/repo/seeds.exs` - Add default family relationship types

---

## Notes
- Database reset is acceptable during development
- Follow existing dark theme and component patterns
- All Ash operations must include `actor: actor` parameter
