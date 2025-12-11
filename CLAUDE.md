# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Church Management System built with:
- **Phoenix 1.8.1** - Web framework
- **Ash Framework 3.0** - Resource-based framework for building Elixir applications
- **AshPostgres 2.0** - PostgreSQL data layer for Ash
- **Phoenix LiveView 1.1** - Real-time web interfaces
- **AshAuthentication** - Authentication and authorization
- **Tailwind CSS** - Styling

## Development Commands

### Setup & Installation
```bash
# Initial setup (installs deps, sets up database, builds assets)
mix setup

# Start development server
mix phx.server

# Start with IEx for debugging
iex -S mix phx.server
```

### Database Commands
```bash
# Run Ash migrations and setup
mix ash.setup

# Generate migration from Ash resource changes
mix ash.codegen --name migration_name

# Run Ecto migrations directly
mix ecto.migrate

# Seed database with test users and data
mix run priv/repo/seeds.exs

# Reset database (DEVELOPMENT ONLY)
mix ash.reset
```

### Testing & Quality
```bash
# Run tests
mix test

# Run specific test file
mix test test/path/to/test.exs

# Run previously failed tests
mix test --failed

# Pre-commit checks (compile with warnings as errors, format, test)
mix precommit
```

### Asset Commands
```bash
# Setup assets (install tailwind and esbuild if missing)
mix assets.setup

# Build assets for development
mix assets.build

# Build and minify for production
mix assets.deploy
```

## Architecture Overview

### Domain-Driven Design with Ash Framework

This application uses the **Ash Framework**, which provides a declarative, resource-based architecture. The core concept is that business logic lives in **Resources** which are grouped into **Domains**.

#### Domains

1. **Chms.Church** (`lib/chms/church.ex`)
   - Primary business domain for church management
   - Contains resources: Congregants, Contributions, MinistryFunds, Events, WeekEndingReports, ReportCategories, ReportCategoryEntries
   - Defines domain-level interfaces for working with resources

2. **Churchapp.Accounts** (`lib/churchapp/accounts.ex`)
   - User authentication and authorization domain
   - Contains User and Token resources
   - Integrated with AshAuthentication

#### Resources

Resources are the core building blocks. Each resource defines:
- **Attributes**: Data fields with types and constraints
- **Actions**: CRUD operations (create, read, update, destroy) and custom actions
- **Policies**: Authorization rules using Ash.Policy.Authorizer
- **Relationships**: Associations with other resources
- **Changes**: Custom logic that runs during action execution
- **Calculations**: Computed attributes

Key resources:
- `Chms.Church.Congregants` - Church members/attendees
- `Chms.Church.Contributions` - Financial contributions
- `Chms.Church.MinistryFunds` - Ministry-specific funds
- `Chms.Church.Events` - Calendar events
- `Chms.Church.WeekEndingReports` - Weekly statistical reports
- `Churchapp.Accounts.User` - Application users with roles and permissions

### Authentication & Authorization

The app uses a comprehensive role-based access control (RBAC) system with five roles:
1. **super_admin** - Full system access
2. **admin** - Manage all church resources
3. **staff** - Manage congregants, view contributions
4. **leader** - View congregants and contributions
5. **member** - View congregants only

**Key Files:**
- `lib/churchapp/accounts/user.ex` - User resource with roles/permissions
- `lib/churchapp/authorization/checks.ex` - Custom policy checks (HasRole, HasPermission, IsSuperAdmin, etc.)
- `lib/churchapp_web/live_user_auth.ex` - LiveView authentication hooks and helper functions
- `lib/churchapp_web/components/auth_components.ex` - UI components for conditional rendering based on auth

**Authorization Patterns:**

In LiveViews:
```elixir
# Require authentication
on_mount {ChurchappWeb.LiveUserAuth, :live_user_required}

# Require admin role
on_mount [{ChurchappWeb.LiveUserAuth, :live_user_required},
          {ChurchappWeb.LiveUserAuth, :require_admin}]

# Always pass actor to Ash operations
actor = socket.assigns.current_user
Ash.read!(query, actor: actor)
```

In templates:
```heex
<.authorized role={:admin} current_user={@current_user}>
  Admin only content
</.authorized>
```

**Test Users:** See AUTH_QUICK_REFERENCE.md for login credentials.

### LiveView Architecture

LiveViews are organized by feature in `lib/churchapp_web/live/`:
- `congregants/` - Member management
- `contributions/` - Financial tracking
- `ministry_funds/` - Fund management
- `events/` - Calendar/event management
- `week_ending_reports/` - Weekly reports
- `users/` - User management (admin only)
- `dashboard/` - Main dashboard

**LiveView Conventions:**
- Use streams for collections to avoid memory issues
- Always set unique DOM IDs on forms and key elements
- Use `on_mount` hooks for authentication
- Pass `actor` to all Ash operations

### Router Organization

Routes are organized into scopes with different authentication requirements:
- **Public routes** (`/`) - Home page, auth routes
- **Authenticated routes** (`/`) - Main app features (dashboard, congregants, contributions, events)
- **Admin routes** (`/admin`) - User management, week ending reports, event admin

### Working with Ash Resources

**Reading data:**
```elixir
actor = socket.assigns.current_user

# List all
Chms.Church.list_congregants!(actor: actor)

# Get by ID
Chms.Church.get_congregant_by_id!(id, actor: actor)

# Custom query
Chms.Church.Congregants
|> Ash.Query.for_read(:read, %{}, actor: actor)
|> Ash.Query.filter(status == :active)
|> Ash.Query.sort(last_name: :asc)
|> Ash.read!(actor: actor)
```

**Creating/updating:**
```elixir
# Create
Chms.Church.Congregants
|> Ash.Changeset.for_create(:create, params, actor: actor)
|> Ash.create!(actor: actor)

# Update
record
|> Ash.Changeset.for_update(:update, params, actor: actor)
|> Ash.update!(actor: actor)

# Destroy
Ash.destroy!(record, actor: actor)
```

**Domain-level functions:**
The `Chms.Church` domain defines convenience functions that can be used directly:
```elixir
# Defined in domain, can call directly
Chms.Church.list_congregants!(actor: actor)
Chms.Church.create_congregant!(params, actor: actor)
```

### Frontend Stack

**LiveView Components:**
- `lib/churchapp_web/components/core_components.ex` - Base UI components (buttons, forms, modals, tables, etc.)
- `lib/churchapp_web/components/auth_components.ex` - Authorization components
- Custom selectors: `congregant_selector.ex`, `ministry_selector.ex`, `state_selector.ex`, `country_selector.ex`, `datetime_input.ex`

**Assets:**
- `assets/js/app.js` - Main JavaScript entry point
- `assets/css/app.css` - Tailwind CSS with custom imports
- No `tailwind.config.js` - Uses Tailwind v4 CSS-based configuration
- Icons: Use `<.icon name="hero-x-mark">` component for Heroicons

**Important:** Never write inline `<script>` tags in templates. Always put JavaScript in `assets/js/` and import into `app.js`.

### Database

- **Database**: PostgreSQL 18.0+
- **Migrations**: Located in `priv/repo/migrations/`
- **Seeds**: `priv/repo/seeds.exs` - Creates test users and sample data
- **Extensions**: ash-functions, citext

**Migration workflow:**
1. Modify Ash resource attributes/relationships
2. Run `mix ash.codegen --name descriptive_name`
3. Review generated migration in `priv/repo/migrations/`
4. Run `mix ecto.migrate`

## Key Patterns & Conventions

### Ash Resource Actions

When defining custom actions on resources, use the `argument` and `accept` patterns:
```elixir
create :create do
  argument :custom_field, :string
  accept [:field1, :field2, ...]

  change {MyModule.MyChange, []}
end
```

### Authorization Policies

All resources with sensitive data should have policies:
```elixir
policies do
  # Super admins bypass all
  bypass action_type([:create, :read, :update, :destroy]) do
    authorize_if {Checks.IsSuperAdmin, []}
  end

  # Role-based access
  policy action_type(:read) do
    authorize_if {Checks.HasRole, role: [:admin, :staff]}
  end
end
```

### LiveView Streams

Use streams for collections to prevent memory issues:
```elixir
# In mount or handle_event
socket
|> stream(:messages, messages)

# In template
<div id="messages" phx-update="stream">
  <div :for={{id, msg} <- @streams.messages} id={id}>
    {msg.text}
  </div>
</div>

# Reset stream
stream(socket, :messages, new_messages, reset: true)
```

### Form Handling

Always use `to_form/2` and the `<.form>` component:
```elixir
# In LiveView
form = AshPhoenix.Form.for_create(Resource, :create, domain: Domain)
assign(socket, form: to_form(form))

# In template
<.form for={@form} phx-submit="save" id="my-form">
  <.input field={@form[:field_name]} label="Label" />
</.form>
```

## Testing

- Test files in `test/` directory mirror `lib/` structure
- Use `Phoenix.LiveViewTest` for LiveView testing
- Use `LazyHTML` for HTML assertions
- Always test element presence with IDs, not text content
- Reference the IDs you add to templates in your tests

## Important Notes

- **Always pass actor:** Every Ash operation must include `actor: actor` parameter
- **No direct Ecto:** Use Ash actions, not Ecto.Repo directly
- **Req for HTTP:** Use the `:req` library for HTTP requests (already included), not httpoison or tesla
- **No inline scripts:** JavaScript must be in assets/js/, never inline in templates
- **Run precommit:** Run `mix precommit` before finishing work to catch issues
- **Phoenix 1.8 patterns:** No `live_redirect`/`live_patch` - use `<.link navigate={}>` and `push_navigate`
- **No Phoenix.View:** Phoenix.View is deprecated and not used
- **HEEx syntax:** Use `{@var}` for attribute interpolation, `{@var}` or `<%= @var %>` for body content, `<%= if/for/case %>` for blocks
- **Tailwind classes:** Can use list syntax for conditional classes: `class={["base", @flag && "extra"]}`

## Additional Documentation

- **AGENTS.md** - Detailed Phoenix/LiveView development guidelines
- **AUTHENTICATION_SETUP.md** - Complete authentication implementation details
- **AUTH_QUICK_REFERENCE.md** - Quick reference for auth patterns and test users
