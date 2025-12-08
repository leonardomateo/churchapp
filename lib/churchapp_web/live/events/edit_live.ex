defmodule ChurchappWeb.EventsLive.EditLive do
  use ChurchappWeb, :live_view

  alias Chms.Church.Events
  alias AshPhoenix.Form

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    actor = socket.assigns[:current_user]

    # Check if user is admin
    unless is_admin?(actor) do
      {:ok,
       socket
       |> put_flash(:error, "You don't have permission to edit events")
       |> push_navigate(to: ~p"/events")}
    else
      case Chms.Church.get_event_by_id(id, actor: actor) do
        {:ok, event} ->
          # Build initial params from the event to preserve date/time values correctly
          initial_params = build_initial_params_from_event(event)

          form =
            event
            |> Form.for_update(:update, domain: Chms.Church, actor: actor)
            |> Form.validate(initial_params)
            |> to_form()

          {:ok,
           socket
           |> assign(:page_title, "Edit #{event.title}")
           |> assign(:event, event)
           |> assign(:form, form)
           |> assign(:start_time_dropdown_open, false)
           |> assign(:end_time_dropdown_open, false)}

        {:error, _} ->
          {:ok,
           socket
           |> put_flash(:error, "Event not found")
           |> push_navigate(to: ~p"/events")}
      end
    end
  end

  @impl true
  def handle_event("validate", params, socket) do
    # Handle both nested "form" params and top-level params
    form_params = params["form"] || params

    # Combine separate date/time fields into datetime fields
    form_params = combine_date_time_fields(params, form_params)

    form = Form.validate(socket.assigns.form, form_params)

    {:noreply, assign(socket, :form, form)}
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
         |> put_flash(:info, "Event \"#{event.title}\" updated successfully")
         |> push_navigate(to: ~p"/events/#{event}")}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
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

    # Get current form values and update start_time
    form_params = get_current_form_params(socket.assigns.form)
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

    # Get current form values and update end_time
    form_params = get_current_form_params(socket.assigns.form)
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

  # Build initial params from event to ensure date/time values are properly serialized
  defp build_initial_params_from_event(event) do
    %{
      "title" => event.title || "",
      "description" => event.description || "",
      "start_time" => format_datetime_for_form(event.start_time),
      "end_time" => format_datetime_for_form(event.end_time),
      "all_day" => to_string(event.all_day || false),
      "location" => event.location || "",
      "color" => event.color || ""
    }
  end

  # Extract current form values to preserve them during partial updates
  defp get_current_form_params(form) do
    base_params = form.params || %{}

    start_time_str =
      case Map.get(base_params, "start_time") do
        nil -> format_datetime_for_form(form[:start_time].value)
        "" -> format_datetime_for_form(form[:start_time].value)
        value -> value
      end

    end_time_str =
      case Map.get(base_params, "end_time") do
        nil -> format_datetime_for_form(form[:end_time].value)
        "" -> format_datetime_for_form(form[:end_time].value)
        value -> value
      end

    %{
      "title" => to_string_value(form[:title].value),
      "description" => to_string_value(form[:description].value),
      "start_time" => start_time_str,
      "end_time" => end_time_str,
      "all_day" => to_string(form[:all_day].value || false),
      "location" => to_string_value(form[:location].value),
      "color" => to_string_value(form[:color].value)
    }
  end

  defp format_datetime_for_form(nil), do: ""
  defp format_datetime_for_form(""), do: ""

  defp format_datetime_for_form(%DateTime{} = dt) do
    date_str = dt |> DateTime.to_date() |> Date.to_iso8601()
    time_str = dt |> DateTime.to_time() |> Time.to_iso8601() |> String.slice(0, 5)
    "#{date_str}T#{time_str}"
  end

  defp format_datetime_for_form(value) when is_binary(value), do: value
  defp format_datetime_for_form(_), do: ""

  defp to_string_value(nil), do: ""
  defp to_string_value(value) when is_binary(value), do: value
  defp to_string_value(value), do: to_string(value)

  @impl true
  def render(assigns) do
    ~H"""
    <div class="view-container active">
      <div class="mb-6">
        <.link
          navigate={~p"/events/#{@event}"}
          class="inline-flex items-center text-sm text-gray-400 hover:text-white transition-colors"
        >
          <.icon name="hero-arrow-left" class="mr-2 h-4 w-4" /> Back to Event
        </.link>
      </div>

      <div class="max-w-2xl">
        <div class="mb-6">
          <h2 class="text-2xl font-bold text-white">Edit Event</h2>
          <p class="mt-1 text-sm text-gray-400">
            Update the event details
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
                  <input
                    type="hidden"
                    name="start_time_only"
                    value={extract_time(@form[:start_time].value)}
                  />
                  <button
                    type="button"
                    phx-click="toggle_start_time_dropdown"
                    disabled={@form[:all_day].value == true || @form[:all_day].value == "true"}
                    class={[
                      "w-full h-[46px] px-4 text-left text-gray-200 bg-dark-700 border border-dark-600 rounded-md focus:ring-2 focus:ring-primary-500 focus:border-transparent flex items-center justify-between",
                      (@form[:all_day].value == true || @form[:all_day].value == "true") &&
                        "opacity-50 cursor-not-allowed"
                    ]}
                  >
                    <span>
                      {format_time_label_from_value(extract_time(@form[:start_time].value))}
                    </span>
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
                          style={
                            if extract_time(@form[:start_time].value) == value,
                              do: "background-color: #06b6d4; color: white;",
                              else: "background-color: #2D2D2D; color: #e5e7eb;"
                          }
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
                  <input
                    type="hidden"
                    name="end_time_only"
                    value={extract_time(@form[:end_time].value)}
                  />
                  <button
                    type="button"
                    phx-click="toggle_end_time_dropdown"
                    disabled={@form[:all_day].value == true || @form[:all_day].value == "true"}
                    class={[
                      "w-full h-[46px] px-4 text-left text-gray-200 bg-dark-700 border border-dark-600 rounded-md focus:ring-2 focus:ring-primary-500 focus:border-transparent flex items-center justify-between",
                      (@form[:all_day].value == true || @form[:all_day].value == "true") &&
                        "opacity-50 cursor-not-allowed"
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
                          style={
                            if extract_time(@form[:end_time].value) == value,
                              do: "background-color: #06b6d4; color: white;",
                              else: "background-color: #2D2D2D; color: #e5e7eb;"
                          }
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
                placeholder="e.g., 320 47th Street"
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
                  value={@form[:color].value || Events.default_color()}
                  class="h-10 w-20 bg-dark-700 border border-dark-600 rounded cursor-pointer"
                />
                <span class="text-sm text-gray-500">
                  Choose a color to display on the calendar
                </span>
              </div>
            </div>

            <%!-- Form Actions --%>
            <div class="flex items-center justify-end gap-3 pt-4 border-t border-dark-600">
              <.link
                navigate={~p"/events/#{@event}"}
                class="px-4 py-2 text-sm font-medium text-gray-300 bg-dark-700 hover:bg-dark-600 rounded-md border border-dark-600 transition-colors"
              >
                Cancel
              </.link>
              <button
                type="submit"
                class="px-4 py-2 text-sm font-medium text-white bg-primary-500 hover:bg-primary-600 rounded-md shadow-lg shadow-primary-500/20 transition-colors"
              >
                Save Changes
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
    value
    |> String.split(~r/[T\s]/)
    |> List.first()
    |> Kernel.||("")
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
    case String.split(value, ~r/[T\s]/) do
      [_date, time | _] ->
        time |> String.slice(0, 5)

      _ ->
        "09:00"
    end
  end

  defp extract_time(_), do: "09:00"

  # Combine separate date and time fields into datetime strings
  defp combine_date_time_fields(params, form_params) do
    start_date = non_empty_string(params["start_date"]) || extract_date(form_params["start_time"])
    end_date = non_empty_string(params["end_date"]) || extract_date(form_params["end_time"])

    start_time_only =
      non_empty_string(params["start_time_only"]) || extract_time(form_params["start_time"])

    end_time_only =
      non_empty_string(params["end_time_only"]) || extract_time(form_params["end_time"])

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

  defp non_empty_string(nil), do: nil
  defp non_empty_string(""), do: nil
  defp non_empty_string(str) when is_binary(str), do: str
  defp non_empty_string(_), do: nil

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

  defp format_time_label_from_value(""), do: "9:00 AM"

  defp format_time_label_from_value(time_value) do
    case String.split(time_value, ":") do
      [hour_str, min_str] ->
        hour = String.to_integer(hour_str)
        minute = String.to_integer(min_str)
        format_time_label(hour, minute)

      _ ->
        "9:00 AM"
    end
  end
end
