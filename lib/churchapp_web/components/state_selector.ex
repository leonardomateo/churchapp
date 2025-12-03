defmodule ChurchappWeb.StateSelector do
  use Phoenix.LiveComponent
  use ChurchappWeb, :html

  alias ChurchappWeb.Utils.USStates

  def update(%{field: field, form: form} = assigns, socket) do
    current_value = field.value

    selected_state =
      if current_value,
        do: USStates.get_state_by_abbr(current_value) || USStates.get_state_by_name(current_value)

    socket =
      socket
      |> assign(:field, field)
      |> assign(:form, form)
      |> assign(:id, assigns[:id] || "state-#{field.id}")
      |> assign(:name, field.name)
      |> assign(:value, current_value || "")
      |> assign(:selected_state, selected_state)
      |> assign(:query, "")
      |> assign(:filtered_states, USStates.states())
      |> assign(:show_dropdown, false)
      |> assign(:focused_index, 0)

    {:ok, socket}
  end

  def handle_event("toggle_dropdown", _params, socket) do
    {:noreply, assign(socket, :show_dropdown, not socket.assigns.show_dropdown)}
  end

  def handle_event("show_dropdown", _params, socket) do
    {:noreply, assign(socket, :show_dropdown, true)}
  end

  def handle_event("hide_dropdown", _params, socket) do
    {:noreply, assign(socket, :show_dropdown, false)}
  end

  # Handle all keyboard input
  def handle_event("handle_key", %{"key" => "ArrowDown", "value" => _value}, socket) do
    if socket.assigns.show_dropdown do
      new_index =
        min(socket.assigns.focused_index + 1, length(socket.assigns.filtered_states) - 1)

      {:noreply, assign(socket, :focused_index, new_index)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("handle_key", %{"key" => "ArrowUp", "value" => _value}, socket) do
    if socket.assigns.show_dropdown do
      new_index = max(socket.assigns.focused_index - 1, 0)
      {:noreply, assign(socket, :focused_index, new_index)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("handle_key", %{"key" => "Enter", "value" => _value}, socket) do
    if socket.assigns.show_dropdown and length(socket.assigns.filtered_states) > 0 do
      {name, code} = Enum.at(socket.assigns.filtered_states, socket.assigns.focused_index)

      {:noreply,
       socket
       |> assign(:value, code)
       |> assign(:selected_state, {name, code})
       |> assign(:query, "")
       |> assign(:show_dropdown, false)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("handle_key", %{"key" => "Escape", "value" => _value}, socket) do
    {:noreply, assign(socket, :show_dropdown, false)}
  end

  # Handle regular typing for search
  def handle_event("handle_key", %{"value" => query}, socket) do
    filtered_states = USStates.search_states(query)
    focused_index = if length(filtered_states) > 0, do: 0, else: -1

    {:noreply,
     socket
     |> assign(:query, query)
     |> assign(:filtered_states, filtered_states)
     |> assign(:focused_index, focused_index)
     |> assign(:show_dropdown, true)}
  end

  def handle_event("select_state", %{"code" => code, "name" => name}, socket) do
    {:noreply,
     socket
     |> assign(:value, code)
     |> assign(:selected_state, {name, code})
     |> assign(:query, "")
     |> assign(:show_dropdown, false)}
  end

  def render(assigns) do
    ~H"""
    <div class="relative" id={@id}>
      <div class="relative">
        <input
          type="text"
          id={"#{@id}-input"}
          value={display_value(@selected_state, @query)}
          phx-focus="show_dropdown"
          phx-keyup="handle_key"
          phx-target={@myself}
          phx-debounce="200"
          autocomplete="off"
          placeholder="Search or select a state"
          class="block w-full px-3 py-2 text-white bg-dark-900 border-dark-700 rounded-md shadow-sm sm:text-sm focus:ring-primary-500 focus:border-primary-500 cursor-pointer"
        />

        <.icon
          name="hero-chevron-down"
          class="absolute right-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-gray-400 pointer-events-none"
        />
      </div>

      <input
        type="hidden"
        name={@name}
        value={@value}
        id={"#{@id}-hidden"}
      />

      <div
        :if={@show_dropdown}
        class="absolute z-50 w-full mt-1 bg-dark-800 border border-dark-700 rounded-md shadow-lg max-h-60 overflow-auto"
        id={"#{@id}-dropdown"}
        phx-click-away="hide_dropdown"
        phx-target={@myself}
      >
        <div :if={@filtered_states == []} class="px-3 py-2 text-gray-400 text-sm">
          No states found
        </div>

        <div
          :for={{{name, code}, index} <- Enum.with_index(@filtered_states)}
          class={[
            "px-3 py-2 cursor-pointer text-sm border-b border-dark-700 last:border-b-0",
            index == @focused_index && "bg-primary-600 text-white",
            index != @focused_index && "text-gray-300 hover:bg-dark-700"
          ]}
          phx-click="select_state"
          phx-value-code={code}
          phx-value-name={name}
          phx-target={@myself}
          phx-capture-click
        >
          <div class="font-medium">{name}</div>
          <div class="text-xs text-gray-400">{code}</div>
        </div>
      </div>
    </div>
    """
  end

  defp display_value(nil, query), do: query
  defp display_value({name, _code}, _query), do: name
end
