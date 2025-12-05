defmodule ChurchappWeb.MinistrySelector do
  @moduledoc """
  A searchable dropdown component for selecting ministries.
  Supports keyboard navigation and displays both default and custom ministries.
  """

  use Phoenix.LiveComponent
  use ChurchappWeb, :html

  def update(%{field: field, form: form, ministries: ministries} = assigns, socket) do
    current_value = field.value

    # Find the currently selected ministry if there is one
    selected_ministry =
      if current_value do
        Enum.find(ministries, fn {_name, value} -> value == current_value end)
      end

    socket =
      socket
      |> assign(:field, field)
      |> assign(:form, form)
      |> assign(:id, assigns[:id] || "ministry-#{field.id}")
      |> assign(:name, field.name)
      |> assign(:value, current_value || "")
      |> assign(:selected_ministry, selected_ministry)
      |> assign(:query, "")
      |> assign(:all_ministries, ministries)
      |> assign(:filtered_ministries, ministries)
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
      # Start from -1, so first arrow down goes to 0
      current_index = socket.assigns.focused_index
      new_index = min(current_index + 1, length(socket.assigns.filtered_ministries) - 1)

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
         length(socket.assigns.filtered_ministries) > 0 do
      {name, value} = Enum.at(socket.assigns.filtered_ministries, socket.assigns.focused_index)

      {:noreply,
       socket
       |> assign(:value, value)
       |> assign(:selected_ministry, {name, value})
       |> assign(:query, "")
       |> assign(:show_dropdown, false)
       |> push_event("ministry-selected", %{value: value})}
    else
      {:noreply, socket}
    end
  end

  def handle_event("handle_key", %{"key" => "Escape"}, socket) do
    {:noreply, assign(socket, :show_dropdown, false)}
  end

  # Handle typing for search
  def handle_event("handle_key", %{"value" => query}, socket) do
    filtered_ministries = search_ministries(socket.assigns.all_ministries, query)

    {:noreply,
     socket
     |> assign(:query, query)
     |> assign(:filtered_ministries, filtered_ministries)
     |> assign(:focused_index, -1)
     |> assign(:show_dropdown, true)}
  end

  def handle_event("select_ministry", %{"value" => value, "name" => name}, socket) do
    {:noreply,
     socket
     |> assign(:value, value)
     |> assign(:selected_ministry, {name, value})
     |> assign(:query, "")
     |> assign(:show_dropdown, false)
     |> push_event("ministry-selected", %{value: value})}
  end

  def handle_event("clear_selection", _params, socket) do
    {:noreply,
     socket
     |> assign(:value, "")
     |> assign(:selected_ministry, nil)
     |> assign(:query, "")
     |> assign(:filtered_ministries, socket.assigns.all_ministries)
     |> assign(:show_dropdown, false)}
  end

  defp search_ministries(ministries, query) when query == "" or is_nil(query) do
    ministries
  end

  defp search_ministries(ministries, query) do
    query_lower = String.downcase(query)

    Enum.filter(ministries, fn {name, _value} ->
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
          value={display_value(@selected_ministry, @query)}
          phx-focus="show_dropdown"
          phx-keyup="handle_key"
          phx-target={@myself}
          phx-debounce="150"
          autocomplete="off"
          placeholder="Search ministries..."
          class="block w-full px-3 py-2 pr-10 text-white bg-dark-900 border border-dark-700 rounded-md shadow-sm sm:text-sm focus:ring-primary-500 focus:border-primary-500 cursor-pointer"
        />

        <%= if @selected_ministry do %>
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
        <div :if={@filtered_ministries == []} class="px-3 py-2 text-gray-400 text-sm">
          No ministries found
        </div>

        <div
          :for={{{name, value}, index} <- Enum.with_index(@filtered_ministries)}
          class={[
            "px-3 py-2 cursor-pointer text-sm border-b border-dark-700 last:border-b-0 transition-colors",
            index == @focused_index && "bg-primary-500 text-white",
            index != @focused_index && "text-gray-300 hover:bg-dark-700"
          ]}
          phx-click="select_ministry"
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
