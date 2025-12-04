defmodule ChurchappWeb.UsersLive.NewLive do
  use ChurchappWeb, :live_view

  @all_permissions [
    :manage_congregants,
    :view_congregants,
    :manage_contributions,
    :view_contributions,
    :manage_ministries,
    :view_reports,
    :manage_users
  ]

  @roles [:super_admin, :admin, :staff, :leader, :member]

  def mount(_params, _session, socket) do
    actor = socket.assigns[:current_user]

    {:ok,
     socket
     |> assign(:page_title, "Create User")
     |> assign(:email, "")
     |> assign(:password, "")
     |> assign(:password_confirmation, "")
     |> assign(:selected_role, :member)
     |> assign(:selected_permissions, [])
     |> assign(:all_permissions, @all_permissions)
     |> assign(:roles, @roles)
     |> assign(:saving, false)
     |> assign(:errors, [])
     |> assign(:actor, actor)}
  end

  def handle_event("update_email", %{"value" => email}, socket) do
    {:noreply, assign(socket, :email, email)}
  end

  def handle_event("update_password", %{"value" => password}, socket) do
    {:noreply, assign(socket, :password, password)}
  end

  def handle_event("update_password_confirmation", %{"value" => password_confirmation}, socket) do
    {:noreply, assign(socket, :password_confirmation, password_confirmation)}
  end

  def handle_event("select_role", %{"role" => role}, socket) do
    {:noreply, assign(socket, :selected_role, String.to_existing_atom(role))}
  end

  def handle_event("toggle_permission", %{"permission" => permission}, socket) do
    permission_atom = String.to_existing_atom(permission)
    current_permissions = socket.assigns.selected_permissions

    new_permissions =
      if permission_atom in current_permissions do
        List.delete(current_permissions, permission_atom)
      else
        [permission_atom | current_permissions]
      end

    {:noreply, assign(socket, :selected_permissions, new_permissions)}
  end

  def handle_event("select_all_permissions", _params, socket) do
    {:noreply, assign(socket, :selected_permissions, @all_permissions)}
  end

  def handle_event("clear_all_permissions", _params, socket) do
    {:noreply, assign(socket, :selected_permissions, [])}
  end

  def handle_event("save", _params, socket) do
    socket = assign(socket, :saving, true)

    # Validate inputs
    errors = validate_inputs(socket.assigns)

    if errors != [] do
      {:noreply,
       socket
       |> assign(:saving, false)
       |> assign(:errors, errors)}
    else
      attrs = %{
        email: socket.assigns.email,
        password: socket.assigns.password,
        password_confirmation: socket.assigns.password_confirmation,
        role: socket.assigns.selected_role,
        permissions: socket.assigns.selected_permissions
      }

      case Churchapp.Accounts.User
           |> Ash.Changeset.for_create(:register_with_password, attrs)
           |> Ash.create(authorize?: false) do
        {:ok, _user} ->
          {:noreply,
           socket
           |> assign(:saving, false)
           |> put_flash(:info, "User created successfully")
           |> push_navigate(to: ~p"/admin/users")}

        {:error, changeset} ->
          errors =
            changeset.errors
            |> Enum.map(fn error ->
              field = Map.get(error, :field, :unknown)
              message = Map.get(error, :message, "Unknown error")
              "#{field}: #{message}"
            end)

          {:noreply,
           socket
           |> assign(:saving, false)
           |> assign(:errors, errors)}
      end
    end
  end

  defp validate_inputs(assigns) do
    errors = []

    errors =
      if assigns.email == "" or not String.contains?(assigns.email, "@") do
        ["Please enter a valid email address" | errors]
      else
        errors
      end

    errors =
      if String.length(assigns.password) < 8 do
        ["Password must be at least 8 characters" | errors]
      else
        errors
      end

    errors =
      if assigns.password != assigns.password_confirmation do
        ["Passwords do not match" | errors]
      else
        errors
      end

    Enum.reverse(errors)
  end

  defp role_badge_class(role) do
    case role do
      :super_admin -> "bg-purple-900/60 text-purple-400 border-purple-800"
      :admin -> "bg-blue-900/60 text-blue-400 border-blue-800"
      :staff -> "bg-green-900/60 text-green-400 border-green-800"
      :leader -> "bg-yellow-900/60 text-yellow-500 border-yellow-800"
      :member -> "bg-gray-800 text-gray-400 border-gray-700"
      _ -> "bg-gray-800 text-gray-400 border-gray-700"
    end
  end

  defp role_description(role) do
    case role do
      :super_admin -> "Full system access. Can manage all users and settings."
      :admin -> "Administrative access. Can manage users and all church data."
      :staff -> "Staff access. Can manage congregants and contributions."
      :leader -> "Leader access. Can view congregants and contributions."
      :member -> "Basic access. Can view congregant directory."
      _ -> ""
    end
  end

  defp permission_description(permission) do
    case permission do
      :manage_congregants -> "Create, edit, and delete congregant records"
      :view_congregants -> "View congregant directory and profiles"
      :manage_contributions -> "Create, edit, and delete contribution records"
      :view_contributions -> "View contribution history and reports"
      :manage_ministries -> "Create, edit, and delete ministry groups"
      :view_reports -> "Access financial and membership reports"
      :manage_users -> "Create, edit, and delete user accounts"
      _ -> ""
    end
  end

  defp permission_icon(permission) do
    case permission do
      :manage_congregants -> "hero-user-plus"
      :view_congregants -> "hero-users"
      :manage_contributions -> "hero-banknotes"
      :view_contributions -> "hero-chart-bar"
      :manage_ministries -> "hero-building-office"
      :view_reports -> "hero-document-chart-bar"
      :manage_users -> "hero-user-circle"
      _ -> "hero-cog"
    end
  end

  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto">
      <%!-- Back Navigation --%>
      <div class="mb-6">
        <.link
          navigate={~p"/admin/users"}
          class="flex items-center text-gray-400 hover:text-white transition-colors"
        >
          <.icon name="hero-arrow-left" class="mr-2 h-4 w-4" /> Back to Users
        </.link>
      </div>

      <%!-- Header --%>
      <div class="bg-dark-800 shadow-xl rounded-lg border border-dark-700 overflow-hidden mb-8">
        <div class="px-6 py-8 border-b border-dark-700">
          <div class="flex items-center gap-6">
            <div class="flex-shrink-0 h-20 w-20 rounded-full bg-primary-500/20 flex items-center justify-center">
              <.icon name="hero-user-plus" class="h-10 w-10 text-primary-500" />
            </div>
            <div class="flex-1">
              <h1 class="text-2xl font-bold text-white mb-2">
                Create New User
              </h1>
              <p class="text-sm text-gray-400">
                Add a new user account with email, password, role and permissions
              </p>
            </div>
          </div>
        </div>
      </div>

      <%!-- Error Messages --%>
      <%= if @errors != [] do %>
        <div class="mb-6 p-4 bg-red-900/20 border border-red-800 rounded-lg">
          <div class="flex items-start gap-3">
            <.icon name="hero-exclamation-circle" class="h-5 w-5 text-red-500 flex-shrink-0 mt-0.5" />
            <div>
              <h3 class="text-sm font-medium text-red-400">Please fix the following errors:</h3>
              <ul class="mt-2 text-sm text-red-300 list-disc list-inside">
                <li :for={error <- @errors}>{error}</li>
              </ul>
            </div>
          </div>
        </div>
      <% end %>

      <%!-- Account Credentials --%>
      <div class="bg-dark-800 shadow-xl rounded-lg border border-dark-700 overflow-hidden mb-8">
        <div class="px-6 py-6 border-b border-dark-700">
          <h2 class="text-lg font-medium text-white flex items-center">
            <.icon name="hero-envelope" class="mr-2 h-5 w-5 text-primary-500" />
            Account Credentials
          </h2>
          <p class="mt-1 text-sm text-gray-400">
            Enter the email and password for the new user
          </p>
        </div>
        <div class="p-6 space-y-6">
          <div>
            <label class="block text-sm font-medium text-gray-300 mb-2">
              Email Address <span class="text-red-500">*</span>
            </label>
            <input
              type="email"
              name="email"
              value={@email}
              phx-keyup="update_email"
              phx-debounce="100"
              placeholder="user@church.org"
              class="w-full px-4 py-3 text-gray-200 bg-dark-700 border border-dark-600 rounded-md focus:ring-2 focus:ring-primary-500 focus:border-transparent transition-colors"
            />
          </div>

          <div class="grid grid-cols-1 sm:grid-cols-2 gap-6">
            <div>
              <label class="block text-sm font-medium text-gray-300 mb-2">
                Password <span class="text-red-500">*</span>
              </label>
              <input
                type="password"
                name="password"
                value={@password}
                phx-keyup="update_password"
                phx-debounce="100"
                placeholder="Minimum 8 characters"
                class="w-full px-4 py-3 text-gray-200 bg-dark-700 border border-dark-600 rounded-md focus:ring-2 focus:ring-primary-500 focus:border-transparent transition-colors"
              />
            </div>

            <div>
              <label class="block text-sm font-medium text-gray-300 mb-2">
                Confirm Password <span class="text-red-500">*</span>
              </label>
              <input
                type="password"
                name="password_confirmation"
                value={@password_confirmation}
                phx-keyup="update_password_confirmation"
                phx-debounce="100"
                placeholder="Re-enter password"
                class="w-full px-4 py-3 text-gray-200 bg-dark-700 border border-dark-600 rounded-md focus:ring-2 focus:ring-primary-500 focus:border-transparent transition-colors"
              />
            </div>
          </div>
        </div>
      </div>

      <%!-- Role Selection --%>
      <div class="bg-dark-800 shadow-xl rounded-lg border border-dark-700 overflow-hidden mb-8">
        <div class="px-6 py-6 border-b border-dark-700">
          <h2 class="text-lg font-medium text-white flex items-center">
            <.icon name="hero-shield-check" class="mr-2 h-5 w-5 text-primary-500" />
            User Role
          </h2>
          <p class="mt-1 text-sm text-gray-400">
            Select the role that defines this user's base access level
          </p>
        </div>
        <div class="p-6">
          <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
            <button
              :for={role <- @roles}
              type="button"
              phx-click="select_role"
              phx-value-role={role}
              class={[
                "relative p-4 rounded-lg border-2 text-left transition-all duration-200",
                if(@selected_role == role,
                  do: "border-primary-500 bg-primary-500/10",
                  else: "border-dark-600 hover:border-dark-500 bg-dark-700/50"
                )
              ]}
            >
              <div class="flex items-center justify-between mb-2">
                <span class={[
                  "px-2.5 py-1 text-xs font-medium rounded-full border",
                  role_badge_class(role)
                ]}>
                  {Phoenix.Naming.humanize(role)}
                </span>
                <%= if @selected_role == role do %>
                  <.icon name="hero-check-circle-solid" class="w-5 h-5 text-primary-500" />
                <% end %>
              </div>
              <p class="text-xs text-gray-400 leading-relaxed">
                {role_description(role)}
              </p>
            </button>
          </div>
        </div>
      </div>

      <%!-- Permissions Selection --%>
      <div class="bg-dark-800 shadow-xl rounded-lg border border-dark-700 overflow-hidden mb-8">
        <div class="px-6 py-6 border-b border-dark-700">
          <div class="flex items-center justify-between">
            <div>
              <h2 class="text-lg font-medium text-white flex items-center">
                <.icon name="hero-key" class="mr-2 h-5 w-5 text-primary-500" />
                Permissions
              </h2>
              <p class="mt-1 text-sm text-gray-400">
                Grant specific permissions beyond the base role
              </p>
            </div>
            <div class="flex gap-2">
              <button
                type="button"
                phx-click="select_all_permissions"
                class="px-3 py-1.5 text-xs font-medium text-gray-400 hover:text-white bg-dark-700 hover:bg-dark-600 rounded-md border border-dark-600 transition-colors"
              >
                Select All
              </button>
              <button
                type="button"
                phx-click="clear_all_permissions"
                class="px-3 py-1.5 text-xs font-medium text-gray-400 hover:text-white bg-dark-700 hover:bg-dark-600 rounded-md border border-dark-600 transition-colors"
              >
                Clear All
              </button>
            </div>
          </div>
        </div>
        <div class="p-6">
          <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <button
              :for={permission <- @all_permissions}
              type="button"
              phx-click="toggle_permission"
              phx-value-permission={permission}
              class={[
                "relative p-4 rounded-lg border-2 text-left transition-all duration-200",
                if(permission in @selected_permissions,
                  do: "border-primary-500 bg-primary-500/10",
                  else: "border-dark-600 hover:border-dark-500 bg-dark-700/50"
                )
              ]}
            >
              <div class="flex items-start gap-3">
                <div class={[
                  "flex-shrink-0 w-10 h-10 rounded-lg flex items-center justify-center",
                  if(permission in @selected_permissions,
                    do: "bg-primary-500/20 text-primary-500",
                    else: "bg-dark-600 text-gray-400"
                  )
                ]}>
                  <.icon name={permission_icon(permission)} class="w-5 h-5" />
                </div>
                <div class="flex-1 min-w-0">
                  <div class="flex items-center justify-between">
                    <span class={[
                      "text-sm font-medium",
                      if(permission in @selected_permissions, do: "text-white", else: "text-gray-300")
                    ]}>
                      {permission |> to_string() |> String.replace("_", " ") |> String.split() |> Enum.map(&String.capitalize/1) |> Enum.join(" ")}
                    </span>
                    <%= if permission in @selected_permissions do %>
                      <.icon name="hero-check-circle-solid" class="w-5 h-5 text-primary-500" />
                    <% end %>
                  </div>
                  <p class="mt-1 text-xs text-gray-400 leading-relaxed">
                    {permission_description(permission)}
                  </p>
                </div>
              </div>
            </button>
          </div>
        </div>
      </div>

      <%!-- Save Button --%>
      <div class="flex justify-end gap-4">
        <.link
          navigate={~p"/admin/users"}
          class="px-6 py-3 text-sm font-medium text-gray-300 bg-dark-700 hover:bg-dark-600 rounded-md border border-dark-600 transition-colors"
        >
          Cancel
        </.link>
        <button
          type="button"
          phx-click="save"
          disabled={@saving}
          class={[
            "px-6 py-3 text-sm font-medium text-white rounded-md shadow-lg transition-colors",
            if(@saving,
              do: "bg-primary-600 cursor-not-allowed opacity-50",
              else: "bg-primary-500 hover:bg-primary-600 shadow-primary-500/20"
            )
          ]}
        >
          <%= if @saving do %>
            <span class="flex items-center gap-2">
              <.icon name="hero-arrow-path" class="w-4 h-4 animate-spin" />
              Creating...
            </span>
          <% else %>
            Create User
          <% end %>
        </button>
      </div>
    </div>
    """
  end
end
