defmodule ChurchappWeb.AttendanceCategoriesLive.IndexLive do
  use ChurchappWeb, :live_view

  require Ash.Query

  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "Attendance Categories")
      |> assign(:show_delete_confirm, false)
      |> assign(:delete_category_id, nil)
      |> fetch_categories()

    {:ok, socket}
  end

  def handle_event("show_delete_confirm", %{"id" => id}, socket) do
    {:noreply, assign(socket, show_delete_confirm: true, delete_category_id: id)}
  end

  def handle_event("cancel_delete", _params, socket) do
    {:noreply, assign(socket, show_delete_confirm: false, delete_category_id: nil)}
  end

  def handle_event("confirm_delete", _params, socket) do
    actor = socket.assigns[:current_user]

    case Chms.Church.get_attendance_category_by_id(socket.assigns.delete_category_id, actor: actor) do
      {:ok, category} ->
        if category.is_system do
          {:noreply,
           socket
           |> put_flash(:error, "Cannot delete system categories")
           |> assign(show_delete_confirm: false, delete_category_id: nil)}
        else
          case Chms.Church.destroy_attendance_category(category, actor: actor) do
            :ok ->
              {:noreply,
               socket
               |> put_flash(:info, "Category \"#{category.name}\" deleted successfully")
               |> assign(show_delete_confirm: false, delete_category_id: nil)
               |> fetch_categories()}

            {:error, _} ->
              {:noreply,
               socket
               |> put_flash(:error, "Failed to delete category")
               |> assign(show_delete_confirm: false, delete_category_id: nil)}
          end
        end

      {:error, _} ->
        {:noreply,
         socket
         |> put_flash(:error, "Category not found")
         |> assign(show_delete_confirm: false, delete_category_id: nil)}
    end
  end

  def handle_event("toggle_active", %{"id" => id}, socket) do
    actor = socket.assigns[:current_user]

    case Chms.Church.get_attendance_category_by_id(id, actor: actor) do
      {:ok, category} ->
        new_status = !category.active

        case Chms.Church.update_attendance_category(category, %{active: new_status}, actor: actor) do
          {:ok, updated} ->
            status_text = if updated.active, do: "activated", else: "deactivated"

            {:noreply,
             socket
             |> put_flash(:info, "Category \"#{category.name}\" #{status_text}")
             |> fetch_categories()}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Failed to update category status")}
        end

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Category not found")}
    end
  end

  defp fetch_categories(socket) do
    actor = socket.assigns[:current_user]

    query =
      Chms.Church.AttendanceCategories
      |> Ash.Query.sort(display_order: :asc)

    case Ash.read(query, actor: actor) do
      {:ok, categories} ->
        assign(socket, :categories, categories)

      {:error, _} ->
        socket
        |> assign(:categories, [])
        |> put_flash(:error, "Failed to load categories")
    end
  end

  def render(assigns) do
    ~H"""
    <div class="view-container active">
      <div class="mb-6 flex flex-col sm:flex-row justify-between items-start sm:items-center space-y-4 sm:space-y-0">
        <div>
          <h2 class="text-2xl font-bold text-white">Attendance Categories</h2>
          <p class="mt-1 text-sm text-gray-400">
            Manage categories for tracking attendance (Services, Classes, etc.)
          </p>
        </div>
        <.link
          navigate={~p"/admin/attendance-categories/new"}
          class="inline-flex items-center px-4 py-2 text-sm font-medium text-white bg-primary-500 hover:bg-primary-600 rounded-md shadow-lg shadow-primary-500/20 transition-colors"
        >
          <.icon name="hero-plus" class="mr-2 h-4 w-4" /> Add Category
        </.link>
      </div>

      <div class="bg-dark-800 rounded-lg border border-dark-700 overflow-hidden">
        <div class="overflow-x-auto">
          <table class="min-w-full divide-y divide-dark-700">
            <thead class="bg-dark-700/50">
              <tr>
                <th
                  scope="col"
                  class="px-6 py-4 text-left text-xs font-medium text-gray-400 uppercase tracking-wider"
                >
                  Color
                </th>
                <th
                  scope="col"
                  class="px-6 py-4 text-left text-xs font-medium text-gray-400 uppercase tracking-wider"
                >
                  Name
                </th>
                <th
                  scope="col"
                  class="px-6 py-4 text-left text-xs font-medium text-gray-400 uppercase tracking-wider"
                >
                  Description
                </th>
                <th
                  scope="col"
                  class="px-6 py-4 text-left text-xs font-medium text-gray-400 uppercase tracking-wider"
                >
                  Type
                </th>
                <th
                  scope="col"
                  class="px-6 py-4 text-left text-xs font-medium text-gray-400 uppercase tracking-wider"
                >
                  Status
                </th>
                <th
                  scope="col"
                  class="px-6 py-4 text-right text-xs font-medium text-gray-400 uppercase tracking-wider"
                >
                  Actions
                </th>
              </tr>
            </thead>
            <tbody class="divide-y divide-dark-700">
              <tr
                :for={category <- @categories}
                class="hover:bg-dark-700/40 transition-colors"
              >
                <td class="px-6 py-4 whitespace-nowrap">
                  <div
                    class="w-6 h-6 rounded-full border-2 border-dark-600"
                    style={"background-color: #{category.color};"}
                  >
                  </div>
                </td>
                <td class="px-6 py-4 whitespace-nowrap">
                  <div class="flex items-center">
                    <.icon
                      name={Chms.Church.AttendanceCategories.category_icon(category.name)}
                      class="h-5 w-5 mr-3 text-gray-400"
                    />
                    <span class="text-sm font-medium text-white">{category.name}</span>
                  </div>
                </td>
                <td class="px-6 py-4">
                  <span class="text-sm text-gray-400">
                    {category.description || "—"}
                  </span>
                </td>
                <td class="px-6 py-4 whitespace-nowrap">
                  <%= if category.is_system do %>
                    <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-blue-900/50 text-blue-400">
                      <.icon name="hero-lock-closed" class="h-3 w-3 mr-1" /> System
                    </span>
                  <% else %>
                    <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-gray-800 text-gray-400">
                      Custom
                    </span>
                  <% end %>
                </td>
                <td class="px-6 py-4 whitespace-nowrap">
                  <button
                    type="button"
                    phx-click="toggle_active"
                    phx-value-id={category.id}
                    class={[
                      "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium transition-colors cursor-pointer",
                      category.active && "bg-green-900/50 text-green-400 hover:bg-green-900/70",
                      !category.active && "bg-red-900/50 text-red-400 hover:bg-red-900/70"
                    ]}
                  >
                    <%= if category.active do %>
                      <.icon name="hero-check-circle" class="h-3 w-3 mr-1" /> Active
                    <% else %>
                      <.icon name="hero-x-circle" class="h-3 w-3 mr-1" /> Inactive
                    <% end %>
                  </button>
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-right">
                  <div class="flex items-center justify-end gap-2">
                    <.link
                      navigate={~p"/admin/attendance-categories/#{category.id}/edit"}
                      class="p-2 text-gray-400 hover:text-white hover:bg-dark-600 rounded-md transition-colors"
                      title="Edit category"
                    >
                      <.icon name="hero-pencil-square" class="h-4 w-4" />
                    </.link>
                    <%= if !category.is_system do %>
                      <button
                        type="button"
                        phx-click="show_delete_confirm"
                        phx-value-id={category.id}
                        class="p-2 text-red-400 hover:text-red-300 hover:bg-red-900/30 rounded-md transition-colors"
                        title="Delete category"
                      >
                        <.icon name="hero-trash" class="h-4 w-4" />
                      </button>
                    <% else %>
                      <div
                        class="p-2 text-gray-600 cursor-not-allowed"
                        title="System categories cannot be deleted"
                      >
                        <.icon name="hero-trash" class="h-4 w-4" />
                      </div>
                    <% end %>
                  </div>
                </td>
              </tr>
              <tr :if={@categories == []} class="hover:bg-dark-700/40">
                <td colspan="6" class="px-6 py-12 text-center text-gray-500">
                  <.icon name="hero-folder-open" class="h-12 w-12 mx-auto mb-4 text-gray-600" />
                  <p>No categories found</p>
                  <.link
                    navigate={~p"/admin/attendance-categories/new"}
                    class="text-primary-500 hover:text-primary-400 mt-2 inline-block"
                  >
                    Create your first category
                  </.link>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      <%!-- Delete Confirmation Modal --%>
      <%= if @show_delete_confirm do %>
        <div
          class="fixed inset-0 z-[100] overflow-y-auto"
          aria-labelledby="modal-title"
          role="dialog"
          aria-modal="true"
        >
          <div class="fixed inset-0 modal-backdrop transition-opacity"></div>
          <div class="flex min-h-full items-center justify-center p-4">
            <div class="relative transform overflow-hidden rounded-lg bg-dark-800 border border-dark-700 shadow-2xl transition-all w-full max-w-lg">
              <div class="p-6">
                <div class="flex items-start gap-4">
                  <div class="flex-shrink-0">
                    <div class="flex h-12 w-12 items-center justify-center rounded-full bg-red-900/20">
                      <.icon name="hero-exclamation-triangle" class="h-6 w-6 text-red-500" />
                    </div>
                  </div>
                  <div class="flex-1">
                    <h3 class="text-lg font-semibold text-white mb-2" id="modal-title">
                      Delete Category
                    </h3>
                    <p class="text-sm text-gray-300">
                      Are you sure you want to delete this category? Any attendance sessions using this category will need to be reassigned. This action cannot be undone.
                    </p>
                  </div>
                </div>
              </div>
              <div class="px-6 py-4 bg-dark-700/50 flex justify-end gap-3">
                <button
                  type="button"
                  phx-click="cancel_delete"
                  class="px-4 py-2 text-sm font-medium text-gray-300 bg-dark-700 hover:bg-dark-600 rounded-md border border-dark-600 transition-colors"
                >
                  Cancel
                </button>
                <button
                  type="button"
                  phx-click="confirm_delete"
                  class="px-4 py-2 text-sm font-medium text-white bg-red-600 hover:bg-red-700 rounded-md transition-colors"
                >
                  Delete Category
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
