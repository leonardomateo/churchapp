defmodule ChurchappWeb.EventsLive.NewLive do
  use ChurchappWeb, :live_view

  alias Chms.Church.Events
  alias Chms.Church.EventActivityNames
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

    # Create form without validating to avoid showing errors on initial load
    form =
      Events
      |> Form.for_create(:create,
        domain: Chms.Church,
        actor: socket.assigns.current_user,
        params: initial_values
      )
      |> to_form()

    activity_names = EventActivityNames.all_name_options()

    socket =
      socket
      |> assign(:page_title, "New Event")
      |> assign(:form, form)
      |> assign(:start_time_dropdown_open, false)
      |> assign(:end_time_dropdown_open, false)
      |> assign(:activity_names, activity_names)
      |> assign(:show_custom_name_modal, false)
      |> assign(:custom_name_input, "")
      |> assign(:custom_name_error, nil)

    {:noreply, socket}
  end

  @impl true
  def handle_event("validate", params, socket) do
    # Handle both nested "form" params and top-level params
    form_params = params["form"] || params

    # Combine separate date/time fields into datetime fields
    form_params = combine_date_time_fields(params, form_params)

    form =
      socket.assigns.form.source
      |> Form.validate(form_params)
      |> to_form()

    {:noreply, assign(socket, :form, form)}
  end

  def handle_event("save", params, socket) do
    # Handle both nested "form" params and top-level params
    form_params = params["form"] || params

    # Combine separate date/time fields into datetime fields (same as validate)
    form_params = combine_date_time_fields(params, form_params)

    case Form.submit(socket.assigns.form.source, params: form_params) do
      {:ok, event} ->
        {:noreply,
         socket
         |> put_flash(:info, "Event \"#{event.title}\" created successfully")
         |> push_navigate(to: ~p"/events")}

      {:error, form} ->
        {:noreply, assign(socket, :form, to_form(form))}
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

    form =
      socket.assigns.form.source
      |> Form.validate(form_params)
      |> to_form()

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

    form =
      socket.assigns.form.source
      |> Form.validate(form_params)
      |> to_form()

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

  def handle_event("open_custom_name_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_custom_name_modal, true)
     |> assign(:custom_name_input, "")
     |> assign(:custom_name_error, nil)}
  end

  def handle_event("close_modal", _params, socket) do
    {:noreply, assign(socket, :show_custom_name_modal, false)}
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
      # Add the new name to the list and select it in the form
      updated_names = socket.assigns.activity_names ++ [{custom_name, custom_name}]

      # Update the form with the new custom name
      form_params = get_current_form_params(socket.assigns.form)
      form_params = Map.put(form_params, "title", custom_name)

      form =
        socket.assigns.form.source
        |> Form.validate(form_params)
        |> to_form()

      {:noreply,
       socket
       |> assign(:activity_names, updated_names)
       |> assign(:form, form)
       |> assign(:show_custom_name_modal, false)
       |> assign(:custom_name_input, "")
       |> put_flash(:info, "New activity '#{custom_name}' added successfully")}
    end
  end

  @impl true
  def handle_info({:activity_selected, value}, socket) do
    # Update the form with the selected activity name
    form_params = get_current_form_params(socket.assigns.form)
    form_params = Map.put(form_params, "title", value)

    form =
      socket.assigns.form.source
      |> Form.validate(form_params)
      |> to_form()

    {:noreply, assign(socket, :form, form)}
  end

  defp is_admin?(nil), do: false
  defp is_admin?(user), do: user.role in [:super_admin, :admin, :staff]

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

      <div class="max-w-2xl mx-auto">
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
              <label class="block text-sm font-medium text-gray-300 mb-2">
                Event / Activity Name <span class="text-red-500">*</span>
              </label>
              <div class="flex gap-2">
                <div class="flex-1">
                  <.live_component
                    module={ChurchappWeb.EventActivitySelector}
                    id="event-activity-selector-new"
                    field={@form[:title]}
                    form={@form}
                    activity_names={@activity_names}
                  />
                </div>
                <div class="relative group">
                  <button
                    type="button"
                    phx-click="open_custom_name_modal"
                    class="flex items-center h-[42px] px-4 text-sm font-medium text-primary-500 bg-primary-500/10 border border-primary-500/20 rounded-md hover:bg-primary-500/20 hover:border-primary-500/30 transition-all duration-200 whitespace-nowrap"
                  >
                    <.icon name="hero-plus" class="h-5 w-5 mr-1.5" /> Add Custom
                  </button>
                  <%!-- Tooltip --%>
                  <div class="absolute bottom-full left-1/2 transform -translate-x-1/2 mb-2 px-3 py-1.5 bg-dark-700 text-white text-xs rounded-md shadow-lg opacity-0 group-hover:opacity-100 transition-opacity duration-200 pointer-events-none whitespace-nowrap">
                    Create a new event/activity name
                    <div class="absolute top-full left-1/2 transform -translate-x-1/2 -mt-1 border-4 border-transparent border-t-dark-700">
                    </div>
                  </div>
                </div>
              </div>
              <p
                :for={msg <- get_field_errors(@form[:title])}
                class="mt-1.5 flex gap-2 items-center text-sm text-red-400"
              >
                <.icon name="hero-exclamation-circle" class="h-5 w-5" />
                {msg}
              </p>
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
                  <p
                    :for={msg <- get_field_errors(@form[:start_time])}
                    class="mt-1.5 flex gap-2 items-center text-sm text-red-400"
                  >
                    <.icon name="hero-exclamation-circle" class="h-5 w-5" />
                    {msg}
                  </p>
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
                  <p
                    :for={msg <- get_field_errors(@form[:end_time])}
                    class="mt-1.5 flex gap-2 items-center text-sm text-red-400"
                  >
                    <.icon name="hero-exclamation-circle" class="h-5 w-5" />
                    {msg}
                  </p>
                </div>
              </div>

              <%!-- Time Row with All Day Toggle --%>
              <div class="grid grid-cols-1 md:grid-cols-[1fr_1fr_auto] gap-4 items-start">
                <%!-- Start Time Custom Dropdown --%>
                <div>
                  <label class="block text-sm font-medium text-gray-300 mb-2">
                    From <span class="text-red-500">*</span>
                  </label>
                  <div class="relative">
                    <input
                      type="hidden"
                      name="start_time_only"
                      value={extract_time(@form[:start_time].value)}
                    />
                    <button
                      type="button"
                      phx-click="toggle_start_time_dropdown"
                      disabled={@form[:all_day].value == true || @form[:all_day].value == ""}
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
                </div>

                <%!-- End Time Custom Dropdown --%>
                <div>
                  <label class="block text-sm font-medium text-gray-300 mb-2">
                    To <span class="text-red-500">*</span>
                  </label>
                  <div class="relative">
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
                  <p
                    :for={msg <- get_field_errors(@form[:end_time])}
                    class="mt-1.5 flex gap-2 items-center text-sm text-red-400"
                  >
                    <.icon name="hero-exclamation-circle" class="h-5 w-5" />
                    {msg}
                  </p>
                </div>

                <div class="flex items-center gap-2 mt-8">
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
                  value={@form[:color].value || "#06b6d4"}
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

      <%!-- Custom Activity Name Modal --%>
      <%= if @show_custom_name_modal do %>
        <div
          class="fixed inset-0 z-50 overflow-y-auto animate-fade-in"
          phx-window-keydown="close_modal"
          phx-key="escape"
        >
          <div class="flex min-h-screen items-center justify-center p-4">
            <%!-- Backdrop --%>
            <div
              class="fixed inset-0 modal-backdrop transition-opacity"
              phx-click="close_modal"
            >
            </div>
            <%!-- Modal --%>
            <div class="relative bg-dark-800 rounded-lg shadow-xl border border-dark-700 w-full max-w-md p-6 z-10 animate-scale-in">
              <%!-- Header --%>
              <div class="flex items-center justify-between mb-4">
                <h3 class="text-lg font-semibold text-white flex items-center">
                  <.icon name="hero-plus-circle" class="mr-2 h-5 w-5 text-primary-500" />
                  Add Custom Event/Activity
                </h3>
                <button
                  type="button"
                  phx-click="close_modal"
                  class="text-gray-400 hover:text-white transition-colors"
                >
                  <.icon name="hero-x-mark" class="h-5 w-5" />
                </button>
              </div>
              <%!-- Content --%>
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
                    placeholder="e.g., Sunday Worship Service, Bible Study..."
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
                  This name will be saved and available for future events
                </p>
              </div>
              <%!-- Actions --%>
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
                    <.icon name="hero-check" class="mr-1 h-4 w-4" /> Save
                  </span>
                </button>
              </div>
            </div>
          </div>
        </div>
      <% end %>
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

  defp get_field_errors(field) do
    case field.errors do
      errors when is_list(errors) ->
        Enum.map(errors, fn
          {msg, _opts} -> msg
          msg when is_binary(msg) -> msg
          _ -> "Invalid"
        end)

      _ ->
        []
    end
  end
end
