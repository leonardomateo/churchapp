defmodule ChurchappWeb.UsersLive.IndexLive do
  use ChurchappWeb, :live_view

  require Ash.Query

  def mount(_params, _session, socket) do
    # Get the current user for authorization
    actor = socket.assigns[:current_user]

    socket =
      socket
      |> assign(:page_title, "User Management")
      |> assign(:search_query, "")
      |> assign(:role_filter, "")
      |> assign(:delete_user_id, nil)
      |> fetch_users(actor)

    {:ok, socket}
  end

  def handle_event("search", %{"query" => query}, socket) do
    actor = socket.assigns[:current_user]

    socket
    |> assign(:search_query, query)
    |> fetch_users(actor)
    |> then(&{:noreply, &1})
  end

  def handle_event("filter_role", %{"role" => role}, socket) do
    actor = socket.assigns[:current_user]

    socket
    |> assign(:role_filter, role)
    |> fetch_users(actor)
    |> then(&{:noreply, &1})
  end

  def handle_event("show_delete_confirm", %{"id" => id}, socket) do
    {:noreply, assign(socket, :delete_user_id, id)}
  end

  def handle_event("cancel_delete", _params, socket) do
    {:noreply, assign(socket, :delete_user_id, nil)}
  end

  def handle_event("confirm_delete", _params, socket) do
    actor = socket.assigns[:current_user]

    case Churchapp.Accounts.get_user_by_id(socket.assigns.delete_user_id, actor: actor) do
      {:ok, user} ->
        # Don't allow deleting yourself
        if user.id == actor.id do
          {:noreply,
           socket
           |> put_flash(:error, "You cannot delete your own account")
           |> assign(:delete_user_id, nil)}
        else
          case Churchapp.Accounts.delete_user(user, actor: actor) do
            :ok ->
              socket
              |> put_flash(:info, "User deleted successfully")
              |> assign(:delete_user_id, nil)
              |> fetch_users(actor)
              |> then(&{:noreply, &1})

            {:error, _} ->
              {:noreply,
               socket
               |> put_flash(:error, "Failed to delete user")
               |> assign(:delete_user_id, nil)}
          end
        end

      {:error, _} ->
        {:noreply,
         socket
         |> put_flash(:error, "User not found")
         |> assign(:delete_user_id, nil)}
    end
  end

  defp fetch_users(socket, actor) do
    query = Churchapp.Accounts.User

    query =
      if socket.assigns.search_query != "" do
        search_term = String.downcase(socket.assigns.search_query)

        Ash.Query.filter(
          query,
          contains(string_downcase(email), ^search_term)
        )
      else
        query
      end

    query =
      if socket.assigns.role_filter != "" do
        role = String.to_existing_atom(socket.assigns.role_filter)
        Ash.Query.filter(query, role == ^role)
      else
        query
      end

    query = Ash.Query.sort(query, email: :asc)

    case Churchapp.Accounts.list_users(query: query, actor: actor) do
      {:ok, users} ->
        assign(socket, :users, users)

      {:error, _} ->
        socket
        |> assign(:users, [])
        |> put_flash(:error, "Failed to load users")
    end
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

  def render(assigns) do
    ~H"""
    <div class="view-container active">
      <div class="mb-6 flex flex-col sm:flex-row justify-between items-start sm:items-center space-y-4 sm:space-y-0">
        <div class="flex items-center gap-4">
          <h2 class="text-2xl font-bold text-white">User Management</h2>
        </div>
        <.link
          navigate={~p"/admin/users/new"}
          class="inline-flex items-center px-4 py-2 text-sm font-medium text-white bg-primary-500 hover:bg-primary-600 rounded-md shadow-lg shadow-primary-500/20 transition-colors"
        >
          <.icon name="hero-plus" class="mr-2 h-4 w-4" /> Add New User
        </.link>
      </div>

      <%!-- Search and Filters --%>
      <div class="mb-6 flex flex-col sm:flex-row gap-4">
        <div class="flex-1">
          <form phx-change="search" phx-submit="search">
            <input
              type="text"
              name="query"
              value={@search_query}
              placeholder="Search by email..."
              phx-debounce="300"
              class="w-full px-4 py-3 text-gray-200 bg-dark-800 border border-dark-700 rounded-md focus:ring-2 focus:ring-primary-500 focus:border-transparent hover:bg-dark-700 hover:border-dark-600 transition-colors"
            />
          </form>
        </div>

        <form phx-change="filter_role">
          <select
            name="role"
            class="h-[50px] px-4 py-3 text-gray-200 bg-dark-800 border border-dark-700 rounded-md focus:ring-2 focus:ring-primary-500 focus:border-transparent hover:bg-dark-700 hover:border-dark-600 transition-colors cursor-pointer"
          >
            <option value="" selected={@role_filter == ""}>All Roles</option>
            <option value="super_admin" selected={@role_filter == "super_admin"}>
              Super Admin
            </option>
            <option value="admin" selected={@role_filter == "admin"}>Admin</option>
            <option value="staff" selected={@role_filter == "staff"}>Staff</option>
            <option value="leader" selected={@role_filter == "leader"}>Leader</option>
            <option value="member" selected={@role_filter == "member"}>Member</option>
          </select>
        </form>
      </div>

      <%!-- Users Table --%>
      <div class="bg-dark-800 rounded-lg border border-dark-700 overflow-hidden">
        <table class="min-w-full divide-y divide-dark-700">
          <thead class="bg-dark-700/50">
            <tr>
              <th class="px-6 py-4 text-left text-xs font-medium text-gray-400 uppercase tracking-wider">
                Email
              </th>
              <th class="px-6 py-4 text-left text-xs font-medium text-gray-400 uppercase tracking-wider">
                Role
              </th>
              <th class="px-6 py-4 text-left text-xs font-medium text-gray-400 uppercase tracking-wider">
                Permissions
              </th>
              <th class="px-6 py-4 text-left text-xs font-medium text-gray-400 uppercase tracking-wider">
                Status
              </th>
              <th class="px-6 py-4 text-right text-xs font-medium text-gray-400 uppercase tracking-wider">
                Actions
              </th>
            </tr>
          </thead>
          <tbody class="bg-dark-800 divide-y divide-dark-700">
            <tr
              :for={user <- @users}
              class="hover:bg-dark-700/40 transition-all duration-200"
            >
              <td class="px-6 py-4 whitespace-nowrap">
                <div class="flex items-center">
                  <div class="flex-shrink-0 h-10 w-10 rounded-full bg-primary-500/20 flex items-center justify-center">
                    <span class="text-primary-400 font-medium text-sm">
                      {user.email |> to_string() |> String.first() |> String.upcase()}
                    </span>
                  </div>
                  <div class="ml-4">
                    <div class="text-sm font-medium text-white">
                      {to_string(user.email)}
                    </div>
                    <div class="text-xs text-gray-500">
                      ID: {String.slice(user.id, 0..7)}...
                    </div>
                  </div>
                </div>
              </td>
              <td class="px-6 py-4 whitespace-nowrap">
                <span class={[
                  "px-3 py-1 inline-flex text-xs font-medium rounded-full border",
                  role_badge_class(user.role)
                ]}>
                  {Phoenix.Naming.humanize(user.role)}
                </span>
              </td>
              <td class="px-6 py-4">
                <div class="flex flex-wrap gap-1 max-w-xs">
                  <%= if user.permissions && user.permissions != [] do %>
                    <span
                      :for={permission <- Enum.take(user.permissions, 3)}
                      class="px-2 py-0.5 text-xs rounded bg-dark-700 text-gray-400 border border-dark-600"
                    >
                      {permission |> to_string() |> String.replace("_", " ")}
                    </span>
                    <%= if length(user.permissions) > 3 do %>
                      <span class="px-2 py-0.5 text-xs rounded bg-dark-700 text-gray-500">
                        +{length(user.permissions) - 3} more
                      </span>
                    <% end %>
                  <% else %>
                    <span class="text-xs text-gray-500 italic">No permissions</span>
                  <% end %>
                </div>
              </td>
              <td class="px-6 py-4 whitespace-nowrap">
                <%= if user.confirmed_at do %>
                  <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-900/60 text-green-400 border border-green-800">
                    <.icon name="hero-check-circle" class="w-3 h-3 mr-1" /> Confirmed
                  </span>
                <% else %>
                  <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-yellow-900/60 text-yellow-500 border border-yellow-800">
                    <.icon name="hero-clock" class="w-3 h-3 mr-1" /> Pending
                  </span>
                <% end %>
              </td>
              <td class="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
                <div class="flex items-center justify-end gap-2">
                  <.link
                    navigate={~p"/admin/users/#{user}/edit"}
                    class="p-2 text-gray-400 hover:text-primary-500 hover:bg-dark-700 rounded-md transition-colors"
                    title="Edit User"
                  >
                    <.icon name="hero-pencil-square" class="w-4 h-4" />
                  </.link>
                  <%= if user.id != @current_user.id do %>
                    <button
                      phx-click="show_delete_confirm"
                      phx-value-id={user.id}
                      class="p-2 text-gray-400 hover:text-red-500 hover:bg-dark-700 rounded-md transition-colors"
                      title="Delete User"
                    >
                      <.icon name="hero-trash" class="w-4 h-4" />
                    </button>
                  <% end %>
                </div>
              </td>
            </tr>
          </tbody>
        </table>

        <%= if @users == [] do %>
          <div class="px-6 py-12 text-center text-gray-500">
            <.icon name="hero-users" class="w-12 h-12 mx-auto mb-4 text-gray-600" />
            <p class="text-lg font-medium">No users found</p>
            <p class="text-sm">Try adjusting your search or filter criteria</p>
          </div>
        <% end %>
      </div>

      <%!-- Delete Confirmation Modal --%>
      <%= if @delete_user_id do %>
        <div
          class="fixed inset-0 z-50 overflow-y-auto"
          aria-labelledby="modal-title"
          role="dialog"
          aria-modal="true"
        >
          <div class="flex items-end justify-center min-h-screen pt-4 px-4 pb-20 text-center sm:block sm:p-0">
            <div class="fixed inset-0 bg-dark-900/75 transition-opacity" phx-click="cancel_delete">
            </div>
            <span class="hidden sm:inline-block sm:align-middle sm:h-screen">&#8203;</span>
            <div class="inline-block align-bottom bg-dark-800 rounded-lg text-left overflow-hidden shadow-xl transform transition-all sm:my-8 sm:align-middle sm:max-w-lg sm:w-full border border-dark-700">
              <div class="bg-dark-800 px-4 pt-5 pb-4 sm:p-6 sm:pb-4">
                <div class="sm:flex sm:items-start">
                  <div class="mx-auto flex-shrink-0 flex items-center justify-center h-12 w-12 rounded-full bg-red-900/20 sm:mx-0 sm:h-10 sm:w-10">
                    <.icon name="hero-exclamation-triangle" class="h-6 w-6 text-red-500" />
                  </div>
                  <div class="mt-3 text-center sm:mt-0 sm:ml-4 sm:text-left">
                    <h3 class="text-lg leading-6 font-medium text-white" id="modal-title">
                      Delete User
                    </h3>
                    <div class="mt-2">
                      <p class="text-sm text-gray-400">
                        Are you sure you want to delete this user? This action cannot be undone.
                        All data associated with this user will be permanently removed.
                      </p>
                    </div>
                  </div>
                </div>
              </div>
              <div class="bg-dark-700/50 px-4 py-3 sm:px-6 sm:flex sm:flex-row-reverse gap-2">
                <button
                  type="button"
                  phx-click="confirm_delete"
                  class="w-full inline-flex justify-center rounded-md border border-transparent shadow-sm px-4 py-2 bg-red-600 text-base font-medium text-white hover:bg-red-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-red-500 sm:ml-3 sm:w-auto sm:text-sm"
                >
                  Delete
                </button>
                <button
                  type="button"
                  phx-click="cancel_delete"
                  class="mt-3 w-full inline-flex justify-center rounded-md border border-dark-600 shadow-sm px-4 py-2 bg-dark-800 text-base font-medium text-gray-300 hover:bg-dark-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-primary-500 sm:mt-0 sm:w-auto sm:text-sm"
                >
                  Cancel
                </button>
              </div>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end
end
