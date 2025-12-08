defmodule ChurchappWeb.Admin.EventsLive do
  use ChurchappWeb, :live_view

  alias Chms.Church.Events
  alias Chms.Church.EventActivityNames

  @impl true
  def mount(_params, _session, socket) do
    events = list_events()
    activity_names = EventActivityNames.all_name_options()

    socket =
      socket
      |> assign(:page_title, "Events Management")
      |> assign(:events, events)
      |> assign(:activity_names, activity_names)
      |> assign(:open_menu_id, nil)
      |> assign(:event_to_delete, nil)
      |> assign(:show_delete_modal, false)
      |> assign(:show_new_activity_modal, false)
      |> assign(:custom_name_input, "")
      |> assign(:custom_name_error, nil)

    {:ok, socket}
  end

  @impl true
  def handle_event("toggle_menu", %{"id" => id}, socket) do
    new_id = if socket.assigns.open_menu_id == id, do: nil, else: id
    {:noreply, assign(socket, :open_menu_id, new_id)}
  end

  def handle_event("close_menu", _params, socket) do
    {:noreply, assign(socket, :open_menu_id, nil)}
  end

  def handle_event("show_delete_modal", %{"id" => id}, socket) do
    event = Enum.find(socket.assigns.events, &(&1.id == id))

    {:noreply,
     socket
     |> assign(:event_to_delete, event)
     |> assign(:show_delete_modal, true)
     |> assign(:open_menu_id, nil)}
  end

  def handle_event("close_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:event_to_delete, nil)
     |> assign(:show_delete_modal, false)
     |> assign(:show_new_activity_modal, false)
     |> assign(:custom_name_input, "")
     |> assign(:custom_name_error, nil)}
  end

  def handle_event("confirm_delete", _params, socket) do
    event = socket.assigns.event_to_delete

    case Chms.Church.destroy_event(event, actor: socket.assigns.current_user) do
      :ok ->
        events = list_events()

        {:noreply,
         socket
         |> assign(:events, events)
         |> assign(:event_to_delete, nil)
         |> assign(:show_delete_modal, false)
         |> put_flash(:info, "Event \"#{event.title}\" deleted successfully")}

      {:error, _} ->
        {:noreply,
         socket
         |> assign(:show_delete_modal, false)
         |> put_flash(:error, "Failed to delete event")}
    end
  end

  # New Activity Name Modal handlers
  def handle_event("open_new_activity_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_new_activity_modal, true)
     |> assign(:custom_name_input, "")
     |> assign(:custom_name_error, nil)}
  end

  def handle_event("validate_custom_name", %{"custom_name" => value}, socket) do
    {:noreply,
     socket
     |> assign(:custom_name_input, value)
     |> assign(:custom_name_error, nil)}
  end

  def handle_event("save_custom_name", %{"custom_name" => custom_name}, socket) do
    custom_name = String.trim(custom_name)

    if custom_name == "" do
      {:noreply,
       socket
       |> assign(:custom_name_error, "Please enter an event/activity name")}
    else
      # Check if name already exists
      existing_names = Enum.map(socket.assigns.activity_names, fn {name, _} -> String.downcase(name) end)

      if String.downcase(custom_name) in existing_names do
        {:noreply,
         socket
         |> assign(:custom_name_error, "This activity name already exists")}
      else
        # Add the new name to the list
        updated_names = socket.assigns.activity_names ++ [{custom_name, custom_name}]

        {:noreply,
         socket
         |> assign(:activity_names, updated_names)
         |> assign(:show_new_activity_modal, false)
         |> assign(:custom_name_input, "")
         |> put_flash(:info, "Activity \"#{custom_name}\" added successfully. Create an event to use it.")}
      end
    end
  end

  defp list_events do
    Events
    |> Ash.Query.sort(start_time: :desc)
    |> Ash.read!(authorize?: false)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <div class="flex items-center justify-between">
        <div>
          <h2 class="text-2xl font-bold text-white">Events Management</h2>
          <p class="mt-1 text-sm text-gray-400">
            Manage all events and activities
          </p>
        </div>
        <button
          type="button"
          phx-click="open_new_activity_modal"
          class="inline-flex items-center px-4 py-2 text-sm font-medium text-white bg-primary-500 hover:bg-primary-600 rounded-md shadow-sm transition-colors"
        >
          <.icon name="hero-plus" class="mr-2 h-4 w-4" /> New Activity
        </button>
      </div>

      <%!-- Activity Names Section --%>
      <div class="bg-dark-800 rounded-lg border border-dark-700 p-4">
        <h3 class="text-sm font-medium text-gray-300 mb-3">Available Activities</h3>
        <div class="flex flex-wrap gap-2">
          <%= if @activity_names == [] do %>
            <p class="text-sm text-gray-500">No activities yet. Click "New Activity" to add one.</p>
          <% else %>
            <%= for {name, _value} <- @activity_names do %>
              <span class="inline-flex items-center px-3 py-1 rounded-full text-sm font-medium bg-dark-700 text-gray-300 border border-dark-600">
                {name}
              </span>
            <% end %>
          <% end %>
        </div>
      </div>

      <%!-- Events Table --%>
      <div class="bg-dark-800 rounded-lg border border-dark-700 overflow-hidden">
        <div class="px-6 py-4 border-b border-dark-700">
          <h3 class="text-lg font-medium text-white">Scheduled Events</h3>
        </div>
        <%= if @events == [] do %>
          <div class="p-8 text-center">
            <.icon name="hero-calendar" class="mx-auto h-12 w-12 text-gray-500" />
            <h3 class="mt-2 text-sm font-medium text-white">No events scheduled</h3>
            <p class="mt-1 text-sm text-gray-400">Events created from the calendar will appear here.</p>
          </div>
        <% else %>
          <table class="min-w-full divide-y divide-dark-700">
            <thead class="bg-dark-700/50">
              <tr>
                <th
                  scope="col"
                  class="px-6 py-3 text-left text-xs font-medium text-gray-400 uppercase tracking-wider"
                >
                  Event Name
                </th>
                <th
                  scope="col"
                  class="px-6 py-3 text-left text-xs font-medium text-gray-400 uppercase tracking-wider"
                >
                  Date
                </th>
                <th
                  scope="col"
                  class="px-6 py-3 text-left text-xs font-medium text-gray-400 uppercase tracking-wider"
                >
                  Time
                </th>
                <th
                  scope="col"
                  class="px-6 py-3 text-left text-xs font-medium text-gray-400 uppercase tracking-wider"
                >
                  Location
                </th>
                <th scope="col" class="relative px-6 py-3">
                  <span class="sr-only">Actions</span>
                </th>
              </tr>
            </thead>
            <tbody class="divide-y divide-dark-700">
              <%= for {event, index} <- Enum.with_index(@events) do %>
                <tr class="hover:bg-dark-700/30 transition-colors">
                  <td class="px-6 py-4 whitespace-nowrap">
                    <div class="flex items-center">
                      <div
                        class="w-3 h-3 rounded-full mr-3 flex-shrink-0"
                        style={"background-color: #{event.color || "#06b6d4"}"}
                      >
                      </div>
                      <div class="text-sm font-medium text-white">{event.title}</div>
                    </div>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-300">
                    {format_date(event.start_time)}
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-300">
                    <%= if event.all_day do %>
                      <span class="text-gray-400">All day</span>
                    <% else %>
                      {format_time(event.start_time)} - {format_time(event.end_time)}
                    <% end %>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-300">
                    {event.location || "-"}
                  </td>
                  <td class="px-6 py-4 text-right">
                    <div class="flex items-center justify-end relative">
                      <button
                        type="button"
                        phx-click="toggle_menu"
                        phx-value-id={event.id}
                        class="p-2 text-gray-400 hover:text-white rounded-md hover:bg-dark-700 transition-colors"
                        aria-label="Actions menu"
                      >
                        <.icon name="hero-ellipsis-vertical" class="h-5 w-5" />
                      </button>

                      <%!-- Dropdown Menu --%>
                      <div
                        :if={@open_menu_id == event.id}
                        phx-click-away="close_menu"
                        class={[
                          "absolute right-0 w-48 rounded-md shadow-lg bg-dark-700 ring-1 ring-dark-600 z-50",
                          if(index >= length(@events) - 2,
                            do: "bottom-full mb-2",
                            else: "top-full mt-2"
                          )
                        ]}
                      >
                        <div class="py-1" role="menu" aria-orientation="vertical">
                          <.link
                            navigate={~p"/events/#{event}"}
                            class="flex items-center px-4 py-2 text-sm text-gray-300 hover:bg-dark-600 hover:text-white transition-colors"
                            role="menuitem"
                          >
                            <.icon name="hero-eye" class="mr-3 h-4 w-4" /> View Details
                          </.link>

                          <.link
                            navigate={~p"/events/#{event}/edit"}
                            class="flex items-center px-4 py-2 text-sm text-gray-300 hover:bg-dark-600 hover:text-white transition-colors"
                            role="menuitem"
                          >
                            <.icon name="hero-pencil-square" class="mr-3 h-4 w-4" /> Edit Event
                          </.link>

                          <button
                            type="button"
                            phx-click="show_delete_modal"
                            phx-value-id={event.id}
                            class="flex items-center w-full px-4 py-2 text-sm text-red-400 hover:bg-dark-600 hover:text-red-300 transition-colors text-left"
                            role="menuitem"
                          >
                            <.icon name="hero-trash" class="mr-3 h-4 w-4" /> Delete Event
                          </button>
                        </div>
                      </div>
                    </div>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        <% end %>
      </div>

      <%!-- New Activity Name Modal --%>
      <%= if @show_new_activity_modal do %>
        <div
          class="fixed inset-0 z-50 overflow-y-auto"
          phx-window-keydown="close_modal"
          phx-key="escape"
        >
          <div class="flex min-h-screen items-center justify-center p-4">
            <%!-- Backdrop --%>
            <div class="fixed inset-0 bg-black/50 transition-opacity" phx-click="close_modal">
            </div>
            <%!-- Modal --%>
            <div class="relative bg-dark-800 rounded-lg shadow-xl border border-dark-700 w-full max-w-md p-6 z-10">
              <div class="flex items-center justify-between mb-4">
                <h3 class="text-lg font-semibold text-white flex items-center">
                  <.icon name="hero-plus-circle" class="mr-2 h-5 w-5 text-primary-500" />
                  Add New Activity
                </h3>
                <button
                  type="button"
                  phx-click="close_modal"
                  class="text-gray-400 hover:text-white transition-colors"
                >
                  <.icon name="hero-x-mark" class="h-5 w-5" />
                </button>
              </div>

              <div class="mb-6">
                <label for="modal-custom-name" class="block text-sm font-medium text-gray-400 mb-2">
                  Activity Name <span class="text-red-500">*</span>
                </label>
                <form phx-change="validate_custom_name">
                  <input
                    type="text"
                    id="modal-custom-name"
                    name="custom_name"
                    value={@custom_name_input}
                    placeholder="e.g., Sunday Worship, Bible Study, Youth Ministry..."
                    class={[
                      "block w-full px-3 py-2 text-white bg-dark-900 border rounded-md shadow-sm sm:text-sm focus:ring-2 focus:ring-primary-500 focus:outline-none transition-colors",
                      @custom_name_error && "border-red-500",
                      !@custom_name_error && "border-dark-700"
                    ]}
                    phx-hook="AutoFocus"
                  />
                </form>
                <%= if @custom_name_error do %>
                  <p class="mt-2 text-sm text-red-400">{@custom_name_error}</p>
                <% end %>
                <p class="mt-2 text-xs text-gray-500">
                  This activity will be available when creating events on the calendar.
                </p>
              </div>

              <div class="flex justify-end space-x-3">
                <button
                  type="button"
                  phx-click="close_modal"
                  class="px-4 py-2 text-sm font-medium text-gray-300 bg-dark-700 hover:bg-dark-600 rounded-md transition-colors"
                >
                  Cancel
                </button>
                <button
                  type="button"
                  phx-click="save_custom_name"
                  phx-value-custom_name={@custom_name_input}
                  class="px-4 py-2 text-sm font-medium text-white bg-primary-500 hover:bg-primary-600 rounded-md shadow-sm transition-colors"
                >
                  <span class="flex items-center">
                    <.icon name="hero-check" class="mr-1 h-4 w-4" /> Save Activity
                  </span>
                </button>
              </div>
            </div>
          </div>
        </div>
      <% end %>

      <%!-- Delete Confirmation Modal --%>
      <%= if @show_delete_modal && @event_to_delete do %>
        <div
          class="fixed inset-0 z-50 overflow-y-auto"
          phx-window-keydown="close_modal"
          phx-key="escape"
        >
          <div class="flex min-h-screen items-center justify-center p-4">
            <%!-- Backdrop --%>
            <div class="fixed inset-0 bg-black/50 transition-opacity" phx-click="close_modal">
            </div>
            <%!-- Modal --%>
            <div class="relative bg-dark-800 rounded-lg shadow-xl border border-dark-700 w-full max-w-md p-6 z-10">
              <div class="flex items-center justify-center w-12 h-12 mx-auto mb-4 rounded-full bg-red-500/10">
                <.icon name="hero-exclamation-triangle" class="h-6 w-6 text-red-500" />
              </div>
              <h3 class="text-lg font-semibold text-white text-center mb-2">
                Delete Event
              </h3>
              <p class="text-sm text-gray-400 text-center mb-6">
                Are you sure you want to delete "<span class="text-white font-medium">{@event_to_delete.title}</span>"?
                This action cannot be undone.
              </p>
              <div class="flex justify-center space-x-3">
                <button
                  type="button"
                  phx-click="close_modal"
                  class="px-4 py-2 text-sm font-medium text-gray-300 bg-dark-700 hover:bg-dark-600 rounded-md transition-colors"
                >
                  Cancel
                </button>
                <button
                  type="button"
                  phx-click="confirm_delete"
                  class="px-4 py-2 text-sm font-medium text-white bg-red-500 hover:bg-red-600 rounded-md shadow-sm transition-colors"
                >
                  Delete
                </button>
              </div>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp format_date(nil), do: "-"

  defp format_date(%DateTime{} = dt) do
    Calendar.strftime(dt, "%b %d, %Y")
  end

  defp format_time(nil), do: "-"

  defp format_time(%DateTime{} = dt) do
    Calendar.strftime(dt, "%I:%M %p")
  end
end
