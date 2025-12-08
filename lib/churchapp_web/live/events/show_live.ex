defmodule ChurchappWeb.EventsLive.ShowLive do
  use ChurchappWeb, :live_view

  alias Chms.Church.Events

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    case Chms.Church.get_event_by_id(id) do
      {:ok, event} ->
        is_admin = is_admin?(socket.assigns[:current_user])

        {:ok,
         socket
         |> assign(:page_title, event.title)
         |> assign(:event, event)
         |> assign(:is_admin, is_admin)
         |> assign(:show_delete_modal, false)}

      {:error, _} ->
        {:ok,
         socket
         |> put_flash(:error, "Event not found")
         |> push_navigate(to: ~p"/events")}
    end
  end

  @impl true
  def handle_event("show_delete_modal", _params, socket) do
    {:noreply, assign(socket, :show_delete_modal, true)}
  end

  def handle_event("cancel_delete", _params, socket) do
    {:noreply, assign(socket, :show_delete_modal, false)}
  end

  def handle_event("confirm_delete", _params, socket) do
    case Chms.Church.destroy_event(socket.assigns.event, actor: socket.assigns.current_user) do
      :ok ->
        {:noreply,
         socket
         |> put_flash(:info, "Event deleted successfully")
         |> push_navigate(to: ~p"/events")}

      {:error, _} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to delete event")
         |> assign(:show_delete_modal, false)}
    end
  end

  def handle_event("export_single_ical", _params, socket) do
    event = socket.assigns.event
    ical_content = Chms.Church.IcalExport.generate_ical_single(event)
    filename = "#{slugify(event.title)}.ics"

    {:noreply, push_event(socket, "download_ical", %{content: ical_content, filename: filename})}
  end

  defp is_admin?(nil), do: false
  defp is_admin?(user), do: user.role in [:super_admin, :admin, :staff]

  defp slugify(title) do
    title
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9\s-]/, "")
    |> String.replace(~r/\s+/, "-")
    |> String.slice(0, 50)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="view-container active" phx-hook="IcalDownload" id="event-show-container">
      <div class="mb-6">
        <.link
          navigate={~p"/events"}
          class="inline-flex items-center text-sm text-gray-400 hover:text-white transition-colors"
        >
          <.icon name="hero-arrow-left" class="mr-2 h-4 w-4" /> Back to Calendar
        </.link>
      </div>

      <div class="max-w-2xl">
        <%!-- Event Header --%>
        <div class="mb-6 flex flex-col sm:flex-row justify-between items-start gap-4">
          <div class="flex items-start gap-4">
            <div
              class="w-4 h-4 rounded-full mt-2 flex-shrink-0"
              style={"background-color: #{@event.color || Events.default_color_for_type(@event.event_type)};"}
            >
            </div>
            <div>
              <h2 class="text-2xl font-bold text-white">{@event.title}</h2>
              <p class="mt-1 text-sm text-gray-400">
                {Events.event_type_label(@event.event_type)}
                <%= if @event.is_recurring do %>
                  <span class="ml-2 inline-flex items-center text-primary-500">
                    <.icon name="hero-arrow-path" class="h-4 w-4 mr-1" /> Recurring
                  </span>
                <% end %>
              </p>
            </div>
          </div>

          <div class="flex items-center gap-2">
            <button
              type="button"
              phx-click="export_single_ical"
              class="inline-flex items-center px-3 py-2 text-sm font-medium text-gray-300 bg-dark-700 hover:bg-dark-600 rounded-md border border-dark-600 transition-colors"
            >
              <.icon name="hero-arrow-down-tray" class="mr-2 h-4 w-4" /> Export
            </button>

            <%= if @is_admin do %>
              <.link
                navigate={~p"/events/#{@event}/edit"}
                class="inline-flex items-center px-3 py-2 text-sm font-medium text-gray-300 bg-dark-700 hover:bg-dark-600 rounded-md border border-dark-600 transition-colors"
              >
                <.icon name="hero-pencil-square" class="mr-2 h-4 w-4" /> Edit
              </.link>

              <button
                type="button"
                phx-click="show_delete_modal"
                class="inline-flex items-center px-3 py-2 text-sm font-medium text-red-400 bg-dark-700 hover:bg-red-900/30 rounded-md border border-dark-600 hover:border-red-800 transition-colors"
              >
                <.icon name="hero-trash" class="mr-2 h-4 w-4" /> Delete
              </button>
            <% end %>
          </div>
        </div>

        <%!-- Event Details Card --%>
        <div class="bg-dark-800 rounded-lg border border-dark-700 overflow-hidden">
          <%!-- Date & Time Section --%>
          <div class="p-6 border-b border-dark-700">
            <h3 class="text-sm font-medium text-gray-400 uppercase tracking-wider mb-4">
              Date & Time
            </h3>
            <div class="flex items-start gap-4">
              <div class="p-3 bg-dark-700 rounded-lg">
                <.icon name="hero-calendar-days" class="h-6 w-6 text-primary-500" />
              </div>
              <div>
                <p class="text-lg font-semibold text-white">
                  {format_date(@event.start_time)}
                </p>
                <%= if @event.all_day do %>
                  <p class="text-sm text-gray-400">All-day event</p>
                <% else %>
                  <p class="text-sm text-gray-400">
                    {format_time(@event.start_time)} - {format_time(@event.end_time)}
                  </p>
                <% end %>
                <%= if @event.is_recurring && @event.recurrence_rule do %>
                  <p class="mt-2 text-sm text-primary-400">
                    <.icon name="hero-arrow-path" class="inline h-4 w-4 mr-1" />
                    {format_recurrence(@event.recurrence_rule)}
                    <%= if @event.recurrence_end_date do %>
                      <span class="text-gray-500">
                        until {Calendar.strftime(@event.recurrence_end_date, "%B %d, %Y")}
                      </span>
                    <% end %>
                  </p>
                <% end %>
              </div>
            </div>
          </div>

          <%!-- Location Section --%>
          <%= if @event.location && @event.location != "" do %>
            <div class="p-6 border-b border-dark-700">
              <h3 class="text-sm font-medium text-gray-400 uppercase tracking-wider mb-4">
                Location
              </h3>
              <div class="flex items-start gap-4">
                <div class="p-3 bg-dark-700 rounded-lg">
                  <.icon name="hero-map-pin" class="h-6 w-6 text-primary-500" />
                </div>
                <div>
                  <p class="text-lg font-medium text-white">{@event.location}</p>
                </div>
              </div>
            </div>
          <% end %>

          <%!-- Description Section --%>
          <%= if @event.description && @event.description != "" do %>
            <div class="p-6 border-b border-dark-700">
              <h3 class="text-sm font-medium text-gray-400 uppercase tracking-wider mb-4">
                Description
              </h3>
              <p class="text-gray-300 whitespace-pre-wrap">{@event.description}</p>
            </div>
          <% end %>

          <%!-- Metadata Section --%>
          <div class="p-6 bg-dark-700/30">
            <div class="flex flex-wrap gap-6 text-sm text-gray-500">
              <div>
                <span class="font-medium">Created:</span>
                {Calendar.strftime(@event.inserted_at, "%B %d, %Y at %I:%M %p")}
              </div>
              <%= if @event.updated_at != @event.inserted_at do %>
                <div>
                  <span class="font-medium">Last updated:</span>
                  {Calendar.strftime(@event.updated_at, "%B %d, %Y at %I:%M %p")}
                </div>
              <% end %>
            </div>
          </div>
        </div>
      </div>

      <%!-- Delete Confirmation Modal --%>
      <%= if @show_delete_modal do %>
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
                      Delete Event
                    </h3>
                    <p class="text-sm text-gray-300">
                      Are you sure you want to delete "<span class="font-medium">{@event.title}</span>"?
                      <%= if @event.is_recurring do %>
                        This will delete all occurrences of this recurring event.
                      <% end %>
                      This action cannot be undone.
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
                  Delete Event
                </button>
              </div>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp format_date(%DateTime{} = dt) do
    Calendar.strftime(dt, "%A, %B %d, %Y")
  end

  defp format_time(%DateTime{} = dt) do
    Calendar.strftime(dt, "%I:%M %p")
  end

  defp format_recurrence(rrule) when is_binary(rrule) do
    cond do
      String.contains?(rrule, "FREQ=WEEKLY") && String.contains?(rrule, "BYDAY=SU") ->
        "Repeats every Sunday"

      String.contains?(rrule, "FREQ=WEEKLY") && String.contains?(rrule, "BYDAY=WE") ->
        "Repeats every Wednesday"

      String.contains?(rrule, "FREQ=WEEKLY") && String.contains?(rrule, "BYDAY=FR") ->
        "Repeats every Friday"

      String.contains?(rrule, "FREQ=WEEKLY") && String.contains?(rrule, "INTERVAL=2") ->
        "Repeats every 2 weeks"

      String.contains?(rrule, "FREQ=WEEKLY") ->
        "Repeats weekly"

      String.contains?(rrule, "FREQ=MONTHLY") && String.contains?(rrule, "BYDAY=1SU") ->
        "Repeats on first Sunday of each month"

      String.contains?(rrule, "FREQ=MONTHLY") ->
        "Repeats monthly"

      String.contains?(rrule, "FREQ=DAILY") ->
        "Repeats daily"

      true ->
        "Custom recurrence"
    end
  end

  defp format_recurrence(_), do: "Recurring"
end
