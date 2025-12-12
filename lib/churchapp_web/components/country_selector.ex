defmodule ChurchappWeb.CountrySelector do
  @moduledoc """
  A searchable dropdown selector for countries.
  Supports searching through predefined countries and custom countries.
  """
  use Phoenix.LiveComponent
  use ChurchappWeb, :html

  alias ChurchappWeb.Utils.Countries

  def update(%{field: field, form: form, countries: countries} = assigns, socket) do
    current_value = field.value

    # Find the currently selected country if there is one
    selected_country =
      if current_value && current_value != "" do
        # Try to find by name first (since we store the name)
        # Try to find by code
        # If not found, create a tuple with the value as both name and code
        Enum.find(countries, fn {name, _code} ->
          String.downcase(name) == String.downcase(current_value)
        end) ||
          Enum.find(countries, fn {_name, code} ->
            String.downcase(code) == String.downcase(current_value)
          end) ||
          {current_value, current_value}
      end

    socket =
      socket
      |> assign(:field, field)
      |> assign(:form, form)
      |> assign(:id, assigns[:id] || "country-#{field.id}")
      |> assign(:name, field.name)
      |> assign(:value, current_value || "")
      |> assign(:selected_country, selected_country)
      |> assign(:query, "")
      |> assign(:all_countries, countries)
      |> assign(:filtered_countries, countries)
      |> assign(:show_dropdown, false)
      |> assign(:focused_index, -1)

    {:ok, socket}
  end

  def handle_event("show_dropdown", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_dropdown, true)
     |> assign(:focused_index, -1)
     |> assign(:filtered_countries, socket.assigns.all_countries)}
  end

  def handle_event("hide_dropdown", _params, socket) do
    {:noreply, assign(socket, :show_dropdown, false)}
  end

  # Handle keyboard navigation
  def handle_event("handle_key", %{"key" => "ArrowDown"}, socket) do
    if socket.assigns.show_dropdown do
      current_index = socket.assigns.focused_index
      new_index = min(current_index + 1, length(socket.assigns.filtered_countries) - 1)
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
         length(socket.assigns.filtered_countries) > 0 do
      {name, _code} = Enum.at(socket.assigns.filtered_countries, socket.assigns.focused_index)

      {:noreply,
       socket
       |> assign(:value, name)
       |> assign(:selected_country, {name, name})
       |> assign(:query, "")
       |> assign(:show_dropdown, false)
       |> push_event("country-selected", %{value: name})}
    else
      {:noreply, socket}
    end
  end

  def handle_event("handle_key", %{"key" => "Escape"}, socket) do
    {:noreply, assign(socket, :show_dropdown, false)}
  end

  # Handle typing for search
  def handle_event("handle_key", %{"value" => query}, socket) do
    filtered_countries = Countries.search_countries(socket.assigns.all_countries, query)
    focused_index = if length(filtered_countries) > 0, do: 0, else: -1

    {:noreply,
     socket
     |> assign(:query, query)
     |> assign(:filtered_countries, filtered_countries)
     |> assign(:focused_index, focused_index)
     |> assign(:show_dropdown, true)}
  end

  def handle_event("select_country", %{"name" => name}, socket) do
    {:noreply,
     socket
     |> assign(:value, name)
     |> assign(:selected_country, {name, name})
     |> assign(:query, "")
     |> assign(:show_dropdown, false)
     |> push_event("country-selected", %{value: name})}
  end

  def handle_event("clear_selection", _params, socket) do
    {:noreply,
     socket
     |> assign(:value, "")
     |> assign(:selected_country, nil)
     |> assign(:query, "")
     |> assign(:filtered_countries, socket.assigns.all_countries)
     |> assign(:show_dropdown, false)}
  end

  def render(assigns) do
    ~H"""
    <div class="relative" id={@id}>
      <div class="relative">
        <input
          type="text"
          id={"#{@id}-input"}
          value={display_value(@selected_country, @query)}
          phx-focus="show_dropdown"
          phx-keyup="handle_key"
          phx-target={@myself}
          phx-debounce="150"
          autocomplete="off"
          placeholder="Search or select a country..."
          class="block w-full px-3 py-2 pr-10 text-white bg-dark-900 border border-dark-700 rounded-md shadow-sm sm:text-sm focus:ring-primary-500 focus:border-primary-500 cursor-pointer"
        />

        <%= if @selected_country do %>
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
            name="hero-chevron-down"
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
        <div :if={@filtered_countries == []} class="px-3 py-2 text-gray-400 text-sm">
          No countries found
        </div>

        <div
          :for={{{name, code}, index} <- Enum.with_index(@filtered_countries)}
          class={[
            "px-3 py-2 cursor-pointer text-sm border-b border-dark-700 last:border-b-0 transition-colors",
            index == @focused_index && "bg-primary-500 text-white",
            index != @focused_index && "text-gray-300 hover:bg-dark-700"
          ]}
          phx-click="select_country"
          phx-value-name={name}
          phx-value-code={code}
          phx-target={@myself}
        >
          <div class="flex items-center justify-between">
            <div class="font-medium">{name}</div>
            <div class={[
              "text-xs",
              index == @focused_index && "text-white/70",
              index != @focused_index && "text-gray-500"
            ]}>
              {code}
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp display_value(nil, query), do: query
  defp display_value({name, _code}, ""), do: name
  defp display_value(_selected, query), do: query
end
