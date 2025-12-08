defmodule ChurchappWeb.EventsLive.IndexLive do
  use ChurchappWeb, :live_view

  require Ash.Query

  alias Chms.Church.Events

  @impl true
  def mount(_params, _session, socket) do
    is_admin = is_admin?(socket.assigns[:current_user])

    socket =
      socket
      |> assign(:page_title, "Event Calendar")
      |> assign(:is_admin, is_admin)
      |> assign(:current_view, "month")
      |> assign(:calendar_title, format_current_month())
      |> assign(:show_export_menu, false)
      |> assign(:view_command, nil)

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    socket = apply_action(socket, socket.assigns.live_action, params)
    {:noreply, socket}
  end

  defp apply_action(socket, :index, _params) do
    socket
  end

  # Handle calendar navigation events from JS hook
  @impl true
  def handle_event("calendar_navigated", %{"title" => title}, socket) do
    {:noreply,
     socket
     |> assign(:calendar_title, title)
     |> assign(:view_command, nil)}
  end

  # Handle date click - create new event
  def handle_event("date_clicked", %{"date" => date, "allDay" => all_day}, socket) do
    if socket.assigns.is_admin do
      {:noreply, push_navigate(socket, to: ~p"/events/new?date=#{date}&all_day=#{all_day}")}
    else
      {:noreply, socket}
    end
  end

  # Handle date range selection - create new event
  def handle_event(
        "date_range_selected",
        %{"start" => start_date, "end" => end_date, "allDay" => all_day},
        socket
      ) do
    if socket.assigns.is_admin do
      {:noreply,
       push_navigate(socket,
         to: ~p"/events/new?start=#{start_date}&end=#{end_date}&all_day=#{all_day}"
       )}
    else
      {:noreply, socket}
    end
  end

  # Handle event click - view event details
  def handle_event("event_clicked", %{"id" => id}, socket) do
    {:noreply, push_navigate(socket, to: ~p"/events/#{id}")}
  end

  # Handle event drop (drag and drop reschedule)
  def handle_event("event_dropped", %{"id" => id, "start" => start_str, "end" => end_str}, socket) do
    if socket.assigns.is_admin do
      with {:ok, event} <- Chms.Church.get_event_by_id(id),
           {:ok, start_time} <- parse_datetime(start_str),
           {:ok, end_time} <- parse_datetime(end_str),
           {:ok, _updated} <-
             Chms.Church.update_event(event, %{start_time: start_time, end_time: end_time},
               actor: socket.assigns.current_user
             ) do
        {:noreply, put_flash(socket, :info, "Event rescheduled successfully")}
      else
        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to reschedule event")}
      end
    else
      {:noreply, socket}
    end
  end

  # Handle event resize
  def handle_event("event_resized", %{"id" => id, "start" => start_str, "end" => end_str}, socket) do
    if socket.assigns.is_admin do
      with {:ok, event} <- Chms.Church.get_event_by_id(id),
           {:ok, start_time} <- parse_datetime(start_str),
           {:ok, end_time} <- parse_datetime(end_str),
           {:ok, _updated} <-
             Chms.Church.update_event(event, %{start_time: start_time, end_time: end_time},
               actor: socket.assigns.current_user
             ) do
        {:noreply, put_flash(socket, :info, "Event updated successfully")}
      else
        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to update event")}
      end
    else
      {:noreply, socket}
    end
  end

  # Fetch events for the calendar (called by JS hook)
  def handle_event(
        "fetch_events",
        %{"start" => start_str, "end" => end_str, "filter" => filter},
        socket
      ) do
    with {:ok, start_date} <- parse_datetime(start_str),
         {:ok, end_date} <- parse_datetime(end_str) do
      events = fetch_events(start_date, end_date, filter, socket.assigns.current_user)
      event_data = Enum.map(events, &event_to_map/1)
      {:reply, %{events: event_data}, socket}
    else
      _ ->
        {:reply, %{events: []}, socket}
    end
  end

  # View toggle buttons
  def handle_event("change_view", %{"view" => view}, socket) do
    {:noreply,
     socket
     |> assign(:current_view, view)
     |> assign(:view_command, view)}
  end

  # Navigation buttons
  def handle_event("navigate", %{"direction" => direction}, socket) do
    {:noreply, assign(socket, :view_command, direction)}
  end

  # Toggle export menu
  def handle_event("toggle_export_menu", _params, socket) do
    {:noreply, assign(socket, :show_export_menu, !socket.assigns.show_export_menu)}
  end

  def handle_event("close_export_menu", _params, socket) do
    {:noreply, assign(socket, :show_export_menu, false)}
  end

  # Export to iCal
  def handle_event("export_ical", _params, socket) do
    # Fetch all events
    events = fetch_all_events(nil, socket.assigns.current_user)
    ical_content = Chms.Church.IcalExport.generate_ical(events)
    filename = "church-events-#{Date.utc_today()}.ics"

    {:noreply,
     socket
     |> assign(:show_export_menu, false)
     |> push_event("download_ical", %{content: ical_content, filename: filename})}
  end

  # Print calendar
  def handle_event("print_calendar", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_export_menu, false)
     |> push_event("print_calendar", %{})}
  end

  # Helper functions
  defp is_admin?(nil), do: false
  defp is_admin?(user), do: user.role in [:super_admin, :admin, :staff]

  defp format_current_month do
    Calendar.strftime(Date.utc_today(), "%B %Y")
  end

  defp parse_datetime(datetime_str) when is_binary(datetime_str) do
    # Handle both ISO 8601 formats
    case DateTime.from_iso8601(datetime_str) do
      {:ok, datetime, _offset} ->
        {:ok, datetime}

      {:error, _} ->
        # Try parsing as date only
        case Date.from_iso8601(datetime_str) do
          {:ok, date} ->
            {:ok, DateTime.new!(date, ~T[00:00:00], "Etc/UTC")}

          {:error, _} = error ->
            error
        end
    end
  end

  defp parse_datetime(_), do: {:error, :invalid_datetime}

  defp fetch_events(start_date, end_date, _filter, actor) do
    query =
      Events
      |> Ash.Query.filter(
        (start_time >= ^start_date and start_time <= ^end_date) or
          (is_recurring == true and
             (is_nil(recurrence_end_date) or recurrence_end_date >= ^DateTime.to_date(start_date)))
      )

    case Chms.Church.list_events(query: query, actor: actor) do
      {:ok, events} -> events
      _ -> []
    end
  end

  defp fetch_all_events(_filter, actor) do
    case Chms.Church.list_events(actor: actor) do
      {:ok, events} -> events
      _ -> []
    end
  end

  defp event_to_map(event) do
    %{
      id: event.id,
      title: event.title,
      description: event.description,
      # Format datetime without Z suffix so FullCalendar treats it as local time
      start_time: format_datetime_for_calendar(event.start_time),
      end_time: format_datetime_for_calendar(event.end_time),
      all_day: event.all_day,
      location: event.location,
      color: event.color || Events.default_color(),
      is_recurring: event.is_recurring,
      recurrence_rule: event.recurrence_rule,
      recurrence_end_date: event.recurrence_end_date && Date.to_iso8601(event.recurrence_end_date)
    }
  end

  # Format datetime without timezone suffix to prevent FullCalendar timezone conversion
  defp format_datetime_for_calendar(%DateTime{} = dt) do
    dt
    |> DateTime.to_naive()
    |> NaiveDateTime.to_iso8601()
  end

  defp format_datetime_for_calendar(nil), do: nil

  @impl true
  def render(assigns) do
    ~H"""
    <div class="view-container active" phx-hook="IcalDownload" id="events-container">
      <%!-- Print Header (only visible when printing) --%>
      <div class="print-header">
        <h1>PACHMS Event Calendar</h1>
        <p>{@calendar_title}</p>
      </div>

      <%!-- Calendar Header --%>
      <div class="mb-6 flex flex-col gap-4 no-print">
        <%!-- Title Row --%>
        <div class="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4">
          <div class="flex items-center gap-3">
            <.icon name="hero-calendar-days" class="h-7 w-7 text-primary-500" />
            <h2 class="text-2xl font-bold text-white">Event Calendar</h2>
          </div>

          <div class="flex items-center gap-3">
            <%!-- Export Dropdown --%>
            <div class="export-dropdown relative" phx-click-away="close_export_menu">
              <button
                type="button"
                phx-click="toggle_export_menu"
                class="calendar-nav-btn inline-flex items-center gap-2"
              >
                <.icon name="hero-arrow-down-tray" class="h-4 w-4" />
                <span class="hidden sm:inline">Export</span>
                <.icon name="hero-chevron-down" class="h-4 w-4" />
              </button>
              <%= if @show_export_menu do %>
                <div class="export-dropdown-menu">
                  <button type="button" phx-click="export_ical" class="export-dropdown-item">
                    <.icon name="hero-calendar" class="h-4 w-4" /> Download iCal (.ics)
                  </button>
                  <button type="button" onclick="window.print()" class="export-dropdown-item">
                    <.icon name="hero-printer" class="h-4 w-4" /> Print Calendar
                  </button>
                </div>
              <% end %>
            </div>

            <%!-- Add Event Button (Admin Only) --%>
            <%= if @is_admin do %>
              <.link
                navigate={~p"/events/new"}
                class="inline-flex items-center px-4 py-2 text-sm font-medium text-white bg-primary-500 hover:bg-primary-600 rounded-md shadow-lg shadow-primary-500/20 transition-colors"
              >
                <.icon name="hero-plus" class="mr-2 h-4 w-4" /> Add Event
              </.link>
            <% end %>
          </div>
        </div>

        <%!-- Controls Row --%>
        <div class="flex flex-col lg:flex-row justify-between items-start lg:items-center gap-4 bg-dark-800 rounded-lg p-4 border border-dark-700">
          <%!-- View Toggle Buttons --%>
          <div class="flex flex-wrap items-center gap-3">
            <div class="flex rounded-lg overflow-hidden border border-dark-600">
              <button
                type="button"
                phx-click="change_view"
                phx-value-view="month"
                class={[
                  "calendar-view-btn border-r border-dark-600",
                  @current_view == "month" && "calendar-view-btn-active",
                  @current_view != "month" && "calendar-view-btn-inactive"
                ]}
              >
                Month
              </button>
              <button
                type="button"
                phx-click="change_view"
                phx-value-view="week"
                class={[
                  "calendar-view-btn border-r border-dark-600",
                  @current_view == "week" && "calendar-view-btn-active",
                  @current_view != "week" && "calendar-view-btn-inactive"
                ]}
              >
                Week
              </button>
              <button
                type="button"
                phx-click="change_view"
                phx-value-view="day"
                class={[
                  "calendar-view-btn border-r border-dark-600",
                  @current_view == "day" && "calendar-view-btn-active",
                  @current_view != "day" && "calendar-view-btn-inactive"
                ]}
              >
                Day
              </button>
              <button
                type="button"
                phx-click="change_view"
                phx-value-view="list"
                class={[
                  "calendar-view-btn",
                  @current_view == "list" && "calendar-view-btn-active",
                  @current_view != "list" && "calendar-view-btn-inactive"
                ]}
              >
                List
              </button>
            </div>
          </div>

        </div>
      </div>

      <%!-- Calendar Container --%>
      <div class="calendar-container bg-dark-800 rounded-lg border border-dark-700 p-4">
        <div
          id="event-calendar"
          phx-hook="EventCalendar"
          phx-update="ignore"
          data-is-admin={to_string(@is_admin)}
          data-view-command={@view_command}
          class="min-h-[600px]"
        >
        </div>
      </div>

      <%!-- Help Text --%>
      <div class="mt-4 text-sm text-gray-500 no-print">
        <%= if @is_admin do %>
          <p>
            <.icon name="hero-information-circle" class="inline h-4 w-4 mr-1" />
            Click on a date to create a new event. Click on an event to view, edit, or delete it. Drag events to reschedule.
          </p>
        <% else %>
          <p>
            <.icon name="hero-information-circle" class="inline h-4 w-4 mr-1" />
            Click on an event to view its details.
          </p>
        <% end %>
      </div>
    </div>
    """
  end
end
