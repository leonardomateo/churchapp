defmodule ChurchappWeb.AttendanceLive.IndexLive do
  use ChurchappWeb, :live_view

  require Ash.Query

  def mount(_params, _session, socket) do
    actor = socket.assigns[:current_user]

    # Load categories for filter dropdown
    categories =
      case Chms.Church.list_active_attendance_categories(actor: actor) do
        {:ok, cats} -> cats
        _ -> []
      end

    socket =
      socket
      |> assign(:page_title, "Attendance")
      |> assign(:categories, categories)
      |> assign(:category_filter, "")
      |> assign(:date_filter, "")
      |> assign(:show_delete_confirm, false)
      |> assign(:delete_session_id, nil)
      |> fetch_sessions()

    {:ok, socket}
  end

  def handle_event("filter_category", %{"category" => category_id}, socket) do
    socket
    |> assign(:category_filter, category_id)
    |> fetch_sessions()
    |> then(&{:noreply, &1})
  end

  def handle_event("filter_date", %{"date" => date}, socket) do
    socket
    |> assign(:date_filter, date)
    |> fetch_sessions()
    |> then(&{:noreply, &1})
  end

  def handle_event("clear_filters", _params, socket) do
    socket
    |> assign(:category_filter, "")
    |> assign(:date_filter, "")
    |> fetch_sessions()
    |> then(&{:noreply, &1})
  end

  def handle_event("show_delete_confirm", %{"id" => id}, socket) do
    {:noreply, assign(socket, show_delete_confirm: true, delete_session_id: id)}
  end

  def handle_event("cancel_delete", _params, socket) do
    {:noreply, assign(socket, show_delete_confirm: false, delete_session_id: nil)}
  end

  def handle_event("confirm_delete", _params, socket) do
    actor = socket.assigns[:current_user]

    case Chms.Church.get_attendance_session_by_id(socket.assigns.delete_session_id, actor: actor) do
      {:ok, session} ->
        case Chms.Church.destroy_attendance_session(session, actor: actor) do
          :ok ->
            {:noreply,
             socket
             |> put_flash(:info, "Attendance session deleted successfully")
             |> assign(show_delete_confirm: false, delete_session_id: nil)
             |> fetch_sessions()}

          {:error, _} ->
            {:noreply,
             socket
             |> put_flash(:error, "Failed to delete session")
             |> assign(show_delete_confirm: false, delete_session_id: nil)}
        end

      {:error, _} ->
        {:noreply,
         socket
         |> put_flash(:error, "Session not found")
         |> assign(show_delete_confirm: false, delete_session_id: nil)}
    end
  end

  defp fetch_sessions(socket) do
    actor = socket.assigns[:current_user]

    query =
      Chms.Church.AttendanceSessions
      |> Ash.Query.sort(session_datetime: :desc)
      |> Ash.Query.load(:category)
      |> Ash.Query.limit(50)

    # Apply category filter
    query =
      if socket.assigns.category_filter != "" do
        Ash.Query.filter(query, category_id == ^socket.assigns.category_filter)
      else
        query
      end

    # Apply date filter
    query =
      if socket.assigns.date_filter != "" do
        case Date.from_iso8601(socket.assigns.date_filter) do
          {:ok, date} ->
            Ash.Query.filter(
              query,
              fragment("?::date", session_datetime) == ^date
            )

          _ ->
            query
        end
      else
        query
      end

    case Ash.read(query, actor: actor) do
      {:ok, sessions} ->
        assign(socket, :sessions, sessions)

      {:error, _} ->
        socket
        |> assign(:sessions, [])
        |> put_flash(:error, "Failed to load attendance sessions")
    end
  end

  def render(assigns) do
    ~H"""
    <div class="view-container active">
      <div class="mb-6 flex flex-col sm:flex-row justify-between items-start sm:items-center space-y-4 sm:space-y-0">
        <div>
          <h2 class="text-2xl font-bold text-white">Attendance</h2>
          <p class="mt-1 text-sm text-gray-400">
            Track and manage attendance for services and classes
          </p>
        </div>
        <div class="flex items-center gap-3">
          <.link
            navigate={~p"/attendance/reports"}
            class="inline-flex items-center px-4 py-2 text-sm font-medium text-gray-300 bg-dark-700 hover:bg-dark-600 rounded-md border border-dark-600 transition-colors"
          >
            <.icon name="hero-chart-bar" class="mr-2 h-4 w-4" /> Reports
          </.link>
          <.link
            navigate={~p"/attendance/new"}
            class="inline-flex items-center px-4 py-2 text-sm font-medium text-white bg-primary-500 hover:bg-primary-600 rounded-md shadow-lg shadow-primary-500/20 transition-colors"
          >
            <.icon name="hero-plus" class="mr-2 h-4 w-4" /> Record Attendance
          </.link>
        </div>
      </div>

      <%!-- Filters --%>
      <div class="mb-6 flex flex-col sm:flex-row gap-4">
        <form phx-change="filter_category" class="flex-1 max-w-xs">
          <select
            name="category"
            value={@category_filter}
            class="w-full px-4 py-2 text-gray-200 bg-dark-800 border border-dark-700 rounded-md focus:ring-2 focus:ring-primary-500 focus:border-transparent cursor-pointer"
          >
            <option value="">All Categories</option>
            <option :for={category <- @categories} value={category.id}>
              {category.name}
            </option>
          </select>
        </form>
        <form phx-change="filter_date">
          <input
            type="date"
            name="date"
            value={@date_filter}
            class="px-4 py-2 text-gray-200 bg-dark-800 border border-dark-700 rounded-md focus:ring-2 focus:ring-primary-500 focus:border-transparent"
          />
        </form>
        <%= if @category_filter != "" || @date_filter != "" do %>
          <button
            type="button"
            phx-click="clear_filters"
            class="inline-flex items-center px-3 py-2 text-sm text-gray-400 hover:text-white transition-colors"
          >
            <.icon name="hero-x-mark" class="mr-1 h-4 w-4" /> Clear filters
          </button>
        <% end %>
      </div>

      <%!-- Sessions Table --%>
      <div class="bg-dark-800 rounded-lg border border-dark-700 overflow-hidden">
        <div class="overflow-x-auto">
          <table class="min-w-full divide-y divide-dark-700">
            <thead class="bg-dark-700/50">
              <tr>
                <th
                  scope="col"
                  class="px-6 py-4 text-left text-xs font-medium text-gray-400 uppercase tracking-wider"
                >
                  Category
                </th>
                <th
                  scope="col"
                  class="px-6 py-4 text-left text-xs font-medium text-gray-400 uppercase tracking-wider"
                >
                  Date & Time
                </th>
                <th
                  scope="col"
                  class="px-6 py-4 text-left text-xs font-medium text-gray-400 uppercase tracking-wider"
                >
                  Attendance
                </th>
                <th
                  scope="col"
                  class="px-6 py-4 text-left text-xs font-medium text-gray-400 uppercase tracking-wider"
                >
                  Notes
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
                :for={session <- @sessions}
                class="hover:bg-dark-700/40 transition-colors cursor-pointer"
                phx-click={JS.navigate(~p"/attendance/#{session.id}")}
              >
                <td class="px-6 py-4 whitespace-nowrap">
                  <div class="flex items-center">
                    <div
                      class="w-3 h-3 rounded-full mr-3"
                      style={"background-color: #{session.category.color};"}
                    >
                    </div>
                    <span class="text-sm font-medium text-white">
                      {session.category.name}
                    </span>
                  </div>
                </td>
                <td class="px-6 py-4 whitespace-nowrap">
                  <div class="text-sm text-white">
                    {format_datetime_day(session.session_datetime)}
                  </div>
                  <div class="text-xs text-gray-500">
                    {format_datetime_time(session.session_datetime)}
                  </div>
                </td>
                <td class="px-6 py-4 whitespace-nowrap">
                  <div class="flex items-center">
                    <.icon name="hero-users" class="h-4 w-4 mr-2 text-gray-400" />
                    <span class="text-sm font-medium text-white">
                      {session.total_present}
                    </span>
                    <span class="text-sm text-gray-500 ml-1">present</span>
                  </div>
                </td>
                <td class="px-6 py-4">
                  <span class="text-sm text-gray-400 truncate max-w-xs block">
                    {session.notes || "—"}
                  </span>
                </td>
                <td
                  class="px-6 py-4 whitespace-nowrap text-right"
                  phx-click={JS.dispatch("stopPropagation")}
                >
                  <div class="flex items-center justify-end gap-2">
                    <.link
                      navigate={~p"/attendance/#{session.id}"}
                      class="p-2 text-gray-400 hover:text-white hover:bg-dark-600 rounded-md transition-colors"
                      title="View details"
                    >
                      <.icon name="hero-eye" class="h-4 w-4" />
                    </.link>
                    <.link
                      navigate={~p"/attendance/#{session.id}/edit"}
                      class="p-2 text-gray-400 hover:text-white hover:bg-dark-600 rounded-md transition-colors"
                      title="Edit"
                    >
                      <.icon name="hero-pencil-square" class="h-4 w-4" />
                    </.link>
                    <button
                      type="button"
                      phx-click="show_delete_confirm"
                      phx-value-id={session.id}
                      class="p-2 text-red-400 hover:text-red-300 hover:bg-red-900/30 rounded-md transition-colors"
                      title="Delete"
                    >
                      <.icon name="hero-trash" class="h-4 w-4" />
                    </button>
                  </div>
                </td>
              </tr>
              <tr :if={@sessions == []} class="hover:bg-dark-700/40">
                <td colspan="5" class="px-6 py-12 text-center text-gray-500">
                  <.icon
                    name="hero-clipboard-document-list"
                    class="h-12 w-12 mx-auto mb-4 text-gray-600"
                  />
                  <p>No attendance sessions found</p>
                  <.link
                    navigate={~p"/attendance/new"}
                    class="text-primary-500 hover:text-primary-400 mt-2 inline-block"
                  >
                    Record your first attendance
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
                      Delete Attendance Session
                    </h3>
                    <p class="text-sm text-gray-300">
                      Are you sure you want to delete this attendance session? All individual attendance records will also be deleted. This action cannot be undone.
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
                  Delete Session
                </button>
              </div>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp format_datetime_day(datetime) do
    Calendar.strftime(datetime, "%A, %b %d, %Y")
  end

  defp format_datetime_time(datetime) do
    Calendar.strftime(datetime, "%I:%M %p")
  end
end
