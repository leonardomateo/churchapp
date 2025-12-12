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
      |> assign(:show_print_modal, false)
      |> assign(:print_layout, "agenda")
      |> assign(:print_start_date, Date.beginning_of_month(Date.utc_today()))
      |> assign(:print_end_date, Date.end_of_month(Date.utc_today()))
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
     |> assign(:show_print_modal, true)}
  end

  # Close print modal
  def handle_event("close_print_modal", _params, socket) do
    {:noreply, assign(socket, :show_print_modal, false)}
  end

  # Update print layout selection
  def handle_event("update_print_layout", %{"layout" => layout}, socket) do
    {:noreply, assign(socket, :print_layout, layout)}
  end

  # Update print dates (from form change)
  def handle_event(
        "update_print_dates",
        %{"start_date" => start_date, "end_date" => end_date},
        socket
      ) do
    socket =
      case Date.from_iso8601(start_date) do
        {:ok, date} -> assign(socket, :print_start_date, date)
        _ -> socket
      end

    socket =
      case Date.from_iso8601(end_date) do
        {:ok, date} -> assign(socket, :print_end_date, date)
        _ -> socket
      end

    {:noreply, socket}
  end

  # Generate print view
  def handle_event("generate_print", _params, socket) do
    start_date = socket.assigns.print_start_date
    end_date = socket.assigns.print_end_date
    layout = socket.assigns.print_layout

    # Convert dates to DateTime for querying
    start_datetime = DateTime.new!(start_date, ~T[00:00:00], "Etc/UTC")
    end_datetime = DateTime.new!(end_date, ~T[23:59:59], "Etc/UTC")

    # Fetch events for the selected date range
    events = fetch_events(start_datetime, end_datetime, nil, socket.assigns.current_user)

    # Generate print HTML based on layout
    print_html = generate_print_html(events, start_date, end_date, layout)

    {:noreply,
     socket
     |> assign(:print_html, print_html)
     |> push_event("show_print_preview", %{html: print_html})}
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

  # Generate print-optimized HTML with inline styles for reliable printing
  defp generate_print_html(events, start_date, end_date, "agenda") do
    # Group events by date
    events_by_date =
      events
      |> Enum.group_by(fn event ->
        DateTime.to_date(event.start_time)
      end)
      |> Enum.sort_by(fn {date, _events} -> date end)

    # Format date range for header
    date_range = format_date_range(start_date, end_date)

    # Build agenda HTML with inline styles for reliable printing
    agenda_html = """
    <div class="print-agenda" style="background: #ffffff; color: #000000; font-family: Georgia, 'Times New Roman', serif; padding: 20px; max-width: 100%;">
      <header class="print-header" style="text-align: center; margin-bottom: 24px; padding-bottom: 16px; border-bottom: 3px double #333333;">
        <h1 style="font-size: 28px; font-weight: bold; margin: 0 0 4px 0; color: #000000; letter-spacing: 0.05em; text-transform: uppercase;">PACHMS Event Calendar</h1>
        <p class="date-range" style="font-size: 16px; color: #444444; margin: 0; font-style: italic;">#{date_range}</p>
      </header>

      <div class="agenda-content" style="display: flex; flex-direction: column; gap: 0;">
        #{Enum.map_join(events_by_date, "\n", fn {date, day_events} ->
      day_events = Enum.sort_by(day_events, & &1.start_time)

      events_html = Enum.map_join(day_events, "\n", fn event ->
        location_html = if event.location do
          """
          <div class="event-location" style="font-size: 14px; color: #555555; display: flex; align-items: center; gap: 4px;">
            <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z"></path>
              <circle cx="12" cy="10" r="3"></circle>
            </svg>
            #{event.location}
          </div>
          """
        else
          ""
        end

        description_html = if event.description do
          """
          <div class="event-description" style="font-size: 13px; color: #666666; margin-top: 4px; line-height: 1.4;">#{event.description}</div>
          """
        else
          ""
        end

        """
        <div class="agenda-event" style="display: flex; align-items: flex-start; gap: 12px; padding: 12px; border: 1px solid #dddddd; border-radius: 4px; background: #ffffff; page-break-inside: avoid;">
          <div class="event-time" style="font-size: 14px; font-weight: 600; color: #333333; min-width: 110px; flex-shrink: 0; padding-top: 2px;">#{format_event_time(event)}</div>
          <div class="event-details" style="flex: 1; min-width: 0;">
            <h3 class="event-title" style="font-size: 16px; font-weight: 600; color: #000000; margin: 0 0 4px 0; line-height: 1.3;">#{event.title}</h3>
            #{location_html}
            #{description_html}
          </div>
          <div class="event-color-indicator" style="width: 4px; min-height: 40px; border-radius: 2px; background-color: #{event.color || "#06b6d4"}; flex-shrink: 0;"></div>
        </div>
        """
      end)

      """
      <div class="agenda-day" style="margin-bottom: 20px; page-break-inside: avoid;">
        <h2 class="agenda-date" style="font-size: 16px; font-weight: bold; color: #000000; margin: 0 0 8px 0; padding: 8px 12px; background: #f0f0f0; border-left: 4px solid #333333;">#{format_date_header(date)}</h2>
        <div class="agenda-events" style="display: flex; flex-direction: column; gap: 8px; padding-left: 12px;">
          #{events_html}
        </div>
      </div>
      """
    end)}
      </div>
    </div>
    """

    agenda_html
  end

  defp generate_print_html(events, start_date, end_date, "grid") do
    # Group events by date for grid layout
    events_by_date =
      events
      |> Enum.group_by(fn event ->
        DateTime.to_date(event.start_time)
      end)
      |> Enum.into(%{}, fn {date, day_events} ->
        {date, Enum.sort_by(day_events, & &1.start_time)}
      end)

    # Format date range for header
    date_range = format_date_range(start_date, end_date)

    # Build grid HTML with inline styles for reliable printing
    grid_html = """
    <div class="print-grid" style="background: #ffffff; color: #000000; font-family: Arial, sans-serif; padding: 20px; max-width: 100%;">
      <header class="print-header" style="text-align: center; margin-bottom: 24px; padding-bottom: 16px; border-bottom: 3px double #333333;">
        <h1 style="font-size: 28px; font-weight: bold; margin: 0 0 4px 0; color: #000000; letter-spacing: 0.05em; text-transform: uppercase;">PACHMS Event Calendar</h1>
        <p class="date-range" style="font-size: 16px; color: #444444; margin: 0; font-style: italic;">#{date_range}</p>
      </header>

      <div class="grid-content" style="display: flex; flex-direction: column; gap: 32px;">
        #{generate_month_grids(start_date, end_date, events_by_date)}
      </div>
    </div>
    """

    grid_html
  end

  defp generate_month_grids(start_date, end_date, events_by_date) do
    # Generate month grids for each month in the date range
    months = generate_month_list(start_date, end_date)

    Enum.map_join(months, "\n", fn month ->
      month_start = Date.beginning_of_month(month)
      _month_end = Date.end_of_month(month)
      month_name = Calendar.strftime(month, "%B %Y")

      # Get days of the month
      days_in_month = Date.days_in_month(month)
      # Convert ISO weekday (1=Mon, 7=Sun) to Sunday-first (0=Sun, 6=Sat) for grid alignment
      first_day_weekday = rem(Date.day_of_week(month_start), 7)

      # Build calendar grid with inline styles for reliable printing
      """
      <div class="month-grid" style="background: #ffffff; margin-bottom: 32px; page-break-inside: avoid;">
        <h2 class="month-title" style="font-size: 20px; font-weight: bold; color: #000000; margin: 0 0 16px 0; padding-bottom: 8px; border-bottom: 2px solid #333333;">#{month_name}</h2>
        <div class="calendar-grid" style="border: 1px solid #cccccc;">
          <div class="day-headers" style="display: grid; grid-template-columns: repeat(7, 1fr); background: #f5f5f5; border-bottom: 1px solid #cccccc;">
            <div class="day-header" style="padding: 8px 4px; text-align: center; font-weight: bold; font-size: 12px; color: #333333; border-right: 1px solid #cccccc;">Sun</div>
            <div class="day-header" style="padding: 8px 4px; text-align: center; font-weight: bold; font-size: 12px; color: #333333; border-right: 1px solid #cccccc;">Mon</div>
            <div class="day-header" style="padding: 8px 4px; text-align: center; font-weight: bold; font-size: 12px; color: #333333; border-right: 1px solid #cccccc;">Tue</div>
            <div class="day-header" style="padding: 8px 4px; text-align: center; font-weight: bold; font-size: 12px; color: #333333; border-right: 1px solid #cccccc;">Wed</div>
            <div class="day-header" style="padding: 8px 4px; text-align: center; font-weight: bold; font-size: 12px; color: #333333; border-right: 1px solid #cccccc;">Thu</div>
            <div class="day-header" style="padding: 8px 4px; text-align: center; font-weight: bold; font-size: 12px; color: #333333; border-right: 1px solid #cccccc;">Fri</div>
            <div class="day-header" style="padding: 8px 4px; text-align: center; font-weight: bold; font-size: 12px; color: #333333;">Sat</div>
          </div>
          <div class="calendar-days" style="background: #ffffff;">
            #{Enum.map_join(0..5, "\n", fn week_offset ->
        week_days = Enum.map_join(0..6, "", fn day_of_week ->
          day_num = week_offset * 7 + day_of_week - first_day_weekday + 1
          border_right = if day_of_week < 6, do: "border-right: 1px solid #cccccc;", else: ""

          if day_num > 0 and day_num <= days_in_month do
            current_date = Date.new!(month.year, month.month, day_num)
            day_events = Map.get(events_by_date, current_date, [])

            events_html = Enum.map_join(Enum.take(day_events, 3), "", fn event -> """
              <div class="day-event" style="font-size: 10px; padding: 2px 4px; border-radius: 2px; color: #ffffff; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; background-color: #{event.color || "#06b6d4"};">
                #{event.title}
              </div>
              """ end)

            more_html = if length(day_events) > 3 do
              """
              <div class="more-events" style="font-size: 10px; color: #666666; font-style: italic;">+#{length(day_events) - 3} more</div>
              """
            else
              ""
            end

            """
            <div class="calendar-day" style="min-height: 80px; padding: 4px; #{border_right} background: #ffffff; vertical-align: top;">
              <div class="day-number" style="font-size: 14px; font-weight: bold; color: #000000; margin-bottom: 4px;">#{day_num}</div>
              <div class="day-events" style="display: flex; flex-direction: column; gap: 2px;">
                #{events_html}
                #{more_html}
              </div>
            </div>
            """
          else
            """
            <div class="calendar-day empty" style="min-height: 80px; padding: 4px; #{border_right} background: #f9f9f9;"></div>
            """
          end
        end)

        """
        <div class="calendar-week" style="display: grid; grid-template-columns: repeat(7, 1fr); border-bottom: 1px solid #cccccc;">
          #{week_days}
        </div>
        """
      end)}
          </div>
        </div>
      </div>
      """
    end)
  end

  defp generate_month_list(start_date, end_date) do
    # Generate list of months between start_date and end_date
    start_month = Date.beginning_of_month(start_date)
    end_month = Date.beginning_of_month(end_date)

    Stream.iterate(start_month, fn date ->
      Date.add(date, Date.days_in_month(date))
      |> Date.beginning_of_month()
    end)
    |> Enum.take_while(fn date -> Date.compare(date, end_month) in [:lt, :eq] end)
  end

  defp format_date_range(start_date, end_date) do
    if start_date.month == end_date.month and start_date.year == end_date.year do
      Calendar.strftime(start_date, "%B %Y")
    else
      "#{Calendar.strftime(start_date, "%B %d, %Y")} - #{Calendar.strftime(end_date, "%B %d, %Y")}"
    end
  end

  defp format_date_header(date) do
    Calendar.strftime(date, "%A, %B %d, %Y")
  end

  defp format_event_time(event) do
    if event.all_day do
      "All day"
    else
      start_time = Calendar.strftime(event.start_time, "%I:%M %p")
      end_time = Calendar.strftime(event.end_time, "%I:%M %p")
      "#{start_time} - #{end_time}"
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="view-container active" phx-hook="PrintCalendar" id="events-container">
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
            <div class="relative" phx-click-away="close_export_menu">
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
                <div
                  style="background-color: #1E1E1E;"
                  class="absolute right-0 top-full mt-2 min-w-[12rem] border border-dark-600 rounded-lg shadow-xl z-50 overflow-hidden"
                >
                  <button
                    type="button"
                    phx-click="export_ical"
                    style="background-color: #1E1E1E;"
                    class="flex items-center gap-3 w-full px-4 py-3 text-sm text-gray-300 hover:bg-dark-700 hover:text-white transition-colors"
                  >
                    <.icon name="hero-calendar" class="h-4 w-4" />
                    <span>Download iCal (.ics)</span>
                  </button>
                  <button
                    type="button"
                    phx-click="print_calendar"
                    style="background-color: #1E1E1E;"
                    class="flex items-center gap-3 w-full px-4 py-3 text-sm text-gray-300 hover:bg-dark-700 hover:text-white transition-colors border-t border-dark-600"
                  >
                    <.icon name="hero-printer" class="h-4 w-4" />
                    <span>Print Calendar</span>
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
            Click on a date to create a new event. Click on an event to view, edit, or delete it.
          </p>
        <% else %>
          <p>
            <.icon name="hero-information-circle" class="inline h-4 w-4 mr-1" />
            Click on an event to view its details.
          </p>
        <% end %>
      </div>

      <%!-- Print Modal --%>
      <%= if @show_print_modal do %>
        <div class="fixed inset-0 z-50 flex items-center justify-center">
          <%!-- Backdrop --%>
          <div
            class="absolute inset-0 bg-black/50"
            phx-click="close_print_modal"
          >
          </div>
          <%!-- Modal Content --%>
          <div class="relative bg-dark-800 rounded-lg shadow-xl max-w-2xl w-full mx-4">
            <div class="border-b border-dark-700 px-6 py-4 flex items-center justify-between">
              <h3 class="text-lg font-semibold text-white">Print Calendar</h3>
              <button
                type="button"
                phx-click="close_print_modal"
                class="text-gray-400 hover:text-white transition-colors"
              >
                <.icon name="hero-x-mark" class="h-5 w-5" />
              </button>
            </div>

            <div class="p-6">
              <div class="mb-6">
                <label class="block text-sm font-medium text-gray-300 mb-3">Layout Style</label>
                <div class="grid grid-cols-2 gap-4">
                  <div
                    phx-click="update_print_layout"
                    phx-value-layout="agenda"
                    class={[
                      "flex flex-col items-center p-4 border-2 rounded-lg cursor-pointer transition-all",
                      @print_layout == "agenda" && "border-primary-500 bg-primary-500/10",
                      @print_layout != "agenda" && "border-dark-600 hover:border-dark-500"
                    ]}
                  >
                    <.icon name="hero-list-bullet" class="h-8 w-8 text-gray-300 mb-2" />
                    <span class="text-gray-300 font-medium">Agenda Style</span>
                    <span class="text-xs text-gray-500 mt-1 text-center">Events grouped by date</span>
                  </div>
                  <div
                    phx-click="update_print_layout"
                    phx-value-layout="grid"
                    class={[
                      "flex flex-col items-center p-4 border-2 rounded-lg cursor-pointer transition-all",
                      @print_layout == "grid" && "border-primary-500 bg-primary-500/10",
                      @print_layout != "grid" && "border-dark-600 hover:border-dark-500"
                    ]}
                  >
                    <.icon name="hero-calendar-days" class="h-8 w-8 text-gray-300 mb-2" />
                    <span class="text-gray-300 font-medium">Monthly Grid</span>
                    <span class="text-xs text-gray-500 mt-1 text-center">
                      Traditional calendar view
                    </span>
                  </div>
                </div>
              </div>

              <div class="mb-6">
                <label class="block text-sm font-medium text-gray-300 mb-3">Date Range</label>
                <form phx-change="update_print_dates" class="flex gap-4 items-center">
                  <div class="flex-1">
                    <label class="block text-xs text-gray-400 mb-1">Start Date</label>
                    <input
                      type="date"
                      name="start_date"
                      value={Date.to_iso8601(@print_start_date)}
                      class="w-full px-3 py-2 bg-dark-700 border border-dark-600 rounded-md text-white focus:ring-primary-500 focus:border-primary-500"
                    />
                  </div>
                  <span class="text-gray-500 pt-5">to</span>
                  <div class="flex-1">
                    <label class="block text-xs text-gray-400 mb-1">End Date</label>
                    <input
                      type="date"
                      name="end_date"
                      value={Date.to_iso8601(@print_end_date)}
                      class="w-full px-3 py-2 bg-dark-700 border border-dark-600 rounded-md text-white focus:ring-primary-500 focus:border-primary-500"
                    />
                  </div>
                </form>
              </div>

              <div class="flex justify-end gap-3 pt-4 border-t border-dark-700">
                <button
                  type="button"
                  phx-click="close_print_modal"
                  class="px-4 py-2 text-gray-300 bg-dark-700 hover:bg-dark-600 rounded-md transition-colors"
                >
                  Cancel
                </button>
                <button
                  type="button"
                  phx-click="generate_print"
                  class="px-4 py-2 text-white bg-primary-500 hover:bg-primary-600 rounded-md transition-colors inline-flex items-center gap-2"
                >
                  <.icon name="hero-printer" class="h-4 w-4" /> Print
                </button>
              </div>
            </div>
          </div>
        </div>
      <% end %>

      <%!-- Hidden Print Preview Container --%>
      <div id="print-preview-container" class="print-preview-container"></div>
    </div>
    """
  end
end
