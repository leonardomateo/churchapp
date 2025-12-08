defmodule ChurchappWeb.EventActivitySelector do
  @moduledoc """
  A searchable dropdown component for selecting event/activity names.
  """
  use Phoenix.LiveComponent
  use ChurchappWeb, :html

  def update(%{field: field, form: form, activity_names: activity_names} = assigns, socket) do
    current_value = field.value

    # Find the currently selected name if there is one
    selected_name =
      if current_value do
        Enum.find(activity_names, fn {_name, value} -> value == current_value end)
      end

    socket =
      socket
      |> assign(:field, field)
      |> assign(:form, form)
      |> assign(:id, assigns[:id] || "event-activity-#{field.id}")
      |> assign(:name, field.name)
      |> assign(:value, current_value || "")
      |> assign(:selected_name, selected_name)
      |> assign(:query, "")
      |> assign(:all_names, activity_names)
      |> assign(:filtered_names, activity_names)
      |> assign(:show_dropdown, false)
      |> assign(:focused_index, -1)

    {:ok, socket}
  end

  def handle_event("show_dropdown", _params, socket) do
    {:noreply, socket |> assign(:show_dropdown, true) |> assign(:focused_index, -1)}
  end

  def handle_event("hide_dropdown", _params, socket) do
    {:noreply, assign(socket, :show_dropdown, false)}
  end

  # Handle keyboard navigation
  def handle_event("handle_key", %{"key" => "ArrowDown"}, socket) do
    if socket.assigns.show_dropdown do
      current_index = socket.assigns.focused_index
      new_index = min(current_index + 1, length(socket.assigns.filtered_names) - 1)
      {:noreply, assign(socket, :focused_index, new_index)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("handle_key", %{"key" => "ArrowUp"}, socket) do
    if socket.assigns.show_dropdown do
      new_index = max(socket.assigns.focused_index - 1, -1)
      {:noreply, assign(socket, :focused_index, new_index)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("handle_key", %{"key" => "Enter"}, socket) do
    if socket.assigns.show_dropdown and socket.assigns.focused_index >= 0 and
         length(socket.assigns.filtered_names) > 0 do
      {name, value} = Enum.at(socket.assigns.filtered_names, socket.assigns.focused_index)

      # Notify parent LiveView about the selection
      send(self(), {:activity_selected, value})

      {:noreply,
       socket
       |> assign(:value, value)
       |> assign(:selected_name, {name, value})
       |> assign(:query, "")
       |> assign(:show_dropdown, false)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("handle_key", %{"key" => "Escape"}, socket) do
    {:noreply, assign(socket, :show_dropdown, false)}
  end

  # Handle typing for search
  def handle_event("handle_key", %{"value" => query}, socket) do
    filtered_names = search_names(socket.assigns.all_names, query)

    {:noreply,
     socket
     |> assign(:query, query)
     |> assign(:filtered_names, filtered_names)
     |> assign(:focused_index, -1)
     |> assign(:show_dropdown, true)}
  end

  def handle_event("select_name", %{"value" => value, "name" => name}, socket) do
    # Notify parent LiveView about the selection
    send(self(), {:activity_selected, value})

    {:noreply,
     socket
     |> assign(:value, value)
     |> assign(:selected_name, {name, value})
     |> assign(:query, "")
     |> assign(:show_dropdown, false)}
  end

  def handle_event("clear_selection", _params, socket) do
    {:noreply,
     socket
     |> assign(:value, "")
     |> assign(:selected_name, nil)
     |> assign(:query, "")
     |> assign(:filtered_names, socket.assigns.all_names)
     |> assign(:show_dropdown, false)}
  end

  defp search_names(names, query) when query == "" or is_nil(query) do
    names
  end

  defp search_names(names, query) do
    query_lower = String.downcase(query)

    Enum.filter(names, fn {name, _value} ->
      name_lower = String.downcase(name)
      String.contains?(name_lower, query_lower)
    end)
  end

  def render(assigns) do
    ~H"""
    <div class="relative" id={@id}>
      <div class="relative">
        <input
          type="text"
          id={"#{@id}-input"}
          value={display_value(@selected_name, @query)}
          phx-focus="show_dropdown"
          phx-keyup="handle_key"
          phx-target={@myself}
          phx-debounce="150"
          autocomplete="off"
          placeholder="Search or select an event/activity..."
          class="block w-full px-3 py-2 pr-10 text-white bg-dark-900 border border-dark-700 rounded-md shadow-sm sm:text-sm focus:ring-primary-500 focus:border-primary-500"
        />

        <%= if @selected_name do %>
          <button
            type="button"
            phx-click="clear_selection"
            phx-target={@myself}
            class="absolute right-3 top-1/2 transform -translate-y-1/2 text-gray-400 hover:text-white transition-colors"
          >
            <.icon name="hero-x-mark" class="h-4 w-4" />
          </button>
        <% else %>
          <.icon
            name="hero-magnifying-glass"
            class="absolute right-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-gray-400 pointer-events-none"
          />
        <% end %>
      </div>

      <input type="hidden" name={@name} value={@value} id={"#{@id}-hidden"} />

      <div
        :if={@show_dropdown}
        class="absolute z-50 w-full mt-1 bg-dark-800 border border-dark-700 rounded-md shadow-lg max-h-60 overflow-auto"
        id={"#{@id}-dropdown"}
        phx-click-away="hide_dropdown"
        phx-target={@myself}
      >
        <div :if={@filtered_names == []} class="px-3 py-2 text-gray-400 text-sm">
          No activities found. Click "Add Custom" to create one.
        </div>

        <div
          :for={{{name, value}, index} <- Enum.with_index(@filtered_names)}
          class={[
            "px-3 py-2 cursor-pointer text-sm border-b border-dark-700 last:border-b-0 transition-colors",
            index == @focused_index && "bg-primary-500 text-white",
            index != @focused_index && "text-gray-300 hover:bg-dark-700"
          ]}
          phx-click="select_name"
          phx-value-value={value}
          phx-value-name={name}
          phx-target={@myself}
        >
          <div class="flex items-center justify-between">
            <div class="font-medium">{name}</div>
            <%= if index == @focused_index do %>
              <.icon name="hero-check" class="h-4 w-4 ml-2" />
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp display_value(nil, query), do: query
  defp display_value({name, _value}, _query), do: name
end
