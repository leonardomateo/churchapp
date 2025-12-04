# Authentication & Authorization Implementation

This document describes the authentication and authorization system implemented for the Church Management Application.

## Overview

The system uses **Ash Framework's** built-in authentication and authorization capabilities with role-based access control (RBAC) and fine-grained permissions.

## User Roles

The application supports five user roles with different permission levels:

### 1. Super Admin (`super_admin`)
- **Full system access**
- Can manage all resources including users
- Can assign roles and permissions
- Access to all administrative functions

### 2. Admin (`admin`)
- Can manage congregants, contributions, and ministries
- Can view all reports
- Cannot manage users (except viewing)
- Cannot change system settings

### 3. Staff (`staff`)
- Can manage congregants
- Can view (but not manage) contributions
- Limited ministry access
- No user management

### 4. Leader (`leader`)
- Can view congregants and contributions
- Read-only access to most resources
- No management capabilities

### 5. Member (`member`)
- Can only view congregants
- Most restricted access level
- Default role for new users

## Permissions System

In addition to roles, users can have specific permissions:

- `manage_congregants` - Create, update, delete congregants
- `view_congregants` - Read access to congregants
- `manage_contributions` - Create, update, delete contributions
- `view_contributions` - Read access to contributions
- `manage_ministries` - Manage ministry assignments
- `view_reports` - Access to reporting features
- `manage_users` - User management (super admin only)

## Test Users

The following test users have been created (or will be created on first seed):

| Email | Password | Role | Description |
|-------|----------|------|-------------|
| superadmin@church.org | SuperAdmin123! | super_admin | Full system access |
| admin@church.org | Admin123! | admin | Administrative access |
| staff@church.org | Staff123! | staff | Staff member access |
| leader@church.org | Leader123! | leader | Leadership access |
| member@church.org | Member123! | member | Basic member access |

## Implementation Details

### 1. User Resource (`lib/churchapp/accounts/user.ex`)
- Added `role` attribute (atom, required, default: `:member`)
- Added `permissions` attribute (array of atoms, default: `[]`)
- Updated policies to allow role-based access control

### 2. Authorization Checks (`lib/churchapp/authorization/checks.ex`)
Custom policy checks:
- `HasRole` - Check if user has specific role(s)
- `HasPermission` - Check if user has specific permission
- `IsAdminOrAbove` - Check if user is admin or super_admin
- `IsSuperAdmin` - Check if user is super_admin

### 3. Resource Policies

#### Congregants Resource
- Super admins: Full access
- Admins/Staff: Can manage (with permission)
- Leaders/Members: Can view only (with permission)

#### Contributions Resource
- Super admins: Full access
- Admins/Staff: Can manage (with permission)
- Leaders: Can view only
- Members: No access

### 4. Router Configuration (`lib/churchapp_web/router.ex`)
Routes are organized into:
- **Public routes**: Home page, authentication routes
- **Protected routes**: All feature routes (congregants, contributions) require authentication

### 5. LiveView Authentication (`lib/churchapp_web/live_user_auth.ex`)
Mount hooks:
- `:live_user_required` - User must be logged in
- `:live_user_optional` - User may or may not be logged in
- `:live_no_user` - User must not be logged in
- `:require_admin` - User must be admin or super_admin
- `{:require_role, role}` - User must have specific role
- `{:require_permission, permission}` - User must have specific permission

Helper functions:
- `has_role?(user, role)` - Check user's role
- `has_permission?(user, permission)` - Check user's permission
- `can?(user, action)` - Check if user can perform action
- `is_admin?(user)` - Check if user is admin or super_admin
- `is_super_admin?(user)` - Check if user is super_admin

### 6. UI Components (`lib/churchapp_web/components/auth_components.ex`)
Reusable components for authorization:

```heex
<!-- Only show to admins -->
<.authorized role={:admin} current_user={@current_user}>
  <button>Admin Only Action</button>
</.authorized>

<!-- Only show to users with specific permission -->
<.authorized permission={:manage_contributions} current_user={@current_user}>
  <button>Manage Contributions</button>
</.authorized>

<!-- Check if user can perform action -->
<.can action={:manage_congregants} current_user={@current_user}>
  <.link navigate={~p"/congregants/new"}>New Congregant</.link>
</.can>

<!-- Admin-only section -->
<.admin_only current_user={@current_user}>
  <.link navigate={~p"/admin"}>Admin Panel</.link>
</.admin_only>

<!-- Display user's role badge -->
<.role_badge role={@current_user.role} />
```

## Usage in LiveViews

### Protecting Routes
Add to the top of your LiveView module:

```elixir
# Require authentication
on_mount {ChurchappWeb.LiveUserAuth, :live_user_required}

# Require admin role
on_mount [{ChurchappWeb.LiveUserAuth, :live_user_required}, {ChurchappWeb.LiveUserAuth, :require_admin}]

# Require specific role
on_mount [{ChurchappWeb.LiveUserAuth, :live_user_required}, {ChurchappWeb.LiveUserAuth, {:require_role, :staff}}]
```

### Passing Actor to Ash Operations
Always pass the current user as actor:

```elixir
def fetch_data(socket) do
  actor = socket.assigns.current_user
  
  query =
    MyResource
    |> Ash.Query.for_read(:read, %{}, actor: actor)
    |> Ash.Query.sort(inserted_at: :desc)
  
  results = Ash.read!(query, actor: actor)
  
  assign(socket, :results, results)
end

def handle_event("delete", %{"id" => id}, socket) do
  actor = socket.assigns.current_user
  
  case Ash.get(MyResource, id, actor: actor) do
    {:ok, record} ->
      case Ash.destroy(record, actor: actor) do
        :ok -> 
          {:noreply, put_flash(socket, :info, "Deleted successfully")}
        {:error, error} ->
          {:noreply, put_flash(socket, :error, "Failed to delete")}
      end
    _ ->
      {:noreply, put_flash(socket, :error, "Record not found")}
  end
end
```

## Database Schema

### Users Table
```sql
ALTER TABLE users ADD COLUMN role TEXT NOT NULL DEFAULT 'member';
ALTER TABLE users ADD COLUMN permissions TEXT[] DEFAULT '{}';
CREATE INDEX ON users(role);
```

## Security Considerations

1. **Default Role**: New users default to `member` (most restricted)
2. **Authorization on All Operations**: All CRUD operations check authorization
3. **Actor Context**: All Ash operations pass the current user as actor
4. **Policy Enforcement**: Policies are enforced at the resource level
5. **Route Protection**: All sensitive routes require authentication

## Testing Authorization

To test authorization:

1. Log in as different users
2. Try accessing resources you shouldn't have access to
3. Verify proper error messages and redirects
4. Test permission-based UI elements (buttons should hide/show appropriately)

## Common Patterns

### Check Permission Before Action
```elixir
def handle_event("delete", params, socket) do
  unless LiveUserAuth.can?(socket.assigns.current_user, :manage_contributions) do
    {:noreply, put_flash(socket, :error, "Permission denied")}
  else
    # Perform delete
  end
end
```

### Conditional UI Rendering
```heex
<%= if LiveUserAuth.can?(@current_user, :manage_congregants) do %>
  <.link navigate={~p"/congregants/new"}>New Congregant</.link>
<% end %>
```

## Extending the System

### Adding New Roles
1. Update the `role` attribute constraints in `user.ex`
2. Update authorization checks in `checks.ex`
3. Update policies in resources
4. Update `can?/2` function in `live_user_auth.ex`

### Adding New Permissions
1. Update the `permissions` attribute constraints in `user.ex`
2. Add new policy checks in resources
3. Update seeds to assign new permissions
4. Update UI components to check new permissions

## Migration Commands

```bash
# Generate migration
mix ash.codegen --name add_user_roles_and_permissions

# Run migration
mix ecto.migrate

# Seed database (with test users)
mix run priv/repo/seeds.exs

# Reset database (development only)
mix ash.reset
```

## Files Modified/Created

### Created Files
- `lib/churchapp/authorization/checks.ex` - Authorization policy checks
- `lib/churchapp_web/components/auth_components.ex` - UI authorization components
- `AUTHENTICATION_SETUP.md` - This documentation

### Modified Files
- `lib/churchapp/accounts/user.ex` - Added role and permissions
- `lib/chms/church/congregants.ex` - Added authorization policies
- `lib/chms/church/contributions.ex` - Added authorization policies
- `lib/churchapp_web/router.ex` - Reorganized routes with auth requirements
- `lib/churchapp_web/live_user_auth.ex` - Enhanced with role/permission checks
- `lib/churchapp_web/live/contributions/index_live.ex` - Added actor context
- `priv/repo/seeds.exs` - Added test users with different roles
- `priv/repo/migrations/20251204004022_add_user_roles_and_permissions.exs` - Database migration

## Next Steps

1. **Add authorization to remaining LiveViews** (congregants, etc.)
2. **Implement audit logging** for sensitive operations
3. **Create admin panel** for user management
4. **Add role/permission assignment UI**
5. **Implement password complexity requirements**
6. **Add two-factor authentication** (optional)
7. **Create API authentication** for mobile apps (if needed)

## Support

For questions or issues with the authentication system, refer to:
- [Ash Framework Documentation](https://hexdocs.pm/ash/)
- [Ash Authentication Documentation](https://hexdocs.pm/ash_authentication/)
- [Ash Policy Authorization](https://hexdocs.pm/ash/policies.html)

