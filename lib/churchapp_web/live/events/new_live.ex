defmodule ChurchappWeb.EventsLive.NewLive do
  use ChurchappWeb, :live_view

  alias Chms.Church.Events
  alias AshPhoenix.Form

  @impl true
  def mount(_params, _session, socket) do
    # Check if user is admin
    unless is_admin?(socket.assigns[:current_user]) do
      {:ok,
       socket
       |> put_flash(:error, "You don't have permission to create events")
       |> push_navigate(to: ~p"/events")}
    else
      {:ok, socket}
    end
  end

  @impl true
  def handle_params(params, _uri, socket) do
    # Pre-populate form based on URL params (from calendar click)
    initial_values = build_initial_values(params)

    form =
      Events
      |> Form.for_create(:create, domain: Chms.Church, actor: socket.assigns.current_user)
      |> Form.validate(initial_values)
      |> to_form()

    socket =
      socket
      |> assign(:page_title, "New Event")
      |> assign(:form, form)
      |> assign(:is_recurring, initial_values[:is_recurring] || false)
      |> assign(:show_recurrence_options, false)
      |> assign(:event_types, Events.event_types())
      |> assign(:recurrence_presets, recurrence_presets())
      |> assign(:start_time_dropdown_open, false)
      |> assign(:end_time_dropdown_open, false)

    {:noreply, socket}
  end

  @impl true
  def handle_event("validate", params, socket) do
    # Handle both nested "form" params and top-level params
    form_params = params["form"] || params

    # Combine separate date/time fields into datetime fields
    form_params = combine_date_time_fields(params, form_params)

    is_recurring = form_params["is_recurring"] == "true"
    was_recurring = socket.assigns.is_recurring

    # If recurring was just enabled and no rule is set, apply a default preset
    form_params =
      if is_recurring && !was_recurring && (form_params["recurrence_rule"] || "") == "" do
        Map.put(form_params, "recurrence_rule", "FREQ=WEEKLY;BYDAY=SU")
      else
        form_params
      end

    form = Form.validate(socket.assigns.form, form_params)

    {:noreply,
     socket
     |> assign(:form, form)
     |> assign(:is_recurring, is_recurring)}
  end

  def handle_event("save", params, socket) do
    # Handle both nested "form" params and top-level params
    form_params = params["form"] || params

    # Combine separate date/time fields into datetime fields (same as validate)
    form_params = combine_date_time_fields(params, form_params)

    case Form.submit(socket.assigns.form, params: form_params) do
      {:ok, event} ->
        {:noreply,
         socket
         |> put_flash(:info, "Event \"#{event.title}\" created successfully")
         |> push_navigate(to: ~p"/events")}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end

  def handle_event("toggle_recurrence", _params, socket) do
    {:noreply, assign(socket, :show_recurrence_options, !socket.assigns.show_recurrence_options)}
  end

  def handle_event("apply_preset", %{"preset" => preset}, socket) do
    rrule = get_preset_rrule(preset)

    # Get current form params and merge with new recurrence values
    current_params = socket.assigns.form.params || %{}

    merged_params =
      Map.merge(current_params, %{
        "is_recurring" => "true",
        "recurrence_rule" => rrule
      })

    form = Form.validate(socket.assigns.form, merged_params)

    {:noreply,
     socket
     |> assign(:form, form)
     |> assign(:is_recurring, true)
     |> assign(:show_recurrence_options, false)}
  end

  def handle_event("toggle_start_time_dropdown", _params, socket) do
    {:noreply,
     socket
     |> assign(:start_time_dropdown_open, !socket.assigns.start_time_dropdown_open)
     |> assign(:end_time_dropdown_open, false)}
  end

  def handle_event("toggle_end_time_dropdown", _params, socket) do
    {:noreply,
     socket
     |> assign(:end_time_dropdown_open, !socket.assigns.end_time_dropdown_open)
     |> assign(:start_time_dropdown_open, false)}
  end

  def handle_event("select_start_time", %{"time" => time}, socket) do
    # Update the form with the new start time
    start_date = extract_date(socket.assigns.form[:start_time].value)
    new_start_time = if start_date != "", do: "#{start_date}T#{time}", else: time

    form_params = socket.assigns.form.params || %{}
    form_params = Map.put(form_params, "start_time", new_start_time)
    form = Form.validate(socket.assigns.form, form_params)

    {:noreply,
     socket
     |> assign(:form, form)
     |> assign(:start_time_dropdown_open, false)}
  end

  def handle_event("select_end_time", %{"time" => time}, socket) do
    # Update the form with the new end time
    end_date = extract_date(socket.assigns.form[:end_time].value)
    new_end_time = if end_date != "", do: "#{end_date}T#{time}", else: time

    form_params = socket.assigns.form.params || %{}
    form_params = Map.put(form_params, "end_time", new_end_time)
    form = Form.validate(socket.assigns.form, form_params)

    {:noreply,
     socket
     |> assign(:form, form)
     |> assign(:end_time_dropdown_open, false)}
  end

  def handle_event("close_time_dropdowns", _params, socket) do
    {:noreply,
     socket
     |> assign(:start_time_dropdown_open, false)
     |> assign(:end_time_dropdown_open, false)}
  end

  defp is_admin?(nil), do: false
  defp is_admin?(user), do: user.role in [:super_admin, :admin, :staff]

  defp build_initial_values(params) do
    # Start with default values - all_day should default to false
    today = Date.utc_today() |> Date.to_iso8601()

    values = %{
      "all_day" => false,
      "start_time" => "#{today}T09:00",
      "end_time" => "#{today}T10:00"
    }

    # Handle single date click
    values =
      if params["date"] do
        date = params["date"]
        all_day = params["all_day"] == "true"

        if all_day do
          # For all-day events, set start and end to the same day
          Map.merge(values, %{
            "all_day" => true,
            "start_time" => "#{date}T09:00",
            "end_time" => "#{date}T10:00"
          })
        else
          # For timed events, default to 1 hour duration
          Map.merge(values, %{
            "all_day" => false,
            "start_time" => date,
            "end_time" => add_hour_to_datetime(date)
          })
        end
      else
        values
      end

    # Handle date range selection
    values =
      if params["start"] && params["end"] do
        Map.merge(values, %{
          "start_time" => params["start"],
          "end_time" => params["end"],
          "all_day" => params["all_day"] == "true"
        })
      else
        values
      end

    values
  end

  defp add_hour_to_datetime(datetime_str) do
    # Handle both date-only (2025-12-08) and datetime (2025-12-08T10:00) formats
    datetime_to_parse =
      cond do
        String.contains?(datetime_str, "T") && String.contains?(datetime_str, "Z") ->
          datetime_str

        String.contains?(datetime_str, "T") ->
          datetime_str <> ":00Z"

        true ->
          # Date only - add default time
          datetime_str <> "T00:00:00Z"
      end

    case DateTime.from_iso8601(datetime_to_parse) do
      {:ok, dt, _} ->
        DateTime.add(dt, 3600, :second)
        |> DateTime.to_iso8601()
        |> String.slice(0, 16)

      _ ->
        datetime_str
    end
  end

  defp recurrence_presets do
    [
      %{id: "weekly_sunday", label: "Every Sunday", rrule: "FREQ=WEEKLY;BYDAY=SU"},
      %{id: "weekly_wednesday", label: "Every Wednesday", rrule: "FREQ=WEEKLY;BYDAY=WE"},
      %{id: "weekly_friday", label: "Every Friday", rrule: "FREQ=WEEKLY;BYDAY=FR"},
      %{id: "biweekly", label: "Every 2 Weeks", rrule: "FREQ=WEEKLY;INTERVAL=2"},
      %{
        id: "monthly_first_sunday",
        label: "First Sunday of Month",
        rrule: "FREQ=MONTHLY;BYDAY=1SU"
      },
      %{id: "monthly_date", label: "Same Day Monthly", rrule: "FREQ=MONTHLY"},
      %{id: "custom", label: "Custom...", rrule: nil}
    ]
  end

  defp get_preset_rrule("weekly_sunday"), do: "FREQ=WEEKLY;BYDAY=SU"
  defp get_preset_rrule("weekly_wednesday"), do: "FREQ=WEEKLY;BYDAY=WE"
  defp get_preset_rrule("weekly_friday"), do: "FREQ=WEEKLY;BYDAY=FR"
  defp get_preset_rrule("biweekly"), do: "FREQ=WEEKLY;INTERVAL=2"
  defp get_preset_rrule("monthly_first_sunday"), do: "FREQ=MONTHLY;BYDAY=1SU"
  defp get_preset_rrule("monthly_date"), do: "FREQ=MONTHLY"
  defp get_preset_rrule(_), do: ""

  @impl true
  def render(assigns) do
    ~H"""
    <div class="view-container active">
      <div class="mb-6">
        <.link
          navigate={~p"/events"}
          class="inline-flex items-center text-sm text-gray-400 hover:text-white transition-colors"
        >
          <.icon name="hero-arrow-left" class="mr-2 h-4 w-4" /> Back to Calendar
        </.link>
      </div>

      <div class="max-w-2xl">
        <div class="mb-6">
          <h2 class="text-2xl font-bold text-white">Create New Event</h2>
          <p class="mt-1 text-sm text-gray-400">
            Add a new event to the church calendar
          </p>
        </div>

        <div class="bg-dark-800 rounded-lg border border-dark-700 p-6">
          <.form
            for={@form}
            id="event-form"
            phx-change="validate"
            phx-submit="save"
            class="space-y-6"
          >
            <%!-- Event / Activity Name --%>
            <div>
              <.input
                field={@form[:title]}
                type="text"
                label="Event / Activity Name *"
                placeholder="e.g., Sunday Worship Service"
                required
              />
            </div>

            <%!-- Event Type --%>
            <div>
              <label for={@form[:event_type].id} class="block text-sm font-medium text-gray-300 mb-2">
                Event Type <span class="text-red-500">*</span>
              </label>
              <select
                id={@form[:event_type].id}
                name={@form[:event_type].name}
                style="height: 46px; padding: 0.75rem 1rem;"
                class="w-full text-gray-200 bg-dark-700 border border-dark-600 rounded-md focus:ring-2 focus:ring-primary-500 focus:border-transparent"
              >
                <%= for event_type <- @event_types do %>
                  <option
                    value={event_type.type}
                    selected={to_string(@form[:event_type].value) == to_string(event_type.type)}
                  >
                    {event_type.label}
                  </option>
                <% end %>
              </select>
            </div>

            <%!-- Date & Time Section --%>
            <div class="space-y-4">
              <%!-- Date Row --%>
              <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div>
                  <label class="block text-sm font-medium text-gray-300 mb-2">
                    Start Date <span class="text-red-500">*</span>
                  </label>
                  <input
                    type="date"
                    id="start_date"
                    name="start_date"
                    phx-hook="DatePicker"
                    value={extract_date(@form[:start_time].value)}
                    class="w-full px-4 py-3 text-base text-gray-200 bg-dark-700 border border-dark-600 rounded-md focus:ring-2 focus:ring-primary-500 focus:border-transparent"
                    required
                  />
                </div>
                <div>
                  <label class="block text-sm font-medium text-gray-300 mb-2">
                    End Date <span class="text-red-500">*</span>
                  </label>
                  <input
                    type="date"
                    id="end_date"
                    name="end_date"
                    phx-hook="DatePicker"
                    value={extract_date(@form[:end_time].value)}
                    class="w-full px-4 py-3 text-base text-gray-200 bg-dark-700 border border-dark-600 rounded-md focus:ring-2 focus:ring-primary-500 focus:border-transparent"
                    required
                  />
                </div>
              </div>

              <%!-- Time Row with All Day Toggle --%>
              <div class="flex flex-wrap items-end gap-4">
                <%!-- Start Time Custom Dropdown --%>
                <div class="flex-1 min-w-[140px] relative">
                  <label class="block text-sm font-medium text-gray-300 mb-2">
                    From <span class="text-red-500">*</span>
                  </label>
                  <input type="hidden" name="start_time_only" value={extract_time(@form[:start_time].value)} />
                  <button
                    type="button"
                    phx-click="toggle_start_time_dropdown"
                    disabled={@form[:all_day].value == true || @form[:all_day].value == "true"}
                    class={[
                      "w-full h-[46px] px-4 text-left text-gray-200 bg-dark-700 border border-dark-600 rounded-md focus:ring-2 focus:ring-primary-500 focus:border-transparent flex items-center justify-between",
                      (@form[:all_day].value == true || @form[:all_day].value == "true") && "opacity-50 cursor-not-allowed"
                    ]}
                  >
                    <span>{format_time_label_from_value(extract_time(@form[:start_time].value))}</span>
                    <.icon name="hero-chevron-down" class="w-4 h-4 text-gray-400" />
                  </button>
                  <%= if @start_time_dropdown_open do %>
                    <div
                      style="background-color: #2D2D2D;"
                      class="absolute z-50 mt-1 w-full border border-dark-600 rounded-md shadow-lg max-h-60 overflow-y-auto"
                      phx-click-away="close_time_dropdowns"
                    >
                      <%= for {label, value} <- time_options() do %>
                        <button
                          type="button"
                          phx-click="select_start_time"
                          phx-value-time={value}
                          style={if extract_time(@form[:start_time].value) == value, do: "background-color: #06b6d4; color: white;", else: "background-color: #2D2D2D; color: #e5e7eb;"}
                          class="w-full px-4 py-2.5 text-left text-sm transition-colors time-picker-option"
                        >
                          {label}
                        </button>
                      <% end %>
                    </div>
                  <% end %>
                </div>

                <%!-- End Time Custom Dropdown --%>
                <div class="flex-1 min-w-[140px] relative">
                  <label class="block text-sm font-medium text-gray-300 mb-2">
                    To <span class="text-red-500">*</span>
                  </label>
                  <input type="hidden" name="end_time_only" value={extract_time(@form[:end_time].value)} />
                  <button
                    type="button"
                    phx-click="toggle_end_time_dropdown"
                    disabled={@form[:all_day].value == true || @form[:all_day].value == "true"}
                    class={[
                      "w-full h-[46px] px-4 text-left text-gray-200 bg-dark-700 border border-dark-600 rounded-md focus:ring-2 focus:ring-primary-500 focus:border-transparent flex items-center justify-between",
                      (@form[:all_day].value == true || @form[:all_day].value == "true") && "opacity-50 cursor-not-allowed"
                    ]}
                  >
                    <span>{format_time_label_from_value(extract_time(@form[:end_time].value))}</span>
                    <.icon name="hero-chevron-down" class="w-4 h-4 text-gray-400" />
                  </button>
                  <%= if @end_time_dropdown_open do %>
                    <div
                      style="background-color: #2D2D2D;"
                      class="absolute z-50 mt-1 w-full border border-dark-600 rounded-md shadow-lg max-h-60 overflow-y-auto"
                      phx-click-away="close_time_dropdowns"
                    >
                      <%= for {label, value} <- time_options() do %>
                        <button
                          type="button"
                          phx-click="select_end_time"
                          phx-value-time={value}
                          style={if extract_time(@form[:end_time].value) == value, do: "background-color: #06b6d4; color: white;", else: "background-color: #2D2D2D; color: #e5e7eb;"}
                          class="w-full px-4 py-2.5 text-left text-sm transition-colors time-picker-option"
                        >
                          {label}
                        </button>
                      <% end %>
                    </div>
                  <% end %>
                </div>

                <div class="flex items-center gap-2 pb-2">
                  <input type="hidden" name={@form[:all_day].name} value="false" />
                  <input
                    type="checkbox"
                    id={@form[:all_day].id}
                    name={@form[:all_day].name}
                    value="true"
                    checked={@form[:all_day].value == true || @form[:all_day].value == "true"}
                    class="h-4 w-4"
                  />
                  <label for={@form[:all_day].id} class="text-sm text-gray-300 whitespace-nowrap">
                    All day
                  </label>
                </div>
              </div>

              <%!-- Hidden inputs for actual start_time and end_time that get submitted --%>
              <input type="hidden" name={@form[:start_time].name} value={@form[:start_time].value} />
              <input type="hidden" name={@form[:end_time].name} value={@form[:end_time].value} />
            </div>

            <%!-- Location --%>
            <div>
              <label for={@form[:location].id} class="block text-sm font-medium text-gray-300 mb-2">
                Location
              </label>
              <input
                type="text"
                id={@form[:location].id}
                name={@form[:location].name}
                value={@form[:location].value}
                placeholder="e.g., Main Sanctuary"
                class="w-full px-4 py-2 text-gray-200 placeholder-gray-500 bg-dark-700 border border-dark-600 rounded-md focus:ring-2 focus:ring-primary-500 focus:border-transparent"
              />
            </div>

            <%!-- Description --%>
            <div>
              <label for={@form[:description].id} class="block text-sm font-medium text-gray-300 mb-2">
                Description
              </label>
              <textarea
                id={@form[:description].id}
                name={@form[:description].name}
                rows="3"
                placeholder="Additional details about the event..."
                class="w-full px-4 py-2 text-gray-200 placeholder-gray-500 bg-dark-700 border border-dark-600 rounded-md focus:ring-2 focus:ring-primary-500 focus:border-transparent resize-none"
              >{@form[:description].value}</textarea>
            </div>

            <%!-- Color Override --%>
            <div>
              <label for={@form[:color].id} class="block text-sm font-medium text-gray-300 mb-2">
                Custom Color <span class="text-gray-500 font-normal">(optional)</span>
              </label>
              <div class="flex items-center gap-3">
                <input
                  type="color"
                  id={@form[:color].id}
                  name={@form[:color].name}
                  value={@form[:color].value || "#06b6d4"}
                  class="h-10 w-20 bg-dark-700 border border-dark-600 rounded cursor-pointer"
                />
                <span class="text-sm text-gray-500">
                  Leave default to use event type color
                </span>
              </div>
            </div>

            <%!-- Recurrence Section --%>
            <div class="border-t border-dark-600 pt-6">
              <div class="flex items-center justify-between mb-4">
                <div class="flex items-center gap-3">
                  <input type="hidden" name={@form[:is_recurring].name} value="false" />
                  <input
                    type="checkbox"
                    id={@form[:is_recurring].id}
                    name={@form[:is_recurring].name}
                    value="true"
                    checked={@is_recurring}
                    class="h-4 w-4"
                  />
                  <label for={@form[:is_recurring].id} class="text-sm font-medium text-gray-300">
                    Recurring Event
                  </label>
                </div>
                <%= if @is_recurring do %>
                  <button
                    type="button"
                    phx-click="toggle_recurrence"
                    class="text-sm text-primary-500 hover:text-primary-400"
                  >
                    {if @show_recurrence_options, do: "Hide options", else: "Show options"}
                  </button>
                <% end %>
              </div>

              <%= if @is_recurring do %>
                <%!-- Hidden input for recurrence_rule to ensure it's always submitted --%>
                <%= if !@show_recurrence_options do %>
                  <input
                    type="hidden"
                    name={@form[:recurrence_rule].name}
                    value={@form[:recurrence_rule].value}
                  />
                <% end %>

                <%!-- Show current recurrence pattern --%>
                <div class="mb-4 p-3 bg-dark-700/50 rounded-lg">
                  <p class="text-sm text-gray-300">
                    <span class="font-medium">Current pattern:</span>
                    <span class="text-primary-400 ml-2">{format_rrule(@form[:recurrence_rule].value)}</span>
                  </p>
                </div>

                <%!-- Recurrence Presets --%>
                <div class="mb-4">
                  <label class="block text-sm font-medium text-gray-300 mb-2">
                    Quick Presets
                  </label>
                  <div class="flex flex-wrap gap-2">
                    <%= for preset <- @recurrence_presets do %>
                      <%= if preset.rrule do %>
                        <button
                          type="button"
                          phx-click="apply_preset"
                          phx-value-preset={preset.id}
                          class={[
                            "px-3 py-1.5 text-xs font-medium border rounded-full transition-colors",
                            if(@form[:recurrence_rule].value == preset.rrule,
                              do: "bg-primary-500 text-white border-primary-500",
                              else: "bg-dark-700 text-gray-300 border-dark-600 hover:bg-dark-600 hover:text-white"
                            )
                          ]}
                        >
                          {preset.label}
                        </button>
                      <% end %>
                    <% end %>
                  </div>
                </div>

                <%!-- Recurrence Rule (Advanced) --%>
                <%= if @show_recurrence_options do %>
                  <div class="space-y-4 p-4 bg-dark-700/50 rounded-lg">
                    <div>
                      <label
                        for={@form[:recurrence_rule].id}
                        class="block text-sm font-medium text-gray-300 mb-2"
                      >
                        Recurrence Rule (RRULE)
                      </label>
                      <input
                        type="text"
                        id={@form[:recurrence_rule].id}
                        name={@form[:recurrence_rule].name}
                        value={@form[:recurrence_rule].value}
                        placeholder="e.g., FREQ=WEEKLY;BYDAY=SU"
                        class="w-full px-4 py-2 text-gray-200 placeholder-gray-500 bg-dark-700 border border-dark-600 rounded-md focus:ring-2 focus:ring-primary-500 focus:border-transparent font-mono text-sm"
                      />
                      <p class="mt-1 text-xs text-gray-500">
                        Uses iCalendar RRULE format. Examples: FREQ=WEEKLY;BYDAY=SU, FREQ=MONTHLY;BYMONTHDAY=1
                      </p>
                    </div>

                    <div>
                      <label
                        for={@form[:recurrence_end_date].id}
                        class="block text-sm font-medium text-gray-300 mb-2"
                      >
                        Recurrence End Date <span class="text-gray-500 font-normal">(optional)</span>
                      </label>
                      <input
                        type="date"
                        id={@form[:recurrence_end_date].id}
                        name={@form[:recurrence_end_date].name}
                        value={@form[:recurrence_end_date].value}
                        class="w-full px-4 py-2 text-gray-200 bg-dark-700 border border-dark-600 rounded-md focus:ring-2 focus:ring-primary-500 focus:border-transparent"
                      />
                      <p class="mt-1 text-xs text-gray-500">
                        Leave empty for no end date
                      </p>
                    </div>
                  </div>
                <% end %>
              <% end %>
            </div>

            <%!-- Form Actions --%>
            <div class="flex items-center justify-end gap-3 pt-4 border-t border-dark-600">
              <.link
                navigate={~p"/events"}
                class="px-4 py-2 text-sm font-medium text-gray-300 bg-dark-700 hover:bg-dark-600 rounded-md border border-dark-600 transition-colors"
              >
                Cancel
              </.link>
              <button
                type="submit"
                class="px-4 py-2 text-sm font-medium text-white bg-primary-500 hover:bg-primary-600 rounded-md shadow-lg shadow-primary-500/20 transition-colors"
              >
                Create Event
              </button>
            </div>
          </.form>
        </div>
      </div>
    </div>
    """
  end

  # Extract date part from datetime value (YYYY-MM-DD)
  defp extract_date(nil), do: ""
  defp extract_date(""), do: ""

  defp extract_date(%DateTime{} = dt) do
    dt |> DateTime.to_date() |> Date.to_iso8601()
  end

  defp extract_date(value) when is_binary(value) do
    # Handle "YYYY-MM-DDTHH:MM" or "YYYY-MM-DD" format
    value |> String.split("T") |> List.first() |> Kernel.||("")
  end

  defp extract_date(_), do: ""

  # Extract time part from datetime value (HH:MM)
  defp extract_time(nil), do: "09:00"
  defp extract_time(""), do: "09:00"

  defp extract_time(%DateTime{} = dt) do
    dt
    |> DateTime.to_time()
    |> Time.to_iso8601()
    |> String.slice(0, 5)
  end

  defp extract_time(value) when is_binary(value) do
    case String.split(value, "T") do
      [_date, time] -> String.slice(time, 0, 5)
      _ -> "09:00"
    end
  end

  defp extract_time(_), do: "09:00"

  # Combine separate date and time fields into datetime strings
  defp combine_date_time_fields(params, form_params) do
    start_date = params["start_date"] || extract_date(form_params["start_time"])
    end_date = params["end_date"] || extract_date(form_params["end_time"])
    start_time_only = params["start_time_only"] || "09:00"
    end_time_only = params["end_time_only"] || "10:00"

    # Only combine if we have date values
    form_params =
      if start_date && start_date != "" do
        Map.put(form_params, "start_time", "#{start_date}T#{start_time_only}")
      else
        form_params
      end

    if end_date && end_date != "" do
      Map.put(form_params, "end_time", "#{end_date}T#{end_time_only}")
    else
      form_params
    end
  end

  defp format_rrule(nil), do: "Not set"
  defp format_rrule(""), do: "Not set"
  defp format_rrule("FREQ=WEEKLY;BYDAY=SU"), do: "Every Sunday"
  defp format_rrule("FREQ=WEEKLY;BYDAY=WE"), do: "Every Wednesday"
  defp format_rrule("FREQ=WEEKLY;BYDAY=FR"), do: "Every Friday"
  defp format_rrule("FREQ=WEEKLY;INTERVAL=2"), do: "Every 2 Weeks"
  defp format_rrule("FREQ=MONTHLY;BYDAY=1SU"), do: "First Sunday of Month"
  defp format_rrule("FREQ=MONTHLY"), do: "Same Day Monthly"
  defp format_rrule(rule), do: rule

  # Generate time options in 30-minute intervals
  defp time_options do
    for hour <- 0..23, minute <- [0, 30] do
      value = format_time_value(hour, minute)
      label = format_time_label(hour, minute)
      {label, value}
    end
  end

  defp format_time_value(hour, minute) do
    hour_str = String.pad_leading(Integer.to_string(hour), 2, "0")
    minute_str = String.pad_leading(Integer.to_string(minute), 2, "0")
    "#{hour_str}:#{minute_str}"
  end

  defp format_time_label(hour, minute) do
    {display_hour, period} =
      cond do
        hour == 0 -> {12, "AM"}
        hour < 12 -> {hour, "AM"}
        hour == 12 -> {12, "PM"}
        true -> {hour - 12, "PM"}
      end

    minute_str = String.pad_leading(Integer.to_string(minute), 2, "0")
    "#{display_hour}:#{minute_str} #{period}"
  end

  # Convert a time value (HH:MM) to display label
  defp format_time_label_from_value(time_value) do
    case String.split(time_value || "09:00", ":") do
      [hour_str, min_str] ->
        hour = String.to_integer(hour_str)
        minute = String.to_integer(min_str)
        format_time_label(hour, minute)

      _ ->
        "9:00 AM"
    end
  end
end
