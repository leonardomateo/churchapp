# Authentication & Authorization Quick Reference

## Test Users

| Email | Password | Role |
|-------|----------|------|
| superadmin@church.org | SuperAdmin123! | super_admin |
| admin@church.org | Admin123! | admin |
| staff@church.org | Staff123! | staff |
| leader@church.org | Leader123! | leader |
| member@church.org | Member123! | member |

## Roles Hierarchy (Most to Least Privileged)

1. **super_admin** - Full system access
2. **admin** - Manage all church resources
3. **staff** - Manage congregants, view contributions
4. **leader** - View congregants and contributions
5. **member** - View congregants only

## Quick Code Snippets

### Protect a LiveView Route
```elixir
# Require login
on_mount {ChurchappWeb.LiveUserAuth, :live_user_required}

# Require admin
on_mount [{ChurchappWeb.LiveUserAuth, :live_user_required}, 
          {ChurchappWeb.LiveUserAuth, :require_admin}]
```

### Pass Actor in LiveView
```elixir
def fetch_data(socket) do
  actor = socket.assigns.current_user
  
  results = 
    MyResource
    |> Ash.Query.for_read(:read, %{}, actor: actor)
    |> Ash.read!(actor: actor)
  
  assign(socket, :results, results)
end
```

### Conditional UI (Template)
```heex
<!-- Using auth component -->
<.authorized role={:admin} current_user={@current_user}>
  <button>Admin Only</button>
</.authorized>

<!-- Using helper function -->
<%= if ChurchappWeb.LiveUserAuth.can?(@current_user, :manage_congregants) do %>
  <.link navigate={~p"/congregants/new"}>New</.link>
<% end %>

<!-- Role badge -->
<.role_badge role={@current_user.role} />
```

### Check Permission in Event Handler
```elixir
def handle_event("delete", params, socket) do
  unless LiveUserAuth.can?(socket.assigns.current_user, :manage_contributions) do
    {:noreply, put_flash(socket, :error, "Permission denied")}
  else
    # Perform action
  end
end
```

## Common Helper Functions

```elixir
import ChurchappWeb.LiveUserAuth

# Check role
has_role?(user, :admin)                    # Single role
has_role?(user, [:admin, :super_admin])    # Multiple roles

# Check permission
has_permission?(user, :manage_congregants)

# Check action capability
can?(user, :manage_contributions)

# Check admin status
is_admin?(user)
is_super_admin?(user)
```

## Authorization Policy Pattern

```elixir
policies do
  # Super admins can do everything
  policy action_type([:create, :read, :update, :destroy]) do
    authorize_if {Checks.IsSuperAdmin, []}
  end

  # Role-based management
  policy action_type([:create, :update, :destroy]) do
    authorize_if {Checks.HasRole, role: [:admin, :staff]}
  end

  # Read-only access
  policy action_type(:read) do
    authorize_if {Checks.HasRole, role: [:admin, :staff, :leader, :member]}
  end
end
```

## Common Auth Components

```heex
<!-- Authorized section -->
<.authorized role={:admin} current_user={@current_user}>
  Content for admins
</.authorized>

<!-- Permission-based -->
<.authorized permission={:manage_congregants} current_user={@current_user}>
  Content for users with permission
</.authorized>

<!-- Action-based -->
<.can action={:manage_contributions} current_user={@current_user}>
  Content for users who can manage contributions
</.can>

<!-- Admin only -->
<.admin_only current_user={@current_user}>
  Admin content
</.admin_only>

<!-- Super admin only -->
<.super_admin_only current_user={@current_user}>
  Super admin content
</.super_admin_only>
```

## Database Commands

```bash
# Run migrations
mix ecto.migrate

# Seed users (safe to run multiple times)
mix run priv/repo/seeds.exs

# Reset everything (DEV ONLY)
mix ash.reset

# Generate new migration
mix ash.codegen --name migration_name
```

## Troubleshooting

### "Forbidden" Error
- Check if user is logged in: `@current_user`
- Verify user has correct role: `@current_user.role`
- Check user permissions: `@current_user.permissions`
- Ensure actor is passed: `Ash.read!(query, actor: actor)`

### User Can't See Content
- Verify mount hook is set: `on_mount {LiveUserAuth, :live_user_required}`
- Check role in authorization component
- Verify policy in resource matches expected role

### Routes Redirecting to Sign-in
- Routes in authenticated scope require login
- Check mount hooks are correct
- Verify session is valid

## Permissions List

- `:manage_congregants` - CRUD congregants
- `:view_congregants` - Read congregants
- `:manage_contributions` - CRUD contributions
- `:view_contributions` - Read contributions
- `:manage_ministries` - CRUD ministries
- `:view_reports` - Access reports
- `:manage_users` - User management (super admin)

## File Locations

- **Authorization Checks**: `lib/churchapp/authorization/checks.ex`
- **UI Components**: `lib/churchapp_web/components/auth_components.ex`
- **LiveView Auth**: `lib/churchapp_web/live_user_auth.ex`
- **User Resource**: `lib/churchapp/accounts/user.ex`
- **Router**: `lib/churchapp_web/router.ex`
- **Seeds**: `priv/repo/seeds.exs`

