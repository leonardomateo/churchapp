defmodule ChurchappWeb.FamilyRelationshipTypesLive.IndexLive do
  use ChurchappWeb, :live_view

  require Ash.Query

  def mount(_params, _session, socket) do
    actor = socket.assigns[:current_user]

    socket =
      socket
      |> assign(:page_title, "Family Relationship Types")
      |> assign(:search_query, "")
      |> assign(:status_filter, "")
      |> assign(:delete_type_id, nil)
      |> fetch_relationship_types(actor)

    {:ok, socket}
  end

  def handle_event("search", %{"query" => query}, socket) do
    actor = socket.assigns[:current_user]

    socket
    |> assign(:search_query, query)
    |> fetch_relationship_types(actor)
    |> then(&{:noreply, &1})
  end

  def handle_event("filter_status", %{"status" => status}, socket) do
    actor = socket.assigns[:current_user]

    socket
    |> assign(:status_filter, status)
    |> fetch_relationship_types(actor)
    |> then(&{:noreply, &1})
  end

  def handle_event("show_delete_confirm", %{"id" => id}, socket) do
    {:noreply, assign(socket, :delete_type_id, id)}
  end

  def handle_event("cancel_delete", _params, socket) do
    {:noreply, assign(socket, :delete_type_id, nil)}
  end

  def handle_event("confirm_delete", _params, socket) do
    actor = socket.assigns[:current_user]

    case Chms.Church.get_family_relationship_type_by_id(socket.assigns.delete_type_id,
           actor: actor
         ) do
      {:ok, type} ->
        case Chms.Church.destroy_family_relationship_type(type, actor: actor) do
          :ok ->
            socket
            |> put_flash(:info, "Relationship type deleted successfully")
            |> assign(:delete_type_id, nil)
            |> fetch_relationship_types(actor)
            |> then(&{:noreply, &1})

          {:error, _} ->
            {:noreply,
             socket
             |> put_flash(
               :error,
               "Failed to delete relationship type. It may be in use by family relationships."
             )
             |> assign(:delete_type_id, nil)}
        end

      {:error, _} ->
        {:noreply,
         socket
         |> put_flash(:error, "Relationship type not found")
         |> assign(:delete_type_id, nil)}
    end
  end

  defp fetch_relationship_types(socket, actor) do
    query = Chms.Church.FamilyRelationshipType

    query =
      if socket.assigns.search_query != "" do
        search_term = String.downcase(socket.assigns.search_query)

        Ash.Query.filter(
          query,
          contains(string_downcase(display_name), ^search_term) or
            contains(string_downcase(name), ^search_term)
        )
      else
        query
      end

    query =
      case socket.assigns.status_filter do
        "active" ->
          Ash.Query.filter(query, is_active == true)

        "inactive" ->
          Ash.Query.filter(query, is_active == false)

        _ ->
          query
      end

    query = Ash.Query.sort(query, sort_order: :asc, display_name: :asc)

    case Chms.Church.list_family_relationship_types(query: query, actor: actor) do
      {:ok, types} ->
        assign(socket, :relationship_types, types)

      {:error, _} ->
        socket
        |> assign(:relationship_types, [])
        |> put_flash(:error, "Failed to load relationship types")
    end
  end

  defp status_badge_class(is_active) do
    if is_active do
      "bg-green-900/60 text-green-400 border-green-800"
    else
      "bg-gray-800 text-gray-400 border-gray-700"
    end
  end

  def render(assigns) do
    ~H"""
    <div class="view-container active">
      <div class="mb-6 flex flex-col sm:flex-row justify-between items-start sm:items-center space-y-4 sm:space-y-0">
        <div class="flex items-center gap-4">
          <h2 class="text-2xl font-bold text-white">Family Relationship Types</h2>
        </div>
        <.link
          navigate={~p"/admin/family-relationship-types/new"}
          class="inline-flex items-center px-4 py-2 text-sm font-medium text-white bg-primary-500 hover:bg-primary-600 rounded-md shadow-lg shadow-primary-500/20 transition-colors"
        >
          <.icon name="hero-plus" class="mr-2 h-4 w-4" /> Add New Type
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
              placeholder="Search by name..."
              phx-debounce="300"
              class="w-full px-4 py-3 text-gray-200 bg-dark-800 border border-dark-700 rounded-md focus:ring-2 focus:ring-primary-500 focus:border-transparent hover:bg-dark-700 hover:border-dark-600 transition-colors"
            />
          </form>
        </div>

        <form phx-change="filter_status">
          <select
            name="status"
            class="h-[50px] px-4 py-3 text-gray-200 bg-dark-800 border border-dark-700 rounded-md focus:ring-2 focus:ring-primary-500 focus:border-transparent hover:bg-dark-700 hover:border-dark-600 transition-colors cursor-pointer"
          >
            <option value="" selected={@status_filter == ""}>All Status</option>
            <option value="active" selected={@status_filter == "active"}>Active</option>
            <option value="inactive" selected={@status_filter == "inactive"}>Inactive</option>
          </select>
        </form>
      </div>

      <%!-- Relationship Types Table --%>
      <div class="bg-dark-800 rounded-lg border border-dark-700 overflow-hidden">
        <table class="min-w-full divide-y divide-dark-700">
          <thead class="bg-dark-700/50">
            <tr>
              <th class="px-6 py-4 text-left text-xs font-medium text-gray-400 uppercase tracking-wider">
                Display Name
              </th>
              <th class="px-6 py-4 text-left text-xs font-medium text-gray-400 uppercase tracking-wider">
                System Name
              </th>
              <th class="px-6 py-4 text-left text-xs font-medium text-gray-400 uppercase tracking-wider">
                Inverse
              </th>
              <th class="px-6 py-4 text-left text-xs font-medium text-gray-400 uppercase tracking-wider">
                Order
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
              :for={type <- @relationship_types}
              class="hover:bg-dark-700/40 transition-all duration-200"
            >
              <td class="px-6 py-4 whitespace-nowrap">
                <div class="flex items-center">
                  <div class="flex-shrink-0 h-10 w-10 rounded-full bg-primary-500/20 flex items-center justify-center">
                    <.icon name="hero-heart" class="w-5 h-5 text-primary-400" />
                  </div>
                  <div class="ml-4">
                    <div class="text-sm font-medium text-white">
                      {type.display_name}
                    </div>
                  </div>
                </div>
              </td>
              <td class="px-6 py-4 whitespace-nowrap">
                <span class="text-sm text-gray-400 font-mono">{type.name}</span>
              </td>
              <td class="px-6 py-4 whitespace-nowrap">
                <span class="text-sm text-gray-400">{type.inverse_name || "-"}</span>
              </td>
              <td class="px-6 py-4 whitespace-nowrap">
                <span class="text-sm text-gray-400">{type.sort_order}</span>
              </td>
              <td class="px-6 py-4 whitespace-nowrap">
                <span class={[
                  "px-3 py-1 inline-flex text-xs font-medium rounded-full border",
                  status_badge_class(type.is_active)
                ]}>
                  {if type.is_active, do: "Active", else: "Inactive"}
                </span>
              </td>
              <td class="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
                <div class="flex items-center justify-end gap-2">
                  <.link
                    navigate={~p"/admin/family-relationship-types/#{type}/edit"}
                    class="p-2 text-gray-400 hover:text-primary-500 hover:bg-dark-700 rounded-md transition-colors"
                    title="Edit Type"
                  >
                    <.icon name="hero-pencil-square" class="w-4 h-4" />
                  </.link>
                  <button
                    phx-click="show_delete_confirm"
                    phx-value-id={type.id}
                    class="p-2 text-gray-400 hover:text-red-500 hover:bg-dark-700 rounded-md transition-colors"
                    title="Delete Type"
                  >
                    <.icon name="hero-trash" class="w-4 h-4" />
                  </button>
                </div>
              </td>
            </tr>
          </tbody>
        </table>

        <%= if @relationship_types == [] do %>
          <div class="px-6 py-12 text-center text-gray-500">
            <.icon name="hero-heart" class="w-12 h-12 mx-auto mb-4 text-gray-600" />
            <p class="text-lg font-medium">No relationship types found</p>
            <p class="text-sm">Try adjusting your search or filter criteria</p>
          </div>
        <% end %>
      </div>

      <%!-- Delete Confirmation Modal --%>
      <%= if @delete_type_id do %>
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
                      Delete Relationship Type
                    </h3>
                    <div class="mt-2">
                      <p class="text-sm text-gray-400">
                        Are you sure you want to delete this relationship type? This action cannot be undone.
                        If this type is currently in use by family relationships, deletion will fail.
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
