defmodule ChurchappWeb.AttendanceLive.ShowLive do
  use ChurchappWeb, :live_view

  require Ash.Query

  def mount(%{"id" => id}, _session, socket) do
    actor = socket.assigns[:current_user]

    case load_session(id, actor) do
      {:ok, session} ->
        socket =
          socket
          |> assign(
            :page_title,
            "#{session.category.name} - #{format_date(session.session_datetime)}"
          )
          |> assign(:session, session)
          |> assign(:show_delete_confirm, false)

        {:ok, socket}

      {:error, _} ->
        {:ok,
         socket
         |> put_flash(:error, "Session not found")
         |> push_navigate(to: ~p"/attendance")}
    end
  end

  defp load_session(id, actor) do
    Chms.Church.AttendanceSessions
    |> Ash.Query.filter(id == ^id)
    |> Ash.Query.load([:category, records: [:congregant]])
    |> Ash.read_one(actor: actor)
  end

  def handle_event("show_delete_confirm", _params, socket) do
    {:noreply, assign(socket, :show_delete_confirm, true)}
  end

  def handle_event("cancel_delete", _params, socket) do
    {:noreply, assign(socket, :show_delete_confirm, false)}
  end

  def handle_event("confirm_delete", _params, socket) do
    actor = socket.assigns[:current_user]

    case Chms.Church.destroy_attendance_session(socket.assigns.session, actor: actor) do
      :ok ->
        {:noreply,
         socket
         |> put_flash(:info, "Attendance session deleted successfully")
         |> push_navigate(to: ~p"/attendance")}

      {:error, _} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to delete session")
         |> assign(:show_delete_confirm, false)}
    end
  end

  defp format_date(datetime) do
    Calendar.strftime(datetime, "%b %d, %Y")
  end

  def render(assigns) do
    # Sort records by congregant name
    sorted_records =
      assigns.session.records
      |> Enum.sort_by(fn r -> "#{r.congregant.first_name} #{r.congregant.last_name}" end)

    assigns = assign(assigns, :sorted_records, sorted_records)

    ~H"""
    <div class="view-container active">
      <div class="mb-6">
        <.link
          navigate={~p"/attendance"}
          class="inline-flex items-center text-sm text-gray-400 hover:text-white transition-colors"
        >
          <.icon name="hero-arrow-left" class="mr-2 h-4 w-4" /> Back to Attendance
        </.link>
      </div>

      <div class="max-w-4xl mx-auto">
        <%!-- Header --%>
        <div class="mb-6 flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4">
          <div>
            <div class="flex items-center gap-3 mb-2">
              <div
                class="w-4 h-4 rounded-full"
                style={"background-color: #{@session.category.color};"}
              >
              </div>
              <span class="text-sm font-medium text-gray-400">
                {@session.category.name}
              </span>
            </div>
            <h2 class="text-2xl font-bold text-white">
              {format_datetime_full(@session.session_datetime)}
            </h2>
          </div>
          <div class="flex items-center gap-3">
            <.link
              navigate={~p"/attendance/#{@session.id}/edit"}
              class="inline-flex items-center px-4 py-2 text-sm font-medium text-gray-300 bg-dark-700 hover:bg-dark-600 rounded-md border border-dark-600 transition-colors"
            >
              <.icon name="hero-pencil-square" class="mr-2 h-4 w-4" /> Edit
            </.link>
            <button
              type="button"
              phx-click="show_delete_confirm"
              class="inline-flex items-center px-4 py-2 text-sm font-medium text-red-400 bg-red-900/20 hover:bg-red-900/40 rounded-md border border-red-500/30 transition-colors"
            >
              <.icon name="hero-trash" class="mr-2 h-4 w-4" /> Delete
            </button>
          </div>
        </div>

        <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
          <%!-- Left Column: Details --%>
          <div class="lg:col-span-1 space-y-6">
            <%!-- Stats Card --%>
            <div class="bg-dark-800 rounded-lg border border-dark-700 p-6">
              <h3 class="text-lg font-semibold text-white mb-4">Summary</h3>
              <div class="space-y-4">
                <div class="flex items-center justify-between">
                  <span class="text-gray-400">Total Present</span>
                  <span class="text-3xl font-bold text-primary-500">
                    {@session.total_present}
                  </span>
                </div>
                <div class="border-t border-dark-600 pt-4 space-y-2">
                  <div class="flex items-center text-sm">
                    <.icon name="hero-calendar" class="h-4 w-4 mr-2 text-gray-500" />
                    <span class="text-gray-400">
                      {Calendar.strftime(@session.session_datetime, "%A, %B %d, %Y")}
                    </span>
                  </div>
                  <div class="flex items-center text-sm">
                    <.icon name="hero-clock" class="h-4 w-4 mr-2 text-gray-500" />
                    <span class="text-gray-400">
                      {Calendar.strftime(@session.session_datetime, "%I:%M %p")}
                    </span>
                  </div>
                </div>
              </div>
            </div>

            <%!-- Notes Card --%>
            <div :if={@session.notes} class="bg-dark-800 rounded-lg border border-dark-700 p-6">
              <h3 class="text-lg font-semibold text-white mb-3">Notes</h3>
              <p class="text-gray-400 text-sm whitespace-pre-wrap">{@session.notes}</p>
            </div>
          </div>

          <%!-- Right Column: Attendees List --%>
          <div class="lg:col-span-2">
            <div class="bg-dark-800 rounded-lg border border-dark-700 p-6">
              <div class="flex items-center justify-between mb-4">
                <h3 class="text-lg font-semibold text-white">
                  Attendees ({length(@sorted_records)})
                </h3>
              </div>

              <div class="space-y-2">
                <div
                  :for={record <- @sorted_records}
                  class="flex items-center p-3 bg-dark-700/50 rounded-lg"
                >
                  <div class="flex-shrink-0 w-5 h-5 rounded-full bg-green-500/20 flex items-center justify-center mr-3">
                    <.icon name="hero-check" class="h-3 w-3 text-green-400" />
                  </div>
                  <.avatar
                    image={record.congregant.image}
                    first_name={record.congregant.first_name}
                    last_name={record.congregant.last_name}
                    size="sm"
                  />
                  <div class="ml-3 flex-1 min-w-0">
                    <.link
                      navigate={~p"/congregants/#{record.congregant.id}"}
                      class="text-sm font-medium text-white hover:text-primary-400 transition-colors"
                    >
                      {record.congregant.first_name} {record.congregant.last_name}
                    </.link>
                    <p class="text-xs text-gray-500">
                      ID: {record.congregant.member_id}
                    </p>
                  </div>
                  <span :if={record.notes} class="text-xs text-gray-500 ml-2" title={record.notes}>
                    <.icon name="hero-chat-bubble-left" class="h-4 w-4" />
                  </span>
                </div>
                <div :if={@sorted_records == []} class="py-8 text-center text-gray-500">
                  <.icon name="hero-user-group" class="h-8 w-8 mx-auto mb-2 text-gray-600" />
                  <p>No attendance records</p>
                </div>
              </div>
            </div>
          </div>
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
                      Are you sure you want to delete this attendance session for
                      <strong>{@session.category.name}</strong>
                      on <strong>{format_datetime_full(@session.session_datetime)}</strong>? All {@session.total_present} attendance records will also be deleted. This action cannot be undone.
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

  defp format_datetime_full(datetime) do
    Calendar.strftime(datetime, "%A, %B %d, %Y at %I:%M %p")
  end
end
