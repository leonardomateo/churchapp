defmodule ChurchappWeb.EventsLive.EditLive do
  use ChurchappWeb, :live_view

  alias Chms.Church.Events
  alias AshPhoenix.Form

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    # Check if user is admin
    unless is_admin?(socket.assigns[:current_user]) do
      {:ok,
       socket
       |> put_flash(:error, "You don't have permission to edit events")
       |> push_navigate(to: ~p"/events")}
    else
      case Chms.Church.get_event_by_id(id) do
        {:ok, event} ->
          form =
            event
            |> Form.for_update(:update, domain: Chms.Church, actor: socket.assigns.current_user)
            |> to_form()

          {:ok,
           socket
           |> assign(:page_title, "Edit #{event.title}")
           |> assign(:event, event)
           |> assign(:form, form)
           |> assign(:is_recurring, event.is_recurring)
           |> assign(:show_recurrence_options, event.is_recurring && event.recurrence_rule != nil)
           |> assign(:event_types, Events.event_types())
           |> assign(:recurrence_presets, recurrence_presets())}

        {:error, _} ->
          {:ok,
           socket
           |> put_flash(:error, "Event not found")
           |> push_navigate(to: ~p"/events")}
      end
    end
  end

  @impl true
  def handle_event("validate", %{"form" => params}, socket) do
    form = Form.validate(socket.assigns.form, params)
    is_recurring = params["is_recurring"] == "true"

    {:noreply,
     socket
     |> assign(:form, form)
     |> assign(:is_recurring, is_recurring)}
  end

  def handle_event("save", %{"form" => params}, socket) do
    case Form.submit(socket.assigns.form, params: params) do
      {:ok, event} ->
        {:noreply,
         socket
         |> put_flash(:info, "Event \"#{event.title}\" updated successfully")
         |> push_navigate(to: ~p"/events/#{event}")}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end

  def handle_event("toggle_recurrence", _params, socket) do
    {:noreply, assign(socket, :show_recurrence_options, !socket.assigns.show_recurrence_options)}
  end

  def handle_event("apply_preset", %{"preset" => preset}, socket) do
    rrule = get_preset_rrule(preset)

    form =
      socket.assigns.form
      |> Form.validate(%{
        "is_recurring" => "true",
        "recurrence_rule" => rrule
      })

    {:noreply,
     socket
     |> assign(:form, form)
     |> assign(:is_recurring, true)
     |> assign(:show_recurrence_options, false)}
  end

  defp is_admin?(nil), do: false
  defp is_admin?(user), do: user.role in [:super_admin, :admin]

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
            <%!-- Event Title --%>
            <div>
              <.input
                field={@form[:title]}
                type="text"
                label="Event Title *"
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
                class="w-full px-4 py-2 text-gray-200 bg-dark-700 border border-dark-600 rounded-md focus:ring-2 focus:ring-primary-500 focus:border-transparent"
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

            <%!-- Date & Time Row --%>
            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <label
                  for={@form[:start_time].id}
                  class="block text-sm font-medium text-gray-300 mb-2"
                >
                  Start Date & Time <span class="text-red-500">*</span>
                </label>
                <input
                  type="datetime-local"
                  id={@form[:start_time].id}
                  name={@form[:start_time].name}
                  value={format_datetime_local(@form[:start_time].value)}
                  class="w-full px-4 py-2 text-gray-200 bg-dark-700 border border-dark-600 rounded-md focus:ring-2 focus:ring-primary-500 focus:border-transparent"
                  required
                />
              </div>

              <div>
                <label for={@form[:end_time].id} class="block text-sm font-medium text-gray-300 mb-2">
                  End Date & Time <span class="text-red-500">*</span>
                </label>
                <input
                  type="datetime-local"
                  id={@form[:end_time].id}
                  name={@form[:end_time].name}
                  value={format_datetime_local(@form[:end_time].value)}
                  class="w-full px-4 py-2 text-gray-200 bg-dark-700 border border-dark-600 rounded-md focus:ring-2 focus:ring-primary-500 focus:border-transparent"
                  required
                />
              </div>
            </div>

            <%!-- All Day Checkbox --%>
            <div class="flex items-center gap-3">
              <input
                type="checkbox"
                id={@form[:all_day].id}
                name={@form[:all_day].name}
                value="true"
                checked={@form[:all_day].value == true || @form[:all_day].value == "true"}
                class="h-4 w-4"
              />
              <label for={@form[:all_day].id} class="text-sm text-gray-300">
                All-day event
              </label>
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
                  value={@form[:color].value || Events.default_color_for_type(@event.event_type)}
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
                          class="px-3 py-1.5 text-xs font-medium bg-dark-700 text-gray-300 border border-dark-600 rounded-full hover:bg-dark-600 hover:text-white transition-colors"
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
                        value={format_date(@form[:recurrence_end_date].value)}
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

  defp format_datetime_local(nil), do: ""
  defp format_datetime_local(""), do: ""

  defp format_datetime_local(%DateTime{} = dt) do
    dt
    |> DateTime.to_naive()
    |> NaiveDateTime.to_iso8601()
    |> String.slice(0, 16)
  end

  defp format_datetime_local(value) when is_binary(value) do
    String.slice(value, 0, 16)
  end

  defp format_datetime_local(_), do: ""

  defp format_date(nil), do: ""
  defp format_date(""), do: ""
  defp format_date(%Date{} = date), do: Date.to_iso8601(date)
  defp format_date(value) when is_binary(value), do: value
  defp format_date(_), do: ""
end
